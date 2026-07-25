import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:mod_repo_scraper/manager/bundle_history_importer.dart';
import 'package:mod_repo_scraper/manager/bundle_snapshot_store.dart';
import 'package:mod_repo_scraper/timber/ktx/timber_kt.dart' as timber;
import 'package:mod_repo_scraper/timber/log_level.dart';
import 'package:mod_repo_scraper/timber/timber.dart' as timber_lib;

/// One-time backfill: read every past version of the forum data bundle from the
/// published repo's git history and save each as a snapshot.
///
/// The published mod repo keeps a commit for every publish, so its git history
/// holds a copy of the bundle from every publish going back months. This walks
/// that history oldest to newest and files each old bundle as an ordinary
/// snapshot in `<data dir>/bundles/`, so the "what changed" and per-topic
/// history pages reach back before we started saving snapshots ourselves.
///
/// It is safe to run more than once: each commit always saves under the same
/// name, so a second run just writes the same files again.
///
/// Examples:
///   # Against a clone you already have (e.g. the publisher's working copy):
///   dart run bin/import_bundle_history.dart \
///       --repo /srv/scraper/StarsectorModRepo --data-dir /srv/scraper/qb_data
///
///   # Against the remote directly (cloned into a temp folder, then cleaned up):
///   dart run bin/import_bundle_history.dart \
///       --repo git@github.com:wispborne/StarsectorModRepo.git --data-dir qb_data
///
///   # See what it would do without writing anything:
///   dart run bin/import_bundle_history.dart --repo ... --data-dir ... --dry-run
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('repo',
        help: 'The published repo: either a path to a clone you already have, '
            'or a URL to clone into a temp folder for the run.')
    ..addOption('data-dir',
        defaultsTo: 'qb_data',
        help: 'The QB data dir. Snapshots are written to its bundles/ folder.')
    ..addOption('bundle-file',
        defaultsTo: 'forum-data-bundle.json',
        help: 'The bundle file to follow through the repo\'s history.')
    ..addOption('keep',
        defaultsTo: '0',
        help: 'How many snapshots to keep while importing. 0 (the default) '
            'keeps every one, so a big backfill is never trimmed part-way.')
    ..addOption('git',
        defaultsTo: 'git', help: 'The git program to run.')
    ..addFlag('dry-run',
        negatable: false,
        help: 'List what would be imported without writing anything.')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage and exit.');

  final ArgResults opts;
  try {
    opts = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(parser.usage);
    exitCode = 64;
    return;
  }

  if (opts['help'] as bool) {
    stdout.writeln('Backfill bundle snapshots from the published repo\'s git '
        'history.\n');
    stdout.writeln(parser.usage);
    return;
  }

  timber_lib.Timber.plant(timber_lib.DebugTree(minLogLevelToShow: LogLevel.info));

  final repo = opts['repo'] as String?;
  if (repo == null || repo.isEmpty) {
    stderr.writeln('--repo is required.');
    stderr.writeln(parser.usage);
    exitCode = 64;
    return;
  }
  final dataDir = opts['data-dir'] as String;
  final bundleFile = opts['bundle-file'] as String;
  final gitExe = opts['git'] as String;
  final dryRun = opts['dry-run'] as bool;
  final keep = int.tryParse(opts['keep'] as String) ?? 0;

  // A folder we can already see is used as it is; anything else is a URL to
  // clone into a temp folder for this run, cleaned up after.
  Directory? tempClone;
  final String repoDir;
  if (BundleHistoryImporter.isLocalClone(repo)) {
    repoDir = repo;
  } else {
    tempClone = Directory.systemTemp.createTempSync('bundle_history_import');
    repoDir = tempClone.path;
    timber.i(message: () => 'Cloning $repo into $repoDir ...');
    // A full clone on purpose. Leaving the file contents out of the clone
    // (`--filter=blob:none`) makes the clone itself quick, but we then read
    // every past version of the bundle, and each one would be fetched back over
    // the network one at a time — about five times slower overall. No working
    // tree is checked out, and only the one branch is fetched.
    final clone = await Process.run(gitExe,
        ['clone', '--no-checkout', '--single-branch', repo, repoDir]);
    if (clone.exitCode != 0) {
      timber.e(message: () => 'Clone failed: ${clone.stderr}');
      tempClone.deleteSync(recursive: true);
      exitCode = 1;
      return;
    }
  }

  try {
    await _import(
      gitExe: gitExe,
      repoDir: repoDir,
      bundleFile: bundleFile,
      dataDir: dataDir,
      keep: keep,
      dryRun: dryRun,
    );
  } finally {
    if (tempClone != null && tempClone.existsSync()) {
      tempClone.deleteSync(recursive: true);
    }
  }
}

