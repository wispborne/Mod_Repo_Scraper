import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/qb/models/scrape_job.dart';
import 'package:mod_repo_scraper/catalog/takedowns.dart';
import 'package:mod_repo_scraper/manager/cancel_token.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/modrepo_service.dart';
import 'package:mod_repo_scraper/manager/publish_service.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:mod_repo_scraper/manager/scraper_service.dart';
import 'package:mod_repo_scraper/manager/scraper_settings.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fake_job_runner.dart';

/// Runs git and hands back the result. Fails the test if git isn't there.
ProcessResult _git(List<String> args, {String? cwd}) {
  final result = Process.runSync('git', args, workingDirectory: cwd);
  return result;
}

/// A fake job that writes its name down when it runs, so a test can see which
/// of two runners went first.
class _OrderedRunner extends FakeJobRunner {
  final String name;
  final List<String> order;

  _OrderedRunner(this.name, this.order);

  @override
  Future<JobOutcome> runJob(
    JobRequest request, {
    RunReporter reporter = const SilentRunReporter(),
    CancelToken? cancel,
    String? runId,
  }) {
    order.add(name);
    return super.runJob(request, reporter: reporter, cancel: cancel, runId: runId);
  }
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
    late String siteDir; // The website's own files, as they sit in the repo.
    late String dataDir; // qb_data, which holds the takedown list.
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
      File(p.join(outputs, 'mod-catalog.json')).writeAsStringSync(modRepo);
      File(p.join(outputs, 'mod-catalog-details.json')).writeAsStringSync(bundle);
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('publish_service');
      remote = p.join(tmp.path, 'remote.git');
      outputs = p.join(tmp.path, 'outputs');
      cloneDir = p.join(tmp.path, 'clone');
      siteDir = p.join(tmp.path, 'site-source');
      dataDir = p.join(tmp.path, 'qb_data');
      Directory(outputs).createSync(recursive: true);
      Directory(p.join(siteDir, 'views')).createSync(recursive: true);
      File(p.join(siteDir, 'index.html')).writeAsStringSync('<html></html>');
      File(p.join(siteDir, 'views', 'browse.js')).writeAsStringSync('// browse');

