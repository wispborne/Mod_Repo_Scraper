import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/author_aliases.dart';
import 'package:mod_repo_scraper/bot/scraper/mod_repo_utils.dart';
import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:mod_repo_scraper/catalog/listing.dart';
import 'package:mod_repo_scraper/catalog/mod_catalog.dart';
import 'package:mod_repo_scraper/catalog/source_post.dart';
import 'package:mod_repo_scraper/catalog/takedowns.dart';
import 'package:mod_repo_scraper/manager/cancel_token.dart';
import 'package:mod_repo_scraper/manager/corrections_service.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/job_manager.dart';
import 'package:mod_repo_scraper/manager/manager_api.dart';
import 'package:mod_repo_scraper/manager/modrepo_service.dart';
import 'package:mod_repo_scraper/manager/run_history_store.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:mod_repo_scraper/manager/scraper_service.dart';
import 'package:mod_repo_scraper/site/requirement_names.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
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
  late CorrectionsService service;

  File takedownsFile() => TakedownList.fileIn(dataPath);
  File restoredFile() => File(p.join(dataPath, TakedownList.restoredFileName));
  File aliasFile() => AuthorAliasFile.fileIn(dataPath);
  File requirementsFile() => File(p.join(dataPath, RequirementNameStore.fileName));

  Future<void> run(List<Correction> corrections) =>
      service.runJob(JobRequest.saveCorrections(corrections));

  List<List<String>> savedPeople() => AuthorAliasFile.read(dataPath).people;
  List<List<String>> savedNotSame() => AuthorAliasFile.read(dataPath).notSame;
  RequirementAnswer? savedAnswer(String written) =>
      (RequirementNameStore(dataPath)..load()).answerFor(written);

  CatalogMod mod(String id, String name, List<SourcePostRef> refs) => CatalogMod(
        id: id,
        mod: ScrapedMod(name: name),
        sourcePosts: [for (final ref in refs) CatalogSourcePost(kind: ref.kind, id: ref.id, llmModName: ref.llmModName)],
      );

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('corrections');
    dataPath = p.join(dir.path, 'qb_data');
    outputPath = p.join(dir.path, 'outputs');
    Directory(dataPath).createSync(recursive: true);
    service = CorrectionsService(dataPath: dataPath, outputPath: outputPath, now: () => DateTime.utc(2026, 11, 5));
    await ModCatalog(
      generatedAt: DateTime.utc(2026),
      mods: [
        mod('lazylib', 'LazyLib', [const SourcePostRef(kind: SourceKind.forum, id: '5444')]),
        mod('useful-tithes', 'Useful.Tithes', [const SourcePostRef(kind: SourceKind.forum, id: '34161', llmModName: 'Useful.Tithes')]),
        mod('corrupt-officials', 'Corrupt.Officials',
            [const SourcePostRef(kind: SourceKind.forum, id: '34161', llmModName: 'Corrupt.Officials')]),
      ],
    ).write(File(p.join(outputPath, ModCatalog.fileName)));
    // A saved alias file that has seen every built-in row, so the list in use
    // is exactly these rows.
    const AuthorAliasFile(people: [
      ['Nes', 'nescom'],
      ['Histidine', 'histidine_my'],
    ], saved: true)
        .write(dataPath);
  });

  tearDown(() {
    // The aliases in force are one list for the whole program.
    ModRepoUtils.useAuthorAliases(ModRepoUtils.builtInAuthorAliases);
    dir.deleteSync(recursive: true);
  });

  group('the browser\'s request', () {
    test('reads the exact shape the browser sends, with missing fields at their defaults', () {
      const sent = '''
{ "kind": "saveCorrections", "publishAfter": true, "corrections": [
  { "kind": "takeDownMod", "modId": "useful-tithes" },
  { "kind": "takeDownAuthor", "names": ["tidal5590", "Tidal"] },
  { "kind": "restore", "entry": "author:tidal5590" },
  { "kind": "sameAuthor", "names": ["Alpha", "beta_7"] },
  { "kind": "differentAuthors", "names": ["Alpha", "gamma"] },
  { "kind": "removeAuthorName", "names": ["nescom"] },
  { "kind": "publishAuthorAs", "names": ["histidine_my"] },
  { "kind": "matchRequirement", "written": "Lazy Lib", "modId": "lazylib" },
  { "kind": "matchRequirement", "written": "Nex", "modId": null },
  { "kind": "matchRequirement", "written": "GraphicLib", "forget": true }
] }''';
      final request = JobRequestMapper.fromMap(jsonDecode(sent) as Map<String, dynamic>);

      expect(request.kind, JobKind.saveCorrections);
      expect(request.publishAfter, isTrue);
      expect(request.corrections, const [
        Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes'),
        Correction(kind: CorrectionKind.takeDownAuthor, names: ['tidal5590', 'Tidal']),
        Correction(kind: CorrectionKind.restore, entry: 'author:tidal5590'),
        Correction(kind: CorrectionKind.sameAuthor, names: ['Alpha', 'beta_7']),
        Correction(kind: CorrectionKind.differentAuthors, names: ['Alpha', 'gamma']),
        Correction(kind: CorrectionKind.removeAuthorName, names: ['nescom']),
        Correction(kind: CorrectionKind.publishAuthorAs, names: ['histidine_my']),
        Correction(kind: CorrectionKind.matchRequirement, written: 'Lazy Lib', modId: 'lazylib'),
        Correction(kind: CorrectionKind.matchRequirement, written: 'Nex'),
        Correction(kind: CorrectionKind.matchRequirement, written: 'GraphicLib', forget: true),
      ]);
      // And back again, as the run history saves it.
      expect(JobRequestMapper.fromMap(jsonDecode(jsonEncode(request.toMap())) as Map<String, dynamic>), request);
    });
  });

  group('takedowns', () {
    test('a mod is taken down with its posts from the catalog, and no other file is touched', () async {
      final aliasesBefore = aliasFile().readAsStringSync();
      await run(const [Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes')]);

      expect(TakedownList.read(dataPath).mods.single,
          const ModTakedown(id: 'useful-tithes', name: 'Useful.Tithes', posts: ['forum:34161#Useful.Tithes'], on: '2026-11-05'));
      expect(aliasFile().readAsStringSync(), aliasesBefore);
      expect(requirementsFile().existsSync(), isFalse);
      expect(restoredFile().existsSync(), isFalse);
    });

    test('a person is taken down', () async {
      await run(const [
        Correction(kind: CorrectionKind.takeDownAuthor, names: [' tidal5590 ', '']),
      ]);
      expect(TakedownList.read(dataPath).authors.single, const AuthorTakedown(names: ['tidal5590'], on: '2026-11-05'));
    });

    test('a restore removes the entry and records it', () async {
      await run(const [
        Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes'),
        Correction(kind: CorrectionKind.takeDownAuthor, names: ['tidal5590']),
      ]);
      await run(const [
        Correction(kind: CorrectionKind.restore, entry: 'useful-tithes'),
        Correction(kind: CorrectionKind.restore, entry: 'author:tidal5590'),
      ]);

      expect(TakedownList.read(dataPath).isEmpty, isTrue);
      final restored = TakedownList.readFile(restoredFile());
      expect(restored.mods.single.id, 'useful-tithes');
      expect(restored.authors.single.names, ['tidal5590']);
    });

    test('a mod or person already taken down is refused', () async {
      await run(const [
        Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes'),
        Correction(kind: CorrectionKind.takeDownAuthor, names: ['tidal5590']),
      ]);
      final before = takedownsFile().readAsStringSync();
      await expectLater(
          run(const [
            Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes'),
            Correction(kind: CorrectionKind.takeDownAuthor, names: ['Tidal']),
          ]),
          throwsA(isA<StateError>().having(
              (e) => e.message,
              'message',
              'Nothing was saved. '
                  'Correction 1 (take down "useful-tithes"): "useful-tithes" is already taken down. '
                  'Correction 2 (take down the person "Tidal"): "Tidal" is already taken down, as tidal5590.')));
      expect(takedownsFile().readAsStringSync(), before);
    });
  });

  group('author aliases', () {
    test('two names with no person become a new person, published under the first', () async {
      await run(const [Correction(kind: CorrectionKind.sameAuthor, names: ['Alpha', 'beta_7'])]);
      expect(savedPeople(), [
        ['Nes', 'nescom'],
        ['Histidine', 'histidine_my'],
        ['Alpha', 'beta_7'],
      ]);
    });

    test('a name joins the person of the other name, which keeps its published name', () async {
      await run(const [Correction(kind: CorrectionKind.sameAuthor, names: ['nescom', 'Nes2'])]);
      await run(const [Correction(kind: CorrectionKind.sameAuthor, names: ['NesThree', 'Nes'])]);
      expect(savedPeople().first, ['Nes', 'nescom', 'Nes2', 'NesThree']);
    });

    test('two people become one, under the first name\'s published name', () async {
      await run(const [Correction(kind: CorrectionKind.sameAuthor, names: ['histidine_my', 'nescom'])]);
      expect(savedPeople(), [
        ['Histidine', 'histidine_my', 'Nes', 'nescom'],
      ]);
    });

    test('joining takes back a "different people" mark between them', () async {
      await run(const [Correction(kind: CorrectionKind.differentAuthors, names: ['Alpha', 'gamma'])]);
      expect(savedNotSame(), [
        ['Alpha', 'gamma'],
      ]);
      await run(const [Correction(kind: CorrectionKind.sameAuthor, names: ['gamma', 'alpha'])]);
      expect(savedNotSame(), isEmpty);
      expect(savedPeople().last, ['gamma', 'alpha']);
    });

    test('two names of one person cannot be marked as different people', () async {
      final before = aliasFile().readAsStringSync();
      await expectLater(
          run(const [Correction(kind: CorrectionKind.differentAuthors, names: ['Nes', 'nescom'])]),
          throwsA(isA<StateError>().having((e) => e.message, 'message',
              'Nothing was saved. Correction 1 ("Nes" and "nescom" are different people): '
                  '"Nes" and "nescom" are marked as different people and listed as one person.')));
      expect(aliasFile().readAsStringSync(), before);
    });

    test('taking a name off a person; a person left with one name is no longer an alias', () async {
      await run(const [Correction(kind: CorrectionKind.sameAuthor, names: ['Nes', 'Nes2'])]);
      await run(const [Correction(kind: CorrectionKind.removeAuthorName, names: ['NESCOM'])]);
      expect(savedPeople().first, ['Nes', 'Nes2']);
      await run(const [Correction(kind: CorrectionKind.removeAuthorName, names: ['Nes2'])]);
      expect(savedPeople(), [
        ['Histidine', 'histidine_my'],
      ]);
    });

    test('choosing the published name moves it to the front', () async {
      await run(const [Correction(kind: CorrectionKind.publishAuthorAs, names: ['histidine_my'])]);
      expect(savedPeople().last, ['histidine_my', 'Histidine']);
      expect(ModRepoUtils.authorAliases.last, ['histidine_my', 'Histidine'],
          reason: 'the new rows are in force for the rebuild');
    });

    test('a name with no person cannot be the published name', () async {
      await expectLater(run(const [Correction(kind: CorrectionKind.publishAuthorAs, names: ['nobody'])]),
          throwsA(isA<StateError>().having((e) => e.message, 'message', contains('Correction 1 (publish the person as "nobody")'))));
    });

    test('the wrong number of names is refused', () async {
      await expectLater(run(const [Correction(kind: CorrectionKind.sameAuthor, names: ['Alpha'])]),
          throwsA(isA<StateError>().having((e) => e.message, 'message', contains('exactly two author names'))));
      await expectLater(run(const [Correction(kind: CorrectionKind.removeAuthorName, names: ['a', 'b'])]),
          throwsA(isA<StateError>().having((e) => e.message, 'message', contains('exactly one author name'))));
    });

    test('a correction that changes nothing writes nothing', () async {
      final before = aliasFile().lastModifiedSync();
      final text = aliasFile().readAsStringSync();
      await run(const [
        Correction(kind: CorrectionKind.sameAuthor, names: ['Nes', 'nescom']),
        Correction(kind: CorrectionKind.publishAuthorAs, names: ['Histidine']),
        Correction(kind: CorrectionKind.removeAuthorName, names: ['nobody']),
      ]);
      expect(aliasFile().readAsStringSync(), text);
      expect(aliasFile().lastModifiedSync(), before);
    });
  });

  group('dependency names', () {
    test('a name is matched to a mod, to none of our mods, or forgotten', () async {
      await run(const [
        Correction(kind: CorrectionKind.matchRequirement, written: 'Lazy Lib', modId: 'lazylib'),
        Correction(kind: CorrectionKind.matchRequirement, written: 'Nex'),
        Correction(kind: CorrectionKind.matchRequirement, written: 'GraphicLib', modId: 'lazylib'),
      ]);
      expect(savedAnswer('Lazy Lib')?.id, 'lazylib');
      expect(savedAnswer('Nex'), isNotNull);
      expect(savedAnswer('Nex')?.id, isNull);

      await run(const [Correction(kind: CorrectionKind.matchRequirement, written: 'GraphicLib', forget: true)]);
      expect(savedAnswer('GraphicLib'), isNull);
      expect(savedAnswer('Lazy Lib')?.id, 'lazylib');
    });

    test('a name can be matched to several mods, with any one of them enough', () async {
      await run(const [
        Correction(
          kind: CorrectionKind.matchRequirement,
          written: 'Tithes OR officials',
          modIds: ['useful-tithes', 'corrupt-officials'],
          anyOne: true,
        ),
      ]);
      final saved = savedAnswer('Tithes OR officials')!;
      expect(saved.ids, ['useful-tithes', 'corrupt-officials']);
      expect(saved.anyOne, isTrue);
    });

    test('a list with an id no mod has is refused', () async {
      await expectLater(
          run(const [
            Correction(
                kind: CorrectionKind.matchRequirement,
                written: 'Lazy Lib',
                modIds: ['lazylib', 'no-such-mod'])
          ]),
          throwsA(isA<StateError>().having((e) => e.message, 'message',
              'Nothing was saved. Correction 1 ("Lazy Lib" means "lazylib" and "no-such-mod"): '
                  'No mod in mod-catalog.json has the id "no-such-mod". "Lazy Lib" cannot match it.')));
      expect(requirementsFile().existsSync(), isFalse);
    });

    test('an id no mod has is refused', () async {
      await expectLater(
          run(const [Correction(kind: CorrectionKind.matchRequirement, written: 'Lazy Lib', modId: 'no-such-mod')]),
          throwsA(isA<StateError>().having((e) => e.message, 'message',
              'Nothing was saved. Correction 1 ("Lazy Lib" means "no-such-mod"): '
                  'No mod in mod-catalog.json has the id "no-such-mod". "Lazy Lib" cannot match it.')));
      expect(requirementsFile().existsSync(), isFalse);
    });
  });

  group('several at once', () {
    test('three kinds are all saved, and the outputs are rebuilt once', () async {
      final steps = <String>[];
      final router = JobRouter(
        qb: _Step('qb', steps),
        modRepo: _Step('modRepo', steps),
        publish: _Step('publish', steps),
        corrections: service,
      );

      await router.runJob(JobRequest.saveCorrections(const [
        Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes'),
        Correction(kind: CorrectionKind.sameAuthor, names: ['Alpha', 'beta_7']),
        Correction(kind: CorrectionKind.matchRequirement, written: 'Lazy Lib', modId: 'lazylib'),
        Correction(kind: CorrectionKind.takeDownAuthor, names: ['tidal5590']),
      ]));

      expect(TakedownList.read(dataPath).mods.single.id, 'useful-tithes');
      expect(TakedownList.read(dataPath).authors.single.names, ['tidal5590']);
      expect(savedPeople().last, ['Alpha', 'beta_7']);
      expect(savedAnswer('Lazy Lib')?.id, 'lazylib');
      expect(steps, ['modRepo:mergeModRepo', 'qb:rebuildBundle']);
    });

    test('a later correction sees the earlier ones', () async {
      await run(const [
        Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes'),
        Correction(kind: CorrectionKind.restore, entry: 'useful-tithes'),
        Correction(kind: CorrectionKind.sameAuthor, names: ['Alpha', 'beta_7']),
        Correction(kind: CorrectionKind.publishAuthorAs, names: ['beta_7']),
      ]);
      expect(TakedownList.read(dataPath).isEmpty, isTrue);
      expect(savedPeople().last, ['beta_7', 'Alpha']);
    });

    test('one refused correction leaves every file as it was, and nothing is rebuilt', () async {
      await run(const [
        Correction(kind: CorrectionKind.takeDownAuthor, names: ['tidal5590']),
        Correction(kind: CorrectionKind.matchRequirement, written: 'Nex'),
      ]);
      final files = [takedownsFile(), aliasFile(), requirementsFile()];
      final before = [for (final file in files) file.readAsStringSync()];
      final steps = <String>[];
      final router = JobRouter(
        qb: _Step('qb', steps),
        modRepo: _Step('modRepo', steps),
        publish: _Step('publish', steps),
        corrections: service,
      );

      await expectLater(
          router.runJob(JobRequest.saveCorrections(const [
            Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes'),
            Correction(kind: CorrectionKind.takeDownMod, modId: 'foo'),
            Correction(kind: CorrectionKind.sameAuthor, names: ['Alpha', 'beta_7']),
            Correction(kind: CorrectionKind.matchRequirement, written: 'Lazy Lib', modId: 'lazylib'),
            Correction(kind: CorrectionKind.restore, entry: 'nothing-here'),
          ], publishAfter: true)),
          throwsA(isA<StateError>().having(
              (e) => e.message,
              'message',
              'Nothing was saved. '
                  'Correction 2 (take down "foo"): No mod or Collection in mod-catalog.json has the id "foo". '
                  'Correction 5 (restore "nothing-here"): There is no takedown entry "nothing-here" to restore.')));

      expect([for (final file in files) file.readAsStringSync()], before);
      expect(restoredFile().existsSync(), isFalse);
      expect(steps, isEmpty);
    });

    test('publishes only when asked, after the one rebuild', () async {
      final steps = <String>[];
      final router = JobRouter(
        qb: _Step('qb', steps),
        modRepo: _Step('modRepo', steps),
        publish: _Step('publish', steps),
        corrections: service,
      );
      await router.runJob(JobRequest.saveCorrections(const [
        Correction(kind: CorrectionKind.matchRequirement, written: 'Nex'),
      ], publishAfter: true));
      await router.runJob(JobRequest.saveCorrections(const [
        Correction(kind: CorrectionKind.matchRequirement, written: 'Lazy Lib', modId: 'lazylib'),
      ]));
      expect(steps, [
        'modRepo:mergeModRepo', 'qb:rebuildBundle', 'publish:publishOutputs',
        'modRepo:mergeModRepo', 'qb:rebuildBundle',
      ]);
    });

    test('the merge writes only ModRepo.json, and the rebuild collects the Catalog diff data', () async {
      final qb = FakeJobRunner();
      final modRepo = FakeJobRunner();
      // Sent as the browser sends it, with no collectMergeDebug.
      await JobRouter(qb: qb, modRepo: modRepo, publish: FakeJobRunner(), corrections: service).runJob(
          const JobRequest(kind: JobKind.saveCorrections, corrections: [
        Correction(kind: CorrectionKind.matchRequirement, written: 'Nex'),
      ]));
      expect(modRepo.ran.single.oldRepoOnly, isTrue);
      expect(qb.ran.single.collectMergeDebug, isTrue);
      expect(qb.ran.single.runLlm, isFalse);
    });

    test('an empty list is refused', () async {
      await expectLater(run(const []), throwsStateError);
    });
  });

  group('when the job is sent', () {
    late JobManager manager;
    late Handler handler;
    late FakeJobRunner qb;
    late FakeJobRunner modRepo;

    setUp(() async {
      qb = FakeJobRunner();
      modRepo = FakeJobRunner();
      manager = JobManager(
        service: JobRouter(
          qb: qb,
          modRepo: modRepo,
          publish: FakeJobRunner(),
          corrections: service,
        ),
        history: RunHistoryStore(p.join(dir.path, 'runs-home')),
      );
      await manager.load();
      handler = ManagerApi(manager: manager, dataPath: dataPath).router;
    });

    Future<void> waitForIdle() async {
      for (var i = 0; i < 400 && (manager.currentRun != null || manager.queuedRuns.isNotEmpty); i++) {
        qb.release();
        modRepo.release();
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    }

    tearDown(waitForIdle);

    Future<Response> send(List<Correction> corrections) async => handler(Request(
          'POST',
          Uri.parse('http://localhost/jobs'),
          body: jsonEncode(JobRequest.saveCorrections(corrections).toMap()),
          headers: {'content-type': 'application/json'},
        ));

    test('a correction that would be refused is refused with the message the job would give, and nothing is queued', () async {
      await run(const [Correction(kind: CorrectionKind.takeDownAuthor, names: ['tidal5590'])]);
      final files = [takedownsFile(), aliasFile()];
      final before = [for (final file in files) file.readAsStringSync()];

      final res = await send(const [
        Correction(kind: CorrectionKind.sameAuthor, names: ['Alpha', 'beta_7']),
        Correction(kind: CorrectionKind.takeDownAuthor, names: ['Tidal']),
        Correction(kind: CorrectionKind.takeDownMod, modId: 'foo'),
      ]);

      expect(res.statusCode, 400);
      expect((jsonDecode(await res.readAsString()) as Map)['error'],
          'Nothing was saved. '
          'Correction 2 (take down the person "Tidal"): "Tidal" is already taken down, as tidal5590. '
          'Correction 3 (take down "foo"): No mod or Collection in mod-catalog.json has the id "foo".');
      expect(manager.history.records, isEmpty);
      expect([for (final file in files) file.readAsStringSync()], before);
      expect(requirementsFile().existsSync(), isFalse);
    });

    test('two takedowns of one person in the same list are refused', () async {
      final res = await send(const [
        Correction(kind: CorrectionKind.takeDownAuthor, names: ['tidal5590']),
        Correction(kind: CorrectionKind.takeDownAuthor, names: ['Tidal']),
      ]);
      expect(res.statusCode, 400);
      expect((jsonDecode(await res.readAsString()) as Map)['error'], contains('Correction 2'));
      expect(takedownsFile().existsSync(), isFalse);
    });

    test('corrections that can be saved are queued', () async {
      final res = await send(const [
        Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes'),
        Correction(kind: CorrectionKind.matchRequirement, written: 'Lazy Lib', modId: 'lazylib'),
      ]);
      expect(res.statusCode, 200);
      expect(manager.history.records, hasLength(1));
    });

    test('the check itself writes no file', () {
      final aliasesBefore = aliasFile().readAsStringSync();
      expect(
          service.refusalOf(const [
            Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes'),
            Correction(kind: CorrectionKind.sameAuthor, names: ['Alpha', 'beta_7']),
            Correction(kind: CorrectionKind.matchRequirement, written: 'Nex'),
          ]),
          isNull);
      expect(takedownsFile().existsSync(), isFalse);
      expect(requirementsFile().existsSync(), isFalse);
      expect(aliasFile().readAsStringSync(), aliasesBefore);
    });

    group('a mod-catalog.json that cannot be read', () {
      const unreadable = 'Could not read mod-catalog.json. Rebuild the outputs. Nothing was saved.';
      File catalogFile() => File(p.join(outputPath, ModCatalog.fileName));

      for (final (what, broken) in [
        ('cut off', (String whole) => whole.substring(0, whole.length ~/ 2)),
        ('the wrong shape', (String _) => '[1, 2, 3]'),
        ('holding the wrong kind of mods', (String _) => '{"items": 5}'),
      ]) {
        test('is refused in plain words when the catalog is $what', () async {
          catalogFile().writeAsStringSync(broken(catalogFile().readAsStringSync()));
          final before = takedownsFile().existsSync();

          for (final correction in const [
            Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes'),
            Correction(kind: CorrectionKind.matchRequirement, written: 'Lazy Lib', modId: 'lazylib'),
          ]) {
            final res = await send([correction]);
            expect(res.statusCode, 400);
            expect((jsonDecode(await res.readAsString()) as Map)['error'], unreadable);
          }
          expect(manager.history.records, isEmpty);
          expect(takedownsFile().existsSync(), before);
          expect(requirementsFile().existsSync(), isFalse);
        });
      }

      test('fails the job with the same words when it breaks while the job waits', () async {
        catalogFile().writeAsStringSync(catalogFile().readAsStringSync().substring(0, 40));
        await expectLater(
          run(const [Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes')]),
          throwsA(isA<StateError>().having((e) => e.message, 'message', unreadable)),
        );
        await expectLater(
          run(const [Correction(kind: CorrectionKind.matchRequirement, written: 'Lazy Lib', modId: 'lazylib')]),
          throwsA(isA<StateError>().having((e) => e.message, 'message', unreadable)),
        );
        expect(takedownsFile().existsSync(), isFalse);
        expect(requirementsFile().existsSync(), isFalse);
      });
    });

    group('saves running or waiting to run', () {
      test('are counted first, so a change one of them makes is refused', () async {
        // Something else runs first, so both saves wait in the queue.
        qb.holdUntilReleased();
        await manager.enqueue(JobRequest.rebuildBundle());

        final first = await send(const [Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes')]);
        expect(first.statusCode, 200);

        final again = await send(const [
          Correction(kind: CorrectionKind.sameAuthor, names: ['Alpha', 'beta_7']),
          Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes'),
        ]);
        expect(again.statusCode, 400);
        expect((jsonDecode(await again.readAsString()) as Map)['error'],
            'Nothing was saved. Correction 2 (take down "useful-tithes"): "useful-tithes" is already taken down. '
            '${CorrectionsService.countsSavesAhead}');
        expect(manager.queuedRuns.length + (manager.currentRun == null ? 0 : 1), 2);

        final other = await send(const [
          Correction(kind: CorrectionKind.sameAuthor, names: ['Alpha', 'beta_7']),
          Correction(kind: CorrectionKind.takeDownMod, modId: 'corrupt-officials'),
        ]);
        expect(other.statusCode, 200);

        await waitForIdle();
        final states = [for (final r in manager.history.records) r.state];
        expect(states, everyElement(RunState.completed));
        expect(TakedownList.read(dataPath).mods.map((m) => m.id), ['useful-tithes', 'corrupt-officials']);
        expect(savedPeople(), anyElement(equals(['Alpha', 'beta_7'])));
      });

      test('a running save that has already written its changes is not counted twice', () async {
        modRepo.holdUntilReleased();
        final first = await send(const [Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes')]);
        expect(first.statusCode, 200);
        // The corrections are saved; the job now waits in its merge step.
        await modRepo.started.future;
        expect(takedownsFile().existsSync(), isTrue);

        final again = await send(const [Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes')]);
        expect(again.statusCode, 400);
        expect((jsonDecode(await again.readAsString()) as Map)['error'],
            'Nothing was saved. Correction 1 (take down "useful-tithes"): "useful-tithes" is already taken down.');

        final other = await send(const [Correction(kind: CorrectionKind.takeDownMod, modId: 'corrupt-officials')]);
        expect(other.statusCode, 200);
      });

      test('a save waiting to run that will be refused is not counted', () async {
        qb.holdUntilReleased();
        await manager.enqueue(JobRequest.rebuildBundle());
        // Put on the queue without the check, as if the files changed after it
        // was sent. It saves nothing when it runs.
        await manager.enqueue(JobRequest.saveCorrections(const [
          Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes'),
          Correction(kind: CorrectionKind.takeDownMod, modId: 'foo'),
        ]));

        final res = await send(const [Correction(kind: CorrectionKind.takeDownMod, modId: 'useful-tithes')]);
        expect(res.statusCode, 200);

        await waitForIdle();
        expect([for (final r in manager.history.records) r.state], containsAll([RunState.failed, RunState.completed]));
        expect(TakedownList.read(dataPath).mods.map((m) => m.id), ['useful-tithes']);
      });
    });
  });
}
