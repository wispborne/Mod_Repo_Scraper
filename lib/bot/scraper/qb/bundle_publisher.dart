import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'download_resolver.dart';
import 'html_processor.dart';
import 'json_data_store.dart';
import 'llm/extraction_store.dart';
import 'models/assumed_download.dart';
import 'models/bundle_meta.dart';
import 'models/forum_data_bundle.dart';
import 'models/mod_detail.dart';
import 'models/post_extraction.dart';
import 'models/scrape_job.dart';
import 'mod_thread_filter.dart';
import '../../../catalog/discord_posts.dart';

class BundlePublisher {
  /// The old bundle, which old TriOS installs read. Written without the
  /// Discord answers until the switch to the catalog, then frozen.
  static const String _bundleFileName = 'forum-data-bundle.json';

  /// The mod details, which new readers use: the old bundle plus the Discord
  /// answers.
  static const String detailsFileName = 'mod-catalog-details.json';

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
  ///
  /// [leaveOutTopics] and [leaveOutThreads] are the forum topics and Discord
  /// threads whose every mod was taken down. They are left out of the index,
  /// the details, the rules-only downloads and the Discord answers.
  Future<ForumDataBundle> createBundle({
    ScrapeResult? scrapeResult,
    Set<int> leaveOutTopics = const {},
    Set<String> leaveOutThreads = const {},
  }) async {
    _log.info('Creating forum data bundle...');

    final rawIndex = await _store.loadIndex();
    final sortedIndex = rawIndex
        .where((s) => !leaveOutTopics.contains(s.topicId))
        .toList()
      ..sort((a, b) => a.topicId.compareTo(b.topicId));
    if (leaveOutTopics.isNotEmpty || leaveOutThreads.isNotEmpty) {
      _log.info('Leaving out ${leaveOutTopics.length} forum topic(s) and '
          '${leaveOutThreads.length} Discord thread(s) whose mods were all '
          'taken down.');
    }

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

    // The keep/drop rule itself lives in `mod_thread_filter.dart`, because the
    // viewer applies the same one when it works out what a run has changed so
    // far.
    final droppedTopicIds = <int>[];
    final droppedLines = <String>[];
    final index = indexWithLlm.where((s) {
      if (keepThreadInBundle(
          title: s.title,
          llmSaidMod: llmIsModByTopic[s.topicId],
          inModIndex: s.inModIndex)) {
        return true;
      }
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
        // The author's own later posts, cleaned the same way. They ride beside
        // the first post rather than joining it: `contentHtml` still means the
        // first post alone, which is what TriOS already reads.
        extraPosts: [
          for (final post in detail.extraPosts)
            QbForumPost(
              contentHtml: HtmlProcessor.stripSessionIds(post.contentHtml),
              images: [
                for (final img in post.images)
                  ImageRef(
                    originalUrl: img.originalUrl,
                    localPath: '',
                    alt: img.alt,
                  ),
              ],
              links: post.links,
              postDate: post.postDate,
              lastEditDate: post.lastEditDate,
            ),
        ],
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

    final discordThreads = [
      for (final thread in _discordThreads())
        if (!leaveOutThreads.contains(thread.threadId)) thread,
    ];

    final bundle = ForumDataBundle(
      updatedAt: updatedAt,
      meta: meta,
      index: index,
      details: details,
      assumedDownloads: assumedDownloads,
      discordThreads: discordThreads,
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

  /// The LLM's answers for the Discord threads the last Discord scrape saved,
  /// in thread id order. A thread with no answer, or an answer with no mods,
  /// is left out. Only the thread's id, link and name go with it — never the
  /// text of its messages. A file attached on Discord is left out of the
  /// downloads, because its address stops working within a day
  /// ([isDiscordAttachmentDownload]); the mod's Discord link leads to it.
  List<DiscordThreadAnswer> _discordThreads() {
    final store = _llmStore;
    if (store == null) return const [];
    DiscordPostsFile saved;
    try {
      saved = DiscordPostsFile.read(File(p.join(_store.basePath, DiscordPostsFile.fileName)));
    } catch (e) {
      _log.warning('Could not read the saved Discord threads; their answers '
          'go out without names or links: $e');
      saved = const DiscordPostsFile();
    }
    final answers = <DiscordThreadAnswer>[];
    final ids = store.discordEntries.keys.toList()..sort();
    for (final id in ids) {
      final mods = store.discordEntries[id]!.mods;
      if (mods.isEmpty) continue;
      final thread = saved.threads[id];
      answers.add(DiscordThreadAnswer(
        threadId: id,
        url: thread?.url ?? '',
        name: thread?.name ?? '',
        mods: [
          for (final mod in mods)
            mod.copyWith(downloads: [
              for (final download in mod.downloads)
                if (!isDiscordAttachmentDownload(download)) download,
            ]),
        ],
      ));
    }
    return answers;
  }

  /// One Discord answer as it is written out: the download confidence the
  /// resolver guessed is taken off, since a Discord entry carries no scores.
  static Map<String, dynamic> discordThreadForPublishing(DiscordThreadAnswer thread) {
    final map = thread.toMap();
    for (final mod in (map['mods'] as List?) ?? const []) {
      for (final download in ((mod as Map)['downloads'] as List?) ?? const []) {
        (download as Map).remove('confidence');
      }
    }
    return map;
  }

  /// Writes the bundle JSON to the local data path: the old bundle without the
  /// Discord answers, and `mod-catalog-details.json` with them.
  Future<void> writeLocal(ForumDataBundle bundle) async {
    await Directory(_outputPath).create(recursive: true);
    final encoder = const JsonEncoder.withIndent('  ');

    final path = p.join(_outputPath, _bundleFileName);
    final old = bundle.toMap()..remove('discordThreads');
    await File(path).writeAsString(encoder.convert(old));
    _log.info('Bundle written to $path');

    final detailsPath = p.join(_outputPath, detailsFileName);
    await File(detailsPath).writeAsString(encoder.convert({
      ...bundle.toMap(),
      'discordThreads': [
        for (final thread in bundle.discordThreads ?? const <DiscordThreadAnswer>[])
          discordThreadForPublishing(thread),
      ],
    }));
    _log.info('Mod details written to $detailsPath '
        '(${bundle.discordThreads?.length ?? 0} Discord threads)');
  }
}
