import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:mod_repo_scraper/catalog/mod_catalog.dart';
import 'package:mod_repo_scraper/catalog/source_post.dart';
import 'package:mod_repo_scraper/site/mod_id_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

SourcePostRef forum(String id, [String? llmName]) => SourcePostRef(kind: SourceKind.forum, id: id, llmModName: llmName);
SourcePostRef discord(String id, [String? llmName]) =>
    SourcePostRef(kind: SourceKind.discord, id: id, llmModName: llmName);

/// One mod of a build, as [ModIdStore.movedIds] is told about it.
({String id, List<String> names, List<String> authors, List<SourcePostRef> refs}) built(
  String id,
  List<SourcePostRef> refs, {
  List<String> names = const [],
  List<String> authors = const [],
}) =>
    (id: id, names: names, authors: authors, refs: refs);

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('moved_ids'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// An id file holding [ids], read back as a run would.
  ModIdStore storeWith(Map<String, Object> ids) {
    File(p.join(dir.path, ModIdStore.fileName)).writeAsStringSync(jsonEncode({'ids': ids}));
    return ModIdStore(dir.path)..load();
  }

  test("a forum page and a Discord page joined into one mod: the other page's address leads to it", () {
    // CarrierUI: the old site made one page from the forum topic and one from
    // the Discord thread.
    final ids = storeWith({
      'carrierui': {'id': 'carrierui', 'firstSeen': '2026-08-24', 'posts': ['discord:5#CarrierUI']},
      'carrierui#topic:28878': {'id': 'carrierui-2', 'firstSeen': '2026-08-25', 'posts': ['forum:28878']},
    });
    final refs = [forum('28878', 'CarrierUI'), discord('5', 'CarrierUI')];
    ids.beginRun(refsThisRun: refs);
    final id = ids.idForPosts('CarrierUI', mark: 'topic:28878', refs: refs);

    expect(id, 'carrierui');
    expect(ids.movedIds([built(id, refs, names: ['CarrierUI'])]), {'carrierui-2': 'carrierui'});
  });

  test("an id from a list of mods leads to the mod's own thread, never to what is left on the list", () {
    // Topic 36175 got a page for each of its mods for a day before the list's
    // links to each mod's own thread were understood.
    final ids = storeWith({
      'cloning#topic:36175': {'id': 'cloning-3', 'posts': ['forum:36175#Cloning']},
      'coalesced little mods': {'id': 'coalesced-little-mods', 'posts': ['forum:36175#Coalesced Little Mods']},
      'cloning': {'id': 'cloning', 'posts': ['forum:35130']},
    });
    ids.beginRun();
    final moved = ids.movedIds(
      [
        built('cloning', [forum('35130')], names: ['Cloning']),
        built('coalesced-little-mods', [forum('36175', 'Coalesced Little Mods')], names: ['Coalesced Little Mods']),
      ],
      pointers: {'forum:36175#Cloning': 'forum:35130'},
    );

    expect(moved, {'cloning-3': 'cloning'});
  });

  test('an id linked to no post goes to the mod on its topic only when that mod goes by its name', () {
    // Topic 30580 was NEON's ship pack and is now Xxarra's Variety Pack.
    final ids = storeWith({
      "neon's ship pack (v3.": {'id': 'neon-s-ship-pack-v3', 'mark': 'topic:30580'},
      'red horizon pact': {'id': 'red-horizon-pact', 'mark': 'topic:34636'},
    });
    ids.beginRun();
    final moved = ids.movedIds([
      built('xxarra-s-variety-pack', [forum('30580', "Xxarra's Variety Pack")], names: ["Xxarra's Variety Pack"]),
      built('neon-s-ship-pack', [discord('7', "NEON's ship pack")], names: ["NEON's ship pack (v3.0.5.8)"]),
      built('red-horizon-pact-update-2', [forum('34636', 'Red Horizon Pact')], names: ['Red Horizon Pact update #2']),
    ]);

    expect(moved, {'neon-s-ship-pack-v3': 'neon-s-ship-pack', 'red-horizon-pact': 'red-horizon-pact-update-2'});
  });

  test("an id remembered under its author never leads to somebody else's mod of the same name", () {
    final ids = storeWith({
      'orbregion#author:someone': {'id': 'orbregion-2', 'mark': 'author:someone'},
    });
    ids.beginRun();
    final moved = ids.movedIds([
      built('orbregion', [forum('32814', 'Orbregion')], names: ['Orbregion'], authors: ['lolghurt']),
    ]);
    expect(moved, isEmpty);
  });

  test('two mods that could both be meant: the old id leads nowhere', () {
    final ids = storeWith({
      'kadur remnant': {'id': 'kadur-remnant'},
    });
    ids.beginRun();
    final moved = ids.movedIds([
      built('kadur-remnant-2', [forum('1')], names: ['Kadur Remnant']),
      built('kadur-remnant-3', [forum('2')], names: ['Kadur Remnant']),
    ]);
    expect(moved, isEmpty);
  });

  test('a move is kept when its posts are gone, and dropped when the id is a mod again', () {
    var ids = storeWith({
      'whichtmi': {'id': 'whichtmi', 'firstSeen': '2026-08-24', 'posts': ['forum:26289']},
      'whichtmi#author:day_breaker': {'id': 'whichtmi-2', 'firstSeen': '2026-08-25', 'posts': ['discord:9']},
    });
    final refs = [forum('26289', 'WhichTMI'), discord('9', 'WhichTMI')];
    ids.beginRun(refsThisRun: refs);
    final id = ids.idForPosts('WhichTMI', mark: 'topic:26289', refs: refs);
    expect(ids.movedIds([built(id, refs, names: ['WhichTMI'])]), {'whichtmi-2': 'whichtmi'});
    ids.save();

    // The Discord thread is gone; the old address still leads to the mod.
    ids = ModIdStore(dir.path)..load();
    ids.beginRun(refsThisRun: [forum('26289', 'WhichTMI')]);
    expect(ids.movedIds([built('whichtmi', [forum('26289', 'WhichTMI')], names: ['WhichTMI'])]), {'whichtmi-2': 'whichtmi'});

    // The mod it leads to is gone too: so is the move.
    expect(ids.movedIds(const []), isEmpty);

    // The old id is a mod of its own again: it is no longer moved.
    expect(ids.movedIds([built('whichtmi-2', [discord('9', 'WhichTMI')], names: ['WhichTMI'])]),
        isNot(contains('whichtmi-2')));
    ids.save();
    final file = jsonDecode(File(p.join(dir.path, ModIdStore.fileName)).readAsStringSync()) as Map;
    expect((file['ids'] as Map)['whichtmi#author:day_breaker'], isNot(contains('movedTo')));
  });

  test('the catalog carries its moved ids through its file', () {
    final catalog = ModCatalog(
      generatedAt: DateTime.utc(2026),
      mods: [CatalogMod(id: 'carrierui', mod: ScrapedMod(name: 'CarrierUI'))],
      movedIds: const {'carrierui-2': 'carrierui'},
    );
    final back = ModCatalog.fromMap(jsonDecode(jsonEncode(catalog.toMap())) as Map<String, dynamic>);
    expect(back.movedIds, {'carrierui-2': 'carrierui'});

    // A catalog with nothing moved writes no field for it.
    expect(ModCatalog(generatedAt: DateTime.utc(2026)).toMap(), isNot(contains('movedIds')));
  });
}
