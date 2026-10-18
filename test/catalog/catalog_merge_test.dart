import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:mod_repo_scraper/catalog/catalog_inputs.dart';
import 'package:mod_repo_scraper/catalog/listing.dart';
import 'package:mod_repo_scraper/catalog/mod_catalog.dart';
import 'package:mod_repo_scraper/catalog/source_post.dart';
import 'package:mod_repo_scraper/site/mod_id_store.dart';
import 'package:test/test.dart';

/// Topic 34161 and three more, saved the way QB saves them, with the LLM's
/// real answer for 34161 in the store.
Future<void> _writeQbStore(String dir, {required bool llmOn}) async {
  final store = JsonDataStore(dir);
  final fixture = jsonDecode(File('test/catalog/fixtures/34161.json').readAsStringSync()) as Map<String, dynamic>;
  final hartley = QbModSummaryMapper.fromMap(fixture['summary'] as Map<String, dynamic>);
  final posts = [for (final html in fixture['posts'] as List) html as String];

  final summaries = [
    hartley,
    QbModSummary(topicId: 1, title: '[0.98a] Plain Mod 1.0', author: 'Someone', topicUrl: 'https://fractalsoftworks.com/forum/index.php?topic=1.0'),
    QbModSummary(
      topicId: 2,
      title: '[0.98a] Indexed Mod v2',
      author: 'Other',
      inModIndex: true,
      indexLines: const [QbIndexLine(name: 'Indexed Mod', author: 'Other', gameVersion: '0.98a', category: 'Faction Mods')],
    ),
    // A question thread the LLM called no mod, with no version tag: the bundle
    // drops it, so the catalog never sees it.
    QbModSummary(topicId: 3, title: 'Any mods with swappable modules?', author: 'Asker'),
  ];
  await store.saveIndex(summaries);
  await store.saveDetail(QbModDetail(topicId: 1, title: summaries[1].title, contentHtml: '<p>Plain Mod. Download below.</p>'));
  await store.saveDetail(QbModDetail(
    topicId: hartley.topicId,
    title: hartley.title,
    contentHtml: posts.first,
    extraPosts: [for (final html in posts.skip(1)) QbForumPost(contentHtml: html)],
  ));

  final llm = LlmExtractionStore(dir, flushEveryN: 1000);
  await llm.put(3, LlmStoreEntry(fingerprint: 'x', schemaVersion: LlmExtractionStore.schemaVersion, promptVersion: 1, mods: const [], isMod: false));
  if (llmOn) {
    await llm.put(
      hartley.topicId,
      LlmStoreEntry(
        fingerprint: 'x',
        schemaVersion: LlmExtractionStore.schemaVersion,
        promptVersion: 1,
        mods: [for (final m in fixture['llmMods'] as List) LlmModMapper.fromMap(m as Map<String, dynamic>)],
      ),
    );
  }
  await llm.flush();
}

