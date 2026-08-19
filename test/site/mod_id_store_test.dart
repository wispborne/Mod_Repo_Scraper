import 'dart:io';

import 'package:mod_repo_scraper/site/mod_id_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mod_ids');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('a mod keeps its id when its release renames the thread', () {
    final store = ModIdStore(dir.path)..load();
    final first = store.idFor('[0.98a] Nexerelin v0.12.1e');
    store.save();

    final later = ModIdStore(dir.path)..load();
    expect(later.idFor('[0.98a] Nexerelin v0.12.2'), first);
    expect(first, 'nexerelin');
  });

  test('the bracketed game version, the mod version and a date are stripped',
      () {
    expect(ModIdStore.cleanName('[0.98a] Nexerelin v0.12.2'), 'nexerelin');
    expect(ModIdStore.cleanName('[0.98a][WIP] Some Mod'), 'some mod');
    expect(ModIdStore.cleanName('Some Mod 1.2.3'), 'some mod');
    expect(ModIdStore.cleanName('Some Mod v1.2 (2024-01-05)'), 'some mod');
    expect(ModIdStore.cleanName('Nexerelin v0.12.2 - diplomacy and war'),
        'nexerelin - diplomacy and war');
    expect(ModIdStore.cleanName('Industrial.Evolution 3.5.2g'),
        'industrial.evolution');
  });

  test('an id reads plainly in an address', () {
    final store = ModIdStore(dir.path)..load();
    expect(store.idFor('[0.98a] Industrial.Evolution 3.5.2g'),
        'industrial-evolution');
    expect(store.idFor('Ashes of The Domain: Vaults of Knowledge'),
        'ashes-of-the-domain-vaults-of-knowledge');
  });

  test('a second mod wanting a taken id gets a number, the first keeps its own',
      () {
    final store = ModIdStore(dir.path)..load();
    expect(store.idFor('Some Mod'), 'some-mod');
    expect(store.idFor('Some.Mod'), 'some-mod-2');
    expect(store.idFor('Some-Mod'), 'some-mod-3');

    // And the first one still answers to what it was given.
    expect(store.idFor('Some Mod'), 'some-mod');
  });

  test('two different mods with one name each get their own page', () {
    final store = ModIdStore(dir.path)..load();

    // Two unrelated mods really are both called "Kadur Remnant", on two
    // different threads.
    expect(store.idFor('Kadur Remnant', mark: 'topic:6649'), 'kadur-remnant');
    expect(store.idFor('Kadur Remnant', mark: 'topic:35145'), 'kadur-remnant-2');

    // And each still answers to its own id, whichever order they are asked in.
    expect(store.idFor('Kadur Remnant', mark: 'topic:35145'), 'kadur-remnant-2');
    expect(store.idFor('Kadur Remnant', mark: 'topic:6649'), 'kadur-remnant');
  });

  test('the second mod of a name keeps its id across runs, either order', () {
    final store = ModIdStore(dir.path)..load();
    store.idFor('CarrierUI', mark: 'topic:28878');
    store.idFor('CarrierUI', mark: 'author:day_breaker');
    store.save();

    // The next run happens to ask the other way round. Neither id moves.
    final later = ModIdStore(dir.path)..load();
    expect(later.idFor('CarrierUI', mark: 'author:day_breaker'), 'carrierui-2');
    expect(later.idFor('CarrierUI', mark: 'topic:28878'), 'carrierui');
  });

  test('a mod already in the file keeps its id when marks arrive', () {
    // The file as it was written before marks were kept.
    File(p.join(dir.path, ModIdStore.fileName)).writeAsStringSync(
        '{"ids": {"some mod": {"id": "some-mod", "firstSeen": "2026-01-01"}}}');

    final store = ModIdStore(dir.path)..load();
    expect(store.idFor('Some Mod', mark: 'topic:100'), 'some-mod');
    expect(store.firstSeenFor('Some Mod', mark: 'topic:100'), '2026-01-01');

    // And a different mod of the same name now gets its own id.
    expect(store.idFor('Some Mod', mark: 'topic:200'), 'some-mod-2');
  });

  test('the day a mod was first seen is remembered', () {
    final store = ModIdStore(dir.path, now: () => DateTime.utc(2026, 8, 19))
      ..load();
    store.idFor('Some Mod');
    expect(store.firstSeenFor('Some Mod'), '2026-08-19');
    store.save();

    final later = ModIdStore(dir.path, now: () => DateTime.utc(2027, 1, 1))
      ..load();
    later.idFor('Some Mod');
    expect(later.firstSeenFor('Some Mod'), '2026-08-19',
        reason: 'the day it was first seen must not move');
  });

  test('ids survive a reload, and a new mod does not take an old id', () {
    final store = ModIdStore(dir.path)..load();
    store.idFor('Some Mod');
    store.idFor('Some.Mod');
    store.save();

    final later = ModIdStore(dir.path)..load();
    expect(later.count, 2);
    expect(later.idFor('Some_Mod'), 'some-mod-3');
  });

  test('a missing id file is fine — it is the first run', () {
    final store = ModIdStore(dir.path);
    expect(store.load, returnsNormally);
    expect(store.count, 0);
  });

  test('an id file that cannot be read stops the run', () {
    File(p.join(dir.path, ModIdStore.fileName)).writeAsStringSync('{ not json');
    final store = ModIdStore(dir.path);

    expect(
      store.load,
      throwsA(isA<StateError>().having(
        (e) => e.message, 'message', contains('Cannot read the mod id file'))),
    );
  });

  test('an id file of the wrong shape stops the run', () {
    File(p.join(dir.path, ModIdStore.fileName))
        .writeAsStringSync('{"mods": []}');
    final store = ModIdStore(dir.path);

    expect(store.load, throwsA(isA<StateError>()));
  });

  test('existingIdFor never hands out a new id', () {
    final store = ModIdStore(dir.path)..load();
    expect(store.existingIdFor('Some Mod'), isNull);
    expect(store.count, 0);

    store.idFor('Some Mod');
    expect(store.existingIdFor('[0.98a] Some Mod v2.0'), 'some-mod');
  });
}
