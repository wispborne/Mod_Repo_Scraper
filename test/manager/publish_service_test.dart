import 'dart:io';

import 'package:mod_repo_scraper/manager/cancel_token.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/modrepo_service.dart';
import 'package:mod_repo_scraper/manager/publish_service.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:mod_repo_scraper/manager/scraper_settings.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fake_job_runner.dart';

/// Runs git and hands back the result. Fails the test if git isn't there.
ProcessResult _git(List<String> args, {String? cwd}) {
  final result = Process.runSync('git', args, workingDirectory: cwd);
  return result;
}

bool _gitIsThere() {
  try {
    return Process.runSync('git', ['--version']).exitCode == 0;
  } catch (_) {
    return false;
  }
}

void main() {
  group('PublishService', () {
    late Directory tmp;
    late String remote; // A bare repo standing in for GitHub.
    late String outputs; // Where the current output files live.
    late String cloneDir; // Where the service keeps its working clone.
    late PublishService service;
    late RecordingRunReporter reporter;

    // Reads a file's content out of the bare remote's default branch.
    String remoteContent(String name) =>
        (_git(['show', 'main:$name'], cwd: remote).stdout as String);

    int remoteCommitCount() =>
        int.parse((_git(['rev-list', '--count', 'main'], cwd: remote).stdout
                as String)
            .trim());

    void writeOutputs(String modRepo, String bundle) {
      File(p.join(outputs, 'ModRepo.json')).writeAsStringSync(modRepo);
      File(p.join(outputs, 'forum-data-bundle.json')).writeAsStringSync(bundle);
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('publish_service');
      remote = p.join(tmp.path, 'remote.git');
      outputs = p.join(tmp.path, 'outputs');
      cloneDir = p.join(tmp.path, 'clone');
      Directory(outputs).createSync(recursive: true);

      // A bare remote with one commit on `main`, holding both files.
      _git(['init', '--bare', '--initial-branch=main', remote]);
      final seed = p.join(tmp.path, 'seed');
      _git(['clone', remote, seed]);
      File(p.join(seed, 'ModRepo.json')).writeAsStringSync('old repo');
      File(p.join(seed, 'forum-data-bundle.json')).writeAsStringSync('old bundle');
      _git(['add', '-A'], cwd: seed);
      _git(['-c', 'user.email=t@t', '-c', 'user.name=Test', 'commit', '-m',
        'seed'], cwd: seed);
      _git(['push', 'origin', 'HEAD:main'], cwd: seed);

      reporter = RecordingRunReporter();
      service = PublishService(
        environment: PublishEnvironment(
          outputPath: outputs,
          repoUrl: remote,
          cloneDir: cloneDir,
        ),
      );
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    test('a changed output makes one commit and pushes both files', () async {
      writeOutputs('new repo', 'new bundle');
      final before = remoteCommitCount();

      final outcome = await service.runJob(JobRequest.publishOutputs(),
          reporter: reporter);

      expect(outcome.cancelled, isFalse);
      expect(outcome.itemsDone, 2);
      expect(remoteCommitCount(), before + 1);
      expect(remoteContent('ModRepo.json'), 'new repo');
      expect(remoteContent('forum-data-bundle.json'), 'new bundle');
    }, skip: _gitIsThere() ? false : 'git is not installed');

    test('nothing changed means no commit and no push', () async {
      // First publish gets "new" onto the remote.
      writeOutputs('new repo', 'new bundle');
      await service.runJob(JobRequest.publishOutputs(), reporter: reporter);
      final after = remoteCommitCount();

      // Second publish, same outputs: nothing to do.
      final reporter2 = RecordingRunReporter();
      final outcome = await service.runJob(JobRequest.publishOutputs(),
          reporter: reporter2);

      expect(outcome.cancelled, isFalse);
      expect(remoteCommitCount(), after);
      expect(reporter2.logs.any((l) => l.contains('Nothing changed')), isTrue);
    }, skip: _gitIsThere() ? false : 'git is not installed');

    test('an unreachable remote fails with the git error, not a silent success',
        () async {
      writeOutputs('new repo', 'new bundle');
      final broken = PublishService(
        environment: PublishEnvironment(
          outputPath: outputs,
          repoUrl: p.join(tmp.path, 'no-such-repo.git'),
          cloneDir: p.join(tmp.path, 'broken-clone'),
        ),
      );

      await expectLater(
        broken.runJob(JobRequest.publishOutputs(), reporter: reporter),
        throwsA(isA<StateError>()),
      );
    }, skip: _gitIsThere() ? false : 'git is not installed');

    test('a cancel before the push pushes nothing', () async {
      writeOutputs('new repo', 'new bundle');
      final before = remoteCommitCount();
      final cancel = CancelToken()..cancel();

      final outcome = await service.runJob(JobRequest.publishOutputs(),
          reporter: reporter, cancel: cancel);

      expect(outcome.cancelled, isTrue);
      expect(remoteCommitCount(), before);
      expect(remoteContent('ModRepo.json'), 'old repo');
      expect(reporter.logs.any((l) => l.contains('left as it was')), isTrue);
    }, skip: _gitIsThere() ? false : 'git is not installed');

    test('it refuses a job that is not a publish', () {
      expect(
        () => service.runJob(JobRequest.rebuildBundle()),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('JobRouter', () {
    test('publishOutputs reaches the publish runner and nothing else', () async {
      final qb = FakeJobRunner();
      final modRepo = FakeJobRunner();
      final publish = FakeJobRunner();
      final router = JobRouter(qb: qb, modRepo: modRepo, publish: publish);

      await router.runJob(JobRequest.publishOutputs());

      expect(publish.ran.map((r) => r.kind), [JobKind.publishOutputs]);
      expect(qb.ran, isEmpty);
      expect(modRepo.ran, isEmpty);
    });

    test('merge and QB kinds still reach their own runners', () async {
      final qb = FakeJobRunner();
      final modRepo = FakeJobRunner();
      final publish = FakeJobRunner();
      final router = JobRouter(qb: qb, modRepo: modRepo, publish: publish);

      await router.runJob(JobRequest.mergeModRepo());
      await router.runJob(JobRequest.rebuildBundle());

      expect(modRepo.ran.map((r) => r.kind), [JobKind.mergeModRepo]);
      expect(qb.ran.map((r) => r.kind), [JobKind.rebuildBundle]);
      expect(publish.ran, isEmpty);
    });
  });
}