/// Hartley's three real Discord announcements, each linking topic 34161.
List<ScrapedMod> _hartleyOnDiscord() => [
      for (final (name, thread, file) in [
        ('Big Pilum Energy 1.0.d', '1355288516208103584', 'Big.Pilum.Energy1.0.d.zip'),
        ('Disco.Balls 1.1.c - More Lamp Colour Options', '1355297749679210787', 'Disco.Balls1.0.c.zip'),
        ('Useful.Tithes 1.0.a', '1424047145354268672', 'Useful.Tithes1.0.a.zip'),
      ])
        ScrapedMod(
          name: name,
          authorsList: const ['sirhartley'],
          sources: const [ModSource.Discord],
          gameVersionReq: '0.98a',
          urls: {
            ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=34161.0',
            ModUrlType.Discord: 'https://discord.com/channels/187635036525166592/$thread/$thread',
            ModUrlType.DirectDownload: 'https://github.com/SirHartley/x/releases/download/1/$file',
          },
        ),
    ];

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('catalog_merge'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('with the LLM off, every kept forum topic and Discord thread gives one rules listing', () async {
    await _writeQbStore(dir.path, llmOn: false);
    final inputs = await CatalogInputs.read(qbDataPath: dir.path, discordMods: _hartleyOnDiscord());

    expect(inputs.forumTopics, 3, reason: 'topic 3 is dropped the same way the bundle drops it');
    expect(inputs.discordThreads, 3);
    expect(inputs.listings, hasLength(6));
    expect(inputs.listings.every((l) => l.origin == ListingOrigin.rules), isTrue);
    expect(inputs.collections, isEmpty);

    final names = inputs.listings.map((l) => l.mod.name).toList();
    expect(names, contains('Indexed Mod'), reason: 'named from its index line');
    expect(names, contains('Plain Mod'), reason: 'named from its title, release parts taken off');
  });

  test("each of Hartley's Discord threads joins its own mod on shared topic 34161", () async {
    await _writeQbStore(dir.path, llmOn: true);
    final inputs = await CatalogInputs.read(qbDataPath: dir.path, discordMods: _hartleyOnDiscord());
    expect(inputs.collections.single.mod.name, "Hartley's Miscellaneous Mods");

    final catalog = await ModCatalog.build(inputs: inputs, ids: ModIdStore(dir.path)..load());

    CatalogMod modFrom(String llmName) =>
        catalog.mods.singleWhere((m) => m.sourcePosts.any((p) => p.kind == SourceKind.forum && p.llmModName == llmName));

    final tithes = modFrom('Useful.Tithes');
    final pilum = modFrom('Big Pilum Energy');
    final disco = modFrom('Disco.Balls');
    final lost = modFrom('Lost.Sector');

    expect(tithes.discordPost?.id, '1424047145354268672');
    expect(pilum.discordPost?.id, '1355288516208103584');
    expect(disco.discordPost?.id, '1355297749679210787');
    expect(lost.discordPost, isNull, reason: 'Lost.Sector was never announced on Discord');

    // Four mods, four ids, and no mod called the topic's name.
    expect({tithes.id, pilum.id, disco.id, lost.id}, hasLength(4));
    expect(catalog.mods.where((m) => m.mod.name == "Hartley's Miscellaneous Mods"), isEmpty);
    // A Collection that never had an id gets no page.
    expect(catalog.collections, isEmpty);
  });

  test('the catalog file reads back as it was written', () async {
    await _writeQbStore(dir.path, llmOn: true);
    final inputs = await CatalogInputs.read(qbDataPath: dir.path, discordMods: _hartleyOnDiscord());
    final catalog = await ModCatalog.build(inputs: inputs, ids: ModIdStore(dir.path)..load());
    final file = File('${dir.path}/out/${ModCatalog.fileName}');
    await catalog.write(file);

    final back = ModCatalog.read(file)!;
    expect(back.mods.map((m) => m.id), catalog.mods.map((m) => m.id));
    expect(back.mods.first.sourcePosts, catalog.mods.first.sourcePosts);
    final json = file.readAsStringSync();
    expect(json, isNot(contains('confidence')));
    expect(json, isNot(contains(dir.path.replaceAll(r'\', r'\\'))));
  });

  test("a mod's old thread and its new one stay two mods, even with a Discord post matching both", () async {
    Listing forumListing(String topicId) => Listing(
          mod: ScrapedMod(
            name: 'Scy',
            authorsList: const ['Tartiflette'],
            gameVersionReq: '0.98a',
            sources: const [ModSource.Index],
            urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=$topicId.0'},
          ),
          ref: SourcePostRef(kind: SourceKind.forum, id: topicId),
        );
    final discord = Listing(
      mod: const ScrapedMod(
        name: 'Scy',
        authorsList: ['Tartiflette'],
        sources: [ModSource.Discord],
        urls: {
          ModUrlType.Discord: 'https://discord.com/channels/1/7/7',
          ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=29535.0',
        },
      ),
      ref: const SourcePostRef(kind: SourceKind.discord, id: '7'),
    );

    final catalog = await ModCatalog.build(
      inputs: CatalogListings(listings: [forumListing('8010'), discord, forumListing('29535')]),
      ids: ModIdStore(dir.path)..load(),
    );

    expect(catalog.mods, hasLength(2));
    final newer = catalog.mods.singleWhere((m) => m.forumPost?.id == '29535');
    expect(newer.discordPost?.id, '7', reason: 'the announcement links the new thread, so it joins that one');
    final older = catalog.mods.singleWhere((m) => m.forumPost?.id == '8010');
    expect(older.discordPost, isNull);
    expect(older.id, isNot(newer.id));
  });
}
