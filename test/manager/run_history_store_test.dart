import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/run_history_store.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:mod_repo_scraper/timber/log_level.dart';
import 'package:mod_repo_scraper/timber/timber.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('run-history-test');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  List<dynamic> readIndex(Directory dir) => jsonDecode(
        File(p.join(dir.path, 'runs', RunHistoryStore.indexFileName))
            .readAsStringSync(),
      ) as List<dynamic>;

  test('a record is written the moment a run starts', () async {
    final store = RunHistoryStore(dir.path);
    await store.load();

    final record = await store.startRun(JobRequest.rebuildBundle());

    final saved = readIndex(dir);
    expect(saved, hasLength(1));
    expect(saved.first['id'], record.id);
    expect(saved.first['state'], 'running');
    expect(saved.first['logFileName'], '${record.id}.log');
  });

  test('two programs sharing one folder keep each other\'s runs', () async {
    // Both have the folder open, as a server and a command line would.
    final server = RunHistoryStore(dir.path);
    final cli = RunHistoryStore(dir.path);
    await server.load();
    await cli.load();

    final fromServer = await server.startRun(JobRequest.rebuildBundle());
    // The command line hasn't heard of that run; it started before it existed.
    final fromCli = await cli.startRun(JobRequest.llmCoveragePass());

    // Each one writing again must not lose the other's run.
    await server.save();

    final ids = [for (final r in readIndex(dir)) r['id'] as String];
    expect(ids, containsAll([fromServer.id, fromCli.id]));
    expect(server.byId(fromCli.id), isNotNull);
    // Newest first is kept.
    expect(ids, [...ids]..sort((a, b) => b.compareTo(a)));
  });

  test('the request is kept, so the same job can be asked for again', () async {
    final store = RunHistoryStore(dir.path);
    await store.load();

    final record = await store.startRun(
        JobRequest.forTopics(JobKind.rescrapeTopics, [123, 456]));

    final reread = RunHistoryStore(dir.path);
    await reread.load();
    final back = reread.byId(record.id)!;
    expect(back.request.kind, JobKind.rescrapeTopics);
    expect(back.request.topicIds, [123, 456]);
  });

  test('counters reach the disk part-way through a run', () async {
    final store = RunHistoryStore(dir.path);
    await store.load();
    var record = await store.startRun(JobRequest.llmCoveragePass());

    for (var done = 1; done <= 12; done++) {
      record = await store.reportProgress(
          record, RunCounters(itemsDone: done, itemsTotal: 100));
    }

    final saved = readIndex(dir);
    expect(saved.first['counters']['itemsDone'], 10,
        reason: 'the index is written every ten progress reports');
    expect(saved.first['state'], 'running');
  });

  test('a failed run keeps its error message', () async {
    final store = RunHistoryStore(dir.path);
    await store.load();
    final record = await store.startRun(JobRequest.rebuildBundle());

    await store.update(record.copyWith(
      state: RunState.failed,
      errorMessage: 'the forum was not there',
      finishedAt: DateTime.now().toUtc(),
    ));

    final saved = readIndex(dir);
    expect(saved.first['state'], 'failed');
    expect(saved.first['errorMessage'], 'the forum was not there');
  });

  test('a run left saying running is marked interrupted next time', () async {
    final store = RunHistoryStore(dir.path);
    await store.load();
    final record = await store.startRun(JobRequest.rebuildBundle());

    // Nothing else happens — as if the program was killed here.
    final next = RunHistoryStore(dir.path);
    await next.load();

    expect(next.byId(record.id)!.state, RunState.interrupted);
    expect(readIndex(dir).first['state'], 'interrupted');
  });

  test('only the newest runs are kept, log files and all', () async {
    final store = RunHistoryStore(dir.path, runsToKeep: 3);
    await store.load();

    final ids = <String>[];
    for (var i = 0; i < 5; i++) {
      final record = await store.startRun(
        JobRequest.rebuildBundle(),
        now: DateTime.utc(2026, 1, 1, 0, i),
      );
      // A real run leaves a log file behind; those are what fill the folder.
      File(p.join(dir.path, 'runs', record.logFileName))
          .writeAsStringSync('log for run $i');
      await store.update(record.copyWith(state: RunState.completed));
      ids.add(record.id);
    }

    expect(store.records, hasLength(3));
    expect(readIndex(dir), hasLength(3));
    // The two oldest are gone, newest first order kept.
    expect(store.records.map((r) => r.id), [ids[4], ids[3], ids[2]]);
    expect(File(p.join(dir.path, 'runs', '${ids[0]}.log')).existsSync(), isFalse);
    expect(File(p.join(dir.path, 'runs', '${ids[1]}.log')).existsSync(), isFalse);
    expect(File(p.join(dir.path, 'runs', '${ids[2]}.log')).existsSync(), isTrue);
  });

  test('keeping every run is still possible', () async {
    final store = RunHistoryStore(dir.path, runsToKeep: 0);
    await store.load();
    for (var i = 0; i < 4; i++) {
      await store.startRun(
        JobRequest.rebuildBundle(),
        now: DateTime.utc(2026, 1, 1, 0, i),
      );
    }
    expect(store.records, hasLength(4));
    expect(readIndex(dir), hasLength(4));
  });

  // A server sits there for weeks. Without this, the history page would show
  // what it showed the morning the server started, and a run somebody kicked
  // off from the command line would be missing exactly when they went looking
  // for it.
  test('a run started by another program shows up without a restart', () async {
    final server = RunHistoryStore(dir.path);
    await server.load();
    expect(server.records, isEmpty);

    // Somebody runs the scraper by hand on the same folder.
    final cli = RunHistoryStore(dir.path);
    await cli.load();
    final theirs = await cli.startRun(JobRequest.llmCoveragePass());

    expect(server.byId(theirs.id), isNotNull,
        reason: 'the server should see it without being restarted');
    expect(server.records.first.id, theirs.id);

    // And it keeps up as that run gets on with it.
    await cli.update(theirs.copyWith(
      state: RunState.completed,
      counters: const RunCounters(itemsDone: 7, itemsTotal: 7, llmCalls: 3),
    ));

    final seen = server.byId(theirs.id)!;
    expect(seen.state, RunState.completed);
    expect(seen.counters.llmCalls, 3);
  });

  // Our own live run is saved every tenth report, so memory is ahead of the
  // file. Reading the file back must not wind it backwards.
  test('re-reading does not undo our own live run', () async {
    final ours = RunHistoryStore(dir.path);
    await ours.load();
    var record = await ours.startRun(JobRequest.llmCoveragePass());

    // Two reports: not enough to reach the disk, so the file still says 0.
    record = await ours.reportProgress(
        record, const RunCounters(itemsDone: 40, itemsTotal: 100, llmCalls: 12));

    // Another program writes the file, which makes ours look out of date.
    final other = RunHistoryStore(dir.path);
    await other.load();
    await other.startRun(JobRequest.rebuildBundle());

    final mine = ours.byId(record.id)!;
    expect(mine.counters.itemsDone, 40, reason: 'our newer count is kept');
    expect(mine.counters.llmCalls, 12);
    expect(ours.records, hasLength(2), reason: 'and we picked up theirs');
  });

  // Dropping old runs throws away the paperwork, never the work. Re-scraping
  // the whole forum because the history got tidy would be a bad trade.
  test('dropping old runs leaves the scraped data alone', () async {
    // The things a run actually produces, all outside the runs folder.
    final data = {
      'mods-index.json': '[{"topicId":123}]',
      'mods/123/detail.json': '{"topicId":123,"title":"Some mod"}',
      'assumed-downloads-cache.json': '{"123":[]}',
      'link-downloadable-cache.json': '{"http://example.com":true}',
      'llm-extraction-cache.json': '{"123":{"summary":"a mod"}}',
      'qb_raw_cache.json': '{"url":"http://example.com"}',
    };
    for (final entry in data.entries) {
      final file = File(p.join(dir.path, entry.key));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(entry.value);
    }

    final store = RunHistoryStore(dir.path, runsToKeep: 1);
    await store.load();
    for (var i = 0; i < 4; i++) {
      final record = await store.startRun(
        JobRequest.rebuildBundle(),
        now: DateTime.utc(2026, 1, 1, 0, i),
      );
      await store.update(record.copyWith(state: RunState.completed));
    }

    expect(store.records, hasLength(1), reason: 'runs really were dropped');
    for (final entry in data.entries) {
      final file = File(p.join(dir.path, entry.key));
      expect(file.existsSync(), isTrue, reason: '${entry.key} should survive');
      expect(file.readAsStringSync(), entry.value,
          reason: '${entry.key} should be untouched');
    }
  });

  // The log file name is read back from a file on disk, and this is the only
  // place that deletes anything, so a damaged or hand-edited index must not be
  // able to point it at the scraped data.
  test('a log name pointing outside the runs folder deletes nothing', () async {
    final treasure = File(p.join(dir.path, 'mods-index.json'))
      ..writeAsStringSync('[{"topicId":123}]');

    // Write an index by hand, as a damaged one might look.
    final runsDir = Directory(p.join(dir.path, 'runs'))
      ..createSync(recursive: true);
    Map<String, dynamic> entry(String id, String logFileName) => {
          'id': id,
          'request': JobRequest.rebuildBundle().toMap(),
          'state': 'completed',
          'startedAt': '2026-01-01T00:00:00.000Z',
          'finishedAt': '2026-01-01T00:00:01.000Z',
          'counters': const RunCounters().toMap(),
          'logFileName': logFileName,
        };
    File(p.join(runsDir.path, RunHistoryStore.indexFileName))
        .writeAsStringSync(jsonEncode([
      entry('20260101T000200Z-rebuildBundle', '20260101T000200Z-rebuildBundle.log'),
      entry('20260101T000100Z-rebuildBundle', '../mods-index.json'),
    ]));

    final store = RunHistoryStore(dir.path, runsToKeep: 1);
    await store.load();
    await store.save();

    expect(store.records, hasLength(1), reason: 'the old run was dropped');
    expect(treasure.existsSync(), isTrue);
    expect(treasure.readAsStringSync(), '[{"topicId":123}]');
  });

  test('a run still going is never dropped', () async {
    final store = RunHistoryStore(dir.path, runsToKeep: 2);
    await store.load();

    // The oldest is the one still running — it must survive, because something
    // is still writing to it.
    final live = await store.startRun(JobRequest.llmCoveragePass(),
        now: DateTime.utc(2026, 1, 1, 0, 0));
    for (var i = 1; i < 4; i++) {
      final record = await store.startRun(
        JobRequest.rebuildBundle(),
        now: DateTime.utc(2026, 1, 1, 0, i),
      );
      await store.update(record.copyWith(state: RunState.completed));
    }

    expect(store.byId(live.id), isNotNull);
    expect(store.byId(live.id)!.state, RunState.running);
  });

  test('two runs get their own log files', () async {
    final tree = DebugTree(minLogLevelToShow: LogLevel.verbose);
    Timber.plant(tree);
    addTearDown(() {
      Timber.uproot(tree);
      DebugTree.extraAppenders.clear();
    });

    final first = RunLogCapture(p.join(dir.path, 'runs', 'first.log'));
    await first.start();
    Timber.i('line for the first run');
    await first.stop();

    final second = RunLogCapture(p.join(dir.path, 'runs', 'second.log'));
    await second.start();
    Timber.i('line for the second run');
    await second.stop();

    final firstText = File(first.path).readAsStringSync();
    final secondText = File(second.path).readAsStringSync();
    expect(firstText, contains('line for the first run'));
    expect(firstText, isNot(contains('line for the second run')));
    expect(secondText, contains('line for the second run'));
    expect(secondText, isNot(contains('line for the first run')));
  });

  // The server has no console, so a reporter that keeps its lines to itself
  // would leave a browsed run showing "1 error" and no word of why. Everything
  // a job says has to land in the run's own log file.
  test("a server job's own words reach its log file", () async {
    final tree = DebugTree(minLogLevelToShow: LogLevel.verbose);
    Timber.plant(tree);
    addTearDown(() {
      Timber.uproot(tree);
      DebugTree.extraAppenders.clear();
    });

    final capture = RunLogCapture(p.join(dir.path, 'runs', 'server.log'));
    await capture.start();
    const LogRunReporter().log('Topic 24860 has no saved post; skipping.');
    await capture.stop();

    expect(
      File(capture.path).readAsStringSync(),
      contains('Topic 24860 has no saved post; skipping.'),
    );
  });
}
