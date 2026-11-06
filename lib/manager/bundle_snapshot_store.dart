import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// The time at the start of a run id (`20260417T032007Z-imported` gives
/// 2026-04-17 03:20:07 UTC), or null when the id does not start with one.
DateTime? runIdTime(String id) {
  final m = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z')
      .firstMatch(id);
  if (m == null) return null;
  final parts = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
  final at =
      DateTime.utc(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
  // DateTime.utc rolls a bad month or day over instead of failing.
  if (at.month != parts[1] || at.day != parts[2] || at.hour != parts[3]) {
    return null;
  }
  return at;
}

/// True when [id] names a snapshot imported from git rather than a real run:
/// it ends in `-imported`, or `-imported-2`, `-imported-3`… for a second commit
/// made in the same second.
bool isImportedSnapshotId(String id) => RegExp(r'-imported(-\d+)?$').hasMatch(id);

/// When a snapshot was saved, for the lists and for finding the run saved
/// nearest to another.
///
/// [recorded] is the time written to the counts file when it was saved; that
/// is used first. Older snapshots have none, and their file time can be wrong:
/// a snapshot imported from git, or a copy of the data folder, carries the
/// time it was imported or copied. So for those the time in the run id (when
/// the run started) is used, and the file time only when the id has none.
DateTime snapshotSavedAt(String id, DateTime fileTime, Object? recorded) {
  if (recorded is String) {
    final at = DateTime.tryParse(recorded);
    if (at != null) return at.toUtc();
  }
  return runIdTime(id) ?? fileTime;
}

/// One saved bundle, as the list shows it.
class BundleSnapshotInfo {
  /// The run that published it. Same id as the run record, its log and its
  /// request.
  final String id;

  /// When it was saved ([snapshotSavedAt]).
  final DateTime savedAt;

  /// How big the file is on disk, squashed down.
  final int sizeBytes;

  /// The headline counts, when they are known. Null means the counts file has
  /// been lost — the snapshot still reads fine.
  final int? indexCount;
  final int? detailCount;
  final int? downloadCount;

  const BundleSnapshotInfo({
    required this.id,
    required this.savedAt,
    required this.sizeBytes,
    this.indexCount,
    this.detailCount,
    this.downloadCount,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'savedAt': savedAt.toUtc().toIso8601String(),
        'sizeBytes': sizeBytes,
        'indexCount': indexCount,
        'detailCount': detailCount,
        'downloadCount': downloadCount,
      };
}

/// Keeps one snapshot of the published bundle per run, in
/// `<data path>/bundles/`, so two runs can be compared afterwards.
///
/// **A snapshot is not a bundle.** The posts' HTML is left out and a short
/// fingerprint of each post kept in its place. That is what makes keeping
/// twenty of them affordable: the published bundle is about 15.5 MB, which is
/// 4.3 MB squashed down, but only 1.2 MB once the post text is out of it. A
/// post that changed still shows up as changed; the words it used to say are
/// not kept, and nothing here can be published as a bundle.
///
/// Like `merges/`, this is paperwork about a run. No scraped data and no output
/// ever lives here, and the trim below will not delete anything else.
class BundleSnapshotStore {
  static const String fileSuffix = '.json.gz';
  static const String countsFileName = 'bundle-counts.json';

  /// The key a detail's post text is replaced by.
  static const String fingerprintKey = 'contentFingerprint';

  final String dataPath;

  /// How many snapshots to keep. 0 or less keeps them all.
  final int bundlesToKeep;

  BundleSnapshotStore(this.dataPath, {this.bundlesToKeep = 500});

  String get bundlesPath => p.join(dataPath, 'bundles');

  String get countsPath => p.join(bundlesPath, countsFileName);

  /// Saves [bundle] as the snapshot for [runId] and drops any snapshots past
  /// the limit. The one just written is never the one dropped.
  Future<File> save(String runId, Map<String, dynamic> bundle) async {
    final folder = Directory(bundlesPath);
    if (!folder.existsSync()) folder.createSync(recursive: true);

    final trimmed = withoutPostText(bundle);
    final file = File(p.join(bundlesPath, '$runId$fileSuffix'));
    final bytes = gzip.encode(utf8.encode(jsonEncode(trimmed)));
    await file.writeAsBytes(bytes, flush: true);

    _writeCounts(runId, trimmed);
    _dropOldSnapshots(keep: runId);
    return file;
  }

  /// The bundle with every post's HTML swapped for a fingerprint of it.
  ///
  /// The original map is left alone — it is the bundle that was just published,
  /// and nothing here may change what went out.
  static Map<String, dynamic> withoutPostText(Map<String, dynamic> bundle) {
    final copy = <String, dynamic>{...bundle};
    final details = bundle['details'];
    if (details is! Map) return copy;

    final trimmedDetails = <String, dynamic>{};
    for (final entry in details.entries) {
      final detail = entry.value;
      if (detail is! Map) {
        trimmedDetails['${entry.key}'] = detail;
        continue;
      }
      // Already trimmed: it has a fingerprint and no post text to take one
      // from. Trimming again would fingerprint the nothing that is left and
      // wipe the one it already has.
      if (!detail.containsKey('contentHtml') &&
          detail.containsKey(fingerprintKey)) {
        trimmedDetails['${entry.key}'] = detail;
        continue;
      }
      final withoutHtml = <String, dynamic>{
        for (final field in detail.entries)
          if (field.key != 'contentHtml') '${field.key}': field.value,
      };
      withoutHtml[fingerprintKey] = fingerprintOf(detail['contentHtml']);
      withoutHtml['extraPosts'] = postsWithoutText(detail['extraPosts']);
      trimmedDetails['${entry.key}'] = withoutHtml;
    }
    copy['details'] = trimmedDetails;
    return copy;
  }

  /// The author's later posts with their HTML swapped for fingerprints, the
  /// same way the first post's is. A thread with none comes back as an empty
  /// list, which is also how a snapshot saved before these existed reads.
  static List<dynamic> postsWithoutText(Object? posts) {
    if (posts is! List) return const [];
    return [
      for (final post in posts)
        if (post is Map)
          <String, dynamic>{
            for (final field in post.entries)
              if (field.key != 'contentHtml') '${field.key}': field.value,
            if (post.containsKey('contentHtml'))
              fingerprintKey: fingerprintOf(post['contentHtml']),
          }
        else
          post,
    ];
  }

  /// A short stand-in for a post's text: same text, same fingerprint. Null when
  /// there was no post text, so "no post" and "an empty post" do not read as a
  /// change.
  static String? fingerprintOf(Object? html) {
    if (html == null) return null;
    final text = '$html';
    return sha1.convert(utf8.encode(text)).toString().substring(0, 16);
  }

  /// Every saved snapshot, newest first. Run ids start with the time in UTC, so
  /// sorting the names backwards is sorting by time.
  List<BundleSnapshotInfo> list() {
    final folder = Directory(bundlesPath);
    if (!folder.existsSync()) return const [];

    final counts = _readCounts();
    final found = <BundleSnapshotInfo>[];
    for (final entry in folder.listSync()) {
      if (entry is! File) continue;
      final id = _idOf(entry);
      if (id == null) continue;
      final stat = entry.statSync();
      final saved = counts[id];
      found.add(BundleSnapshotInfo(
        id: id,
        savedAt: snapshotSavedAt(id, stat.modified, saved?['savedAt']),
        sizeBytes: stat.size,
        indexCount: saved?['indexCount'] as int?,
        detailCount: saved?['detailCount'] as int?,
        downloadCount: saved?['downloadCount'] as int?,
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

  /// The snapshot saved just before [id], or null when [id] is the oldest one
  /// kept. This is what "what did this run change?" compares against.
  String? idBefore(String id) {
    final all = list();
    final at = all.indexWhere((s) => s.id == id);
    if (at < 0 || at + 1 >= all.length) return null;
    return all[at + 1].id;
  }

  /// Reads one snapshot back as plain maps — what the web API serves. Null when
  /// there is no such snapshot, or when the file cannot be read; the caller
  /// says so in plain words rather than falling over.
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
  /// sitting directly in the `bundles/` folder.
  ///
  /// The id can arrive from a web request, and this is the one place that opens
  /// and deletes files here, so `../mods-index.json` must not get anywhere near
  /// it.
  File? _fileFor(String id) {
    if (id.isEmpty || id.contains('/') || id.contains(r'\')) return null;
    final full = p.canonicalize(p.join(bundlesPath, '$id$fileSuffix'));
    if (!p.equals(p.dirname(full), p.canonicalize(bundlesPath))) return null;
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

  void _writeCounts(String runId, Map<String, dynamic> bundle) {
    final counts = _readCounts();
    counts[runId] = {
      'indexCount': (bundle['index'] as List?)?.length,
      'detailCount': (bundle['details'] as Map?)?.length,
      'downloadCount': (bundle['assumedDownloads'] as Map?)?.length,
      'savedAt': _savedNow(runId),
    };
    try {
      File(countsPath).writeAsStringSync(jsonEncode(counts));
    } on FileSystemException {
      // Same again: the snapshot itself is what matters.
    }
  }

  /// The time to record for a snapshot saved now. A snapshot imported from git
  /// ([isImportedSnapshotId]) records the time in its id, which is the
  /// commit's.
  static String _savedNow(String runId) {
    final at = isImportedSnapshotId(runId) ? runIdTime(runId) : null;
    return (at ?? DateTime.now()).toUtc().toIso8601String();
  }

  /// Keeps the newest [bundlesToKeep] snapshots and deletes the rest.
  ///
  /// Only files ending in `.json.gz` sitting directly in `bundles/` are ever
  /// deleted, and never the one named by [keep] — the run that has just
  /// finished writing it.
  void _dropOldSnapshots({String? keep}) {
    if (bundlesToKeep <= 0) return;
    final all = list();
    if (all.length <= bundlesToKeep) return;

    final kept = <String>[];
    final dropped = <String>[];
    for (final snapshot in all) {
      if (snapshot.id == keep || kept.length < bundlesToKeep) {
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
