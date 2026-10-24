import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:mod_repo_scraper/catalog/listing.dart';
import 'package:mod_repo_scraper/catalog/mod_catalog.dart';
import 'package:mod_repo_scraper/catalog/source_post.dart';
import 'package:mod_repo_scraper/catalog/takedowns.dart';
import 'package:mod_repo_scraper/manager/cancel_token.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/modrepo_service.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:mod_repo_scraper/manager/scraper_service.dart';
import 'package:mod_repo_scraper/manager/takedown_service.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fake_job_runner.dart';

/// A runner that writes down every step it is asked for, in one shared list.
class _Step extends FakeJobRunner {
  final String name;
  final List<String> steps;
  _Step(this.name, this.steps);

  @override
  Future<JobOutcome> runJob(JobRequest request,
      {RunReporter reporter = const SilentRunReporter(), CancelToken? cancel, String? runId}) {
    steps.add('$name:${request.kind.name}');
    return super.runJob(request, reporter: reporter, cancel: cancel, runId: runId);
  }
}

void main() {
  late Directory dir;
  late String dataPath;
  late String outputPath;
  late TakedownService service;

  CatalogMod mod(String id, String name, List<SourcePostRef> refs) => CatalogMod(
        id: id,
        mod: ScrapedMod(name: name),
        sourcePosts: [for (final ref in refs) CatalogSourcePost(kind: ref.kind, id: ref.id, llmModName: ref.llmModName)],
      );

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('takedown_job');
    dataPath = p.join(dir.path, 'qb_data');
    outputPath = p.join(dir.path, 'outputs');
    service = TakedownService(dataPath: dataPath, outputPath: outputPath, now: () => DateTime.utc(2026, 10, 22));
    await ModCatalog(
      generatedAt: DateTime.utc(2026),
      mods: [
        mod('diable-avionics-tidal-fork', 'Diable Avionics (TIDAL FORK)',
            [const SourcePostRef(kind: SourceKind.discord, id: '1507163509224509510', llmModName: 'Diable Avionics')]),
        mod('useful-tithes', 'Useful.Tithes', [const SourcePostRef(kind: SourceKind.forum, id: '34161', llmModName: 'Useful.Tithes')]),
        mod('corrupt-officials', 'Corrupt.Officials',
            [const SourcePostRef(kind: SourceKind.forum, id: '34161', llmModName: 'Corrupt.Officials')]),
      ],
    ).write(File(p.join(outputPath, ModCatalog.fileName)));
  });

  tearDown(() => dir.deleteSync(recursive: true));

  group('the list step', () {
    test('a mod entry records its posts from the catalog', () async {
      await service.runJob(JobRequest.takeDown(modId: 'diable-avionics-tidal-fork'));
      expect(TakedownList.read(dataPath).mods.single, const ModTakedown(
        id: 'diable-avionics-tidal-fork',
        name: 'Diable Avionics (TIDAL FORK)',
        posts: ['discord:1507163509224509510'],
        on: '2026-10-22',
      ));
    });

    test('a mod on a shared topic is recorded by its name', () async {
      await service.runJob(JobRequest.takeDown(modId: 'useful-tithes'));
      expect(TakedownList.read(dataPath).mods.single.posts, ['forum:34161#Useful.Tithes']);
    });

    test('an author entry', () async {
      await service.runJob(JobRequest.takeDown(authors: [' tidal5590 ', '']));
      expect(TakedownList.read(dataPath).authors.single, const AuthorTakedown(names: ['tidal5590'], on: '2026-10-22'));
    });

    for (final (what, request) in [
      ('an id no mod has', JobRequest.takeDown(modId: 'no-such-mod')),
      ('no id and no names', JobRequest.takeDown(authors: const [' '])),
      ('a restore of an entry that is not there', JobRequest.restoreTakedown('nothing-here')),
    ]) {
      test('$what is refused and changes nothing', () async {
        await expectLater(service.runJob(request), throwsA(isA<StateError>()));
        expect(TakedownList.fileIn(dataPath).existsSync(), isFalse);
      });
    }

    test('a mod or person already taken down is refused', () async {
      await service.runJob(JobRequest.takeDown(modId: 'useful-tithes'));
      await service.runJob(JobRequest.takeDown(authors: ['tidal5590']));
      final before = TakedownList.fileIn(dataPath).readAsStringSync();
      await expectLater(service.runJob(JobRequest.takeDown(modId: 'useful-tithes')), throwsA(isA<StateError>()));
      await expectLater(service.runJob(JobRequest.takeDown(authors: ['Tidal'])), throwsA(isA<StateError>()));
      expect(TakedownList.fileIn(dataPath).readAsStringSync(), before);
    });

    test('a restore removes the entry and records it', () async {
      await service.runJob(JobRequest.takeDown(modId: 'useful-tithes'));
      await service.runJob(JobRequest.takeDown(authors: ['tidal5590']));
      await service.runJob(JobRequest.restoreTakedown('useful-tithes'));
      await service.runJob(JobRequest.restoreTakedown('author:tidal5590'));

      expect(TakedownList.read(dataPath).isEmpty, isTrue);
      final restored = TakedownList.readFile(File(p.join(dataPath, TakedownList.restoredFileName)));
      expect(restored.mods.single.id, 'useful-tithes');
      expect(restored.authors.single.names, ['tidal5590']);
    });

    test('taking a restored mod down again forgets the restore', () async {
      await service.runJob(JobRequest.takeDown(modId: 'useful-tithes'));
      await service.runJob(JobRequest.restoreTakedown('useful-tithes'));
      await service.runJob(JobRequest.takeDown(modId: 'useful-tithes'));
      final restored = TakedownList.readFile(File(p.join(dataPath, TakedownList.restoredFileName)));
      expect(restored.isEmpty, isTrue);
    });
  });

  group('the whole job', () {
    test('changes the list, merges, rebuilds and publishes, with no scrape and no LLM', () async {
      final steps = <String>[];
      final qb = _Step('qb', steps);
      final router = JobRouter(
        qb: qb,
        modRepo: _Step('modRepo', steps),
        publish: _Step('publish', steps),
        takedowns: _Step('list', steps),
      );

      await router.runJob(JobRequest.takeDown(modId: 'useful-tithes', publishAfter: true));
      await router.runJob(JobRequest.restoreTakedown('useful-tithes'));

      expect(steps, [
        'list:takeDown', 'modRepo:mergeModRepo', 'qb:rebuildBundle', 'publish:publishOutputs',
        'list:restoreTakedown', 'modRepo:mergeModRepo', 'qb:rebuildBundle',
      ]);
      expect(qb.ran.every((r) => !r.runLlm), isTrue);
    });

    test('the merge step writes only ModRepo.json', () async {
      final modRepo = FakeJobRunner();
      await JobRouter(qb: FakeJobRunner(), modRepo: modRepo, publish: FakeJobRunner(), takedowns: FakeJobRunner())
          .runJob(JobRequest.takeDown(modId: 'useful-tithes'));
      expect(modRepo.ran.single.oldRepoOnly, isTrue);
    });

    test('stopped after the entry is written, the entry stays and nothing else runs', () async {
      final cancel = CancelToken();
      final modRepo = FakeJobRunner();
      final router = JobRouter(
        qb: FakeJobRunner(),
        modRepo: modRepo,
        publish: FakeJobRunner(),
        takedowns: _CancelAfter(service, cancel),
      );

      final outcome = await router.runJob(JobRequest.takeDown(modId: 'useful-tithes'), cancel: cancel);

      expect(outcome.cancelled, isTrue);
      expect(modRepo.ran, isEmpty);
      expect(TakedownList.read(dataPath).mods.single.id, 'useful-tithes');
    });
  });
}

/// Runs the real list step, then asks the job to stop.
class _CancelAfter implements JobRunner {
  final TakedownService inner;
  final CancelToken cancel;
  _CancelAfter(this.inner, this.cancel);

  @override
  Future<JobOutcome> runJob(JobRequest request,
      {RunReporter reporter = const SilentRunReporter(), CancelToken? cancel, String? runId}) async {
    final outcome = await inner.runJob(request, reporter: reporter);
    this.cancel.cancel();
    return outcome;
  }
}
