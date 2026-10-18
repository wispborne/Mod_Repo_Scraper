import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/mod_merger.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/mod_thread_filter.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:mod_repo_scraper/catalog/catalog_inputs.dart';
import 'package:mod_repo_scraper/catalog/download_key.dart';
import 'package:mod_repo_scraper/catalog/forum_listing.dart';
import 'package:mod_repo_scraper/catalog/listing.dart';
import 'package:mod_repo_scraper/catalog/mod_catalog.dart';
import 'package:mod_repo_scraper/catalog/source_post.dart';
import 'package:mod_repo_scraper/catalog/source_post_listings.dart';
import 'package:mod_repo_scraper/site/mod_id_store.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// Cases found by comparing the first full catalog with the published site.

SourcePostRef forum(String id, [String? llmName]) => SourcePostRef(kind: SourceKind.forum, id: id, llmModName: llmName);
SourcePostRef discord(String id, [String? llmName]) =>
    SourcePostRef(kind: SourceKind.discord, id: id, llmModName: llmName);

const _drones = 'All the Domain Drones+ New Drones';
const _dronesZip = 'https://www.dropbox.com/s/abc123/All%20the%20Domain%20Drones%2B%20New%20Drones.rar?dl=1';

Listing _dronesListing({required SourcePostRef ref, required String author, required String download}) => Listing(
      mod: ScrapedMod(
        name: _drones,
        authorsList: [author],
        sources: [ref.kind == SourceKind.forum ? ModSource.ModdingSubforum : ModSource.Discord],
        urls: {
          ref.kind == SourceKind.forum ? ModUrlType.Forum : ModUrlType.Discord: ref.kind == SourceKind.forum
              ? 'https://fractalsoftworks.com/forum/index.php?topic=${ref.id}.0'
              : 'https://discord.com/channels/1/${ref.id}/${ref.id}',
        },
      ),
      ref: ref,
      origin: ListingOrigin.llm,
      downloadKeys: {downloadKey(download)!},
    );

