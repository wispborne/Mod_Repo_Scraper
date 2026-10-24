import 'dart:io';

import 'package:mod_repo_scraper/catalog/takedown_publish.dart';
import 'package:mod_repo_scraper/catalog/takedowns.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The check every publish runs before it copies the takedown list into the
/// published repo. The clone here is a plain folder: the check reads only its
/// `takedowns.json`.
void main() {
  late Directory dir;
  late String dataPath;
  late String cloneDir;

  const tidal = ModTakedown(id: 'diable-avionics-tidal-fork', name: 'Diable Avionics (TIDAL FORK)',
      posts: ['discord:1507163509224509510'], on: '2026-10-22');
  const tithes = ModTakedown(id: 'useful-tithes', name: 'Useful.Tithes', posts: ['forum:34161#Useful.Tithes'], on: '2026-10-22');
  const person = AuthorTakedown(names: ['tidal5590'], on: '2026-10-22');

  setUp(() {
    dir = Directory.systemTemp.createTempSync('takedown_publish');
    dataPath = p.join(dir.path, 'qb_data');
    cloneDir = p.join(dir.path, 'clone');
    Directory(cloneDir).createSync();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  File cloneList() => File(p.join(cloneDir, TakedownList.fileName));
  File restoredFile() => File(p.join(dataPath, TakedownList.restoredFileName));
  void publish() => publishTakedowns(dataPath: dataPath, cloneDir: cloneDir);

  test('a missing local file with published entries stops the publish', () {
    const TakedownList(mods: [tidal], authors: [person]).writeFile(cloneList());
    expect(
      publish,
      throwsA(isA<StateError>().having((e) => e.message, 'message',
          allOf(contains('diable-avionics-tidal-fork'), contains('author:tidal5590')))),
    );
    expect(TakedownList.readFile(cloneList()).mods, [tidal], reason: 'the published copy is left alone');
  });

  test('a local list that lost an entry stops the publish', () {
    const TakedownList(mods: [tidal, tithes]).writeFile(cloneList());
    const TakedownList(mods: [tidal]).write(dataPath);
    expect(publish, throwsA(isA<StateError>().having((e) => e.message, 'message', contains('useful-tithes'))));
  });

  test('a missing local file with nothing published writes an empty list', () {
    publish();
    expect(TakedownList.readFile(cloneList()).isEmpty, isTrue);
    expect(cloneList().existsSync(), isTrue);
  });

  test('the local list replaces the published one', () {
    const TakedownList(mods: [tidal]).writeFile(cloneList());
    const TakedownList(mods: [tidal, tithes], authors: [person]).write(dataPath);
    publish();
    expect(TakedownList.readFile(cloneList()), TakedownList.read(dataPath));
  });

  test('a recorded restore lets the publish go ahead, and outlives a push that failed', () {
    const TakedownList(mods: [tidal, tithes]).writeFile(cloneList());
    const TakedownList(mods: [tidal]).write(dataPath);
    const TakedownList(mods: [tithes]).writeFile(restoredFile());

    publish();
    expect(TakedownList.readFile(cloneList()).mods, [tidal]);
    expect(TakedownList.readFile(restoredFile()).mods, [tithes],
        reason: 'the fetched list still had it, so the push may not have happened');

    // The push failed: the next publish fetches the old list again.
    const TakedownList(mods: [tidal, tithes]).writeFile(cloneList());
    publish();
    expect(TakedownList.readFile(restoredFile()).mods, [tithes]);

    // This time the fetched list no longer has it: the restore went out.
    const TakedownList(mods: [tidal]).writeFile(cloneList());
    publish();
    expect(restoredFile().existsSync(), isFalse);
  });

  test('an author restore counts for the same person under another spelling', () {
    const TakedownList(authors: [person]).writeFile(cloneList());
    const TakedownList(authors: [AuthorTakedown(names: ['Tidal'], on: '2026-10-23')]).writeFile(restoredFile());
    publish();
    expect(TakedownList.readFile(cloneList()).isEmpty, isTrue);
  });
}
