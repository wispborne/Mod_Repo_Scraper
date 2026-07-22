import 'dart:io';

import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/job_manager.dart';
import 'package:mod_repo_scraper/manager/run_history_store.dart';
import 'package:test/test.dart';

import 'fake_job_runner.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('live-status-test');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('the live view follows the run and clears when it ends', () async {
    final service = FakeJobRunner()
      ..phaseName = 'Asking the LLM'
      ..itemName = 'Nexerelin'
      ..itemsTotal = 7
      ..holdUntilReleased();
    final manager = JobManager(
      service: service,
      history: RunHistoryStore(dir.path),
    );
    await manager.load();

    expect(manager.liveStatus, isNull);

    final done = manager.submit(JobRequest.rebuildBundle());
    await service.started.future;

    final live = manager.liveStatus!;
    expect(live.runId, manager.currentRun!.id);
    expect(live.phase, 'Asking the LLM');
    expect(live.item, 'Nexerelin');
    expect(live.itemsDone, 1);
    expect(live.itemsTotal, 7);

    service.release();
    await done;

    expect(manager.liveStatus, isNull);
    expect(manager.currentRun, isNull);
  });
}
