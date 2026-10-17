import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/catalog/source_post.dart';
import 'package:mod_repo_scraper/site/mod_id_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

SourcePostRef forum(String id, [String? llmName]) => SourcePostRef(kind: SourceKind.forum, id: id, llmModName: llmName);
SourcePostRef discord(String id, [String? llmName]) =>
    SourcePostRef(kind: SourceKind.discord, id: id, llmModName: llmName);

void main() {
  late Directory dir;
  var today = DateTime.utc(2026, 1, 1);

  setUp(() => dir = Directory.systemTemp.createTempSync('ids_by_post'));
  tearDown(() => dir.deleteSync(recursive: true));

  ModIdStore store() => ModIdStore(dir.path, now: () => today)..load();

  /// Saves, then reads the file back as a new run would.
  ModIdStore nextRun(ModIdStore s) {
    s.save();
    return store();
  }

  test('an older file with no posts still reads, and gains posts as mods are seen', () {
    File(p.join(dir.path, ModIdStore.fileName)).writeAsStringSync(jsonEncode({
      'ids': {
        'nexerelin': {'id': 'nexerelin', 'mark': 'topic:9175'},
      },
    }));
    var ids = store();
    expect(ids.idForPosts('Nexerelin', mark: 'topic:9175', refs: [forum('9175', 'Nexerelin')]), 'nexerelin');

    ids = nextRun(ids);
    expect(ids.postsOfId('nexerelin'), ['forum:9175#Nexerelin']);
  });

  test('a mod keeps its id when its name changes', () {
    var ids = store();
    final id = ids.idForPosts('Yunru Mods', mark: 'topic:21968', refs: [forum('21968')]);
    ids = nextRun(ids);

    // The index's first line now reads differently.
    expect(ids.idForPosts('Midline Expansion', mark: 'topic:21968', refs: [forum('21968')]), id);
  });

  test('a mod keeps its id when its topic is retitled for a release', () {
    var ids = store();
    final id = ids.idForPosts('Foo 1.2', mark: 'topic:5', refs: [forum('5')]);
    ids = nextRun(ids);
    expect(ids.idForPosts('Foo 1.3 - Now With Bar', mark: 'topic:5', refs: [forum('5')]), id);
  });

  test('a Discord-only mod keeps its id when the LLM first gives it a better name', () {
    var ids = store();
    final id = ids.idForPosts('fresh mod release!!', mark: 'someone', refs: [discord('900')]);
    ids = nextRun(ids);
    expect(ids.idForPosts('Fresh Mod', mark: 'someone', refs: [discord('900', 'Fresh Mod')]), id);
  });

  test("two mods on one topic are told apart by the LLM's names", () {
    var ids = store();
    final tithes = ids.idForPosts('Useful.Tithes', mark: 'topic:34161', refs: [forum('34161', 'Useful.Tithes')]);
    final pilum = ids.idForPosts('Big Pilum Energy', mark: 'topic:34161', refs: [forum('34161', 'Big Pilum Energy')]);
    expect(tithes, isNot(pilum));

    ids = nextRun(ids);
    // Asked in the other order, each still finds its own.
    expect(ids.idForPosts('Big Pilum Energy', mark: 'topic:34161', refs: [forum('34161', 'Big Pilum Energy')]), pilum);
    expect(ids.idForPosts('Useful.Tithes', mark: 'topic:34161', refs: [forum('34161', 'Useful.Tithes')]), tithes);
  });

  test('posts pointing at two ids: the older id wins and the clash is said', () {
    today = DateTime.utc(2025, 1, 1);
    var ids = store();
    final older = ids.idForPosts('Mod A', mark: 'topic:1', refs: [forum('1')]);
    today = DateTime.utc(2026, 1, 1);
    final newer = ids.idForPosts('Mod B', mark: 'someone', refs: [discord('2')]);
    ids = nextRun(ids);

    final clashes = <String>[];
    final joined = ids.idForPosts('Mod A', mark: 'topic:1', refs: [forum('1'), discord('2')], onClash: clashes.add);
    expect(joined, older);
    expect(clashes.single, contains(newer));
  });

  test('a brand-new mod gets an id from its name, numbered when that is taken', () {
    final ids = store();
    expect(ids.idForPosts('Kadur Remnant', mark: 'topic:1', refs: [forum('1')]), 'kadur-remnant');
    expect(ids.idForPosts('Kadur Remnant', mark: 'topic:2', refs: [forum('2')]), 'kadur-remnant-2');
  });

  test("an id is never given to another mod, even one with the same name and mark", () {
    var ids = store();
    final first = ids.idForPosts('CarrierUI', mark: 'someone', refs: [forum('1')]);
    ids = nextRun(ids);
    // A mod the merge kept apart from the first, from a post of its own, whose
    // name and mark happen to be the same. The first mod's id is linked to its
    // own post, so it is not this one's.
    final second = ids.idForPosts('CarrierUI', mark: 'someone', refs: [discord('7')]);
    expect(second, isNot(first));
    // And the first still has its own.
    expect(ids.idForPosts('CarrierUI', mark: 'someone', refs: [forum('1')]), first);
  });

  test("a Collection keeps its old id for its page, and no mod is ever given it", () {
    var ids = store();
    final old = ids.idForPosts('Derelict Start, Remnant Start, Omega Start & Threat Start',
        mark: 'topic:34457', refs: [forum('34457')]);
    ids = nextRun(ids);

    expect(ids.reserveCollection('Derelict Start, Remnant Start, Omega Start & Threat Start',
        mark: 'topic:34457', ref: forum('34457')), old);
    final derelict = ids.idForPosts('Derelict Start', mark: 'topic:34457', refs: [forum('34457', 'Derelict Start')]);
    expect(derelict, isNot(old));
  });

  test('a Collection that never had an id gets none', () {
    final ids = store();
    expect(ids.reserveCollection("Hartley's Miscellaneous Mods", mark: 'topic:34161', ref: forum('34161')), isNull);
  });

  test('an unreadable id file fails the run', () {
    File(p.join(dir.path, ModIdStore.fileName)).writeAsStringSync('{not json');
    expect(() => store(), throwsStateError);
  });

  group('a mod the LLM renames on a shared post', () {
    /// Gives each named mod on [topic] its id in one run, the way the catalog
    /// does: [ModIdStore.beginRun] is told every listing first.
    Map<String, String> run(ModIdStore ids, String topic, List<String> names, {List<String>? renames}) {
      ids.beginRun(refsThisRun: [for (final name in names) forum(topic, name)]);
      return {
        for (final name in names)
          name: ids.idForPosts(name, mark: 'topic:$topic', refs: [forum(topic, name)], onRenamed: renames?.add),
      };
    }

    test('keeps its id when the new name shares a word only it had', () {
      var ids = store();
      final before = run(ids, '12535', ['BDS Bismarck', 'BSP Peenemunde']);
      ids = nextRun(ids);

      final renames = <String>[];
      final after = run(ids, '12535', ['BDS Bismarck', 'Peenemunde Mobile Battlestation'], renames: renames);
      expect(after['Peenemunde Mobile Battlestation'], before['BSP Peenemunde']);
      expect(after['BDS Bismarck'], before['BDS Bismarck']);
      expect(renames.single, allOf(contains('BSP Peenemunde'), contains('Peenemunde Mobile Battlestation')));

      // The new name is linked from then on, so the next run finds it directly.
      ids = nextRun(ids);
      expect(ids.postsOfId(before['BSP Peenemunde']!), contains('forum:12535#Peenemunde Mobile Battlestation'));
    });

    test('keeps its id when only the spelling changed', () {
      var ids = store();
      final before = run(ids, '35651', ["Kwin's Faction", 'Other Faction']);
      ids = nextRun(ids);
      final after = run(ids, '35651', ['Kwins Faction', 'Other Faction']);
      expect(after['Kwins Faction'], before["Kwin's Faction"]);
    });

    test('the merge sees the old id too, so a renamed mod stays with its other posts', () {
      var ids = store();
      final before = run(ids, '12535', ['BDS Bismarck', 'BSP Peenemunde']);
      ids = nextRun(ids);
      ids.beginRun(refsThisRun: [forum('12535', 'BDS Bismarck'), forum('12535', 'Peenemunde Mobile Battlestation')]);
      expect(ids.idLinkedTo(forum('12535', 'Peenemunde Mobile Battlestation')), before['BSP Peenemunde']);
    });

    test('a mod that went away is not replaced by one that arrived', () {
      // Hartley's topic: one run read Corrupt.Officials, a later one
      // Useful.Tithes. They are different mods, and being the one left over on
      // each side is no reason to share an address.
      var ids = store();
      final before = run(ids, '34161', ['Big Pilum Energy', 'Corrupt.Officials', 'Disco.Balls']);
      ids = nextRun(ids);
      final after = run(ids, '34161', ['Big Pilum Energy', 'Useful.Tithes', 'Disco.Balls']);
      expect(after['Useful.Tithes'], isNot(before['Corrupt.Officials']));
      expect(after['Big Pilum Energy'], before['Big Pilum Energy']);
    });

    test('a word many mods use is no reason to pair two names', () {
      var ids = store();
      ids.idForPosts('Derelict Start', mark: 'topic:1', refs: [forum('1')]);
      ids.idForPosts('Remnant Start', mark: 'topic:2', refs: [forum('2')]);
      final before = run(ids, '2303', ['Cruiser Start Bundle', 'Font Bundle']);
      ids = nextRun(ids);
      final after = run(ids, '2303', ['Destroyer Start Bundle', 'Font Bundle']);
      expect(after['Destroyer Start Bundle'], isNot(before['Cruiser Start Bundle']));
    });

    test('a word another mod on the post still uses is no reason to pair two names', () {
      var ids = store();
      final before = run(ids, '33840', ['Europa Federation', 'Europa Ships']);
      ids = nextRun(ids);
      // Europa Ships went; the new name shares "Europa" with a mod still there.
      final after = run(ids, '33840', ['Europa Federation', 'Europa Weapons']);
      expect(after['Europa Weapons'], isNot(before['Europa Ships']));
      expect(after['Europa Federation'], before['Europa Federation']);
    });

    test('no pairing when two new names could each be the old one', () {
      var ids = store();
      final before = run(ids, '12535', ['BDS Bismarck', 'BSP Peenemunde']);
      ids = nextRun(ids);
      final after = run(ids, '12535', ['BDS Bismarck', 'Peenemunde Station', 'Peenemunde Carrier']);
      expect(after['Peenemunde Station'], isNot(before['BSP Peenemunde']));
      expect(after['Peenemunde Carrier'], isNot(before['BSP Peenemunde']));
    });

    test('no pairing when two old names could each be the new one', () {
      var ids = store();
      final before = run(ids, '12535', ['Peenemunde Station', 'Peenemunde Carrier', 'BDS Bismarck']);
      ids = nextRun(ids);
      final after = run(ids, '12535', ['Peenemunde Battlestation', 'BDS Bismarck']);
      expect(after['Peenemunde Battlestation'], isNot(before['Peenemunde Station']));
      expect(after['Peenemunde Battlestation'], isNot(before['Peenemunde Carrier']));
    });

    test('nothing is re-linked when the run did not say which names are on the post', () {
      var ids = store();
      final before = run(ids, '12535', ['BDS Bismarck', 'BSP Peenemunde']);
      ids = nextRun(ids);
      ids.beginRun();
      final id = ids.idForPosts('Peenemunde Mobile Battlestation',
          mark: 'topic:12535', refs: [forum('12535', 'Peenemunde Mobile Battlestation')]);
      expect(id, isNot(before['BSP Peenemunde']));
    });
  });
}
