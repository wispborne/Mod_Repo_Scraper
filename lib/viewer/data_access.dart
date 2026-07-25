import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../bot/scraper/qb/download_resolver.dart';
import '../bot/scraper/qb/llm/extraction_store.dart';
import '../bot/scraper/qb/models/mod_detail.dart';
import '../bot/scraper/qb/models/mod_summary.dart';
import '../manager/bundle_snapshot_store.dart';
import '../manager/merge_snapshot_store.dart';

/// One file the raw-file/log endpoints are allowed to serve, addressed by a
/// short [id] and never by a path the client supplies (D7). [hint] tells the
/// user what run produces the file when it is missing on disk.
class AllowlistEntry {
  final String id;
  final File file;
  final String hint;

  AllowlistEntry(this.id, this.file, this.hint);
}

/// Caches a single parsed file in memory, re-reading only when the file's
/// last-modified time changes (D4). Returns null when the file is absent.
class _MtimeCache<T> {
  final File file;
  final T Function(String contents) parse;

  DateTime? _mtime;
  T? _value;

  _MtimeCache(this.file, this.parse);

  T? get() {
    if (!file.existsSync()) {
      _mtime = null;
      _value = null;
      return null;
    }
    final mtime = file.statSync().modified;
    if (_value == null || _mtime != mtime) {
      _value = parse(file.readAsStringSync());
      _mtime = mtime;
    }
    return _value;
  }
}

/// Reads the scraper's output files fresh (mtime-cached per D4) and exposes them
/// as typed values the API handlers join and filter. Never writes anything, and
/// never opens `config.properties`.
class DataAccess {
  final String dataDir;
  final String outputsDir;
  final String rootDir;

  late final File _indexFile = File(p.join(dataDir, 'mods-index.json'));
  late final File _llmCacheFile =
      File(p.join(dataDir, 'llm-extraction-cache.json'));
  late final File _llmTestFile = File(p.join(dataDir, 'llm-test-output.json'));
  late final File _assumedFile =
      File(p.join(dataDir, 'assumed-downloads-cache.json'));
  late final File _modRepoFile = File(p.join(outputsDir, 'ModRepo.json'));
  late final File _bundleFile =
      File(p.join(outputsDir, 'forum-data-bundle.json'));
  late final File _mergeDebugFile = File(p.join(rootDir, 'merge-debug.json'));
  late final File _logFile = File(p.join(rootDir, 'ModRepo.log'));
  late final Directory _modsDir = Directory(p.join(dataDir, 'mods'));

  late final _MtimeCache<List<QbModSummary>> _indexCache = _MtimeCache(
    _indexFile,
    (s) => (jsonDecode(s) as List<dynamic>)
        .map((e) => QbModSummaryMapper.fromMap(e as Map<String, dynamic>))
        .toList(),
  );

  late final _MtimeCache<Map<int, LlmStoreEntry>> _llmCache = _MtimeCache(
    _llmCacheFile,
    (s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      final out = <int, LlmStoreEntry>{};
      for (final e in map.entries) {
        final id = int.tryParse(e.key);
        if (id == null) continue;
        out[id] = LlmStoreEntry.fromJson(e.value as Map<String, dynamic>);
      }
      return out;
    },
  );

  late final _MtimeCache<Map<int, List<DownloadCandidate>>> _assumedCache =
      _MtimeCache(
    _assumedFile,
    (s) {
      final map = jsonDecode(s) as Map<String, dynamic>;
      final out = <int, List<DownloadCandidate>>{};
      for (final e in map.entries) {
        final id = int.tryParse(e.key);
        if (id == null) continue;
        final entry = e.value as Map<String, dynamic>;
        final candidates = (entry['candidates'] as List<dynamic>? ?? [])
            .map((c) => DownloadCandidate.fromJson(c as Map<String, dynamic>))
            .toList();
        out[id] = candidates;
      }
      return out;
    },
  );

  late final _MtimeCache<Map<String, dynamic>> _modRepoCache = _MtimeCache(
      _modRepoFile, (s) => jsonDecode(s) as Map<String, dynamic>);
  late final _MtimeCache<Map<String, dynamic>> _bundleCache = _MtimeCache(
      _bundleFile, (s) => jsonDecode(s) as Map<String, dynamic>);
  late final _MtimeCache<Map<String, dynamic>> _mergeDebugCache = _MtimeCache(
      _mergeDebugFile, (s) => jsonDecode(s) as Map<String, dynamic>);
  late final _MtimeCache<Map<String, dynamic>> _llmTestCache = _MtimeCache(
      _llmTestFile, (s) => jsonDecode(s) as Map<String, dynamic>);

  // Placeholder-detail scan (D4), rebuilt when mods/ or the index changes.
  DateTime? _placeholderModsMtime;
  DateTime? _placeholderIndexMtime;
  Set<int>? _placeholderIds;

  DataAccess({
    required this.dataDir,
    required this.outputsDir,
    required this.rootDir,
  });

  /// The fixed allowlist of files the raw-file and log endpoints may serve (D7).
  late final List<AllowlistEntry> allowlist = [
    AllowlistEntry('mods-index', _indexFile, 'Run the QB scraper.'),
    AllowlistEntry('llm-extraction-cache', _llmCacheFile,
        'Run the scraper with LLM extraction enabled.'),
    AllowlistEntry('llm-test-output', _llmTestFile,
        'Run the scraper with LLM test mode enabled.'),
    AllowlistEntry(
        'assumed-downloads-cache', _assumedFile, 'Run the QB scraper.'),
    AllowlistEntry('modrepo', _modRepoFile, 'Run the mod repo merge.'),
    AllowlistEntry('forum-data-bundle', _bundleFile,
        'Run the QB scraper to publish the bundle.'),
    AllowlistEntry('merge-debug', _mergeDebugFile,
        'Run the scraper with modrepo_merge_debug enabled.'),
    AllowlistEntry('log', _logFile, 'Run the scraper.'),
  ];

