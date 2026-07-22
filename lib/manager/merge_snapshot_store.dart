import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../bot/scraper/debug/merge_debug_data.dart';

/// One saved merge, as the list shows it.
class MergeSnapshotInfo {
  /// The run that made it. Same id as the run record, its log and its request.
  final String id;

  /// When the file was written.
  final DateTime savedAt;

  /// How big the file is on disk, squashed down.
  final int sizeBytes;

  /// The headline counts, when they are known. Null means the counts file has
  /// been lost — the snapshot still reads fine.
  final int? inputCount;
  final int? groupCount;
  final int? finalCount;

  const MergeSnapshotInfo({
    required this.id,
    required this.savedAt,
    required this.sizeBytes,
    this.inputCount,
    this.groupCount,
    this.finalCount,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'savedAt': savedAt.toUtc().toIso8601String(),
        'sizeBytes': sizeBytes,
        'inputCount': inputCount,
        'groupCount': groupCount,
        'finalCount': finalCount,
      };
}

/// Keeps one merge debug snapshot per merge run, in `<data path>/merges/`.
///
/// A run's data is around 12 MB written out plainly, so each snapshot is stored
/// squashed down (gzip, no indenting) — roughly a megabyte. Twenty of those is
/// a folder you can forget about; twenty of the plain ones is not.
///
/// These are paperwork about a run, like its log file. No scraped data and no
/// output ever lives here, and the trim below will not delete anything else.
class MergeSnapshotStore {
  static const String fileSuffix = '.json.gz';
  static const String countsFileName = 'merge-counts.json';

  final String dataPath;

  /// How many snapshots to keep. 0 or less keeps them all.
  final int mergesToKeep;

  MergeSnapshotStore(this.dataPath, {this.mergesToKeep = 20});

  String get mergesPath => p.join(dataPath, 'merges');

  String get countsPath => p.join(mergesPath, countsFileName);

  /// Saves [data] as the snapshot for [runId] and drops any snapshots past the
  /// limit. The one just written is never the one dropped.
  Future<File> save(String runId, MergeDebugData data) async {
    MergeDebugDataMapper.ensureInitialized();
    final folder = Directory(mergesPath);
    if (!folder.existsSync()) folder.createSync(recursive: true);

    final file = File(p.join(mergesPath, '$runId$fileSuffix'));
    final bytes = gzip.encode(utf8.encode(jsonEncode(data.toMap())));
    await file.writeAsBytes(bytes, flush: true);

    _writeCounts(runId, data);
    _dropOldSnapshots(keep: runId);
    return file;
  }

  /// Every saved snapshot, newest first. Run ids start with the time in UTC, so
  /// sorting the names backwards is sorting by time.
  List<MergeSnapshotInfo> list() {
    final folder = Directory(mergesPath);
    if (!folder.existsSync()) return const [];

    final counts = _readCounts();
    final found = <MergeSnapshotInfo>[];
    for (final entry in folder.listSync()) {
      if (entry is! File) continue;
      final id = _idOf(entry);
      if (id == null) continue;
      final stat = entry.statSync();
      final saved = counts[id];
      found.add(MergeSnapshotInfo(
        id: id,
        savedAt: stat.modified,
        sizeBytes: stat.size,
        inputCount: saved?['inputCount'] as int?,
        groupCount: saved?['groupCount'] as int?,
        finalCount: saved?['finalCount'] as int?,
      ));
    }
    found.sort((a, b) => b.id.compareTo(a.id));
    return found;
  }

  /// The newest saved snapshot's id, or null when none are saved.
  String? get newestId {
    final all = list();
    return all.isEmpty ? null : all.first.id;
  }

  bool has(String id) => _fileFor(id)?.existsSync() ?? false;

  /// Reads one snapshot back. Null when there is no such snapshot, or when the
  /// file cannot be read — the caller says so in plain words rather than
  /// falling over.
  MergeDebugData? read(String id) {
    final file = _fileFor(id);
    if (file == null || !file.existsSync()) return null;
    try {
      MergeDebugDataMapper.ensureInitialized();
      final text = utf8.decode(gzip.decode(file.readAsBytesSync()));
      return MergeDebugDataMapper.fromMap(
          jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// The same as [read], but as plain maps — what the web API serves. Reading
  /// it this way skips building thousands of objects only to turn them straight
  /// back into JSON.
  Map<String, dynamic>? readRaw(String id) {
    final file = _fileFor(id);
    if (file == null || !file.existsSync()) return null;
    try {
      final text = utf8.decode(gzip.decode(file.readAsBytesSync()));
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------

  /// The snapshot file for [id], but only if that name really is a snapshot
  /// sitting directly in the `merges/` folder.
  ///
  /// The id can arrive from a web request, and this is the one place that
  /// opens and deletes files here, so `../mods-index.json` must not get
  /// anywhere near it.
  File? _fileFor(String id) {
    if (id.isEmpty || id.contains('/') || id.contains(r'\')) return null;
    final full = p.canonicalize(p.join(mergesPath, '$id$fileSuffix'));
    if (!p.equals(p.dirname(full), p.canonicalize(mergesPath))) return null;
    return File(full);
  }

  /// The run id a file holds a snapshot for, or null when it isn't one.
  String? _idOf(File file) {
    final name = p.basename(file.path);
    if (!name.endsWith(fileSuffix)) return null;
    final id = name.substring(0, name.length - fileSuffix.length);
    return id.isEmpty ? null : id;
  }

  Map<String, Map<String, dynamic>> _readCounts() {
    final file = File(countsPath);
    if (!file.existsSync()) return {};
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.value is Map<String, dynamic>)
            e.key as String: e.value as Map<String, dynamic>,
      };
    } catch (_) {
      // Losing the counts costs the list its headline numbers and nothing else.
      return {};
    }
  }

  void _writeCounts(String runId, MergeDebugData data) {
    final counts = _readCounts();
    counts[runId] = {
      'inputCount': data.inputCount,
      'groupCount': data.groupsCreated,
      'finalCount': data.finalCount,
    };
    try {
      File(countsPath).writeAsStringSync(jsonEncode(counts));
    } on FileSystemException {
      // Same again: the snapshot itself is what matters.
    }
  }

  /// Keeps the newest [mergesToKeep] snapshots and deletes the rest.
  ///
  /// Only files ending in `.json.gz` sitting directly in `merges/` are ever
  /// deleted, and never the one named by [keep] — the run that has just
  /// finished writing it.
  void _dropOldSnapshots({String? keep}) {
    if (mergesToKeep <= 0) return;
    final all = list();
    if (all.length <= mergesToKeep) return;

    final kept = <String>[];
    final dropped = <String>[];
    for (final snapshot in all) {
      if (snapshot.id == keep || kept.length < mergesToKeep) {
        kept.add(snapshot.id);
      } else {
        dropped.add(snapshot.id);
      }
    }
    if (dropped.isEmpty) return;

    for (final id in dropped) {
      final file = _fileFor(id);
      if (file == null) continue;
      try {
        if (file.existsSync()) file.deleteSync();
      } on FileSystemException {
        // A file we can't delete is untidy, not broken.
      }
    }

    final counts = _readCounts();
    for (final id in dropped) {
      counts.remove(id);
    }
    try {
      File(countsPath).writeAsStringSync(jsonEncode(counts));
    } on FileSystemException {
      // Leftover counts for a snapshot that is gone do no harm.
    }
  }
}
