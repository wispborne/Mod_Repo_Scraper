import 'dart:io';

import 'package:args/args.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/forum_data_bundle.dart';
import 'package:mod_repo_scraper/manager/bundle_snapshot_store.dart';
import 'package:mod_repo_scraper/site/release_detector.dart';
import 'package:mod_repo_scraper/site/release_state_store.dart';
import 'package:mod_repo_scraper/timber/ktx/timber_kt.dart' as timber;
import 'package:mod_repo_scraper/timber/log_level.dart';
import 'package:mod_repo_scraper/timber/timber.dart' as timber_lib;

/// One-time backfill: walk every saved bundle in order and work out which mods
/// released, so the feed starts with a history rather than empty.
///
/// A normal run only ever moves the release state on by one bundle, because
/// walking all of them takes real time and memory. This does the full walk once.
/// It is safe to run again: each saved bundle is remembered by name, so a second
/// run skips everything the first one already read, and only picks up bundles
/// saved since.
///
/// Examples:
///   dart run bin/backfill_releases.dart --data-dir qb_data
///   dart run bin/backfill_releases.dart --data-dir qb_data --dry-run
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('data-dir',
        defaultsTo: 'qb_data',
        help: 'The QB data dir. Saved bundles are read from its bundles/ '
            'folder, and the release state is written to it.')
    ..addFlag('again',
        negatable: false,
        help: 'Start from nothing and read every saved bundle again, throwing '
            'away the release history worked out so far.')
    ..addFlag('dry-run',
        negatable: false,
        help: 'Work it all out and print it, without writing anything.')
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
    stdout.writeln('Work out which mods released, from every saved bundle.\n');
    stdout.writeln(parser.usage);
    return;
  }

  timber_lib.Timber.plant(
      timber_lib.DebugTree(minLogLevelToShow: LogLevel.info));

  final dataDir = opts['data-dir'] as String;
  final dryRun = opts['dry-run'] as bool;
  final startAgain = opts['again'] as bool;

  // Every snapshot is read, so nothing may be trimmed while this runs.
  final snapshots = BundleSnapshotStore(dataDir, bundlesToKeep: 0);
  final saved = snapshots.list().reversed.toList(); // oldest first
  if (saved.isEmpty) {
    timber.w(
        message: () => 'No saved bundles in ${snapshots.bundlesPath}. There is '
            'nothing to work out yet.');
    return;
  }

  final store = ReleaseStateStore(dataDir);
  final state = startAgain ? ReleaseState() : store.load();
  final detector = ReleaseDetector(state);

  final alreadyRead = saved.where((s) => state.bundlesSeen.contains(s.id)).length;
  timber.i(
      message: () => '${saved.length} saved bundles, $alreadyRead already read.');

  var walked = 0;
  var found = 0;
  for (final snapshot in saved) {
    final raw = snapshots.readRaw(snapshot.id);
    if (raw == null) {
      timber.w(message: () => 'Could not read ${snapshot.id}, skipping it.');
      continue;
    }

    final ForumDataBundle bundle;
    try {
      bundle = ForumDataBundleMapper.fromMap(raw);
    } catch (e) {
      timber.w(message: () => 'Could not read ${snapshot.id} as a bundle: $e');
      continue;
    }

    final releases = detector.advance(bundle,
        bundleId: snapshot.id,
        seenOn: _dayFromId(snapshot.id) ?? snapshot.savedAt);
    walked++;
    found += releases.length;

    for (final release in releases) {
      timber.i(
          message: () => '${release.seenOn}  ${release.modName}  '
              '${release.oldVersion ?? '?'} -> ${release.newVersion}');
    }

    // Saved as it goes, so a backfill stopped part-way keeps what it worked out
    // and the next run carries on from there.
    if (!dryRun && walked % 10 == 0) store.save(state);
  }

  if (!dryRun) store.save(state);

  timber.i(
      message: () => 'Read $walked bundles and found $found releases. The feed '
          'now holds ${state.releases.length}.'
          '${dryRun ? ' Nothing was written (--dry-run).' : ''}');
}

/// A run id starts with the time it began, in UTC, written so that sorting the
/// names sorts by time — `20260417T032007Z`. Reading the day back out of the
/// name is what files a release under the day it really happened. A snapshot
/// imported from the published repo's history carries its commit's time this
/// way, while the file on disk was only written when the import ran, so the
/// file's own date would put every imported release on one day.
DateTime? _dayFromId(String id) {
  final match = RegExp(r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z')
      .firstMatch(id);
  if (match == null) return null;
  final parts = [
    for (var group = 1; group <= 6; group++) int.parse(match.group(group)!)
  ];
  return DateTime.utc(
      parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
}
