import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:mod_repo_scraper/catalog/catalog_comparison.dart';
import 'package:mod_repo_scraper/catalog/listing.dart';
import 'package:mod_repo_scraper/catalog/mod_catalog.dart';
import 'package:mod_repo_scraper/catalog/source_post.dart';
import 'package:test/test.dart';

CatalogMod _mod(String id, String name, List<CatalogSourcePost> posts) =>
    CatalogMod(id: id, mod: ScrapedMod(name: name), sourcePosts: posts);

const _forum = SourceKind.forum;
const _discord = SourceKind.discord;

void main() {
  final catalog = ModCatalog(
    generatedAt: DateTime.utc(2026),
    mods: [
      _mod('nexerelin', 'Nexerelin', const [CatalogSourcePost(kind: _forum, id: '9175')]),
      _mod('brighton-federation', 'Brighton Federation', const [
        CatalogSourcePost(kind: _discord, id: '5'),
        CatalogSourcePost(kind: _forum, id: '13236'),
      ]),
      _mod('derelict-start', 'Derelict Start',
          const [CatalogSourcePost(kind: _forum, id: '34457', llmModName: 'Derelict Start', foundBy: ListingOrigin.llm)]),
      _mod('kwin', 'Kwin', const [CatalogSourcePost(kind: _discord, id: '7', llmModName: 'Kwin', foundBy: ListingOrigin.llm)]),
      _mod('farsight', 'Farsight', const [CatalogSourcePost(kind: _discord, id: '7', llmModName: 'Farsight', foundBy: ListingOrigin.llm)]),
    ],
    collections: [
      const CatalogCollection(
        id: 'derelict-starts',
        name: 'Derelict Starts',
        post: SourcePostRef(kind: _forum, id: '34457'),
        modIds: ['derelict-start'],
      ),
    ],
  );

  final published = [
    const PublishedPage(id: 'nexerelin', name: 'Nexerelin', forumTopic: '9175'),
    const PublishedPage(id: 'the-brighton-federation', name: 'The Brighton Federation', forumTopic: '13236'),
    const PublishedPage(id: 'derelict-starts', name: 'Derelict Starts', forumTopic: '34457'),
    const PublishedPage(id: 'gone', name: 'Gone', forumTopic: '1'),
    const PublishedPage(id: 'kwin', name: 'Kwin', forumTopic: '35651'),
  ];

  final comparison = compareCatalog(published: published, catalog: catalog);

  test('a published id with no mod and no Collection is missing, and blocks the switch', () {
    expect(comparison.missing.map((p) => p.id), containsAll(['gone', 'the-brighton-federation']));
    expect(comparison.blocksTheSwitch, isTrue);
  });

  test('a missing id whose post is now in another mod is said to be joined into it', () {
    expect(comparison.joinedInto['the-brighton-federation']?.id, 'brighton-federation');
    expect(comparison.joinedInto.containsKey('gone'), isFalse);
  });

  test('an id that is now a Collection page is listed apart from the missing ones', () {
    expect(comparison.becameCollections.single.$1.id, 'derelict-starts');
    expect(comparison.missing.map((p) => p.id), isNot(contains('derelict-starts')));
  });

  test('a mod that lost the forum topic its page had is listed', () {
    expect(comparison.postsChanged.map((e) => e.$1.id), ['kwin']);
  });

  test('new mods and Discord threads giving several mods are listed', () {
    expect(comparison.added.map((m) => m.id), containsAll(['brighton-federation', 'derelict-start', 'farsight']));
    expect(comparison.discordThreadsWithSeveral['7']?.map((m) => m.id), ['kwin', 'farsight']);
  });

  test('the report names every section', () {
    final report = comparison.toMarkdown();
    expect(report, contains('The switch is blocked'));
    expect(report, contains('joined into `brighton-federation`'));
  });
}
