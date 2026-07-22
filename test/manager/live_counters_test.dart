import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/job_manager.dart';
import 'package:mod_repo_scraper/manager/run_history_store.dart';
import 'package:test/test.dart';

import 'fake_job_runner.dart';

/// What a run has spent has to be saved as it goes, not only when it ends.
/// Otherwise a run that is killed part-way says it made no LLM calls and hit no
/// errors, which is a flattering lie about work you have already paid for.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('live-counters-test');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('errors and LLM calls show up while the run is still going', () async {
    final service = FakeJobRunner()
      ..reportErrors = 2
      ..reportLlmCalls = 17
      ..holdUntilReleased();
    final manager = JobManager(service: service, history: RunHistoryStore(dir.path));
    await manager.load();

    final done = manager.submit(JobRequest.llmCoveragePass());
    await service.started.future;

    final counters = manager.currentRun!.counters;
    expect(counters.llmCalls, 17);
    expect(counters.errors, 2);

    service.release();
    await done;
  });

  test('a job that says nothing about them does not wipe them', () async {
    // The scrape cannot count its failures as it goes, so it leaves errors
    // alone and the job's own answer fills them in at the end.
    final service = FakeJobRunner()
      ..reportLlmCalls = 5
      ..holdUntilReleased();
    final manager = JobManager(service: service, history: RunHistoryStore(dir.path));
    await manager.load();

    final done = manager.submit(JobRequest.fullRun());
    await service.started.future;

    expect(manager.currentRun!.counters.llmCalls, 5);
    expect(manager.currentRun!.counters.errors, 0);

    service.release();
    await done;
  });

  test('a run that dies still says what it spent', () async {
    final service = FakeJobRunner()
      ..reportLlmCalls = 46
      ..holdUntilReleased();
    final history = RunHistoryStore(dir.path);
    final manager = JobManager(service: service, history: history);
    await manager.load();

    final done = manager.submit(JobRequest.llmCoveragePass());
    await service.started.future;
    // Whatever is known so far reaches the disk, exactly as the process dying
    // here would leave it.
    await history.save();

    // A second manager starting on the same folder reads what was left behind
    // and marks the run interrupted — with its spending intact.
    final reopened = RunHistoryStore(dir.path);
    await reopened.load();
    final left = reopened.records.first;
    expect(left.state, RunState.interrupted);
    expect(left.counters.llmCalls, 46);

    // And it is really on disk, not just in memory.
    final onDisk = jsonDecode(File(reopened.indexPath).readAsStringSync());
    expect((onDisk as List).first['counters']['llmCalls'], 46);

    service.release();
    await done;
  });
}
