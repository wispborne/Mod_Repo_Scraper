import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:synchronized/synchronized.dart';

import '../models/post_extraction.dart';
import 'llm_client.dart';

/// One finished per-thread LLM result: the list of mods found on the thread,
/// plus the hash used to tell whether a re-run is needed.
class LlmStoreEntry {
  final String fingerprint;
  final int schemaVersion;
  final int promptVersion;
  final List<LlmMod> mods;

  /// The model's call on whether this thread is a downloadable mod release.
  /// Defaults to true, so an entry saved before this field existed is never
  /// treated as a non-mod. See [LlmThreadData.isMod].
  final bool isMod;

  /// Token counts and speeds from the call that produced this entry, when the
  /// endpoint reported them (llama.cpp does). Null for entries saved before
  /// stats were recorded, or when the answer came from cache.
  final LlmCallStats? stats;

  /// The model that wrote this entry, and the endpoint it was asked through.
  /// Shown in the viewer only — never published. Null for entries saved before
  /// these were recorded.
  final String? model;
  final String? endpoint;

  LlmStoreEntry({
    required this.fingerprint,
    required this.schemaVersion,
    required this.promptVersion,
    required this.mods,
    this.isMod = true,
    this.stats,
    this.model,
    this.endpoint,
  });

  /// The thread's LLM data as it sits on the bundle's `index` item — just the
  /// `mods` list. Drops the caching metadata (fingerprint/versions) and the
  /// internal `isMod` call, which is only used to decide keep/drop and is not
  /// published.
  LlmThreadData toThreadData() => LlmThreadData(mods: mods);

  Map<String, dynamic> toJson() => {
        'fingerprint': fingerprint,
        'schemaVersion': schemaVersion,
        'promptVersion': promptVersion,
        'isMod': isMod,
        'mods': mods.map((m) => m.toMap()).toList(),
        if (stats != null && !stats!.isEmpty) 'stats': stats!.toJson(),
        if (model != null) 'model': model,
        if (endpoint != null) 'endpoint': endpoint,
      };

  factory LlmStoreEntry.fromJson(Map<String, dynamic> json) => LlmStoreEntry(
        fingerprint: json['fingerprint'] as String,
        schemaVersion: json['schemaVersion'] as int? ?? 0,
        promptVersion: json['promptVersion'] as int? ?? 0,
        // Absent in entries saved before this field: default to true so they
        // are never mistaken for non-mod threads.
        isMod: json['isMod'] as bool? ?? true,
        mods: (json['mods'] as List<dynamic>? ?? [])
            .map((e) => LlmModMapper.fromMap(e as Map<String, dynamic>))
            .toList(),
        stats: json['stats'] is Map<String, dynamic>
            ? LlmCallStats.fromJson(json['stats'] as Map<String, dynamic>)
            : null,
        model: json['model'] as String?,
        endpoint: json['endpoint'] as String?,
      );
}

/// The file that stores all LLM results, doubles as a cache, and lets
/// interrupted runs pick up where they left off. A forum topic's answer is
/// keyed by its bare topic id, as it always was; a Discord thread's by
/// `discord:<thread id>`. [entries] stays forum-only, so everything that reads
/// forum answers by topic id reads them exactly as before. Only one
/// write happens at a time, and saves happen as the run goes so a crash does
/// not lose everything.
class LlmExtractionStore {
  static const int schemaVersion = 6;
  static const String _filename = 'llm-extraction-cache.json';

  final String _dataPath;
  final Logger _log;

  /// Save to disk after this many new/changed entries, or after
  /// [_flushInterval] passes — whichever comes first.
  final int _flushEveryN;
  final Duration _flushInterval;

  final Map<int, LlmStoreEntry> _entries = {};

  /// Discord threads' answers, keyed by thread id (without the `discord:`).
  final Map<String, LlmStoreEntry> _discordEntries = {};

  static const String discordKeyPrefix = 'discord:';
  final Lock _writeLock = Lock();

  int _dirtySinceFlush = 0;
  DateTime? _lastFlush;

