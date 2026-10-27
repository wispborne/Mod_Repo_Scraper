import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../bot/scraper/qb/download_resolver.dart';
import '../bot/scraper/qb/llm/extraction_store.dart';
import '../bot/scraper/qb/llm/picture_caption_store.dart';
import '../bot/scraper/qb/models/mod_detail.dart';
import '../bot/scraper/qb/models/mod_summary.dart';
import '../catalog/discord_posts.dart';
import '../manager/bundle_snapshot_store.dart';
import '../manager/merge_snapshot_store.dart';
import 'working_bundle.dart';

/// One file the raw-file/log endpoints are allowed to serve, addressed by a
/// short [id] and never by a path the client supplies. [hint] tells the
/// user what run produces the file when it is missing on disk.
class AllowlistEntry {
  final String id;
  final File file;
  final String hint;

  AllowlistEntry(this.id, this.file, this.hint);
}

/// Caches a single parsed file in memory, re-reading only when the file's
/// last-modified time changes. Returns null when the file is absent.
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

/// Read-only access to scraper outputs, cached by file modification time.
/// Does not open `config.properties`.
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
  late final File _modRepoFile = File(p.join(outputsDir, 'mod-catalog.json'));
  late final File _bundleFile =
      File(p.join(outputsDir, 'mod-catalog-details.json'));
  late final File _mergeDebugFile = File(p.join(rootDir, 'merge-debug.json'));
  late final File _logFile = File(p.join(rootDir, 'ModRepo.log'));
  late final Directory _modsDir = Directory(p.join(dataDir, 'mods'));
  late final File _discordPostsFile =
      File(p.join(dataDir, DiscordPostsFile.fileName));
  late final File _pictureCaptionsFile =
      File(p.join(dataDir, PictureCaptionStore.fileName));

  /// What the model saw in each picture, as saved: keyed the way
  /// [PictureCaptionStore.keyFor] keys them.
  late final _MtimeCache<Map<String, Map<String, dynamic>>> _pictureCaptionsCache =
      _MtimeCache(
    _pictureCaptionsFile,
    (s) {
      final pictures = (jsonDecode(s) as Map<String, dynamic>)['pictures'];
      if (pictures is! Map<String, dynamic>) return const {};
      return {
        for (final e in pictures.entries)
          if (e.value is Map<String, dynamic>) e.key: e.value as Map<String, dynamic>,
      };
    },
  );

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

  /// The Discord threads' LLM answers, keyed by thread id. They sit in the
  /// same file as the forum's, under `discord:<thread id>`.
  late final _MtimeCache<Map<String, LlmStoreEntry>> _discordLlmCache =
      _MtimeCache(
    _llmCacheFile,
    (s) => {
      for (final e in (jsonDecode(s) as Map<String, dynamic>).entries)
        if (e.key.startsWith('discord:'))
          e.key.substring('discord:'.length):
              LlmStoreEntry.fromJson(e.value as Map<String, dynamic>),
    },
  );

  /// The download rules' answers for Discord threads, keyed by thread id.
  late final _MtimeCache<Map<String, List<DownloadCandidate>>>
      _discordAssumedCache = _MtimeCache(
    _assumedFile,
    (s) => {
      for (final e in (jsonDecode(s) as Map<String, dynamic>).entries)
        if (e.key.startsWith('discord:'))
          e.key.substring('discord:'.length): [
            for (final c in ((e.value as Map<String, dynamic>)['candidates']
                    as List<dynamic>? ??
                const []))
              DownloadCandidate.fromJson(c as Map<String, dynamic>),
          ],
    },
  );

  late final _MtimeCache<DiscordPostsFile> _discordPostsCache = _MtimeCache(
    _discordPostsFile,
    (_) => DiscordPostsFile.read(_discordPostsFile),
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

  /// The names the Discord reader gave each thread, keyed by thread id, from
  /// the ModRepo pipeline's `discord_cache.json`.
  late final _MtimeCache<Map<String, List<String>>> _discordAuthorsCache = _MtimeCache(
    File(p.join(rootDir, 'discord_cache.json')),
    (s) {
      final out = <String, List<String>>{};
      final items = (jsonDecode(s) as Map<String, dynamic>)['items'] as List<dynamic>? ?? const [];
      for (final item in items.whereType<Map<String, dynamic>>()) {
        final url = '${(item['urls'] as Map?)?['Discord'] ?? ''}';
        final thread = RegExp(r'/channels/\d+/(\d+)').firstMatch(url)?.group(1);
        if (thread == null) continue;
        out.putIfAbsent(thread, () => []).addAll([
          for (final name in item['authorsList'] as List<dynamic>? ?? const []) '$name',
        ]);
      }
      return out;
    },
  );

  late final _MtimeCache<Map<String, dynamic>> _modRepoCache =
      _MtimeCache(_modRepoFile, (s) => jsonDecode(s) as Map<String, dynamic>);
  late final _MtimeCache<Map<String, dynamic>> _bundleCache =
      _MtimeCache(_bundleFile, (s) => jsonDecode(s) as Map<String, dynamic>);
  late final _MtimeCache<Map<String, dynamic>> _mergeDebugCache = _MtimeCache(
      _mergeDebugFile, (s) => jsonDecode(s) as Map<String, dynamic>);
  late final _MtimeCache<Map<String, dynamic>> _llmTestCache =
      _MtimeCache(_llmTestFile, (s) => jsonDecode(s) as Map<String, dynamic>);

  // Invalidate the placeholder scan when mods/ or the index changes.
  DateTime? _placeholderModsMtime;
  DateTime? _placeholderIndexMtime;
  Set<int>? _placeholderIds;

  DataAccess({
    required this.dataDir,
    required this.outputsDir,
    required this.rootDir,
  });

  /// The fixed allowlist for raw-file and log endpoints.
  late final List<AllowlistEntry> allowlist = [
    AllowlistEntry('mods-index', _indexFile, 'Run the QB scraper.'),
    AllowlistEntry('llm-extraction-cache', _llmCacheFile,
        'Run the scraper with LLM extraction enabled.'),
    AllowlistEntry('picture-captions', _pictureCaptionsFile,
        'Run the scraper with llm_caption_pictures on.'),
    AllowlistEntry('llm-test-output', _llmTestFile,
        'Run the scraper with LLM test mode enabled.'),
    AllowlistEntry(
        'assumed-downloads-cache', _assumedFile, 'Run the QB scraper.'),
    AllowlistEntry('modrepo', _modRepoFile, 'Run the mod repo merge.'),
    AllowlistEntry('forum-data-bundle', _bundleFile,
        'Run the QB scraper to publish the mod details.'),
    AllowlistEntry('merge-debug', _mergeDebugFile,
        'Run the scraper with modrepo_merge_debug enabled.'),
    AllowlistEntry('log', _logFile, 'Run the scraper.'),
    AllowlistEntry('discord-posts', _discordPostsFile,
        'Run a ModRepo scrape that includes Discord.'),
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

  /// What the model saw in [url], as saved — its kind and caption, or why it
  /// could not be read — or null when it has not been looked at.
  Map<String, dynamic>? pictureCaption(String url) =>
      _pictureCaptionsCache.get()?[PictureCaptionStore.keyFor(url)];

  Map<int, List<DownloadCandidate>>? get assumedDownloads =>
      _assumedCache.get();

  Map<String, dynamic>? get modRepo => _modRepoCache.get();

  /// The names the Discord reader gave each thread, or null when Discord has
  /// never been scraped here.
  Map<String, List<String>>? get discordAuthors => _discordAuthorsCache.get();

  /// The Discord threads the last Discord scrape saved, or null when there is
  /// no such file yet.
  DiscordPostsFile? get discordPosts => _discordPostsCache.get();

  /// The LLM's answers for Discord threads, keyed by thread id.
  Map<String, LlmStoreEntry>? get discordLlmCache => _discordLlmCache.get();

  /// The download rules' answers for Discord threads, keyed by thread id.
  Map<String, List<DownloadCandidate>>? get discordAssumedDownloads =>
      _discordAssumedCache.get();

  Map<String, dynamic>? get bundle => _bundleCache.get();

  Map<String, dynamic>? get mergeDebug => _mergeDebugCache.get();

  Map<String, dynamic>? get llmTest => _llmTestCache.get();

  bool get mergeDebugExists => _mergeDebugFile.existsSync();

  // --- Saved merges ---

  late final MergeSnapshotStore mergeSnapshots = MergeSnapshotStore(dataDir);

  /// Retains two immutable snapshots to avoid repeated decompression while
  /// paging or comparing. Merges and bundles share this cache.
  final Map<String, Map<String, dynamic>> _snapshotCache = {};
  final List<String> _snapshotOrder = [];

  /// Cached snapshot keys, oldest insertion first. Exposed for cache tests.
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

  /// Builds a snapshot-shaped comparison of working data. Null without a mods
  /// index. See [WorkingBundle] for publication restrictions.
  Map<String, dynamic>? workingBundle() => _workingBundle.bundle;

  /// Newest working file write time, populated by [workingBundle].
  DateTime? get workingLastWrittenAt => _workingBundle.lastWrittenAt;

  late final WorkingBundle _workingBundle = WorkingBundle(this);

  /// Bypasses the two-snapshot cache so a history scan does not evict the pair
  /// used by the comparison page.
  Map<String, dynamic>? bundleRunUncached(String id) =>
      bundleSnapshots.readRaw(id);

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

  /// Reads one topic's detail without caching.
  QbModDetail? loadDetail(int topicId) {
    final file =
        File(p.join(dataDir, 'mods', topicId.toString(), 'detail.json'));
    if (!file.existsSync()) return null;
    return QbModDetailMapper.fromMap(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
  }

  /// Topic ids whose detail.json is a placeholder. Rebuilt only when
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
