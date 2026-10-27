import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/author_aliases.dart';
import 'package:mod_repo_scraper/bot/scraper/mod_repo_utils.dart';
import 'package:mod_repo_scraper/manager/author_alias_service.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/modrepo_service.dart';
import 'package:mod_repo_scraper/viewer/author_alias_views.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fake_job_runner.dart';

void main() {
  late Directory dir;
  late String dataPath;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('author_aliases');
    dataPath = dir.path;
  });
  tearDown(() {
    // The aliases in force are one list for the whole program.
    ModRepoUtils.useAuthorAliases(ModRepoUtils.builtInAuthorAliases);
    dir.deleteSync(recursive: true);
  });

  group('the file', () {
    test('no file means the built-in rows', () {
      final file = AuthorAliasFile.read(dataPath);
      expect(file.saved, isFalse);
      expect(file.rowsToUse(), ModRepoUtils.builtInAuthorAliases);
    });

    test('a saved file is the whole list, so a built-in row can be removed', () {
      const builtIn = [
        ['Nes', 'nescom'],
        ['Genir', 'halke1986'],
      ];
      const AuthorAliasFile(people: [
        ['Nes', 'nescom'],
      ], saved: true)
          .write(dataPath, builtIn: builtIn);
      expect(AuthorAliasFile.read(dataPath).rowsToUse(builtIn), [
        ['Nes', 'nescom'],
      ]);
    });

    test('a built-in row added after the file was saved still applies', () {
      const AuthorAliasFile(people: [
        ['Nes', 'nescom'],
      ], saved: true)
          .write(dataPath, builtIn: const [
        ['Nes', 'nescom'],
      ]);
      expect(
          AuthorAliasFile.read(dataPath).rowsToUse(const [
            ['Nes', 'nescom'],
            ['Genir', 'halke1986'],
          ]),
          [
            ['Nes', 'nescom'],
            ['Genir', 'halke1986'],
          ]);
    });

    test('a built-in row that grew a name joins the saved row rather than splitting the person', () {
      const AuthorAliasFile(people: [
        ['Nes', 'nescom'],
      ], saved: true)
          .write(dataPath, builtIn: const [
        ['Nes', 'nescom'],
      ]);
      expect(
          AuthorAliasFile.read(dataPath).rowsToUse(const [
            ['Nes', 'nescom', 'nes_again'],
          ]),
          [
            ['Nes', 'nescom', 'nes_again'],
          ]);
    });

    test('a file that cannot be read stops the job', () {
      File(p.join(dataPath, AuthorAliasFile.fileName)).writeAsStringSync('{ not json');
      expect(() => AuthorAliasFile.read(dataPath), throwsStateError);
    });

    test('installing it changes who counts as one person', () {
      const AuthorAliasFile(people: [
        ['Alpha', 'beta_7'],
      ], saved: true)
          .write(dataPath);
      expect(ModRepoUtils.samePerson('Alpha', 'beta_7'), isFalse);
      AuthorAliasFile.install(dataPath);
      expect(ModRepoUtils.samePerson('Alpha', 'beta_7'), isTrue);
      expect(ModRepoUtils.tidyAuthorNames(['beta_7', 'Alpha']), ['Alpha']);
    });
  });

  group('the first name in a row is the one published', () {
    test('even without capitals', () {
      expect(ModRepoUtils.tidyAuthorNames(['NikoTheGuyDude', 'zoeythegirlgal']), ['zoeythegirlgal']);
    });

    test('even when the mod only gives another of their names', () {
      expect(ModRepoUtils.tidyAuthorNames(['NikoTheGuyDude']), ['zoeythegirlgal']);
      expect(ModRepoUtils.tidyAuthorNames(['Ed', 'nick7884']), ['Ed', 'Nick XR']);
    });

    test('a name in no row loses to one listed in a row', () {
      ModRepoUtils.useAuthorAliases(const [
        ['quiet', 'Loud'],
      ]);
      expect(ModRepoUtils.tidyAuthorNames(['Loud', 'quiet']), ['quiet']);
    });
  });

  group('checking a list before it is saved', () {
    test('names are trimmed and repeats dropped', () {
      final checked = checkAliasRows([
        [' Nes ', 'nescom', 'NES'],
      ], const []);
      expect(checked.people, [
        ['Nes', 'nescom'],
      ]);
    });

    test('a person with one name is refused', () {
      expect(
          () => checkAliasRows([
                ['Nes', ' '],
              ], const []),
          throwsA(isA<StateError>().having((e) => e.message, 'message', contains('"Nes" has no other name'))));
    });

    test('one name for two people is refused', () {
      expect(
          () => checkAliasRows([
                ['Nes', 'nescom'],
                ['NESCOM', 'other'],
              ], const []),
          throwsA(isA<StateError>().having((e) => e.message, 'message', contains('listed for two people'))));
    });

    test('a pair marked different that is also one person is refused', () {
      expect(
          () => checkAliasRows([
                ['Nes', 'nescom'],
              ], [
                ['nes', 'Nescom'],
              ]),
          throwsStateError);
    });
  });

  group('the job', () {
    test('saves the file, then merges and rebuilds from saved files with no LLM', () async {
      final qb = FakeJobRunner();
      final modRepo = FakeJobRunner();
      final router = JobRouter(
        qb: qb,
        modRepo: modRepo,
        publish: FakeJobRunner(),
        authorAliases: AuthorAliasService(dataPath: dataPath),
      );

      await router.runJob(JobRequest.setAuthorAliases([
        ['Alpha', 'beta_7'],
      ], notSame: [
        ['Alpha', 'gamma'],
      ]));

      final saved = AuthorAliasFile.read(dataPath);
      expect(saved.people, [
        ['Alpha', 'beta_7'],
      ]);
      expect(saved.notSame, [
        ['Alpha', 'gamma'],
      ]);
      expect(modRepo.ran.single.kind, JobKind.mergeModRepo);
      expect(modRepo.ran.single.oldRepoOnly, isTrue);
      expect(qb.ran.single.kind, JobKind.rebuildBundle);
      expect(qb.ran.single.runLlm, isFalse);
    });

    test('a list that cannot be saved leaves the file as it was and rebuilds nothing', () async {
      const AuthorAliasFile(people: [
        ['Nes', 'nescom'],
      ], saved: true)
          .write(dataPath);
      final modRepo = FakeJobRunner();
      final router = JobRouter(
        qb: FakeJobRunner(),
        modRepo: modRepo,
        publish: FakeJobRunner(),
        authorAliases: AuthorAliasService(dataPath: dataPath),
      );

      await expectLater(
          router.runJob(JobRequest.setAuthorAliases([
            ['lonely'],
          ])),
          throwsStateError);
      expect(AuthorAliasFile.read(dataPath).people, [
        ['Nes', 'nescom'],
      ]);
      expect(modRepo.ran, isEmpty);
    });
  });

  group('suggestions', () {
    Map<String, Object?> report({List<List<String>> notSame = const []}) => authorAliasReport(
          catalogItems: [
            {
              'id': 'blue',
              'name': 'Blue',
              'authorsList': ['Somebody'],
              'sourcePosts': [
                {'kind': 'forum', 'id': '1'},
                {'kind': 'discord', 'id': '9'},
              ],
            },
          ],
          forumAuthors: {
            '1': ['Somebody'],
          },
          discordAuthors: {
            '9': ['other_account', deletedDiscordUser],
          },
          notSame: notSame,
        );

    test('a forum name and a different Discord name on one mod are offered', () {
      final suggestions = report()['suggestions'] as List;
      expect(suggestions, hasLength(1));
      expect((suggestions.single as Map)['forum'], 'Somebody');
      expect((suggestions.single as Map)['discord'], 'other_account');
    });

    test('a pair marked as different people is not offered again', () {
      expect(
          report(notSame: [
            ['OTHER_ACCOUNT', 'somebody'],
          ])['suggestions'],
          isEmpty);
    });

    test('a pair already in a row is not offered', () {
      ModRepoUtils.useAuthorAliases(const [
        ['Somebody', 'other_account'],
      ]);
      expect(report()['suggestions'], isEmpty);
    });

    test('counts the mods each name is on', () {
      expect((report()['modCounts'] as Map)['other_account'], 1);
    });
  });
}
