import 'dart:io';

import 'package:mod_repo_scraper/manager/bundle_snapshot_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dataDir;

  setUp(() async {
    dataDir = await Directory.systemTemp.createTemp('bundle_snapshots');
  });

  tearDown(() async {
    if (await dataDir.exists()) await dataDir.delete(recursive: true);
  });

  /// A bundle the shape of the real one: an index list and two maps keyed by
  /// topic id.
  Map<String, dynamic> sampleBundle({
    String postText = '<p>Hello</p>',
    int topics = 2,
  }) =>
      {
        'updatedAt': '2026-07-22T12:00:00Z',
        'meta': {'version': 1},
        'index': [
          for (var i = 0; i < topics; i++)
            {'topicId': 100 + i, 'title': 'Mod $i', 'author': 'Author $i'},
        ],
        'details': {
          for (var i = 0; i < topics; i++)
            '${100 + i}': {
              'topicId': 100 + i,
              'title': 'Mod $i',
              'contentHtml': '$postText for mod $i',
              'images': <dynamic>[],
            },
        },
        'assumedDownloads': {
          '100': {
            'candidates': [
              {'url': 'https://example.com/mod.zip'}
            ]
          },
        },
      };

  group('what a snapshot keeps', () {
    test('the posts\' text is left out and a fingerprint kept instead',
        () async {
      final store = BundleSnapshotStore(dataDir.path);
      await store.save('20260722T120000Z-fullRun', sampleBundle());

      final back = store.readRaw('20260722T120000Z-fullRun');
      expect(back, isNotNull);
      final detail = (back!['details'] as Map)['100'] as Map;
      expect(detail.containsKey('contentHtml'), isFalse,
          reason: 'a snapshot must not carry the post text');
      expect(detail[BundleSnapshotStore.fingerprintKey], isNotEmpty);
      // Everything else about the topic is kept.
      expect(detail['title'], 'Mod 0');
      expect(back['index'], hasLength(2));
      expect((back['assumedDownloads'] as Map).keys, ['100']);
    });

    test('a changed post changes its fingerprint', () async {
      final store = BundleSnapshotStore(dataDir.path);
      await store.save('20260722T120000Z-fullRun', sampleBundle());
      await store.save(
          '20260722T130000Z-fullRun', sampleBundle(postText: '<p>Goodbye</p>'));

      String fingerprint(String id) => ((store.readRaw(id)!['details']
          as Map)['100'] as Map)[BundleSnapshotStore.fingerprintKey] as String;

      expect(fingerprint('20260722T120000Z-fullRun'),
          isNot(fingerprint('20260722T130000Z-fullRun')));
    });

    test('the same post keeps the same fingerprint', () async {
      final store = BundleSnapshotStore(dataDir.path);
      await store.save('20260722T120000Z-fullRun', sampleBundle());
      await store.save('20260722T130000Z-fullRun', sampleBundle());

      String fingerprint(String id) => ((store.readRaw(id)!['details']
          as Map)['100'] as Map)[BundleSnapshotStore.fingerprintKey] as String;

      expect(fingerprint('20260722T120000Z-fullRun'),
          fingerprint('20260722T130000Z-fullRun'));
    });

    test('a topic with no post text is not mistaken for a changed one', () {
      expect(BundleSnapshotStore.fingerprintOf(null), isNull);
      expect(BundleSnapshotStore.fingerprintOf(''), isNotNull);
    });

    test('trimming an already-trimmed bundle leaves it alone', () {
      // It has a fingerprint and no post text to take one from. Doing it again
      // used to fingerprint the nothing that was left, quietly wiping the one
      // it already had — and a topic with no fingerprint reads as "the post
      // text was read for the first time" against every other snapshot.
      final once = BundleSnapshotStore.withoutPostText(sampleBundle());
      final twice = BundleSnapshotStore.withoutPostText(once);

      String fingerprint(Map<String, dynamic> bundle) =>
          ((bundle['details'] as Map)['100'] as Map)[
              BundleSnapshotStore.fingerprintKey] as String;

      expect(fingerprint(twice), fingerprint(once));
    });

    test('the bundle handed in is not changed', () async {
      final store = BundleSnapshotStore(dataDir.path);
      final bundle = sampleBundle();
      await store.save('20260722T120000Z-fullRun', bundle);

      // The caller's map is the bundle that was just published. Nothing here
      // may reach into it.
      final detail = (bundle['details'] as Map)['100'] as Map;
      expect(detail['contentHtml'], contains('Hello'));
      expect(detail.containsKey(BundleSnapshotStore.fingerprintKey), isFalse);
    });
  });

  group('listing and reading back', () {
    test('snapshots are listed newest first with their headline counts',
        () async {
      final store = BundleSnapshotStore(dataDir.path);
      await store.save('20260720T100000Z-fullRun', sampleBundle(topics: 5));
      await store.save('20260722T100000Z-rebuildBundle', sampleBundle(topics: 9));

      final all = store.list();
      expect(all.map((s) => s.id),
          ['20260722T100000Z-rebuildBundle', '20260720T100000Z-fullRun']);
      expect(all.first.indexCount, 9);
      expect(all.first.detailCount, 9);
      expect(all.first.downloadCount, 1);
      expect(all.first.sizeBytes, greaterThan(0));
      expect(store.newestId, '20260722T100000Z-rebuildBundle');
    });

    test('the one before a run is the next one down the list', () async {
      final store = BundleSnapshotStore(dataDir.path);
      await store.save('20260720T100000Z-fullRun', sampleBundle());
      await store.save('20260721T100000Z-fullRun', sampleBundle());
      await store.save('20260722T100000Z-fullRun', sampleBundle());

      expect(store.idBefore('20260722T100000Z-fullRun'),
          '20260721T100000Z-fullRun');
      // The oldest one kept has nothing before it.
      expect(store.idBefore('20260720T100000Z-fullRun'), isNull);
      expect(store.idBefore('never-heard-of-it'), isNull);
    });

    test('a snapshot that is gone reads back as missing, not as a crash', () {
      final store = BundleSnapshotStore(dataDir.path);
      expect(store.readRaw('20260722T120000Z-fullRun'), isNull);
      expect(store.has('20260722T120000Z-fullRun'), isFalse);
      expect(store.list(), isEmpty);
    });

    test('an unreadable snapshot reads back as missing', () async {
      final store = BundleSnapshotStore(dataDir.path);
      await store.save('20260722T120000Z-fullRun', sampleBundle());
      // Not gzip at all.
      File(p.join(store.bundlesPath, '20260722T120000Z-fullRun.json.gz'))
          .writeAsStringSync('this is not a snapshot');

      expect(store.readRaw('20260722T120000Z-fullRun'), isNull);
    });

    test('a name that tries to climb out of the folder is refused', () async {
      final store = BundleSnapshotStore(dataDir.path);
      await store.save('20260722T120000Z-fullRun', sampleBundle());
      for (final bad in ['../mods-index', '..\\mods-index', '', 'a/b']) {
        expect(store.readRaw(bad), isNull, reason: bad);
        expect(store.has(bad), isFalse, reason: bad);
      }
    });
  });

  group('keeping only the newest', () {
    test('the oldest snapshots are dropped', () async {
      final store = BundleSnapshotStore(dataDir.path, bundlesToKeep: 3);
      for (final day in [20, 21, 22, 23, 24]) {
        await store.save('202607${day}T100000Z-fullRun', sampleBundle());
      }

      expect(store.list().map((s) => s.id), [
        '20260724T100000Z-fullRun',
        '20260723T100000Z-fullRun',
        '20260722T100000Z-fullRun',
      ]);
      // The counts file forgets the dropped ones too.
      final counts =
          File(store.countsPath).readAsStringSync();
      expect(counts, isNot(contains('20260720')));
    });

    test('zero keeps everything', () async {
      final store = BundleSnapshotStore(dataDir.path, bundlesToKeep: 0);
      for (final day in [20, 21, 22, 23, 24]) {
        await store.save('202607${day}T100000Z-fullRun', sampleBundle());
      }
      expect(store.list(), hasLength(5));
    });

    test('nothing but snapshots is ever deleted', () async {
      final store = BundleSnapshotStore(dataDir.path, bundlesToKeep: 1);

      // Things that must survive a trim: scraped data, a cache, an output, and
      // a stray file sitting in the snapshot folder itself.
      final index = File(p.join(dataDir.path, 'mods-index.json'))
        ..writeAsStringSync('[]');
      final cache = File(p.join(dataDir.path, 'llm-extraction-cache.json'))
        ..writeAsStringSync('{}');
      Directory(p.join(dataDir.path, 'bundles')).createSync(recursive: true);
      final stray = File(p.join(dataDir.path, 'bundles', 'notes.txt'))
        ..writeAsStringSync('leave me alone');
      final nested = Directory(p.join(dataDir.path, 'bundles', 'deeper'))
        ..createSync();
      final nestedFile = File(p.join(nested.path, 'old.json.gz'))
        ..writeAsStringSync('not mine to delete');

      for (final day in [20, 21, 22]) {
        await store.save('202607${day}T100000Z-fullRun', sampleBundle());
      }

      expect(store.list(), hasLength(1));
      expect(index.existsSync(), isTrue);
      expect(cache.existsSync(), isTrue);
      expect(stray.existsSync(), isTrue);
      expect(nestedFile.existsSync(), isTrue);
    });

    test('the snapshot just written is never the one dropped', () async {
      final store = BundleSnapshotStore(dataDir.path, bundlesToKeep: 2);
      // An id that sorts oldest, saved last. Run ids start with the time, so
      // this cannot really happen — but if it did, a run must not delete the
      // snapshot it has just written.
      await store.save('20260724T100000Z-fullRun', sampleBundle());
      await store.save('20260723T100000Z-fullRun', sampleBundle());
      await store.save('20260701T100000Z-fullRun', sampleBundle());

      expect(store.has('20260701T100000Z-fullRun'), isTrue);
      // Keeping it puts the count one over the limit for that one save. Erring
      // towards keeping a file is the right way round to be wrong.
      expect(store.list(), hasLength(3));
    });
  });
}
