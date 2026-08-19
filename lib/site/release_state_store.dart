import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// What we currently believe about one thread's mod version.
///
/// [believed] is the version we are willing to say the mod is on. [reading] is
/// the latest thing the extractor said, and [readingCount] is how many scrapes
/// in a row it has said it. A reading only becomes believed once it has held for
/// two scrapes running, which is what keeps a single odd reading out of the
/// feed.
class ThreadVersionState {
  /// The believed version, cleaned to one spelling. Null until a reading has
  /// settled.
  String? believed;

  /// The believed version as the author wrote it, for showing on the site.
  String? believedRaw;

  /// The most recent reading, cleaned. Null when nothing readable has come in.
  String? reading;

  /// The author's own spelling of [reading].
  String? readingRaw;

  /// How many scrapes in a row [reading] has been the answer.
  int readingCount;

  ThreadVersionState({
    this.believed,
    this.believedRaw,
    this.reading,
    this.readingRaw,
    this.readingCount = 0,
  });

  Map<String, dynamic> toMap() => {
        if (believed != null) 'believed': believed,
        if (believedRaw != null) 'believedRaw': believedRaw,
        if (reading != null) 'reading': reading,
        if (readingRaw != null) 'readingRaw': readingRaw,
        'readingCount': readingCount,
      };

  static ThreadVersionState fromMap(Map<String, dynamic> map) =>
      ThreadVersionState(
        believed: map['believed'] as String?,
        believedRaw: map['believedRaw'] as String?,
        reading: map['reading'] as String?,
        readingRaw: map['readingRaw'] as String?,
        readingCount: (map['readingCount'] as num?)?.toInt() ?? 0,
      );
}

/// One mod on one thread putting out a new version.
///
/// This is kept against the forum topic id rather than the mod's permanent id,
/// because the detector works over saved bundles and a bundle knows about
/// threads, not about merged mods. The site's own feed is built from these by
/// joining each topic to its merged mod, which is a job the data builder already
/// does.
class ThreadRelease {
  final int topicId;

  /// The mod's name as the thread had it when the release was seen.
  final String modName;

  /// The day it was seen, as `YYYY-MM-DD`.
  final String seenOn;

  /// The version it moved from. Null when this is the first release recorded
  /// for a thread whose earlier versions we never saw.
  final String? oldVersion;

  /// The version it moved to, as the author wrote it.
  final String newVersion;

  final String? gameVersion;

  /// That version's changelog notes, copied word for word. Null when the post
  /// gave none.
  final String? changelogNotes;

  const ThreadRelease({
    required this.topicId,
    required this.modName,
    required this.seenOn,
    this.oldVersion,
    required this.newVersion,
    this.gameVersion,
    this.changelogNotes,
  });

  Map<String, dynamic> toMap() => {
        'topicId': topicId,
        'modName': modName,
        'seenOn': seenOn,
        if (oldVersion != null) 'oldVersion': oldVersion,
        'newVersion': newVersion,
        if (gameVersion != null) 'gameVersion': gameVersion,
        if (changelogNotes != null) 'changelogNotes': changelogNotes,
      };

  static ThreadRelease fromMap(Map<String, dynamic> map) => ThreadRelease(
        topicId: (map['topicId'] as num).toInt(),
        modName: map['modName'] as String? ?? '',
        seenOn: map['seenOn'] as String? ?? '',
        oldVersion: map['oldVersion'] as String?,
        newVersion: map['newVersion'] as String? ?? '',
        gameVersion: map['gameVersion'] as String?,
        changelogNotes: map['changelogNotes'] as String?,
      );
}

/// Everything the detector remembers between runs.
class ReleaseState {
  /// What we believe about each thread, keyed by forum topic id.
  final Map<int, ThreadVersionState> threads;

  /// Every release recorded so far, oldest first.
  final List<ThreadRelease> releases;

  /// The saved bundles already walked, so the backfill can be run again without
  /// counting the same bundle twice.
  final Set<String> bundlesSeen;

  ReleaseState({
    Map<int, ThreadVersionState>? threads,
    List<ThreadRelease>? releases,
    Set<String>? bundlesSeen,
  })  : threads = threads ?? {},
        releases = releases ?? [],
        bundlesSeen = bundlesSeen ?? {};

  /// The state for [topicId], making an empty one the first time it is asked
  /// for.
  ThreadVersionState of(int topicId) =>
      threads.putIfAbsent(topicId, ThreadVersionState.new);

  /// The releases newest first, which is the order the feed is written in.
  List<ThreadRelease> get newestFirst =>
      releases.reversed.toList(growable: false);
}

/// Reads and writes what the detector believes, in
/// `<data path>/mod-releases.json`.
///
/// This is working state, not an output: it never reaches the published files as
/// it is. It is small — one line per thread plus the release history — so it is
/// written plainly rather than squashed, and can be read by a person when the
/// feed says something odd.
class ReleaseStateStore {
  static const String fileName = 'mod-releases.json';

  final String dataPath;

  ReleaseStateStore(this.dataPath);

  String get filePath => p.join(dataPath, fileName);

  /// Reads the state back. A missing file means nothing has been worked out yet,
  /// which is the first run. A file that cannot be read throws — carrying on
  /// from an empty state would announce every mod's current version as a fresh
  /// release.
  ReleaseState load() {
    final file = File(filePath);
    if (!file.existsSync()) return ReleaseState();

    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } catch (e) {
      throw StateError(
        'Cannot read the release state at $filePath: $e\n'
        'Starting again from nothing would announce every mod at once, so the '
        'run has stopped. Put the file back, or delete it and re-run the '
        'backfill.',
      );
    }
    if (decoded is! Map) {
      throw StateError('The release state at $filePath is not the shape we '
          'wrote it in.');
    }

    final threads = <int, ThreadVersionState>{};
    final storedThreads = decoded['threads'];
    if (storedThreads is Map) {
      storedThreads.forEach((key, value) {
        final topicId = int.tryParse('$key');
        if (topicId == null || value is! Map) return;
        threads[topicId] =
            ThreadVersionState.fromMap(Map<String, dynamic>.from(value));
      });
    }

    final releases = <ThreadRelease>[];
    final storedReleases = decoded['releases'];
    if (storedReleases is List) {
      for (final entry in storedReleases) {
        if (entry is Map) {
          releases.add(
              ThreadRelease.fromMap(Map<String, dynamic>.from(entry)));
        }
      }
    }

    final seen = <String>{};
    final storedSeen = decoded['bundlesSeen'];
    if (storedSeen is List) {
      for (final id in storedSeen) {
        if (id is String && id.isNotEmpty) seen.add(id);
      }
    }

    return ReleaseState(
        threads: threads, releases: releases, bundlesSeen: seen);
  }

  /// Writes the state back. Called after every bundle the detector walks, so a
  /// backfill stopped part-way keeps what it has already worked out.
  void save(ReleaseState state) {
    final dir = Directory(dataPath);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final threads = <String, dynamic>{};
    final topicIds = state.threads.keys.toList()..sort();
    for (final topicId in topicIds) {
      threads['$topicId'] = state.threads[topicId]!.toMap();
    }

    File(filePath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'threads': threads,
        'releases': state.releases.map((r) => r.toMap()).toList(),
        'bundlesSeen': state.bundlesSeen.toList()..sort(),
      }),
    );
  }
}
