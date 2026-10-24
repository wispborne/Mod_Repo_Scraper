import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/mod_repo_utils.dart';
import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:mod_repo_scraper/catalog/catalog_inputs.dart';
import 'package:mod_repo_scraper/catalog/listing.dart';
import 'package:mod_repo_scraper/catalog/mod_catalog.dart';
import 'package:mod_repo_scraper/catalog/source_post.dart';
import 'package:mod_repo_scraper/catalog/takedowns.dart';
import 'package:mod_repo_scraper/site/mod_id_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

SourcePostRef forum(String id, [String? llmName]) => SourcePostRef(kind: SourceKind.forum, id: id, llmModName: llmName);
SourcePostRef discord(String id, [String? llmName]) =>
    SourcePostRef(kind: SourceKind.discord, id: id, llmModName: llmName);

const _tidalThread = '1507163509224509510';

Listing listing(String name, SourcePostRef ref, {List<String> authors = const []}) => Listing(
      mod: ScrapedMod(
        name: name,
        authorsList: authors,
        sources: [ref.kind == SourceKind.forum ? ModSource.ModdingSubforum : ModSource.Discord],
        urls: {
          ref.kind == SourceKind.forum ? ModUrlType.Forum : ModUrlType.Discord: ref.kind == SourceKind.forum
              ? 'https://fractalsoftworks.com/forum/index.php?topic=${ref.id}.0'
              : 'https://discord.com/channels/1/${ref.id}/${ref.id}',
        },
      ),
      ref: ref,
      origin: ref.llmModName == null ? ListingOrigin.rules : ListingOrigin.rulesAndLlm,
    );

