import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/qb/models/assumed_download.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/forum_data_bundle.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
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

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('opening_posts');
    builder = PublicDataBuilder(
      outputPath: p.join(dir.path, 'outputs'),
      idStore: ModIdStore(p.join(dir.path, 'data'))..load(),
    );
  });

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
    test('each fork is published with the download tied to it', () {
      final data = builder.build(
        mods: [umbrellaMod()],
        bundle: bundleWith(
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

    test('without the second post nothing is published for the forks', () {
      // What the site did before this change. The names are in the first post,
      // but the downloads are not, so the extractor grounded none of them and
      // every fork arrives here with an empty download list.
      final data = builder.build(
        mods: [umbrellaMod()],
        bundle: bundleWith(
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

    test('the umbrella mod keeps the first post as its description', () {
      final data = builder.build(
        mods: [umbrellaMod()],
        bundle: bundleWith(
          threadWith([
            fork('Kwin\'s Sector Industry Compilation', 'kwin.zip'),
            fork('Farsight Drive', 'farsight.zip'),
          ]),
          detailWith(extraPosts: [QbForumPost(contentHtml: secondPost)]),
        ),
      );

      final umbrella = data.details.values
          .firstWhere((d) => d.listing.name == 'Computica\'s Faction Forks');
      expect(umbrella.descriptionHtml, isNot(contains('Adds four lore-rich')),
          reason: 'the shared post is nobody\'s description');
    });

    test('a screenshot in the second post reaches the gallery', () {
      final data = builder.build(
        mods: [umbrellaMod()],
        bundle: bundleWith(
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
    PublicSiteData buildWithAnchors() => builder.build(
          mods: [umbrellaMod()],
          bundle: bundleWith(
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

    test('is the author\'s own paragraph, not the AI\'s', () {
      final data = buildWithAnchors();

      final kwin = data.details.values.firstWhere(
          (d) => d.listing.name == 'Kwin\'s Sector Industry Compilation');
      expect(kwin.description, contains('Adds four lore-rich corporations'));
      expect(kwin.description, contains('colony Charter Offices'));
      expect(kwin.descriptionIsGenerated, isFalse,
          reason: 'the words are the author\'s, only located by the model');
      expect(kwin.description, isNot(contains('An AI paragraph')));
    });

    test('does not carry a sibling\'s words', () {
      final data = buildWithAnchors();

      final kwin = data.details.values.firstWhere(
          (d) => d.listing.name == 'Kwin\'s Sector Industry Compilation');
      expect(kwin.description, isNot(contains('living crystal ships')));

      final farsight = data.details.values
          .firstWhere((d) => d.listing.name == 'Farsight Drive');
      expect(farsight.description, contains('living crystal ships'));
      expect(farsight.description, isNot(contains('lore-rich corporations')));
    });

    test('falls back to the AI paragraph when nothing was pointed at', () {
      final data = buildWithAnchors();

      final valkyrians = data.details.values
          .firstWhere((d) => d.listing.name == 'Valkyrians');
      expect(valkyrians.description, 'An AI paragraph about Valkyrians.');
      expect(valkyrians.descriptionIsGenerated, isTrue);
    });

    test('a mod on a thread of its own still gets the whole post', () {
      final data = builder.build(
        mods: [
          ScrapedMod(
            name: 'Nexerelin',
            gameVersionReq: '0.98a',
            authorsList: const ['Histidine'],
            sources: const [ModSource.Index],
            urls: const {
              ModUrlType.Forum:
                  'https://fractalsoftworks.com/forum/index.php?topic=9175.0',
            },
          ),
        ],
        bundle: ForumDataBundle(
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
      expect(nex.description, contains('Adds diplomacy, invasions'),
          reason: 'a single-mod thread publishes its first post, anchors or no');
    });
  });
}