  LlmExtractionStore(
    this._dataPath, {
    Logger? logger,
    int flushEveryN = 5,
    Duration flushInterval = const Duration(seconds: 5),
  })  : _log = logger ?? Logger('LlmExtractionStore'),
        _flushEveryN = flushEveryN,
        _flushInterval = flushInterval;

  File get _file => File(p.join(_dataPath, _filename));

  /// Loads existing entries, skipping any saved with a different format version.
  Future<void> load() async {
    final file = _file;
    if (!file.existsSync()) return;
    try {
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _entries.clear();
      _discordEntries.clear();
      for (final entry in map.entries) {
        final topicId = int.tryParse(entry.key);
        final threadId = entry.key.startsWith(discordKeyPrefix)
            ? entry.key.substring(discordKeyPrefix.length)
            : null;
        if (topicId == null && threadId == null) continue;
        final stored = LlmStoreEntry.fromJson(entry.value as Map<String, dynamic>);
        if (stored.schemaVersion != schemaVersion) continue;
        if (topicId != null) {
          _entries[topicId] = stored;
        } else {
          _discordEntries[threadId!] = stored;
        }
      }
      _log.info('Loaded LLM extraction store with ${_entries.length} forum '
          'and ${_discordEntries.length} Discord entries');
    } catch (e) {
      _log.warning('Failed to load LLM extraction store: $e');
    }
  }

  /// Returns the stored entry for [topicId], or null if absent.
  LlmStoreEntry? get(int topicId) => _entries[topicId];

  /// Returns true when a matching entry already exists, meaning we can skip the
  /// LLM call.
  bool isFresh(int topicId, String fingerprint, int promptVersion) {
    final e = _entries[topicId];
    return e != null &&
        e.fingerprint == fingerprint &&
        e.schemaVersion == schemaVersion &&
        e.promptVersion == promptVersion;
  }

  /// The stored entry for a store key: a bare topic id or
  /// `discord:<thread id>`. Null if absent or the key is neither.
  LlmStoreEntry? getKey(String key) {
    final topicId = int.tryParse(key);
    if (topicId != null) return _entries[topicId];
    if (key.startsWith(discordKeyPrefix)) {
      return _discordEntries[key.substring(discordKeyPrefix.length)];
    }
    return null;
  }

  /// A Discord thread's stored entry, or null.
  LlmStoreEntry? getDiscord(String threadId) => _discordEntries[threadId];

  /// [isFresh] for a store key.
  bool isFreshKey(String key, String fingerprint, int promptVersion) {
    final e = getKey(key);
    return e != null &&
        e.fingerprint == fingerprint &&
        e.schemaVersion == schemaVersion &&
        e.promptVersion == promptVersion;
  }

  /// [put] for a store key.
  Future<void> putKey(String key, LlmStoreEntry entry) async {
    final topicId = int.tryParse(key);
    if (topicId != null) return put(topicId, entry);
    if (!key.startsWith(discordKeyPrefix)) {
      throw ArgumentError('Not a store key: $key');
    }
    _discordEntries[key.substring(discordKeyPrefix.length)] = entry;
    await _markDirty();
  }

  /// Files an answer saved under [oldFingerprint] under [newFingerprint]
  /// instead, when nothing else about it is out of date. Returns whether it
  /// did. Lets the way a fingerprint is worked out change without paying for
  /// every answer again, provided the input is still what was read.
  Future<bool> moveFingerprint(
    String key, {
    required String oldFingerprint,
    required String newFingerprint,
    required int promptVersion,
  }) async {
    final e = getKey(key);
    if (e == null ||
        e.fingerprint != oldFingerprint ||
        e.schemaVersion != schemaVersion ||
        e.promptVersion != promptVersion) {
      return false;
    }
    await putKey(
        key,
        LlmStoreEntry(
          fingerprint: newFingerprint,
          schemaVersion: e.schemaVersion,
          promptVersion: e.promptVersion,
          mods: e.mods,
          isMod: e.isMod,
          stats: e.stats,
          model: e.model,
          endpoint: e.endpoint,
        ));
    return true;
  }

  /// Stores a finished result and saves to disk when due.
  Future<void> put(int topicId, LlmStoreEntry entry) async {
    _entries[topicId] = entry;
    await _markDirty();
  }

