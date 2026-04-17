import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'download_resolver.dart';
import 'json_data_store.dart';
import 'models/assumed_download.dart';
import 'models/forum_data_bundle.dart';
import 'models/mod_detail.dart';

class BundlePublisher {
  static const String _bundleFileName = 'forum-data-bundle.json';

  final JsonDataStore _store;
  final QbDownloadResolver _resolver;
  final String _dataPath;
  final String? _repoPath;
  final Logger _log;

  BundlePublisher({
    required JsonDataStore store,
    required QbDownloadResolver resolver,
    required String dataPath,
    String? repoPath,
    Logger? logger,
  })  : _store = store,
        _resolver = resolver,
        _dataPath = dataPath,
        _repoPath = repoPath,
        _log = logger ?? Logger('BundlePublisher');

  /// Assembles a [ForumDataBundle] from the data store and resolver cache.
  Future<ForumDataBundle> createBundle() async {
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

    final bundle = ForumDataBundle(
      updatedAt: updatedAt,
      index: index,
      details: details,
      assumedDownloads: assumedDownloads,
    );

    _log.info(
        'Bundle created: ${index.length} mods, ${details.length} details, '
        '${assumedDownloads.length} assumed-download entries, '
        'updatedAt=${updatedAt.toUtc().toIso8601String()}');

    return bundle;
  }

  /// Writes the bundle JSON to the local data path.
  Future<void> writeLocal(ForumDataBundle bundle) async {
    final path = p.join(_dataPath, _bundleFileName);
    final json = const JsonEncoder.withIndent('  ').convert(bundle.toMap());
    await File(path).writeAsString(json);
    _log.info('Bundle written to $path');
  }

  /// Publishes the bundle to the configured git repo clone.
  /// No-ops when [_repoPath] is null or empty.
  Future<void> publish(ForumDataBundle bundle) async {
    if (_repoPath == null || _repoPath!.isEmpty) {
      _log.fine('Publishing skipped: repoPath not configured');
      return;
    }

    if (!Directory(_repoPath!).existsSync()) {
      _log.warning('Publishing skipped: repoPath does not exist ($_repoPath)');
      return;
    }

    final bundlePath = p.join(_repoPath!, _bundleFileName);
    _log.info('Publishing forum data bundle to $bundlePath');

    final json = const JsonEncoder.withIndent('  ').convert(bundle.toMap());
    await File(bundlePath).writeAsString(json);

    final commitMessage =
        'scrape update: ${bundle.updatedAt.toUtc().toIso8601String()}';

    await _runGit(['add', _bundleFileName]);
    final committed = await _runGit(['commit', '-m', commitMessage]);

    if (!committed) {
      _log.info('Bundle unchanged since last publish, skipping push');
      return;
    }

    await _runGit(['push']);
    _log.info(
        'Bundle pushed (${bundle.updatedAt.toUtc().toIso8601String()})');
  }

  /// Runs a git command inside [_repoPath]. Returns true on exit code 0.
  Future<bool> _runGit(List<String> args) async {
    final result = await Process.run(
      'git',
      ['-C', _repoPath!, ...args],
    );

    if (result.exitCode != 0) {
      final stderr = (result.stderr as String).trim();
      // "nothing to commit" is not a real error.
      if (args.first == 'commit' && stderr.contains('nothing to commit')) {
        return false;
      }
      _log.warning(
          'git ${args.first} exited ${result.exitCode}: $stderr');
      return false;
    }

    final stdout = (result.stdout as String).trim();
    if (stdout.isNotEmpty) {
      _log.fine('git ${args.first}: $stdout');
    }

    return true;
  }
}