Future<void> _import({
  required String gitExe,
  required String repoDir,
  required String bundleFile,
  required String dataDir,
  required int keep,
  required bool dryRun,
}) async {
  final revisions = await _revisions(gitExe, repoDir, bundleFile);
  if (revisions.isEmpty) {
    timber.w(
        message: () => 'No commits touch $bundleFile in $repoDir. Nothing to '
            'import — is this the right repo and file?');
    return;
  }
  timber.i(
      message: () => '${revisions.length} versions of $bundleFile found, from '
          '${revisions.first.time.toIso8601String()} to '
          '${revisions.last.time.toIso8601String()}.');

  final store = BundleSnapshotStore(dataDir, bundlesToKeep: keep);
  final importer = BundleHistoryImporter(store);

  var saved = 0;
  var skipped = 0;
  for (var i = 0; i < revisions.length; i++) {
    final rev = revisions[i];
    final raw = await _fileAt(gitExe, repoDir, rev.sha, bundleFile);
    if (raw == null) {
      skipped++;
      continue;
    }

    Map<String, dynamic> bundle;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        timber.w(
            message: () => 'Skipping ${rev.sha}: the file is not a JSON object.');
        skipped++;
        continue;
      }
      bundle = decoded;
    } catch (e) {
      timber.w(message: () => 'Skipping ${rev.sha}: could not read the JSON ($e).');
      skipped++;
      continue;
    }

    if (dryRun) {
      timber.i(
          message: () => 'Would import ${BundleHistoryImporter.idForCommit(rev.time)}'
              ' from ${rev.sha}.');
      saved++;
    } else {
      final id = await importer.importOne(rev.time, bundle);
      saved++;
      // A quiet line every so often, so a long backfill shows it is moving.
      if (saved % 25 == 0 || i == revisions.length - 1) {
        timber.i(message: () => 'Imported $saved of ${revisions.length} '
            '(latest $id).');
      }
    }
  }

  final where = dryRun ? 'Would import' : 'Imported';
  timber.i(
      message: () => '$where $saved snapshot(s)'
          '${skipped > 0 ? ', skipped $skipped unreadable' : ''}. '
          '${dryRun ? 'Nothing was written (dry run).' : 'Done.'}');
}

/// One past version of the bundle: which commit it came from and when that
/// commit was made.
class _Revision {
  final String sha;
  final DateTime time;
  const _Revision(this.sha, this.time);
}

/// Every commit that changed the bundle file, oldest first, with its commit
/// time. `%cI` is the committer date in strict ISO 8601, which parses cleanly.
Future<List<_Revision>> _revisions(
    String gitExe, String repoDir, String bundleFile) async {
  final result = await Process.run(
    gitExe,
    ['-C', repoDir, 'log', '--reverse', '--format=%H %cI', '--', bundleFile],
  );
  if (result.exitCode != 0) {
    throw StateError('git log failed (exit ${result.exitCode}): '
        '${(result.stderr as String).trim()}');
  }
  final revisions = <_Revision>[];
  for (final line in (result.stdout as String).split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    final space = trimmed.indexOf(' ');
    if (space < 0) continue;
    final sha = trimmed.substring(0, space);
    final when = DateTime.tryParse(trimmed.substring(space + 1).trim());
    if (when == null) continue;
    revisions.add(_Revision(sha, when.toUtc()));
  }
  return revisions;
}

/// The bundle file's text at one commit, or null when it cannot be read.
Future<String?> _fileAt(
    String gitExe, String repoDir, String sha, String bundleFile) async {
  final result = await Process.run(
    gitExe,
    ['-C', repoDir, 'show', '$sha:$bundleFile'],
    stdoutEncoding: utf8,
  );
  if (result.exitCode != 0) return null;
  return result.stdout as String;
}
