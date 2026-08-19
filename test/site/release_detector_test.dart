import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/qb/models/forum_data_bundle.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:mod_repo_scraper/site/release_detector.dart';
import 'package:mod_repo_scraper/site/release_state_store.dart';
import 'package:test/test.dart';

void main() {
  late ReleaseDetector detector;
  var day = 0;

  setUp(() {
    detector = ReleaseDetector(ReleaseState());
    day = 0;
  });

  /// One saved bundle holding one thread.
  ForumDataBundle bundleWith({
    int topicId = 9175,
    String title = '[0.98a] Nexerelin',
    String gameVersion = '0.98a',
    String? version,
    Map<String, String>? changelog,
    int replies = 0,
  }) =>
      ForumDataBundle(
        updatedAt: DateTime.utc(2026, 8, 1).add(Duration(days: day)),
        index: [
          QbModSummary(
            topicId: topicId,
            title: title,
            gameVersion: gameVersion,
            replies: replies,
            llm: LlmThreadData(mods: [
              LlmMod(
                name: 'Nexerelin',
                extras: LlmExtras(
                  version: version,
                  changelog:
                      changelog == null ? null : LlmChangelog(entries: changelog),
                ),
              ),
            ]),
          ),
        ],
      );

  /// Walks one more bundle, a day later each time.
  List<ThreadRelease> scrape({
    String? version,
    String title = '[0.98a] Nexerelin',
    String gameVersion = '0.98a',
    Map<String, String>? changelog,
    int replies = 0,
  }) {
    day++;
    return detector.advance(
      bundleWith(
        title: title,
        gameVersion: gameVersion,
        version: version,
        changelog: changelog,
        replies: replies,
      ),
      bundleId: 'bundle-$day',
    );
  }

  /// Reads the same version until it is believed, which takes two scrapes.
  void settle(String version, {String title = '[0.98a] Nexerelin'}) {
    scrape(version: version, title: title);
    scrape(version: version, title: title);
  }

  test('somebody replying to a thread is not a release', () {
    settle('0.12.1e');
    expect(scrape(version: '0.12.1e', replies: 40), isEmpty);
    expect(scrape(version: '0.12.1e', replies: 41), isEmpty);
    expect(detector.state.releases, isEmpty);
  });

  test('a mod putting out a new version is one release', () {
    settle('0.12.1e');
    expect(scrape(version: '0.12.2'), isEmpty, reason: 'not settled yet');

    final found = scrape(version: '0.12.2');
    expect(found, hasLength(1));
    expect(found.single.oldVersion, '0.12.1e');
    expect(found.single.newVersion, '0.12.2');
    expect(found.single.gameVersion, '0.98a');
    expect(found.single.seenOn, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });

  test('the same version spelled differently is not a release', () {
    settle('0.95');
    expect(scrape(version: 'v.0.95'), isEmpty);
    expect(scrape(version: 'Version 0.95'), isEmpty);
    expect(detector.state.releases, isEmpty);
  });

  test('an unreadable version is ignored and the known version stands', () {
    settle('1.2.0');
    scrape(version: 'v.60, .54a');
    scrape(version: 'v.60, .54a');

    expect(detector.state.releases, isEmpty);
    expect(detector.state.of(9175).believed, '1.2.0');
  });

  test('the extractor handing back the game version is thrown out', () {
    settle('1.2.0');
    expect(scrape(version: '0.98a', title: '[0.98a] Some Mod'), isEmpty);
    expect(scrape(version: '0.98a', title: '[0.98a] Some Mod'), isEmpty);
    expect(detector.state.of(9175).believed, '1.2.0');
  });

  test('leaving beta is a release', () {
    settle('0.99a BETA');
    scrape(version: '0.99a');
    expect(scrape(version: '0.99a'), hasLength(1));
  });

  test('adding a letter on the end is a release', () {
    settle('3.5.2');
    scrape(version: '3.5.2g');
    final found = scrape(version: '3.5.2g');
    expect(found, hasLength(1));
    expect(found.single.newVersion, '3.5.2g');
  });

  test('a one-off misreading never reaches the feed', () {
    settle('1.3.1');
    expect(scrape(version: '1.4.0'), isEmpty);
    expect(scrape(version: '1.3.1'), isEmpty);
    expect(scrape(version: '1.3.1'), isEmpty);
    expect(detector.state.releases, isEmpty);
    expect(detector.state.of(9175).believed, '1.3.1');
  });

  test('a settled older reading does not move the known version back', () {
    settle('1.3.3');
    settle('1.3.2');
    settle('1.3.2');
    expect(detector.state.releases, isEmpty);
    expect(detector.state.of(9175).believed, '1.3.3');
  });

  test('a title naming the old version drops the new one', () {
    settle('0.3', title: 'BattleFarer Forever [v 0.3]');
    scrape(version: '0.30', title: 'BattleFarer Forever [v 0.3]');
    scrape(version: '0.30', title: 'BattleFarer Forever [v 0.3]');

    expect(detector.state.releases, isEmpty);
    expect(detector.state.of(9175).believed, '0.3');
  });

  test('a title with no version has no say', () {
    settle('1.3.0', title: 'Planet Search');
    scrape(version: '1.3.2', title: 'Planet Search');
    expect(scrape(version: '1.3.2', title: 'Planet Search'), hasLength(1));
  });

  test('a title naming the new version lets it through', () {
    settle('1.3.0', title: '[0.98a] Some Mod v1.3.0');
    scrape(version: '1.3.2', title: '[0.98a] Some Mod v1.3.2');
    expect(scrape(version: '1.3.2', title: '[0.98a] Some Mod v1.3.2'),
        hasLength(1));
  });

  test('the first version believed for a mod is not a release', () {
    expect(scrape(version: '1.0.0'), isEmpty);
    expect(scrape(version: '1.0.0'), isEmpty);
    expect(detector.state.of(9175).believed, '1.0.0');
    expect(detector.state.releases, isEmpty);
  });

  test('1.3.3, then 1.3.2, then 1.3.3 again is exactly one release', () {
    settle('1.3.2'); // believed, and not a release — nothing came before it
    settle('1.3.3'); // a real move forward
    settle('1.3.2'); // the extractor changing its mind
    settle('1.3.3'); // and changing it back

    expect(detector.state.releases, hasLength(1));
    expect(detector.state.releases.single.oldVersion, '1.3.2');
    expect(detector.state.releases.single.newVersion, '1.3.3');
  });

  test('a release carries the post\'s own changelog notes', () {
    settle('1.0.0');
    scrape(version: '1.1.0', changelog: {'1.1.0': 'Fixed the thing.'});
    final found =
        scrape(version: '1.1.0', changelog: {'1.1.0': 'Fixed the thing.'});

    expect(found.single.changelogNotes, 'Fixed the thing.');
  });

  test('notes are matched however the post spelled the version', () {
    settle('1.0.0');
    scrape(version: '1.1.0', changelog: {'v1.1.0': 'Fixed the thing.'});
    final found =
        scrape(version: '1.1.0', changelog: {'v1.1.0': 'Fixed the thing.'});

    expect(found.single.changelogNotes, 'Fixed the thing.');
  });

  test('a release with no notes is still recorded', () {
    settle('1.0.0');
    scrape(version: '1.1.0');
    final found = scrape(version: '1.1.0');

    expect(found, hasLength(1));
    expect(found.single.changelogNotes, isNull);
  });

  test('the same saved bundle is never walked twice', () {
    final bundle = bundleWith(version: '1.0.0');
    detector.advance(bundle, bundleId: 'one');
    detector.advance(bundle, bundleId: 'one');
    expect(detector.state.of(9175).readingCount, 1);

    detector.advance(bundle, bundleId: 'two');
    expect(detector.state.of(9175).readingCount, 2);
  });

  test('a thread the bundle stopped carrying is left as it was', () {
    settle('1.0.0');
    day++;
    detector.advance(
        ForumDataBundle(updatedAt: DateTime.utc(2026, 9, 1), index: const []),
        bundleId: 'empty');
    expect(detector.state.of(9175).believed, '1.0.0');
  });

  group('the state survives being written and read back', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('release_state');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('a run picks up where the last one left off', () {
      final store = ReleaseStateStore(dir.path);
      settle('1.0.0');
      scrape(version: '1.1.0');
      store.save(detector.state);

      final laterRun = ReleaseDetector(store.load());
      expect(laterRun.state.of(9175).believed, '1.0.0');
      expect(laterRun.state.of(9175).reading, '1.1.0');
      expect(laterRun.state.of(9175).readingCount, 1);

      final found = laterRun.advance(bundleWith(version: '1.1.0'),
          bundleId: 'next');
      expect(found, hasLength(1));
      expect(found.single.newVersion, '1.1.0');
    });

    test('the feed reads newest first', () {
      final store = ReleaseStateStore(dir.path);
      settle('1.0.0');
      settle('1.1.0');
      settle('1.2.0');
      store.save(detector.state);

      final read = store.load();
      expect(read.releases, hasLength(2));
      expect(read.newestFirst.first.newVersion, '1.2.0');
      expect(read.newestFirst.last.newVersion, '1.1.0');
    });

    test('a state file that cannot be read stops the run', () {
      File('${dir.path}/${ReleaseStateStore.fileName}')
          .writeAsStringSync('{ not json');
      expect(ReleaseStateStore(dir.path).load, throwsA(isA<StateError>()));
    });
  });
}
