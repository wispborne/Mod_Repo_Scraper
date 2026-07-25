import 'dart:io';

import 'bundle_snapshot_store.dart';

/// Turns old published bundles into snapshots, so the history pages can reach
/// back before we started saving snapshots ourselves.
///
/// The published mod repo commits the bundle to git on every publish, so git
/// holds a copy from every publish going back months. This takes one of those
/// old bundles at a time and files it as an ordinary snapshot — same shape, same
/// fingerprints, same folder — as if we had been saving them all along.
///
/// This is the part with no git in it, so it can be tested on plain maps. The
/// `bin/import_bundle_history.dart` command does the git reading and hands each
/// old bundle here.
class BundleHistoryImporter {
  final BundleSnapshotStore store;

  /// The tail every imported snapshot's name carries, so the viewer can tell an
  /// imported one (no run behind it) from a real run.
  static const String idSuffix = 'imported';

  /// Names used already in this import, so two commits made in the same second
  /// do not write over each other. A fresh importer starts empty, which is what
  /// makes a second import run reproduce the same names and overwrite in place.
  final Set<String> _usedThisRun = <String>{};

  BundleHistoryImporter(this.store);

  /// The snapshot name for a commit made at [commitTime]. Same stamp shape as a
  /// real run id (`20260416T232007Z-imported`), so imported and real snapshots
  /// sort into one timeline by name alone.
  static String idForCommit(DateTime commitTime) {
    final t = commitTime.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${t.year}${two(t.month)}${two(t.day)}T'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}Z';
    return '$stamp-$idSuffix';
  }

  /// True when [id] names an imported snapshot rather than a real run.
  static bool isImportedId(String id) => id.endsWith('-$idSuffix');

  /// True when a `--repo` value names a folder on this machine rather than
  /// something to clone.
  ///
  /// The shape is checked before the disk is, because Windows refuses to be
  /// asked whether `git@github.com:owner/repo.git` exists — the colon makes it
  /// an illegal file name there, and asking throws rather than answering "no".
  /// (On Linux the same question simply answers "no", which is why this needs a
  /// test rather than a try on one machine.) The disk check that follows is
  /// wrapped for the same reason: a name we have not thought of must come back
  /// as "not a folder", never as a crash.
  static bool isLocalClone(String repo) {
    // Every git URL form: https://, ssh://, git://, file://, and the scp-like
    // `user@host:path` that SSH remotes are usually written as.
    if (repo.contains('://')) return false;
    if (RegExp(r'^[^/\\]+@[^/\\]+:').hasMatch(repo)) return false;
    try {
      return Directory(repo).existsSync();
    } on FileSystemException {
      return false;
    }
  }

  /// Files one old [bundle] as the snapshot for a commit made at [commitTime]
  /// and returns the name it was saved under.
  ///
  /// The name comes from the commit time, so importing the same commit twice
  /// writes the same file twice — the import is safe to re-run. If two different
  /// commits fall in the same second, the second gets a `-2` (then `-3`…) so one
  /// does not quietly replace the other.
  Future<String> importOne(
      DateTime commitTime, Map<String, dynamic> bundle) async {
    final id = _uniqueId(idForCommit(commitTime));
    await store.save(id, bundle);
    return id;
  }

  String _uniqueId(String base) {
    if (_usedThisRun.add(base)) return base;
    var n = 2;
    while (!_usedThisRun.add('$base-$n')) {
      n++;
    }
    return '$base-$n';
  }
}
