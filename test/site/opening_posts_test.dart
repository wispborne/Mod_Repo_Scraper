import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/qb/models/assumed_download.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/forum_data_bundle.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:mod_repo_scraper/catalog/catalog_inputs.dart';
import 'package:mod_repo_scraper/catalog/forum_listing.dart';
import 'package:mod_repo_scraper/catalog/listing.dart';
import 'package:mod_repo_scraper/catalog/mod_catalog.dart';
import 'package:mod_repo_scraper/catalog/source_post.dart';
import 'package:mod_repo_scraper/catalog/source_post_listings.dart';
import 'package:mod_repo_scraper/site/mod_id_store.dart';
import 'package:mod_repo_scraper/site/public_data_builder.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The thread this whole change is about: topic 35651, "Computica's Faction
/// Forks". The first post says what the project is and lists the forks by name;
/// every download and every per-mod write-up sits in the author's second post.
void main() {
  late Directory dir;
  late PublicDataBuilder builder;
  late ModIdStore idStore;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('opening_posts');
    idStore = ModIdStore(p.join(dir.path, 'data'))..load();
    builder = PublicDataBuilder(
      outputPath: p.join(dir.path, 'outputs'),
      idStore: idStore,
    );
  });

  /// Builds the site the way a run does: each thread in [bundle] turned into
  /// its listings, merged into a catalog with ids, and the pages built from it.
  Future<PublicSiteData> buildViaCatalog(ForumDataBundle bundle) async {
    final listings = <Listing>[];
    final collections = <Listing>[];
    for (final thread in bundle.index) {
      final detail = bundle.details['${thread.topicId}'];
      final result = SourcePostListings.combine(
        rules: forumRulesListing(thread),
        llmMods: thread.llm?.mods ?? const [],
        postWords: SourcePostListings.openingRunWords(detail == null
            ? SourcePost(kind: SourceKind.forum, id: '${thread.topicId}', title: thread.title)
            : SourcePost.fromForumDetail(detail).copyWith(title: thread.title)),
      );
      listings.addAll(result.listings);
      if (result.collection != null) collections.add(result.collection!);
    }
    final catalog = await ModCatalog.build(
      inputs: CatalogListings(listings: listings, collections: collections),
      ids: idStore,
    );
    return builder.build(mods: catalog.mods, collections: catalog.collections, bundle: bundle);
  }

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  const topicId = 35651;
  const forumUrl =
      'https://fractalsoftworks.com/forum/index.php?topic=$topicId.0';

  const firstPost = '<p>Computica\'s Faction Forks</p>'
      '<p>A rehabilitation project for older Starsector faction mods.</p>'
      '<p>Current forks: Kwin\'s Sector Industry Compilation, '
      'Farsight Drive, Valkyrians.</p>';

  const secondPost = '<p>Downloads</p>'
      '<p>Kwin\'s Sector Industry Compilation</p>'
      '<p>Adds four lore-rich corporations with unique ships, weapons and '
      'colony Charter Offices.</p>'
      '<a href="https://github.com/x/kwin.zip">Download</a>'
      '<p>Farsight Drive</p>'
      '<p>Brings a secretive Eridani biotech faction with living crystal '
      'ships and karma-driven hullmods.</p>'
      '<a href="https://github.com/x/farsight.zip">Download</a>'
      '<p>Valkyrians</p>'
      '<p>A translated and polished fork with new buildings.</p>'
      '<a href="https://github.com/x/valkyrians.zip">Download</a>';

  LlmMod fork(
    String name,
    String file, {
    String? startsWith,
    String? endsWith,
  }) =>
      LlmMod(
        name: name,
        role: LlmModRole.main,
        downloads: [
          LlmDownload(url: 'https://github.com/x/$file', kind: 'direct'),
        ],
        descriptionAnchors: startsWith == null || endsWith == null
            ? null
            : LlmDescriptionAnchors(startsWith: startsWith, endsWith: endsWith),
        extras: LlmExtras(
          summary: LlmModSummary(paragraph: 'An AI paragraph about $name.'),
        ),
      );

  /// The merge only knew about the umbrella thread, which is the real case:
  /// the forks were never announced on Discord, so nothing else saw them.
  ScrapedMod umbrellaMod() => ScrapedMod(
        name: 'Computica\'s Faction Forks',
        gameVersionReq: '0.98a',
        authorsList: const ['Computica'],
        sources: const [ModSource.Index],
        urls: const {ModUrlType.Forum: forumUrl},
      );

  QbModSummary threadWith(List<LlmMod> mods) => QbModSummary(
        topicId: topicId,
        title: 'Computica\'s Faction Forks - Updated 7/16/2026',
        gameVersion: '0.98a',
        author: 'Computica',
        topicUrl: forumUrl,
        llm: LlmThreadData(mods: mods),
      );

  QbModDetail detailWith({List<QbForumPost> extraPosts = const []}) =>
      QbModDetail(
        topicId: topicId,
        title: 'Computica\'s Faction Forks - Updated 7/16/2026',
        author: 'Computica',
        contentHtml: firstPost,
        extraPosts: extraPosts,
      );

  ForumDataBundle bundleWith(QbModSummary thread, QbModDetail detail) =>
      ForumDataBundle(
        updatedAt: DateTime.utc(2026, 8, 25),
        index: [thread],
        details: {'$topicId': detail},
        assumedDownloads: const <String, List<AssumedDownloadCandidate>>{},
      );

  group('a thread whose downloads are in the author\'s second post', () {
    test('each fork is published with the download tied to it', () async {
      final data = await buildViaCatalog(bundleWith(
          threadWith([
            fork('Kwin\'s Sector Industry Compilation', 'kwin.zip'),
            fork('Farsight Drive', 'farsight.zip'),
            fork('Valkyrians', 'valkyrians.zip'),
          ]),
          detailWith(extraPosts: [QbForumPost(contentHtml: secondPost)]),
        ),
      );

      final names = data.list.mods.map((m) => m.displayName ?? m.name).toList();
      expect(names, contains('Kwin\'s Sector Industry Compilation'));
      expect(names, contains('Farsight Drive'));
      expect(names, contains('Valkyrians'));

      final kwin = data.details.values.firstWhere(
          (d) => d.listing.name == 'Kwin\'s Sector Industry Compilation');
      expect(kwin.downloads.single.url, 'https://github.com/x/kwin.zip');
      expect(kwin.listing.partOfThreadTitle, isNotNull,
          reason: 'a mod made up from a thread says which thread');
    });

    test('without the second post nothing is published for the forks', () async {
      // What the site did before this change. The names are in the first post,
      // but the downloads are not, so the extractor grounded none of them and
      // every fork arrives here with an empty download list.
      final data = await buildViaCatalog(bundleWith(
          threadWith([
            LlmMod(name: 'Kwin\'s Sector Industry Compilation'),
            LlmMod(name: 'Farsight Drive'),
          ]),
          detailWith(),
        ),
      );

      final names = data.list.mods.map((m) => m.displayName ?? m.name).toList();
      expect(names, ['Computica\'s Faction Forks'],
          reason: 'no download is no page');
    });

    test('two forks make the thread a Collection, and the thread is no mod', () async {
      final data = await buildViaCatalog(bundleWith(
          threadWith([
            fork('Kwin\'s Sector Industry Compilation', 'kwin.zip'),
            fork('Farsight Drive', 'farsight.zip'),
          ]),
          detailWith(extraPosts: [QbForumPost(contentHtml: secondPost)]),
        ),
      );

      final names = data.list.mods.map((m) => m.displayName ?? m.name).toList();
      expect(names, unorderedEquals(['Kwin\'s Sector Industry Compilation', 'Farsight Drive']));
      // The shared post is nobody's description.
      for (final detail in data.details.values) {
        expect(detail.descriptionHtml ?? '', isNot(contains('A rehabilitation project')));
      }
    });

    test('a screenshot in the second post reaches the gallery', () async {
      final data = await buildViaCatalog(bundleWith(
          threadWith([fork('Kwin\'s Sector Industry Compilation', 'kwin.zip')]),
          QbModDetail(
            topicId: topicId,
            title: 'Computica\'s Faction Forks',
            author: 'Computica',
            contentHtml: firstPost,
            extraPosts: [
              QbForumPost(
                contentHtml: secondPost,
                images: [
                  ImageRef(
                      originalUrl: 'https://i.imgur.com/kwin-screenshot.png'),
                ],
              ),
            ],
          ),
        ),
      );

      final umbrella = data.details.values.first;
      expect(umbrella.gallery.map((g) => g.url),
          contains('https://i.imgur.com/kwin-screenshot.png'));
    });
  });

  group('each fork\'s own description', () {
    Future<PublicSiteData> buildWithAnchors() => buildViaCatalog(bundleWith(
            threadWith([
              fork(
                'Kwin\'s Sector Industry Compilation',
                'kwin.zip',
                startsWith: 'Adds four lore-rich corporations',
                endsWith: 'colony Charter Offices',
              ),
              fork(
                'Farsight Drive',
                'farsight.zip',
                startsWith: 'Brings a secretive Eridani biotech faction',
                endsWith: 'karma-driven hullmods',
              ),
              fork('Valkyrians', 'valkyrians.zip'),
            ]),
            detailWith(extraPosts: [QbForumPost(contentHtml: secondPost)]),
          ),
        );

    test('is the author\'s own paragraph, not the AI\'s', () async {
      final data = await buildWithAnchors();

      final kwin = data.details.values.firstWhere(
          (d) => d.listing.name == 'Kwin\'s Sector Industry Compilation');
      expect(kwin.description, contains('Adds four lore-rich corporations'));
      expect(kwin.description, contains('colony Charter Offices'));
      expect(kwin.descriptionIsGenerated, isFalse,
          reason: 'the words are the author\'s, only located by the model');
      expect(kwin.description, isNot(contains('An AI paragraph')));
    });

    test('does not carry a sibling\'s words', () async {
      final data = await buildWithAnchors();

      final kwin = data.details.values.firstWhere(
          (d) => d.listing.name == 'Kwin\'s Sector Industry Compilation');
      expect(kwin.description, isNot(contains('living crystal ships')));

      final farsight = data.details.values
          .firstWhere((d) => d.listing.name == 'Farsight Drive');
      expect(farsight.description, contains('living crystal ships'));
      expect(farsight.description, isNot(contains('lore-rich corporations')));
    });

    test('falls back to the AI paragraph when nothing was pointed at', () async {
      final data = await buildWithAnchors();

      final valkyrians = data.details.values
          .firstWhere((d) => d.listing.name == 'Valkyrians');
      expect(valkyrians.description, 'An AI paragraph about Valkyrians.');
      expect(valkyrians.descriptionIsGenerated, isTrue);
    });

    test('a summary from the second post keeps the full description', () async {
      final data = await buildViaCatalog(ForumDataBundle(
          updatedAt: DateTime.utc(2026, 8, 25),
          index: [
            QbModSummary(
              topicId: 9175,
              title: 'Nexerelin',
              author: 'Histidine',
              topicUrl:
                  'https://fractalsoftworks.com/forum/index.php?topic=9175.0',
              llm: LlmThreadData(mods: [
                fork(
                  'Nexerelin',
                  'nex.zip',
                  startsWith: 'Adds four lore-rich corporations',
                  endsWith: 'colony Charter Offices',
                ),
              ]),
            ),
          ],
          details: {
            '9175': QbModDetail(
              topicId: 9175,
              title: 'Nexerelin',
              author: 'Histidine',
              contentHtml: '<p>Adds diplomacy, invasions and much more.</p>',
              extraPosts: [QbForumPost(contentHtml: secondPost)],
            ),
          },
          assumedDownloads: const <String, List<AssumedDownloadCandidate>>{},
        ),
      );

      final nex = data.details.values.single;
      expect(nex.description, contains('Adds diplomacy, invasions'));
      expect(nex.description, isNot(contains('Adds four lore-rich corporations')));
      expect(nex.listing.summary, startsWith('Adds four lore-rich corporations'));
      expect(nex.listing.summaryIsGenerated, isFalse);
      expect(nex.descriptionIsGenerated, isFalse);
      expect(nex.aiDescription, 'An AI paragraph about Nexerelin.');
    });
  });
}
