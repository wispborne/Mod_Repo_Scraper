import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'download_resolver.dart';
import 'forum_constants.dart';
import 'html_processor.dart';
import 'json_data_store.dart';
import 'llm/extraction_store.dart';
import 'models/assumed_download.dart';
import 'models/bundle_meta.dart';
import 'models/forum_data_bundle.dart';
import 'models/mod_detail.dart';
import 'models/post_extraction.dart';
import 'models/scrape_job.dart';

class BundlePublisher {
  static const String _bundleFileName = 'forum-data-bundle.json';

  final JsonDataStore _store;
  final QbDownloadResolver _resolver;

  /// When present (LLM feature on), each thread's mods list is read from here
  /// and attached to the matching `index` item's `llm` field. Null means no
  /// `llm` field is written on any index item.
  final LlmExtractionStore? _llmStore;

  final String _outputPath;
  final Logger _log;

  BundlePublisher({
    required JsonDataStore store,
    required QbDownloadResolver resolver,
    required String outputPath,
    LlmExtractionStore? llmStore,
    Logger? logger,
  })  : _store = store,
        _resolver = resolver,
        _llmStore = llmStore,
        _outputPath = outputPath,
        _log = logger ?? Logger('BundlePublisher');

  /// Assembles a [ForumDataBundle] from the data store and resolver cache.
  Future<ForumDataBundle> createBundle({ScrapeResult? scrapeResult}) async {
    _log.info('Creating forum data bundle...');

    final rawIndex = await _store.loadIndex();
    final sortedIndex = rawIndex.toList()
      ..sort((a, b) => a.topicId.compareTo(b.topicId));

    // The LLM output hangs off each thread. Read each thread's mods list from
    // the store and attach it to the matching index item; a thread that produced
    // nothing keeps no `llm` field. Missing entirely when the feature is off.
    final llmByTopic = <int, LlmThreadData>{};
    // The mod/not-mod call for every thread the LLM actually judged, including
    // ones that produced no mods (those never reach [llmByTopic]). Used by the
    // drop filter below.
    final llmIsModByTopic = <int, bool>{};
    if (_llmStore != null) {
      for (final entry in _llmStore!.entries.entries) {
        final data = entry.value.toThreadData();
        // The mod/not-mod call comes off the cache entry — it drives the
        // keep/drop filter but is not published on the thread's `llm` field.
        llmIsModByTopic[entry.key] = entry.value.isMod;
        if (!data.isEmpty) llmByTopic[entry.key] = data;
      }
    }
    final indexWithLlm = [
      for (final s in sortedIndex)
        llmByTopic[s.topicId] != null ? s.copyWith(llm: llmByTopic[s.topicId]) : s,
    ];

    // Drop a thread only when BOTH signals agree it is not a mod: the LLM judged
    // it a non-mod AND its title carries no game-version tag. A version tag, a
    // missing judgment (LLM off, not yet run, or bailed), or a positive call all
    // keep the thread — so we never drop on the LLM's word alone.
    final droppedTopicIds = <int>[];
    final droppedLines = <String>[];
    final index = indexWithLlm.where((s) {
      final judged = llmIsModByTopic[s.topicId];
      if (judged != false) return true;
      if (ForumConstants.gameVersionRegex.hasMatch(s.title)) return true;
      droppedTopicIds.add(s.topicId);
      droppedLines.add('${s.topicId}: ${s.title}');
      return false;
    }).toList();
    final keptTopicIds = index.map((s) => s.topicId).toSet();

    final multiModThreadCount =
        llmByTopic.values.where((d) => d.mods.length > 1).length;

    final details = <String, QbModDetail>{};
    for (final summary in index) {
      final detail = await _store.loadDetail(summary.topicId);
      if (detail == null) continue;

      // Strip local image paths — meaningless on remote machines.
      final strippedImages = detail.images
          .map((img) => ImageRef(
                originalUrl: img.originalUrl,
                localPath: '',
                alt: img.alt,
              ))
          .toList();

      details[summary.topicId.toString()] = QbModDetail(
        topicId: detail.topicId,
        title: detail.title,
        category: detail.category ?? summary.category,
        gameVersion: detail.gameVersion,
        author: detail.author,
        authorTitle: detail.authorTitle,
        authorPostCount: detail.authorPostCount,
        authorAvatarPath: detail.authorAvatarPath,
        postDate: detail.postDate,
        lastEditDate: detail.lastEditDate,
        // Strip the forum session token here too, so the published bundle is
        // clean even for topics whose stored detail was saved before this was
        // fixed and has not been re-scraped yet. A no-op once the stored HTML is
        // already clean.
        contentHtml: HtmlProcessor.stripSessionIds(detail.contentHtml),
        images: strippedImages,
        links: detail.links,
        scrapedAt: detail.scrapedAt,
        isPlaceholderDetail: detail.isPlaceholderDetail,
      );
    }

    // Rules-only downloads, sorted by topicId. This is always exactly what the
    // resolver found — the LLM never overwrites it, so clients with the LLM
    // turned off see a stable, rules-only list.
    final rawCandidates = _resolver.getAllCandidates();
    final assumedDownloads = <String, List<AssumedDownloadCandidate>>{};
    final ruleTopicIds = rawCandidates.keys.toList()..sort();
    for (final topicId in ruleTopicIds) {
      // Skip threads the drop filter removed, so the rules-only list stays in
      // step with the index.
      if (!keptTopicIds.contains(topicId)) continue;
      final entries = (rawCandidates[topicId] ?? const [])
          .map((c) => AssumedDownloadCandidate.fromDownloadCandidate(c))
          .toList();
      if (entries.isEmpty) continue;
      assumedDownloads[topicId.toString()] = entries;
    }

    // updatedAt = max scrapedAt across the index.
    final updatedAt = index.isNotEmpty
        ? index.map((s) => s.scrapedAt).reduce(
            (a, b) => a.isAfter(b) ? a : b)
        : DateTime.now().toUtc();

    final placeholderDetailCount =
        details.values.where((d) => d.isPlaceholderDetail).length;

    final meta = BundleMeta(
      generatedAt: DateTime.now().toUtc(),
      totalMods: index.length,
      totalDetails: details.length,
      totalAssumedDownloadEntries: assumedDownloads.length,
      placeholderDetailCount: placeholderDetailCount,
      scrapeDurationSeconds: scrapeResult?.duration.inSeconds,
      modsScraped: scrapeResult?.modsScraped,
      imagesDownloaded: scrapeResult?.imagesDownloaded,
      errors: scrapeResult?.errors,
    );

    final bundle = ForumDataBundle(
      updatedAt: updatedAt,
      meta: meta,
      index: index,
      details: details,
      assumedDownloads: assumedDownloads,
    );

    if (droppedTopicIds.isNotEmpty) {
      _log.info(
          'Dropped ${droppedTopicIds.length} thread(s) as non-mod (LLM said not '
          'a mod and the title has no game-version tag):\n'
          '${droppedLines.join('\n')}');
    }

    _log.info(
        'Bundle created: ${index.length} mods, ${details.length} details, '
        '${assumedDownloads.length} rules-only assumed-download entries, '
        '${llmByTopic.length} threads with LLM output '
        '($multiModThreadCount multi-mod), '
        '${droppedTopicIds.length} dropped as non-mod, '
        '$placeholderDetailCount placeholder details, '
        'updatedAt=${updatedAt.toUtc().toIso8601String()}');

    return bundle;
  }

  /// Writes the bundle JSON to the local data path.
  Future<void> writeLocal(ForumDataBundle bundle) async {
    await Directory(_outputPath).create(recursive: true);
    final path = p.join(_outputPath, _bundleFileName);
    final json = const JsonEncoder.withIndent('  ').convert(bundle.toMap());
    await File(path).writeAsString(json);
    _log.info('Bundle written to $path');
  }
}