      // A bare remote with one commit on `main`, holding both files.
      _git(['init', '--bare', '--initial-branch=main', remote]);
      final seed = p.join(tmp.path, 'seed');
      _git(['clone', remote, seed]);
      File(p.join(seed, 'mod-catalog.json')).writeAsStringSync('old repo');
      File(p.join(seed, 'mod-catalog-details.json')).writeAsStringSync('old bundle');
      // The frozen files, which old TriOS installs read.
      File(p.join(seed, 'ModRepo.json')).writeAsStringSync('frozen repo');
      File(p.join(seed, 'forum-data-bundle.json')).writeAsStringSync('frozen bundle');
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
          dataPath: dataDir,
          sitePath: siteDir,
        ),
      );
    });

    /// Writes the website's data files where a run leaves them, under
    /// `<outputs>/site/`.
    void writeWebsiteData(List<String> modIds) {
      final site = Directory(p.join(outputs, 'site', 'mods'))
        ..createSync(recursive: true);
      File(p.join(outputs, 'site', 'mods.json'))
          .writeAsStringSync('{"mods": []}');
      File(p.join(outputs, 'site', 'updates.json'))
          .writeAsStringSync('{"releases": []}');
      File(p.join(outputs, 'site', 'updates.xml'))
          .writeAsStringSync('<feed/>');
      Directory(p.join(outputs, 'site', 'how-to-install-mods'))
          .createSync(recursive: true);
      File(p.join(outputs, 'site', 'how-to-install-mods', 'index.html'))
          .writeAsStringSync('<title>How to install mods</title>');
      for (final id in modIds) {
        File(p.join(site.path, '$id.json')).writeAsStringSync('{"id": "$id"}');
        Directory(p.join(site.path, id)).createSync(recursive: true);
        File(p.join(site.path, id, 'index.html'))
            .writeAsStringSync('<title>$id</title>');
      }
    }

    bool inRemote(String path) =>
        _git(['cat-file', '-e', 'main:$path'], cwd: remote).exitCode == 0;

    tearDown(() => tmp.deleteSync(recursive: true));

    test('a changed output makes one commit and pushes both files', () async {
      writeOutputs('new repo', 'new bundle');
      final before = remoteCommitCount();

      final outcome = await service.runJob(JobRequest.publishOutputs(),
          reporter: reporter);

      expect(outcome.cancelled, isFalse);
      expect(outcome.itemsDone, 2);
      expect(remoteCommitCount(), before + 1);
      expect(remoteContent('mod-catalog.json'), 'new repo');
      expect(remoteContent('mod-catalog-details.json'), 'new bundle');
    }, skip: _gitIsThere() ? false : 'git is not installed');

    test('the frozen ModRepo.json and forum-data-bundle.json are left as they were', () async {
      writeOutputs('new repo', 'new bundle');
      // Even a local copy of an old file is never carried across.
      File(p.join(outputs, 'ModRepo.json')).writeAsStringSync('stale local repo');
      File(p.join(outputs, 'forum-data-bundle.json')).writeAsStringSync('stale local bundle');

      await service.runJob(JobRequest.publishOutputs(), reporter: reporter);

      expect(remoteContent('mod-catalog.json'), 'new repo');
      expect(remoteContent('ModRepo.json'), 'frozen repo');
      expect(remoteContent('forum-data-bundle.json'), 'frozen bundle');
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
          dataPath: dataDir,
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
      expect(remoteContent('mod-catalog.json'), 'old repo');
      expect(reporter.logs.any((l) => l.contains('left as it was')), isTrue);
    }, skip: _gitIsThere() ? false : 'git is not installed');

    test('the website files go out in the same commit as the outputs', () async {
      writeOutputs('new repo', 'new bundle');
      writeWebsiteData(['nexerelin', 'quality-captains']);
      final before = remoteCommitCount();

      await service.runJob(JobRequest.publishOutputs(), reporter: reporter);

      // One commit, and everything in it.
      expect(remoteCommitCount(), before + 1);
      expect(remoteContent('mod-catalog.json'), 'new repo');
      expect(remoteContent('mod-catalog-details.json'), 'new bundle');
      expect(remoteContent('mods.json'), '{"mods": []}');
      expect(remoteContent('updates.json'), '{"releases": []}');
      expect(remoteContent('mods/nexerelin.json'), '{"id": "nexerelin"}');
    }, skip: _gitIsThere() ? false : 'git is not installed');

    test('the pushed repo holds the site next to the data it reads', () async {
      writeOutputs('new repo', 'new bundle');
      writeWebsiteData(['nexerelin']);

      await service.runJob(JobRequest.publishOutputs(), reporter: reporter);

      // The site's own files, at the root, so the repo can be served as it is.
      expect(inRemote('index.html'), isTrue);
      expect(inRemote('views/browse.js'), isTrue);
      // And the files the site asks for, at the addresses it asks for them.
      expect(inRemote('mods.json'), isTrue);
      expect(inRemote('updates.json'), isTrue);
      expect(inRemote('updates.xml'), isTrue,
          reason: 'the feed people subscribe to has to go out too');
      expect(inRemote('how-to-install-mods/index.html'), isTrue,
          reason: 'the install guide is a page of its own');
      expect(inRemote('mods/nexerelin.json'), isTrue);
      expect(inRemote('mods/nexerelin/index.html'), isTrue,
          reason: 'a link shared in Discord has to land on the mod, not on the '
              'front page');
    }, skip: _gitIsThere() ? false : 'git is not installed');

    test('publishes problem report forms but skips other dot folders', () async {
      writeOutputs('new repo', 'new bundle');
      Directory(p.join(siteDir, '.github', 'ISSUE_TEMPLATE'))
          .createSync(recursive: true);
      File(p.join(siteDir, '.github', 'ISSUE_TEMPLATE', 'mod-problem.yml'))
          .writeAsStringSync('name: Problem with a mod');
      Directory(p.join(siteDir, '.idea')).createSync();
      File(p.join(siteDir, '.idea', 'workspace.xml')).writeAsStringSync('<x/>');

      await service.runJob(JobRequest.publishOutputs(), reporter: reporter);

      expect(inRemote('.github/ISSUE_TEMPLATE/mod-problem.yml'), isTrue,
          reason: 'GitHub only reads issue forms from .github in the repo');
      expect(inRemote('.idea/workspace.xml'), isFalse);
    }, skip: _gitIsThere() ? false : 'git is not installed');

    test('a publish with no website files still publishes the outputs',
        () async {
      writeOutputs('new repo', 'new bundle');
      final before = remoteCommitCount();

      final outcome = await service.runJob(JobRequest.publishOutputs(),
          reporter: reporter);

      expect(outcome.cancelled, isFalse);
      expect(remoteCommitCount(), before + 1);
      expect(remoteContent('mod-catalog.json'), 'new repo');
      expect(remoteContent('mod-catalog-details.json'), 'new bundle');
      expect(inRemote('mods.json'), isFalse);
      expect(
          reporter.logs.any((l) => l.contains('website files were not there')),
          isTrue);
    }, skip: _gitIsThere() ? false : 'git is not installed');

    test('a mod that has gone loses its file from the published repo', () async {
      writeOutputs('new repo', 'new bundle');
      writeWebsiteData(['nexerelin', 'quality-captains']);
      await service.runJob(JobRequest.publishOutputs(), reporter: reporter);
      expect(inRemote('mods/quality-captains.json'), isTrue);

      // The next run no longer produces that mod.
      File(p.join(outputs, 'site', 'mods', 'quality-captains.json'))
          .deleteSync();
      writeOutputs('newer repo', 'newer bundle');
      await service.runJob(JobRequest.publishOutputs(),
          reporter: RecordingRunReporter());

      expect(inRemote('mods/nexerelin.json'), isTrue);
      expect(inRemote('mods/quality-captains.json'), isFalse);
    }, skip: _gitIsThere() ? false : 'git is not installed');

    test('it refuses a job that is not a publish', () {
      expect(
        () => service.runJob(JobRequest.rebuildBundle()),
        throwsA(isA<ArgumentError>()),
      );
    });

    /// Puts [content] into the remote at [name], as an earlier publish would.
    void pushToRemote(String name, String content) {
      final seed = p.join(tmp.path, 'seed');
      _git(['pull', '--quiet', 'origin', 'main'], cwd: seed);
      File(p.join(seed, name)).writeAsStringSync(content);
      _git(['add', '-A'], cwd: seed);
      _git(['-c', 'user.email=t@t', '-c', 'user.name=Test', 'commit', '-m', 'list'], cwd: seed);
      _git(['push', 'origin', 'HEAD:main'], cwd: seed);
    }

    const tidal = TakedownList(mods: [
      ModTakedown(id: 'diable-avionics-tidal-fork', name: 'Diable Avionics (TIDAL FORK)',
          posts: ['discord:1507163509224509510'], on: '2026-10-22'),
    ]);

    test('the takedown list and the not-found page go out with the rest', () async {
      writeOutputs('new repo', 'new bundle');
      writeWebsiteData(['nexerelin']);
      File(p.join(outputs, 'site', '404.html')).writeAsStringSync('<title>Not found</title>');
      tidal.write(dataDir);

      await service.runJob(JobRequest.publishOutputs(), reporter: reporter);

      expect(remoteContent('404.html'), '<title>Not found</title>');
      expect(remoteContent('takedowns.json'), contains('diable-avionics-tidal-fork'));
      expect(remoteContent('ModRepo.json'), 'frozen repo');
      expect(remoteContent('forum-data-bundle.json'), 'frozen bundle');
    }, skip: _gitIsThere() ? false : 'git is not installed');

    test('a lost local list stops the publish and pushes nothing', () async {
      final file = File(p.join(tmp.path, 'published-list.json'));
      tidal.writeFile(file);
      pushToRemote('takedowns.json', file.readAsStringSync());
      writeOutputs('new repo', 'new bundle');
      final before = remoteCommitCount();

      await expectLater(
        service.runJob(JobRequest.publishOutputs(), reporter: reporter),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('diable-avionics-tidal-fork'))),
      );
      expect(remoteCommitCount(), before);
      expect(remoteContent('mod-catalog.json'), 'old repo');
    }, skip: _gitIsThere() ? false : 'git is not installed');
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

    test('fetchAndUpdate fetches the sources first, then runs the forum '
        'scrape that builds the catalog', () async {
      final order = <String>[];
      final qb = _OrderedRunner('qb', order);
      final modRepo = _OrderedRunner('modRepo', order);
      final router =
          JobRouter(qb: qb, modRepo: modRepo, publish: FakeJobRunner());

      await router.runJob(JobRequest.fetchAndUpdate(
        scope: ScopeType.all,
        boards: {ScrapeBoard.main},
        sources: {ModSourceKind.discord},
      ));

      expect(order, ['modRepo', 'qb'],
          reason: 'the LLM can only read Discord threads already fetched');

      final merge = modRepo.ran.single;
      expect(merge.kind, JobKind.scrapeAndMerge);
      expect(merge.oldRepoOnly, isTrue,
          reason: 'the catalog is built once, by the forum half');
      expect(merge.modSources, {ModSourceKind.forum, ModSourceKind.discord},
          reason: 'the old forum scraper still feeds ModRepo.json');

      final scrape = qb.ran.single;
      expect(scrape.kind, JobKind.fullRun);
      expect(scrape.scope, ScopeType.all);
      expect(scrape.boards, {ScrapeBoard.main});
      expect(scrape.runLlm, isTrue);
      expect(scrape.collectMergeDebug, isTrue);
      expect(scrape.replayAllowed, isFalse);
    });

    test('with no board ticked, neither scraper goes near the forum', () async {
      final qb = FakeJobRunner();
      final modRepo = FakeJobRunner();
      final router =
          JobRouter(qb: qb, modRepo: modRepo, publish: FakeJobRunner());

      await router.runJob(JobRequest.fetchAndUpdate(
        boards: {},
        sources: {ModSourceKind.discord},
      ));

      expect(modRepo.ran.single.kind, JobKind.scrapeAndMerge);
      expect(modRepo.ran.single.modSources, {ModSourceKind.discord},
          reason: 'the old forum scraper must not run either');
      // The LLM still reads the Discord threads just fetched.
      expect(qb.ran.single.kind, JobKind.llmCoveragePass);
      expect(qb.ran.single.collectMergeDebug, isTrue);
    });

    test('with no board ticked and the LLM off, the forum half only rebuilds',
        () async {
      final qb = FakeJobRunner();
      final router =
          JobRouter(qb: qb, modRepo: FakeJobRunner(), publish: FakeJobRunner());

      await router.runJob(JobRequest.fetchAndUpdate(
        boards: {},
        sources: {ModSourceKind.discord},
        runLlm: false,
      ));

      expect(qb.ran.single.kind, JobKind.rebuildBundle);
      expect(qb.ran.single.runLlm, isFalse);
    });

    test('rebuildFromSaved merges saved files, then rebuilds the bundle',
        () async {
      final qb = FakeJobRunner();
      final modRepo = FakeJobRunner();
      final router =
          JobRouter(qb: qb, modRepo: modRepo, publish: FakeJobRunner());

      await router.runJob(JobRequest.rebuildFromSaved());

      expect(modRepo.ran.single.kind, JobKind.mergeModRepo);
      expect(modRepo.ran.single.oldRepoOnly, isTrue);
      expect(qb.ran.single.kind, JobKind.rebuildBundle);
      expect(qb.ran.single.collectMergeDebug, isTrue);
    });

    test('a combined job stopped during the merge never starts the forum half',
        () async {
      final qb = FakeJobRunner();
      final modRepo = FakeJobRunner();
      final router =
          JobRouter(qb: qb, modRepo: modRepo, publish: FakeJobRunner());

      final outcome = await router.runJob(JobRequest.rebuildFromSaved(),
          cancel: CancelToken()..cancel());

      expect(outcome.cancelled, isTrue);
      expect(modRepo.ran, hasLength(1));
      expect(qb.ran, isEmpty);
    });
  });
}