/// The five other Diable Avionics mods, and the Tidal fork's Discord thread.
List<Listing> diableAvionics() => [
      listing('Diable Avionics', forum('10', 'Diable Avionics'), authors: ['Tartiflette']),
      listing('Diable Avionics', forum('11', 'Diable Avionics'), authors: ['Someone']),
      listing('Diable Avionics', forum('12', 'Diable Avionics'), authors: ['Another']),
      listing('Diable Avionics', forum('13', 'Diable Avionics'), authors: ['Third']),
      listing('Diable Avionics: Original Flavor', forum('14', 'Diable Avionics: Original Flavor'),
          authors: ['After', 'Tartiflette', 'Tidal']),
      listing('Diable Avionics (TIDAL FORK)', discord(_tidalThread, 'Diable Avionics'), authors: ['tidal5590']),
    ];

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('takedowns'));
  tearDown(() => dir.deleteSync(recursive: true));

  void seedIds(Map<String, Object> ids) =>
      File(p.join(dir.path, ModIdStore.fileName)).writeAsStringSync(jsonEncode({'ids': ids}));

  Future<ModCatalog> build(List<Listing> listings,
      {TakedownList takedowns = const TakedownList(), List<Listing> collections = const [], List<String>? log}) async {
    final ids = ModIdStore(dir.path)..load();
    final catalog = await ModCatalog.build(
      inputs: CatalogListings(listings: listings, collections: collections),
      ids: ids,
      takedowns: takedowns,
      log: log?.add,
    );
    ids.save();
    return catalog;
  }

  Map<String, List<String>> postsById(ModCatalog catalog) => {
        for (final mod in catalog.mods) mod.id: [for (final post in mod.sourcePosts) post.ref.key]..sort(),
      };

  group('the list file', () {
    test('a missing file is an empty list', () {
      expect(TakedownList.read(dir.path).isEmpty, isTrue);
    });

    test('a broken file throws and names the file', () {
      TakedownList.fileIn(dir.path).writeAsStringSync('{ not json');
      expect(() => TakedownList.read(dir.path),
          throwsA(isA<StateError>().having((e) => e.message, 'message', contains(TakedownList.fileName))));
    });

    test('written and read back, with no field but the id, name, posts and day', () {
      const list = TakedownList(
        mods: [ModTakedown(id: 'diable-avionics-tidal-fork', name: 'Diable Avionics (TIDAL FORK)', posts: ['discord:$_tidalThread'], on: '2026-10-22')],
        authors: [AuthorTakedown(names: ['tidal5590'], on: '2026-10-22')],
      );
      list.write(dir.path);
      final raw = jsonDecode(TakedownList.fileIn(dir.path).readAsStringSync()) as Map<String, dynamic>;
      expect((raw['mods'] as List).single, {
        'id': 'diable-avionics-tidal-fork',
        'name': 'Diable Avionics (TIDAL FORK)',
        'posts': ['discord:$_tidalThread'],
        'on': '2026-10-22',
      });
      expect(File('${TakedownList.fileIn(dir.path).path}.tmp').existsSync(), isFalse);
      expect(TakedownList.read(dir.path), list);
    });
  });

  group('samePerson', () {
    test('spellings of one person match', () {
      expect(ModRepoUtils.samePerson('tidal5590', 'Tidal'), isTrue);
      expect(ModRepoUtils.samePerson('tidal5590', 'TIDAL'), isTrue);
      expect(ModRepoUtils.samePerson('Dreadnought70', 'Dreadnought'), isTrue);
      expect(ModRepoUtils.samePerson('Nes', 'nescom'), isTrue);
    });

    test('a part of a name is not a match', () {
      expect(ModRepoUtils.samePerson('Tidal', 'Tidalwave'), isFalse);
      expect(ModRepoUtils.samePerson('Tidal', 'Tartiflette'), isFalse);
    });

    test('a credit naming two people matches either', () {
      expect(ModRepoUtils.samePerson('After, Tartiflette and Tidal', 'tidal5590'), isTrue);
      expect(ModRepoUtils.samePerson('Tartiflette', 'After & Tartiflette'), isTrue);
    });
  });

  group("an entry's posts", () {
    CatalogMod mod(String id, String name, List<SourcePostRef> refs) => CatalogMod(
          id: id,
          mod: ScrapedMod(name: name),
          sourcePosts: [for (final ref in refs) CatalogSourcePost(kind: ref.kind, id: ref.id, llmModName: ref.llmModName)],
        );

    final catalog = ModCatalog(
      generatedAt: DateTime.utc(2026),
      mods: [
        mod('diable-avionics-tidal-fork', 'Diable Avionics (TIDAL FORK)', [discord(_tidalThread, 'Diable Avionics')]),
        mod('corrupt-officials', 'Corrupt.Officials', [forum('34161', 'Corrupt.Officials')]),
        mod('useful-tithes', 'Useful.Tithes', [forum('34161', 'Useful.Tithes')]),
        mod('salvage-rights', 'Salvage.Rights', [forum('34161', 'Salvage.Rights')]),
        mod('station-tax', 'Station.Tax', [forum('34161', 'Station.Tax')]),
      ],
      collections: [CatalogCollection(id: 'hartleys-mods', name: "Hartley's Mods", post: forum('34161'))],
    );

    test('a one-mod Discord thread is recorded as the whole post', () {
      expect(takedownPostsFor(catalog, 'diable-avionics-tidal-fork')!.posts, ['discord:$_tidalThread']);
    });

    test('one of four mods on a forum topic is recorded by its name', () {
      expect(takedownPostsFor(catalog, 'useful-tithes')!.posts, ['forum:34161#Useful.Tithes']);
    });

    test("a Collection's id records no posts", () {
      final found = takedownPostsFor(catalog, 'hartleys-mods')!;
      expect(found.isCollection, isTrue);
      expect(found.posts, isEmpty);
    });

    test('an id that is not in the catalog gives nothing', () {
      expect(takedownPostsFor(catalog, 'no-such-mod'), isNull);
    });
  });

  group('the Tidal fork', () {
    const entry = TakedownList(mods: [
      ModTakedown(
          id: 'diable-avionics-tidal-fork', name: 'Diable Avionics (TIDAL FORK)', posts: ['discord:$_tidalThread'], on: '2026-10-22'),
    ]);

    test('only the fork is left out, and the others keep their posts', () async {
      final before = await build(diableAvionics());
      expect(before.mods.map((m) => m.id), contains('diable-avionics-tidal-fork'));
      final others = postsById(before)..remove('diable-avionics-tidal-fork');
      expect(others, hasLength(5));

      final log = <String>[];
      final after = await build(diableAvionics(), takedowns: entry, log: log);
      expect(after.mods.map((m) => m.id), isNot(contains('diable-avionics-tidal-fork')));
      expect(postsById(after), others);
      expect(after.takedownReport.removedPosts, {'discord:$_tidalThread'});
      expect(after.takedownReport.matches.single.mods.single.id, 'diable-avionics-tidal-fork');
      expect(log.where((line) => line.startsWith('WARNING')), isEmpty);

      final restored = await build(diableAvionics());
      expect(postsById(restored), postsById(before));
    });

    test('its id leads nowhere and the id file keeps its posts', () async {
      await build(diableAvionics());
      final after = await build(diableAvionics(), takedowns: entry);
      expect(after.movedIds.keys, isNot(contains('diable-avionics-tidal-fork')));
      expect(after.movedIds.values, isNot(contains('diable-avionics-tidal-fork')));
      final ids = ModIdStore(dir.path)..load();
      expect(ids.postsOfId('diable-avionics-tidal-fork'), contains('discord:$_tidalThread#Diable Avionics'));
    });

    test('a new thread by the same author is not blocked by a mod entry', () async {
      await build(diableAvionics());
      final after = await build([...diableAvionics(), listing('Diable Avionics (TIDAL FORK)', discord('999', 'Diable Avionics'), authors: ['tidal5590'])],
          takedowns: entry);
      final fresh = after.mods.where((m) => m.sourcePosts.any((post) => post.id == '999')).single;
      expect(fresh.id, isNot('diable-avionics-tidal-fork'));
    });
  });

  group('one mod on a shared topic', () {
    const entry = TakedownList(mods: [
      ModTakedown(id: 'useful-tithes', name: 'Useful.Tithes', posts: ['forum:34161#Useful.Tithes'], on: '2026-10-22'),
    ]);

    void seed() => seedIds({
          'corrupt.officials': {'id': 'corrupt-officials', 'posts': ['forum:34161#Corrupt.Officials']},
          'useful.tithes': {'id': 'useful-tithes', 'posts': ['forum:34161#Useful.Tithes']},
          'salvage.rights': {'id': 'salvage-rights', 'posts': ['forum:34161#Salvage.Rights']},
        });

    List<Listing> topic(String tithesName, {List<Listing> extra = const []}) => [
          listing('Corrupt.Officials', forum('34161', 'Corrupt.Officials'), authors: ['SirHartley']),
          listing(tithesName, forum('34161', tithesName), authors: ['SirHartley']),
          listing('Salvage.Rights', forum('34161', 'Salvage.Rights'), authors: ['SirHartley']),
          ...extra,
        ];

    test('a small rename is still blocked before the merge', () async {
      seed();
      final catalog = await build(topic('Useful Tithes'), takedowns: entry);
      expect(catalog.mods.map((m) => m.id), unorderedEquals(['corrupt-officials', 'salvage-rights']));
      expect(catalog.takedownReport.removedPosts, isEmpty, reason: 'the topic still has two mods');
    });

    test('a bigger rename keeps the id through the id store and is left out', () async {
      seed();
      final catalog = await build(topic('Tithes Collector'), takedowns: entry);
      expect(catalog.mods.map((m) => m.id), unorderedEquals(['corrupt-officials', 'salvage-rights']));
      expect(catalog.takedownReport.matches.single.mods.single.name, 'Tithes Collector');
    });

    test('a rename the id store declines is published under a new id, with a warning', () async {
      seed();
      final log = <String>[];
      final catalog = await build(topic('Levy Service'), takedowns: entry, log: log);
      expect(catalog.mods.map((m) => m.id), unorderedEquals(['corrupt-officials', 'salvage-rights', 'levy-service']));
      expect(log.where((line) => line.startsWith('WARNING') && line.contains('useful-tithes')), hasLength(1));
    });

    for (final spelling in ['Useful.Tithes', 'UsefulTithes']) {
      test('a new mod with a close name does not get the blocked id ("$spelling" still there)', () async {
        seed();
        final catalog = await build(
          topic(spelling, extra: [listing('Useful Tithes Plus', forum('34161', 'Useful Tithes Plus'), authors: ['SirHartley'])]),
          takedowns: entry,
        );
        final plus = catalog.mods.singleWhere((m) => m.mod.name == 'Useful Tithes Plus');
        expect(plus.id, isNot('useful-tithes'));
        expect(catalog.mods.map((m) => m.id), isNot(contains('useful-tithes')));
      });
    }
  });

  group('author entries', () {
    const entry = TakedownList(authors: [AuthorTakedown(names: ['tidal5590'], on: '2026-10-22')]);

    test('a mod made with others and a mod first seen after the entry are left out', () async {
      final catalog = await build([
        ...diableAvionics(),
        listing('Project Solar Tail', forum('20', 'Project Solar Tail'), authors: ['TIDAL']),
      ], takedowns: entry);
      final names = catalog.mods.map((m) => m.mod.name);
      expect(names, isNot(contains('Diable Avionics: Original Flavor')));
      expect(names, isNot(contains('Project Solar Tail')));
      expect(names, isNot(contains('Diable Avionics (TIDAL FORK)')));
      expect(names.where((n) => n == 'Diable Avionics'), hasLength(4));
      final credits = {for (final mod in catalog.takedownReport.matches.single.mods) mod.name: mod.credit};
      expect(credits['Diable Avionics: Original Flavor'], 'Tidal');
      expect(credits['Project Solar Tail'], 'TIDAL');
    });

    test('a similar name is not a match', () async {
      final catalog = await build([listing('Waves', forum('21', 'Waves'), authors: ['Tidalwave'])], takedowns: entry);
      expect(catalog.mods, hasLength(1));
    });

    test('one of two mods on a topic: its id leads nowhere and no move is saved', () async {
      seedIds({
        'alpha': {'id': 'alpha', 'posts': ['forum:600#Alpha']},
        'beta': {'id': 'beta', 'posts': ['forum:600#Beta']},
      });
      final catalog = await build([
        listing('Alpha', forum('600', 'Alpha'), authors: ['Tidal']),
        listing('Beta', forum('600', 'Beta'), authors: ['Someone']),
      ], takedowns: entry);
      expect(catalog.mods.map((m) => m.id), ['beta']);
      expect(catalog.movedIds, isEmpty);
      final saved = jsonDecode(File(p.join(dir.path, ModIdStore.fileName)).readAsStringSync()) as Map;
      expect((saved['ids'] as Map)['alpha'], isNot(contains('movedTo')));
      expect(catalog.takedownReport.removedPosts, isEmpty);
    });
  });

  group('Collections', () {
    void seed() => seedIds({
          "hartley's mods": {'id': 'hartleys-mods', 'posts': ['forum:500']},
          'alpha': {'id': 'alpha', 'posts': ['forum:500#Alpha']},
          'beta': {'id': 'beta', 'posts': ['forum:500#Beta']},
        });

    List<Listing> mods() => [
          listing('Alpha', forum('500', 'Alpha'), authors: ['Tidal']),
          listing('Beta', forum('500', 'Beta'), authors: ['Tidal']),
        ];
    final collection = [listing("Hartley's Mods", forum('500'), authors: ['Tidal'])];

    test('a Collection that loses one mod still lists the other', () async {
      seed();
      final catalog = await build(mods(),
          collections: collection,
          takedowns: const TakedownList(mods: [ModTakedown(id: 'alpha', name: 'Alpha', posts: ['forum:500#Alpha'], on: '2026-10-22')]));
      expect(catalog.collections.single.modIds, ['beta']);
    });

    test('a Collection with every mod removed is gone', () async {
      seed();
      final catalog = await build(mods(),
          collections: collection, takedowns: const TakedownList(authors: [AuthorTakedown(names: ['Tidal'], on: '2026-10-22')]));
      expect(catalog.mods, isEmpty);
      expect(catalog.collections, isEmpty);
      expect(catalog.takedownReport.removedPosts, {'forum:500'});
    });

    test('a Collection taken down by its id is gone while its mods stay', () async {
      seed();
      final log = <String>[];
      final catalog = await build(mods(),
          collections: collection,
          takedowns: const TakedownList(mods: [ModTakedown(id: 'hartleys-mods', name: "Hartley's Mods", on: '2026-10-22')]),
          log: log);
      expect(catalog.collections, isEmpty);
      expect(catalog.mods.map((m) => m.id), unorderedEquals(['alpha', 'beta']));
      expect(catalog.takedownReport.matches.single.collections.single.id, 'hartleys-mods');
      expect(log.where((line) => line.startsWith('WARNING')), isEmpty);
    });
  });
}
