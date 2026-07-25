import 'dart:io';

import 'package:mod_repo_scraper/manager/bundle_history_importer.dart';
import 'package:mod_repo_scraper/manager/bundle_snapshot_store.dart';
import 'package:test/test.dart';

void main() {
  late Directory dataDir;

  setUp(() async {
    dataDir = await Directory.systemTemp.createTemp('bundle_history_import');
  });

  tearDown(() async {
    if (await dataDir.exists()) await dataDir.delete(recursive: true);
  });

  /// A bundle the shape of the real one, carrying full post text the way an old
  /// git copy does.
  Map<String, dynamic> bundle({String postText = '<p>Hello</p>'}) => {
        'updatedAt': '2026-04-16T23:20:07Z',
        'index': [
          {'topicId': 100, 'title': 'A Mod', 'author': 'Someone'},
        ],
        'details': {
          '100': {
            'topicId': 100,
            'contentHtml': postText,
            'images': <dynamic>[],
          },
        },
        'assumedDownloads': <String, dynamic>{},
      };

  test('a commit becomes a snapshot named for its time', () async {
    final importer = BundleHistoryImporter(BundleSnapshotStore(dataDir.path));

    final id =
        await importer.importOne(DateTime.utc(2026, 4, 16, 23, 20, 7), bundle());

    expect(id, '20260416T232007Z-imported');
    expect(BundleHistoryImporter.isImportedId(id), isTrue);
  });

  test('the name sorts by time, so imported and real snapshots interleave', () {
    final older =
        BundleHistoryImporter.idForCommit(DateTime.utc(2026, 4, 16, 1, 0, 0));
    final newer =
        BundleHistoryImporter.idForCommit(DateTime.utc(2026, 5, 1, 1, 0, 0));
    // A real run id from July, in the same stamp shape.
    const realJulyRun = '20260701T000000Z-fullRun';

    final names = [newer, realJulyRun, older]..sort();
    expect(names, [older, newer, realJulyRun]);
  });

  test('the post text is dropped and a fingerprint kept, like any snapshot',
      () async {
    final store = BundleSnapshotStore(dataDir.path);
    final importer = BundleHistoryImporter(store);

    final id =
        await importer.importOne(DateTime.utc(2026, 4, 16, 23, 20, 7), bundle());

    final detail = (store.readRaw(id)!['details'] as Map)['100'] as Map;
    expect(detail.containsKey('contentHtml'), isFalse);
    expect(detail[BundleSnapshotStore.fingerprintKey], isNotEmpty);
  });

  test('the fingerprint matches the live save path for the same text', () async {
    final store = BundleSnapshotStore(dataDir.path);
    final importer = BundleHistoryImporter(store);

    // The importer's snapshot for a post...
    final importedId =
        await importer.importOne(DateTime.utc(2026, 4, 16, 23, 20, 7), bundle());
    // ...and a normal run saving a bundle with the very same post text.
    await store.save('20260701T000000Z-fullRun', bundle());

    String fingerprint(String id) => ((store.readRaw(id)!['details'] as Map)['100']
        as Map)[BundleSnapshotStore.fingerprintKey] as String;

    // Same text, same fingerprint — so the seam between imported and real
    // history shows no false "post text changed".
    expect(fingerprint(importedId), fingerprint('20260701T000000Z-fullRun'));
  });

  test('re-importing the same commit overwrites in place, does not pile up',
      () async {
    final store = BundleSnapshotStore(dataDir.path);
    final when = DateTime.utc(2026, 4, 16, 23, 20, 7);

    await BundleHistoryImporter(store).importOne(when, bundle());
    // A second, fresh importer (as a re-run would use) with the same commit.
    await BundleHistoryImporter(store).importOne(when, bundle());

    expect(store.list(), hasLength(1));
  });

  group('telling a folder from something to clone', () {
    // Windows throws when asked whether a path holding a colon exists, so a
    // URL must be spotted by its shape before the disk is touched at all.
    // Linux just answers "no", which is how this got through the first time.
    test('an SSH remote is not mistaken for a folder', () {
      expect(
          BundleHistoryImporter.isLocalClone(
              'git@github.com:wispborne/StarsectorModRepo.git'),
          isFalse);
    });

    test('every other URL form is spotted too', () {
      for (final url in [
        'https://github.com/wispborne/StarsectorModRepo.git',
        'ssh://git@github.com/wispborne/StarsectorModRepo.git',
        'git://github.com/wispborne/StarsectorModRepo.git',
        'file:///srv/scraper/StarsectorModRepo',
      ]) {
        expect(BundleHistoryImporter.isLocalClone(url), isFalse, reason: url);
      }
    });

    test('a folder that is really there is used as it is', () {
      expect(BundleHistoryImporter.isLocalClone(dataDir.path), isTrue);
    });

    test('a Windows drive path is not mistaken for an SSH remote', () {
      // `C:\...` holds a colon but no `@`, so the URL check must let it through
      // to the disk check rather than calling it a remote.
      expect(BundleHistoryImporter.isLocalClone(r'C:\no\such\folder'), isFalse);
      expect(BundleHistoryImporter.isLocalClone('/no/such/folder'), isFalse);
    });
  });

  test('two commits in the same second get separate names', () async {
    final store = BundleSnapshotStore(dataDir.path);
    final importer = BundleHistoryImporter(store);
    final when = DateTime.utc(2026, 4, 16, 23, 20, 7);

    final first = await importer.importOne(when, bundle());
    final second = await importer.importOne(when, bundle(postText: '<p>Two</p>'));

    expect(first, isNot(second));
    expect(store.list(), hasLength(2));
  });
}
