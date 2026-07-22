import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/debug/merge_debug_data.dart';
import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:mod_repo_scraper/manager/merge_snapshot_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dataDir;

  setUp(() async {
    dataDir = await Directory.systemTemp.createTemp('merge_snapshots');
  });

  tearDown(() async {
    if (await dataDir.exists()) await dataDir.delete(recursive: true);
  });

  MergeDebugData sampleData({int inputCount = 3, int finalCount = 2}) =>
      MergeDebugData(
        inputCount: inputCount,
        afterPreDedupCount: inputCount,
        groupsCreated: finalCount,
        finalCount: finalCount,
        finalOutput: [
          for (var i = 0; i < finalCount; i++)
            ScrapedMod(name: 'Mod $i', authorsList: ['Author $i']),
        ],
      );

  test('a saved snapshot reads back as the same data', () async {
    final store = MergeSnapshotStore(dataDir.path);
    await store.save('20260722T120000Z-mergeModRepo', sampleData());

    final back = store.read('20260722T120000Z-mergeModRepo');
    expect(back, isNotNull);
    expect(back!.inputCount, 3);
    expect(back.finalCount, 2);
    expect(back.finalOutput.map((m) => m.name), ['Mod 0', 'Mod 1']);
  });

  test('snapshots are listed newest first, with their headline counts',
      () async {
    final store = MergeSnapshotStore(dataDir.path);
    await store.save('20260720T100000Z-mergeModRepo', sampleData(inputCount: 5));
    await store.save('20260722T100000Z-mergeModRepo', sampleData(inputCount: 9));

    final all = store.list();
    expect(all.map((s) => s.id), [
      '20260722T100000Z-mergeModRepo',
      '20260720T100000Z-mergeModRepo',
    ]);
    expect(all.first.inputCount, 9);
    expect(all.first.sizeBytes, greaterThan(0));
    expect(store.newestId, '20260722T100000Z-mergeModRepo');
  });

  test('a snapshot that was never saved reads back as nothing', () {
    final store = MergeSnapshotStore(dataDir.path);
    expect(store.read('20260722T100000Z-mergeModRepo'), isNull);
    expect(store.has('20260722T100000Z-mergeModRepo'), isFalse);
    expect(store.list(), isEmpty);
  });

  test('a damaged snapshot reads back as nothing rather than throwing',
      () async {
    final store = MergeSnapshotStore(dataDir.path);
    await store.save('20260722T100000Z-mergeModRepo', sampleData());
    await File(p.join(dataDir.path, 'merges',
            '20260722T100000Z-mergeModRepo.json.gz'))
        .writeAsString('not gzipped json');

    expect(store.read('20260722T100000Z-mergeModRepo'), isNull);
    // Still listed — the file is there, it just can't be read.
    expect(store.list(), hasLength(1));
  });

  test('only the newest snapshots are kept', () async {
    final store = MergeSnapshotStore(dataDir.path, mergesToKeep: 3);
    for (final day in ['18', '19', '20', '21', '22']) {
      await store.save('202607${day}T100000Z-mergeModRepo', sampleData());
    }

    final ids = store.list().map((s) => s.id).toList();
    expect(ids, [
      '20260722T100000Z-mergeModRepo',
      '20260721T100000Z-mergeModRepo',
      '20260720T100000Z-mergeModRepo',
    ]);
    // The counts file forgets what it no longer has.
    expect(store.list().every((s) => s.inputCount == 3), isTrue);
  });

  test('zero keeps every snapshot', () async {
    final store = MergeSnapshotStore(dataDir.path, mergesToKeep: 0);
    for (final day in ['18', '19', '20', '21', '22']) {
      await store.save('202607${day}T100000Z-mergeModRepo', sampleData());
    }
    expect(store.list(), hasLength(5));
  });

  test('the trim touches nothing but snapshots', () async {
    // Things that must survive: scraped data next door, and files inside the
    // merges folder that are not snapshots.
    final modsIndex = File(p.join(dataDir.path, 'mods-index.json'))
      ..writeAsStringSync('[]');
    final store = MergeSnapshotStore(dataDir.path, mergesToKeep: 1);
    await store.save('20260718T100000Z-mergeModRepo', sampleData());
    final strayNote = File(p.join(dataDir.path, 'merges', 'notes.txt'))
      ..writeAsStringSync('keep me');

    for (final day in ['19', '20', '21', '22']) {
      await store.save('202607${day}T100000Z-mergeModRepo', sampleData());
    }

    expect(store.list(), hasLength(1));
    expect(modsIndex.existsSync(), isTrue);
    expect(strayNote.existsSync(), isTrue);
    expect(File(store.countsPath).existsSync(), isTrue);
  });

  test('an id naming a path outside the folder reads nothing and deletes '
      'nothing', () async {
    final store = MergeSnapshotStore(dataDir.path);
    final modsIndex = File(p.join(dataDir.path, 'mods-index.json'))
      ..writeAsStringSync('[]');

    expect(store.read('../mods-index'), isNull);
    expect(store.read('..\\mods-index'), isNull);
    expect(store.has('../mods-index'), isFalse);
    expect(modsIndex.existsSync(), isTrue);
  });
}
