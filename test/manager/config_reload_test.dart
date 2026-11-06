import 'dart:io';

import 'package:mod_repo_scraper/bot/common.dart';
import 'package:mod_repo_scraper/manager/config_reload.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/job_manager.dart';
import 'package:mod_repo_scraper/manager/run_history_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fake_job_runner.dart';

void main() {
  late Directory dir;
  late String configPath;
  late BotConfig startup;
  late FakeJobRunner first;

  /// Every runner built after startup, with the settings it was built from.
  late List<({BotConfig config, FakeJobRunner runner})> built;
  late JobManager manager;
  late List<String> logged;

  const job = JobRequest(kind: JobKind.rebuildBundle);

  /// Writes the config file so its change time and size both move, whatever
  /// the file system's clock resolution.
  void writeConfig(String text) {
    final file = File(configPath)..writeAsStringSync(text);
    file.setLastModifiedSync(
        file.lastModifiedSync().add(const Duration(seconds: 5)));
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('config-reload-test');
    configPath = p.join(dir.path, 'config.properties');
    File(configPath).writeAsStringSync(
        'qb_data_path = ${dir.path}\nllm_max_topics = 200\n');
    final stamp = FileStamp.of(configPath);
    startup = Common.readConfig(configFilePath: configPath)!;

    first = FakeJobRunner();
    built = [];
    logged = [];
    final reload = ConfigReload(
      configPath: configPath,
      startup: startup,
      seen: stamp,
      build: (config) async {
        final runner = FakeJobRunner();
        built.add((config: config, runner: runner));
        return runner;
      },
    );
    manager = JobManager(
      service: first,
      history: RunHistoryStore(dir.path),
      beforeJob: (log) => reload.beforeJob((line) {
        logged.add(line);
        log(line);
      }),
    );
    await manager.load();
  });

  tearDown(() async {
    first.release();
    for (final b in built) {
      b.runner.release();
    }
    for (var i = 0; i < 200 && manager.currentRun != null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test('an unchanged file builds nothing', () async {
    await manager.submit(job);
    await manager.submit(job);
    expect(built, isEmpty);
    expect(first.ran, hasLength(2));
    expect(logged, isEmpty);
  });

  test('a limit changed between jobs is used by the next job', () async {
    await manager.submit(job);
    writeConfig('qb_data_path = ${dir.path}\nllm_max_topics = 300\n');

    final record = await manager.submit(job);
    expect(record.state, RunState.completed);
    expect(built, hasLength(1));
    expect(built.single.config.llmMaxTopics, 300);
    expect(built.single.runner.ran, hasLength(1));
    expect(first.ran, hasLength(1));
    expect(logged.single, contains('changed since the last job'));

    // Read once: the job after that builds nothing new.
    await manager.submit(job);
    expect(built, hasLength(1));
    expect(built.single.runner.ran, hasLength(2));
  });

  test('a change made during a job waits for the next job', () async {
    first.holdUntilReleased();
    final running = manager.submit(job);
    await first.started.future;

    writeConfig('qb_data_path = ${dir.path}\nllm_max_topics = 300\n');
    first.release();
    await running;
    expect(first.ran, hasLength(1));
    expect(built, isEmpty);

    await manager.submit(job);
    expect(built.single.config.llmMaxTopics, 300);
    expect(built.single.runner.ran, hasLength(1));
  });

  test('the data folder and the log level wait for a restart', () async {
    writeConfig('qb_data_path = somewhere_else\nlog_level = DEBUG\n'
        'llm_max_topics = 300\n');

    await manager.submit(job);
    final config = built.single.config;
    expect(config.qbDataPath, startup.qbDataPath);
    expect(config.logLevel, startup.logLevel);
    expect(config.llmMaxTopics, 300);
    expect(logged.where((l) => l.contains('after a restart')), hasLength(2));
  });

  test('a file that is gone keeps the last good settings, and says so',
      () async {
    File(configPath).deleteSync();

    final record = await manager.submit(job);
    expect(record.state, RunState.completed);
    expect(first.ran, hasLength(1));
    expect(built, isEmpty);
    expect(logged.single, contains('is gone'));
  });

  test('services that cannot be built keep the last good ones', () async {
    final failing = JobManager(
      service: first,
      history: RunHistoryStore(dir.path),
      beforeJob: ConfigReload(
        configPath: configPath,
        startup: startup,
        seen: FileStamp.of(configPath),
        build: (_) async => throw StateError('the cache is broken'),
      ).beforeJob,
    );
    await failing.load();
    writeConfig('llm_max_topics = 300\n');

    final record = await failing.submit(job);
    expect(record.state, RunState.completed);
    expect(first.ran, hasLength(1));
  });

  test('a hook that throws does not stop the job', () async {
    final throwing = JobManager(
      service: first,
      history: RunHistoryStore(dir.path),
      beforeJob: (_) async => throw StateError('oops'),
    );
    await throwing.load();
    final record = await throwing.submit(job);
    expect(record.state, RunState.completed);
    expect(first.ran, hasLength(1));
  });

  test('the runner a hook hands back replaces the old one', () async {
    final replacement = FakeJobRunner();
    var calls = 0;
    final swapping = JobManager(
      service: first,
      history: RunHistoryStore(dir.path),
      beforeJob: (_) async => calls++ == 0 ? replacement : null,
    );
    await swapping.load();
    await swapping.submit(job);
    await swapping.submit(job);
    expect(first.ran, isEmpty);
    expect(replacement.ran, hasLength(2));
    expect(swapping.service, same(replacement));
  });
}
