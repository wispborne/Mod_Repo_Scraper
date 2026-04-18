import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'download_resolver.dart';
import 'json_data_store.dart';
import 'models/assumed_download.dart';
import 'models/bundle_meta.dart';
import 'models/forum_data_bundle.dart';
import 'models/mod_detail.dart';
import 'models/scrape_job.dart';

class BundlePublisher {
  static const String _bundleFileName = 'forum-data-bundle.json';

  final JsonDataStore _store;
  final QbDownloadResolver _resolver;
  final String _outputPath;
  final Logger _log;

  BundlePublisher({
    required JsonDataStore store,
    required QbDownloadResolver resolver,
    required String outputPath,
    Logger? logger,
  })  : _store = store,
        _resolver = resolver,
        _outputPath = outputPath,
        _log = logger ?? Logger('BundlePublisher');

  /// Assembles a [ForumDataBundle] from the data store and resolver cache.
  Future<ForumDataBundle> createBundle({ScrapeResult? scrapeResult}) async {
    _log.info('Creating forum data bundle...');

    final rawIndex = await _store.loadIndex();
    final index = rawIndex.toList()
      ..sort((a, b) => a.topicId.compareTo(b.topicId));

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
        contentHtml: detail.contentHtml,
        images: strippedImages,
        links: detail.links,
        scrapedAt: detail.scrapedAt,
        isPlaceholderDetail: detail.isPlaceholderDetail,
      );
    }

    // Collect assumed downloads sorted by topicId.
    final rawCandidates = _resolver.getAllCandidates();
    final sortedKeys = rawCandidates.keys.toList()..sort();
    final assumedDownloads = <String, List<AssumedDownloadCandidate>>{};
    for (final topicId in sortedKeys) {
      final candidates = rawCandidates[topicId]!;
      if (candidates.isEmpty) continue;
      assumedDownloads[topicId.toString()] = candidates
          .map((c) => AssumedDownloadCandidate.fromDownloadCandidate(c))
          .toList();
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

    _log.info(
        'Bundle created: ${index.length} mods, ${details.length} details, '
        '${assumedDownloads.length} assumed-download entries, '
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