  Future<void> _markDirty() async {
    _dirtySinceFlush++;

    final due = _dirtySinceFlush >= _flushEveryN ||
        _lastFlush == null ||
        DateTime.now().difference(_lastFlush!) >= _flushInterval;
    if (due) {
      await flush();
    }
  }

  /// Forgets the saved results for these topics, so the next run asks the LLM
  /// about them again. Every other topic's entry is left exactly as it was.
  /// Nothing is written here — the caller saves once it has the new results.
  void dropTopics(Iterable<int> topicIds) {
    for (final id in topicIds) {
      if (_entries.remove(id) != null) _dirtySinceFlush++;
    }
  }

  /// [dropTopics] for Discord threads.
  void dropDiscordThreads(Iterable<String> threadIds) {
    for (final id in threadIds) {
      if (_discordEntries.remove(id) != null) _dirtySinceFlush++;
    }
  }

  /// Saves everything to disk. Safe to call from multiple places at once.
  Future<void> flush() async {
    await _writeLock.synchronized(() async {
      if (_dirtySinceFlush == 0 && _lastFlush != null) return;
      // The dirty count and the snapshot are read together, before the writes
      // below give other work a chance to run. Only what the snapshot caught
      // is subtracted at the end — an entry put while the file was being
      // written stays dirty, so the next flush still saves it. Zeroing the
      // count here instead used to lose those entries: reads now run beside
      // each other, and a second result can land mid-write.
      final inSnapshot = _dirtySinceFlush;
      final snapshot = {
        for (final e in _entries.entries) e.key.toString(): e.value.toJson(),
        for (final e in _discordEntries.entries)
          '$discordKeyPrefix${e.key}': e.value.toJson(),
      };
      final json = const JsonEncoder.withIndent('  ').convert(snapshot);
      await Directory(_dataPath).create(recursive: true);
      await _file.writeAsString(json);
      _dirtySinceFlush -= inSnapshot;
      _lastFlush = DateTime.now();
      _log.fine('Saved LLM results to disk (${snapshot.length} entries)');
    });
  }

  /// All forum entries, for the bundle publisher.
  Map<int, LlmStoreEntry> get entries => Map.unmodifiable(_entries);

  /// All Discord entries, keyed by thread id.
  Map<String, LlmStoreEntry> get discordEntries =>
      Map.unmodifiable(_discordEntries);

  /// Discord attachment addresses, which carry a signature Discord writes
  /// fresh every time a message is fetched.
  static final RegExp _discordAttachmentUrl = RegExp(
      r'''https?://(?:cdn\.discordapp\.com|media\.discordapp\.net)/[^\s"'<>()\[\]]+''');

  static final RegExp _discordSignaturePart = RegExp(r'^(?:ex|is|hm)=');

  /// [text] with the signature (`ex`, `is` and `hm`) taken off every Discord
  /// attachment address in it.
  ///
  /// A Discord thread's fingerprint is worked out from this. The signature
  /// changes on every fetch while the picture stays the same, so with it left
  /// in, every thread with a picture was read again after each Discord fetch.
  static String withoutDiscordSignatures(String text) =>
      text.replaceAllMapped(_discordAttachmentUrl, (m) {
        final url = m[0]!;
        final q = url.indexOf('?');
        if (q < 0) return url;
        final kept = url
            .substring(q + 1)
            .split('&')
            .where((part) =>
                part.isNotEmpty && !_discordSignaturePart.hasMatch(part))
            .toList();
        final base = url.substring(0, q);
        return kept.isEmpty ? base : '$base?${kept.join('&')}';
      });

  /// A fingerprint of the exact input, field list, and prompt version. Changing
  /// any of these re-runs the topic.
  static String computeFingerprint({
    required String userPrompt,
    required int promptVersion,
    required List<String> fieldSet,
  }) {
    final canonical = [
      'v$promptVersion',
      'fields:${(fieldSet.toList()..sort()).join(',')}',
      userPrompt,
    ].join(' ');
    return sha256.convert(utf8.encode(canonical)).toString();
  }
}