void main() {
  group('download keys', () {
    test('two spellings of one Dropbox file are one key', () {
      expect(
        downloadKey('https://www.dropbox.com/s/abc123/Mod.rar?dl=1'),
        downloadKey('http://dropbox.com/s/abc123/Mod.rar/?dl=0'),
      );
    });

    test('two different files are two keys', () {
      expect(
        downloadKey('https://github.com/a/b/releases/download/v1/Mod.zip'),
        isNot(downloadKey('https://github.com/a/b/releases/download/v2/Mod.zip')),
      );
    });

    test('an address that is not http(s) has no key', () {
      expect(downloadKey('mailto:someone@example.com'), isNull);
      expect(downloadKey('not a link'), isNull);
    });
  });

  group('one post', () {
    final zip = LlmDownload(url: 'https://github.com/vicegrip/emergent-threats/releases/download/v1.3.3/EmergentThreats_v1.3.3.zip');
    final rules = Listing(
      mod: const ScrapedMod(name: 'Emergent Threats/IX Revival v1.3.3', authorsList: ['vicegrip']),
      ref: discord('1355071745366822950'),
    );
    const words = 'Emergent Threats/IX Revival v1.3.3\n\nEmergent Threats now includes ET: IX Revival. Download below.';

    test('two LLM mods offering the same one file are one mod, not a Collection', () {
      final result = SourcePostListings.combine(
        rules: rules,
        llmMods: [
          LlmMod(name: 'Emergent Threats', downloads: [zip]),
          LlmMod(name: 'ET: IX Revival', nicknames: const ['IX Revival'], downloads: [zip]),
        ],
        postWords: words,
      );

      expect(result.isCollection, isFalse);
      expect(result.listings, hasLength(1));
      expect(result.listings.single.mod.name, 'Emergent Threats/IX Revival v1.3.3');
      expect(result.listings.single.ref.llmModName, 'Emergent Threats');
    });

    test('two LLM mods with a file each are still two mods', () {
      final result = SourcePostListings.combine(
        rules: rules,
        llmMods: [
          LlmMod(name: 'Emergent Threats', downloads: [zip]),
          LlmMod(name: 'ET: IX Revival', downloads: [LlmDownload(url: 'https://example.com/IXRevival.zip')]),
        ],
        postWords: words,
      );

      expect(result.listings, hasLength(2));
    });

    test('each listing carries the downloads the LLM tied to it', () {
      final result = SourcePostListings.combine(
        rules: rules,
        llmMods: [LlmMod(name: 'Emergent Threats', downloads: [zip])],
        postWords: words,
      );

      expect(result.listings.single.downloadKeys, {downloadKey(zip.url)});
    });
  });

  group('merge', () {
    test('the same name offering the same file joins, whoever the sources say wrote it', () async {
      final merged = await ModMerger().mergeListings([
        _dronesListing(ref: forum('25888', _drones), author: 'Dreadnought70', download: _dronesZip),
        _dronesListing(
          ref: discord('1271590391065477143', _drones),
          author: 'nathan_the_grudge_bearer',
          download: _dronesZip.replaceFirst('dl=1', 'dl=0'),
        ),
        _dronesListing(ref: discord('1437782625262506116', _drones), author: 'nathan_the_grudge_bearer', download: _dronesZip),
      ]);

      expect(merged, hasLength(1));
      expect(merged.single.sourcePosts, hasLength(3));
    });

    test('the same name with different files and different authors stays apart', () async {
      final merged = await ModMerger().mergeListings([
        _dronesListing(ref: forum('25888', _drones), author: 'Dreadnought70', download: _dronesZip),
        _dronesListing(
          ref: discord('1271590391065477143', _drones),
          author: 'somebody_else',
          download: 'https://example.com/a-different-file.zip',
        ),
      ]);

      expect(merged, hasLength(2));
    });
  });

  group('ids', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('catalog_fixes'));
    tearDown(() => dir.deleteSync(recursive: true));

    ModIdStore store(Map<String, Object> ids) {
      File(p.join(dir.path, ModIdStore.fileName)).writeAsStringSync(jsonEncode({'ids': ids}));
      return ModIdStore(dir.path)..load();
    }

    test("a Discord thread that joins another forum topic leaves its old topic's id with that topic", () {
      // The old site paired Exotica's Discord thread with topic 32811. It is
      // really Kaysaar's edition, topic 29538, and joins that now.
      for (final topicFirst in [true, false]) {
        final ids = store({
          'exotica technologies': {
            'id': 'exotica-technologies',
            'firstSeen': '2026-08-24',
            'mark': 'topic:32811',
            'posts': ['forum:32811', 'discord:1218337390570246274'],
          },
          'exotica technologies#topic:29538': {
            'id': 'exotica-technologies-2',
            'firstSeen': '2026-10-10',
            'mark': 'topic:29538',
            'posts': ['forum:29538'],
          },
        });
        final lukas = [forum('32811', 'Exotica Technologies')];
        final kaysaar = [discord('1218337390570246274', 'Exotica Technologies'), forum('29538', 'Exotica Technologies')];
        ids.beginRun(refsThisRun: [...lukas, ...kaysaar]);

        String idOf(List<SourcePostRef> refs) =>
            ids.idForPosts('Exotica Technologies', mark: 'topic:${refs.last.id}', refs: refs);
        final String lukasId;
        final String kaysaarId;
        if (topicFirst) {
          lukasId = idOf(lukas);
          kaysaarId = idOf(kaysaar);
        } else {
          kaysaarId = idOf(kaysaar);
          lukasId = idOf(lukas);
        }

        expect(lukasId, 'exotica-technologies', reason: 'topic first: $topicFirst');
        expect(kaysaarId, 'exotica-technologies-2', reason: 'topic first: $topicFirst');
      }
    });

    test("a Discord-only mod keeps its old page's id when the page's topic has moved on to another mod", () {
      // Topic 30580 was NEON's Ship Pack and is now Xxarra's Variety Pack. NEON's
      // Discord threads are a mod of their own and keep the old address.
      final ids = store({
        "neon's ship pack": {
          'id': 'neon-s-ship-pack',
          'firstSeen': '2026-08-24',
          'mark': 'topic:30580',
          'posts': ['forum:30580', 'discord:1354944903573930145'],
        },
        "xxarra's variety pack": {
          'id': 'xxarra-s-variety-pack',
          'firstSeen': '2026-09-01',
          'mark': 'topic:30580',
          'posts': ["forum:30580#Xxarra's Variety Pack"],
        },
      });
      final xxarra = [forum('30580', "Xxarra's Variety Pack")];
      final neon = [discord('1354944903573930145', "NEON's ship pack")];
      ids.beginRun(refsThisRun: [...xxarra, ...neon]);

      expect(ids.idForPosts("Xxarra's Variety Pack", refs: xxarra), 'xxarra-s-variety-pack');
      expect(ids.idForPosts("NEON's ship pack", refs: neon), 'neon-s-ship-pack');
    });

    test("a forum topic's id still goes with a Discord thread when that topic is gone", () {
      final ids = store({
        'exotica technologies': {
          'id': 'exotica-technologies',
          'firstSeen': '2026-08-24',
          'mark': 'topic:32811',
          'posts': ['forum:32811', 'discord:1218337390570246274'],
        },
      });
      final refs = [discord('1218337390570246274', 'Exotica Technologies'), forum('29538', 'Exotica Technologies')];
      ids.beginRun(refsThisRun: refs);

      expect(ids.idForPosts('Exotica Technologies', refs: refs), 'exotica-technologies');
    });
  });

  test('a title tagged "[.98a]" counts as tagged with a game version', () {
    expect(
      keepThreadInBundle(title: '[.98a][WIP]One Big Happy Fleet: a Star Trek mod', llmSaidMod: false),
      isTrue,
    );
    expect(keepThreadInBundle(title: 'Any mods with swappable modules?', llmSaidMod: false), isFalse);
  });

  test('a topic with no saved post is a mod only when the mod index lists it', () async {
    final dir = Directory.systemTemp.createTempSync('catalog_fixes_inputs');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = JsonDataStore(dir.path);
    await store.saveIndex([
      // A question on the Modding board whose post was never fetched.
      QbModSummary(topicId: 34771, title: 'A VERY basic modding question', author: 'MoffHul11', sourceBoard: 3),
      // An indexed topic behind the forum's login: only its index line is known.
      QbModSummary(
        topicId: 22693,
        inModIndex: true,
        indexLines: const [QbIndexLine(name: 'Fast Engine Rendering', author: 'tomatopaste', gameVersion: '0.95a', category: 'Utility mods')],
      ),
      QbModSummary(topicId: 5, title: '[0.98a] Saved Mod 1.0', author: 'Someone'),
    ]);
    await store.saveDetail(QbModDetail(topicId: 5, title: '[0.98a] Saved Mod 1.0', contentHtml: '<p>Saved Mod.</p>'));

    final inputs = await CatalogInputs.read(qbDataPath: dir.path);

    expect([for (final l in inputs.listings) l.ref.id]..sort(), ['22693', '5']);
    expect(inputs.listings.firstWhere((l) => l.ref.id == '22693').mod.name, 'Fast Engine Rendering');
  });

  test('a topic the index does not list is named from its title with nothing left dangling', () {
    String nameOf(String title) => forumRulesListing(QbModSummary(topicId: 1, title: title)).mod.name;

    expect(nameOf('[0.95.1a] Everything Recoverable (v1.1.2)'), 'Everything Recoverable');
    expect(nameOf('[0.98a] Companions of the Imperium - V-1.2'), 'Companions of the Imperium');
    expect(nameOf('[0.98a] - Gambling Den v1.6.3'), 'Gambling Den');
    expect(nameOf('[0.98]Agrean Breakers, ver 3.0'), 'Agrean Breakers');
  });

  test("listings join when the LLM gives both the same name, though the titles are too far apart", () async {
    Listing customLpcs(SourcePostRef ref, String title) => Listing(
          mod: ScrapedMod(
            name: title,
            authorsList: const ['ymfah'],
            sources: [ref.kind == SourceKind.forum ? ModSource.ModdingSubforum : ModSource.Discord],
            urls: {
              ref.kind == SourceKind.forum ? ModUrlType.Forum : ModUrlType.Discord: ref.kind == SourceKind.forum
                  ? 'https://fractalsoftworks.com/forum/index.php?topic=${ref.id}.0'
                  : 'https://discord.com/channels/1/${ref.id}/${ref.id}',
            },
          ),
          ref: ref,
          origin: ListingOrigin.rulesAndLlm,
        );

    final merged = await ModMerger().mergeListings([
      customLpcs(forum('29658', 'Custom LPCs'), 'Custom LPCs - Create your own wings!'),
      customLpcs(discord('1223662562865053766', 'Custom LPCs'), 'Custom LPCs v1.2.0 - Prometheus (LP IED) Chip Edition'),
    ]);

    expect(merged, hasLength(1));
  });

  test("the mod that still goes by an old id's name keeps it, not the topic its old page linked", () async {
    // The old page "nitelib-update-i" was the Discord thread's NiteLib, with
    // the forum link its message gave. That topic, 29589, is NebuLib.
    final dir = Directory.systemTemp.createTempSync('catalog_fixes_claims');
    addTearDown(() => dir.deleteSync(recursive: true));
    File(p.join(dir.path, ModIdStore.fileName)).writeAsStringSync(jsonEncode({
      'ids': {
        'nitelib [update i]': {
          'id': 'nitelib-update-i',
          'firstSeen': '2026-08-24',
          'posts': ['forum:29589', 'discord:1220400822039351388'],
        },
      },
    }));

    final catalog = await ModCatalog.build(
      inputs: CatalogListings(listings: [
        Listing(
          mod: const ScrapedMod(
            name: 'NebuLib',
            authorsList: ['Purple Nebula'],
            sources: [ModSource.ModdingSubforum],
            urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=29589.0'},
          ),
          ref: forum('29589', 'NebuLib'),
          origin: ListingOrigin.rulesAndLlm,
        ),
        Listing(
          mod: const ScrapedMod(
            name: 'NiteLib v1.1.0 [Update I]',
            authorsList: ['satellite_sol'],
            sources: [ModSource.Discord],
            urls: {ModUrlType.Discord: 'https://discord.com/channels/1/1220400822039351388/1220400822039351388'},
          ),
          ref: discord('1220400822039351388', 'NiteLib'),
          origin: ListingOrigin.rulesAndLlm,
        ),
      ]),
      ids: ModIdStore(dir.path)..load(),
    );

    String idOf(String postId) => catalog.mods.singleWhere((m) => m.sourcePosts.any((p) => p.id == postId)).id;
    expect(idOf('1220400822039351388'), 'nitelib-update-i');
    expect(idOf('29589'), isNot('nitelib-update-i'));
  });
}