  AllowlistEntry? allowlistById(String id) {
    for (final e in allowlist) {
      if (e.id == id) return e;
    }
    return null;
  }

  // --- Typed loaders (null when the backing file is absent) ---

  List<QbModSummary>? get index => _indexCache.get();

  Map<int, LlmStoreEntry>? get llmCache => _llmCache.get();

  Map<int, List<DownloadCandidate>>? get assumedDownloads => _assumedCache.get();

  Map<String, dynamic>? get modRepo => _modRepoCache.get();

  Map<String, dynamic>? get bundle => _bundleCache.get();

  Map<String, dynamic>? get mergeDebug => _mergeDebugCache.get();

  Map<String, dynamic>? get llmTest => _llmTestCache.get();

  bool get mergeDebugExists => _mergeDebugFile.existsSync();

  // --- Saved merges ---

  late final MergeSnapshotStore mergeSnapshots = MergeSnapshotStore(dataDir);

  /// The last couple of snapshots read — merges and bundles alike — so paging
  /// through one or comparing two doesn't unzip megabytes again on every
  /// request. Snapshots never change once written, so there is nothing to
  /// invalidate.
  final Map<String, Map<String, dynamic>> _snapshotCache = {};
  final List<String> _snapshotOrder = [];

  /// Which snapshots are being held, oldest use first. Read only, and only so a
  /// test can check that walking every snapshot for a topic's history does not
  /// push out the pair a comparison is working with.
  List<String> get heldSnapshots => List.unmodifiable(_snapshotOrder);

  /// Every saved merge, newest first.
  List<MergeSnapshotInfo> mergeRuns() => mergeSnapshots.list();

  /// One saved merge, or null when there is no such run or it can't be read.
  Map<String, dynamic>? mergeRun(String id) =>
      _held('merge:$id', () => mergeSnapshots.readRaw(id));

  // --- Saved bundles ---

  late final BundleSnapshotStore bundleSnapshots = BundleSnapshotStore(dataDir);

  /// Every saved bundle, newest first.
  List<BundleSnapshotInfo> bundleRuns() => bundleSnapshots.list();

  /// The saved bundle from just before [id], for "what did this run change?".
  String? bundleRunBefore(String id) => bundleSnapshots.idBefore(id);

  /// One saved bundle, or null when there is no such run or it can't be read.
  Map<String, dynamic>? bundleRun(String id) =>
      _held('bundle:$id', () => bundleSnapshots.readRaw(id));

  /// One saved bundle, read straight from disk and not held.
  ///
  /// Working out a topic's history reads every snapshot in turn. Putting them
  /// all through the small holding pen below would push out the pair the
  /// compare page is working with and gain nothing, since each is wanted once.
  Map<String, dynamic>? bundleRunUncached(String id) =>
      bundleSnapshots.readRaw(id);

  /// Reads a snapshot through the small holding pen above.
  Map<String, dynamic>? _held(
      String key, Map<String, dynamic>? Function() read) {
    final already = _snapshotCache[key];
    if (already != null) return already;

    final fresh = read();
    if (fresh == null) return null;

    _snapshotCache[key] = fresh;
    _snapshotOrder.add(key);
    while (_snapshotOrder.length > 2) {
      _snapshotCache.remove(_snapshotOrder.removeAt(0));
    }
    return fresh;
  }

  /// Reads one topic's detail on demand, uncached (D4).
  QbModDetail? loadDetail(int topicId) {
    final file =
        File(p.join(dataDir, 'mods', topicId.toString(), 'detail.json'));
    if (!file.existsSync()) return null;
    return QbModDetailMapper.fromMap(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
  }

  /// Set of topic ids whose detail.json is a placeholder (D4). Rebuilt only when
  /// the mods/ directory mtime or the index mtime changes.
  Set<int> placeholderDetailIds() {
    final modsMtime =
        _modsDir.existsSync() ? _modsDir.statSync().modified : null;
    final indexMtime =
        _indexFile.existsSync() ? _indexFile.statSync().modified : null;
    if (_placeholderIds != null &&
        _placeholderModsMtime == modsMtime &&
        _placeholderIndexMtime == indexMtime) {
      return _placeholderIds!;
    }

    final ids = <int>{};
    if (_modsDir.existsSync()) {
      for (final entry in _modsDir.listSync()) {
        if (entry is! Directory) continue;
        final topicId = int.tryParse(p.basename(entry.path));
        if (topicId == null) continue;
        final detail = File(p.join(entry.path, 'detail.json'));
        if (!detail.existsSync()) continue;
        try {
          final map = jsonDecode(detail.readAsStringSync());
          if (map is Map && map['isPlaceholderDetail'] == true) {
            ids.add(topicId);
          }
        } catch (_) {
          // Skip unreadable detail files rather than failing the whole scan.
        }
      }
    }

    _placeholderIds = ids;
    _placeholderModsMtime = modsMtime;
    _placeholderIndexMtime = indexMtime;
    return ids;
  }
}
