import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/manager/data_lock.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/job_manager.dart';
import 'package:mod_repo_scraper/manager/run_history_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fake_job_runner.dart';

void main() {
  late Directory dir;
  late String lockPath;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('data-lock-test');
    lockPath = p.join(dir.path, DataLock.fileName);
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  /// A lock that pretends every process id in [alive] is still running.
  DataLock makeLock(String label, int pid, Set<int> alive) => DataLock(
        dataPath: dir.path,
        label: label,
        ownPid: pid,
        retryDelay: const Duration(milliseconds: 5),
        isProcessAlive: alive.contains,
      );

  test('the second writer waits its turn and says who it is waiting for',
      () async {
    final alive = {100, 200};
    final first = makeLock('cli', 100, alive);
    final second = makeLock('server', 200, alive);

    await first.acquire();
    expect(File(lockPath).existsSync(), isTrue);

    final lines = <String>[];
    var secondGotIt = false;
    final waiting = second.acquire(log: lines.add).then((_) {
      secondGotIt = true;
    });

    // Give it several tries at the lock; it must still be waiting.
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(secondGotIt, isFalse);
    expect(lines, ['Waiting for the lock held by cli (pid 100).']);

    await first.release();
    await waiting;
    expect(secondGotIt, isTrue);

    // Said once, not once per try.
    expect(lines.length, 1);
    expect(second.currentHolder()!.label, 'server');
  });

  test('a lock left by a dead process is cleared, and the clearing is logged',
      () async {
    File(lockPath).writeAsStringSync(jsonEncode({
      'pid': 999,
      'label': 'cli',
      'startedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
    }));

    final lines = <String>[];
    // 999 is not in the "alive" set, so it counts as gone.
    final lock = makeLock('server', 100, {100});
    await lock.acquire(log: lines.add);

    expect(lock.isHeld, isTrue);
    expect(lock.currentHolder()!.pid, 100);
    expect(
        lines,
        ['Clearing a lock left behind by cli (pid 999), which is no longer '
            'running.']);
  });

  test('the lock is gone after a job throws', () async {
    final service = FakeJobRunner()..throwThis = StateError('the run broke');
    final manager = JobManager(
      service: service,
      history: RunHistoryStore(dir.path),
      lock: makeLock('cli', 100, {100}),
    );
    await manager.load();

    final record = await manager.submit(JobRequest.rebuildBundle());

    expect(record.state, RunState.failed);
    expect(File(lockPath).existsSync(), isFalse);
  });

  test('the lock is gone after a job finishes', () async {
    final manager = JobManager(
      service: FakeJobRunner(),
      history: RunHistoryStore(dir.path),
      lock: makeLock('cli', 100, {100}),
    );
    await manager.load();

    final record = await manager.submit(JobRequest.rebuildBundle());

    expect(record.state, RunState.completed);
    expect(File(lockPath).existsSync(), isFalse);
  });

  test('two managers on one folder take turns', () async {
    final alive = {100, 200};
    final firstService = FakeJobRunner()..holdUntilReleased();
    final firstManager = JobManager(
      service: firstService,
      history: RunHistoryStore(dir.path),
      lock: makeLock('cli', 100, alive),
    );
    final secondService = FakeJobRunner();
    final secondManager = JobManager(
      service: secondService,
      history: RunHistoryStore(p.join(dir.path, 'other')),
      lock: makeLock('server', 200, alive),
    );
    await firstManager.load();
    await secondManager.load();

    final firstDone = firstManager.submit(JobRequest.rebuildBundle());
    await firstService.started.future;

    final secondDone = secondManager.submit(JobRequest.rebuildBundle());
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(secondService.ran, isEmpty, reason: 'it should still be waiting');

    firstService.release();
    await firstDone;
    await secondDone;
    expect(secondService.ran, hasLength(1));
    expect(File(lockPath).existsSync(), isFalse);
  });
}
