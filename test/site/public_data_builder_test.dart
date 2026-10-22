import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/mod_merger.dart';
import 'package:mod_repo_scraper/catalog/catalog_inputs.dart';
import 'package:mod_repo_scraper/catalog/discord_posts.dart';
import 'package:mod_repo_scraper/catalog/forum_listing.dart';
import 'package:mod_repo_scraper/catalog/listing.dart';
import 'package:mod_repo_scraper/catalog/mod_catalog.dart';
import 'package:mod_repo_scraper/catalog/other_listings.dart';
import 'package:mod_repo_scraper/catalog/source_post.dart';
import 'package:mod_repo_scraper/catalog/source_post_listings.dart';
import 'package:mod_repo_scraper/site/mod_name_match.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/picture_caption_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/assumed_download.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/forum_data_bundle.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:mod_repo_scraper/site/mod_id_store.dart';
import 'package:mod_repo_scraper/site/models/public_mod.dart';
import 'package:mod_repo_scraper/site/post_html.dart';
import 'package:mod_repo_scraper/site/public_data_builder.dart';
import 'package:mod_repo_scraper/site/release_state_store.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;
  late ModIdStore idStore;
  late PublicDataBuilder builder;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('public_site');
    idStore = ModIdStore(p.join(dir.path, 'data'))..load();
    builder = PublicDataBuilder(
      outputPath: p.join(dir.path, 'outputs'),
      idStore: idStore,
    );
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// A merged mod with a forum thread, as the ModRepo pipeline produces one.
  ScrapedMod forumMod({
    String name = 'Nexerelin',
    int topicId = 9175,
    String? summary = 'Adds diplomacy and invasions.',
    String? description,
    Map<String, Image> images = const {},
    List<String> authors = const ['Histidine'],
  }) =>
      ScrapedMod(
        name: name,
        description: description,
        summary: summary,
        images: images,
        gameVersionReq: '0.98a',
        authorsList: authors,
        categories: const ['Total Conversions'],
        sources: const [ModSource.Index],
        urls: {
          ModUrlType.Forum:
              'https://fractalsoftworks.com/forum/index.php?topic=$topicId.0',
        },
      );

  /// One thread in the bundle, with whatever the LLM found on it.
  QbModSummary thread({
    int topicId = 9175,
    String title = '[0.98a] Nexerelin v0.12.2',
    List<LlmMod> llmMods = const [],
    bool isWip = false,
    String? createdDate,
    String? lastPostDate,
    String author = 'Histidine',
  }) =>
      QbModSummary(
        topicId: topicId,
        title: title,
        gameVersion: '0.98a',
        author: author,
        createdDate: createdDate,
        lastPostDate: lastPostDate,
        topicUrl:
            'https://fractalsoftworks.com/forum/index.php?topic=$topicId.0',
        isWip: isWip,
        llm: llmMods.isEmpty ? null : LlmThreadData(mods: llmMods),
      );

  ForumDataBundle bundleOf({
    List<QbModSummary> index = const [],
    Map<String, QbModDetail> details = const {},
    Map<String, List<AssumedDownloadCandidate>> downloads = const {},
  }) =>
      ForumDataBundle(
        updatedAt: DateTime.utc(2026, 8, 18),
        index: index,
        details: details,
        assumedDownloads: downloads,
      );

  /// What the catalog makes of merged mods on threads of one mod each: the
  /// mod's own id, and a forum link naming the LLM mod its facts are read
  /// from — the one with its name, else the thread's only main mod, else its
  /// only mod. The listing step's own rules are tested in
  /// `test/catalog/source_post_listings_test.dart`; these tests are about what
  /// a page shows once the catalog has said which mod is which.
  List<CatalogMod> catalogOf(List<ScrapedMod> mods, {ForumDataBundle? bundle, ModIdStore? ids}) {
    final store = ids ?? idStore;
    final threads = {for (final t in bundle?.index ?? const <QbModSummary>[]) '${t.topicId}': t};
    String? llmNameFor(ScrapedMod mod, QbModSummary? thread) {
      final llmMods = thread?.llm?.mods ?? const <LlmMod>[];
      for (final candidate in llmMods) {
        if (modNamesMatch(candidate.name, mod.name)) return candidate.name;
      }
      final mains = [for (final m in llmMods) if (m.role == LlmModRole.main) m];
      if (mains.length == 1) return mains.single.name;
      if (mains.isEmpty && llmMods.length == 1) return llmMods.single.name;
      return null;
    }

    return [
      for (final mod in mods)
        () {
          final topicId = ModMerger.extractForumTopicId(mod.getUrls()[ModUrlType.Forum]);
          final threadId = discordThreadIdOf(mod.getUrls()[ModUrlType.Discord]);
          final nexusId = nexusIdOf(mod.getUrls()[ModUrlType.NexusMods]);
          return CatalogMod(
            id: store.idFor(mod.name, mark: PublicDataBuilder.markFor(mod, topicId)),
            mod: mod,
            sourcePosts: [
              if (topicId != null)
                CatalogSourcePost(
                  kind: SourceKind.forum,
                  id: topicId,
                  llmModName: llmNameFor(mod, threads[topicId]),
                ),
              if (threadId != null) CatalogSourcePost(kind: SourceKind.discord, id: threadId),
              if (nexusId != null) CatalogSourcePost(kind: SourceKind.nexus, id: nexusId),
            ],
          );
        }(),
    ];
  }

  /// [PublicDataBuilder.build] over [catalogOf] the given merged mods.
  PublicSiteData buildFrom({
    required List<ScrapedMod> mods,
    ForumDataBundle? bundle,
    List<ThreadRelease> threadReleases = const [],
    DiscordPostsFile discordPosts = const DiscordPostsFile(),
    DateTime? generatedAt,
  }) =>
      builder.build(
        mods: catalogOf(mods, bundle: bundle),
        bundle: bundle,
        threadReleases: threadReleases,
        discordPosts: discordPosts,
        generatedAt: generatedAt,
      );

  /// Builds the site the way a real run does: each thread in [bundle] and each
  /// of [discordMods] turned into listings, merged into a catalog with ids, and
  /// the site built from that.
  Future<PublicSiteData> buildThroughCatalog({
    required ForumDataBundle bundle,
    List<ScrapedMod> discordMods = const [],
    List<ThreadRelease> threadReleases = const [],
  }) async {
    final listings = <Listing>[];
    final collections = <Listing>[];
    for (final thread in bundle.index) {
      final detail = bundle.details['${thread.topicId}'];
      final words = SourcePostListings.openingRunWords(
        detail == null
            ? SourcePost(kind: SourceKind.forum, id: '${thread.topicId}', title: thread.title)
            : SourcePost.fromForumDetail(detail).copyWith(title: thread.title),
      );
      final result = SourcePostListings.combine(
        rules: forumRulesListing(thread),
        llmMods: thread.llm?.mods ?? const [],
        postWords: words,
      );
      listings.addAll(result.listings);
      if (result.collection != null) collections.add(result.collection!);
    }
    for (final mod in discordMods) {
      listings.add(discordRulesListing(mod)!);
    }
    final catalog = await ModCatalog.build(
      inputs: CatalogListings(listings: listings, collections: collections),
      ids: idStore,
    );
    return builder.build(
      mods: catalog.mods,
      collections: catalog.collections,
      bundle: bundle,
      threadReleases: threadReleases,
    );
  }

  QbModDetail postOf(String contentHtml,
          {int topicId = 9175,
          List<ImageRef> images = const [],
          String? avatarPath}) =>
      QbModDetail(
        topicId: topicId,
        title: '[0.98a] Nexerelin v0.12.2',
        author: 'Histidine',
        authorAvatarPath: avatarPath,
        contentHtml: contentHtml,
        images: images,
      );

  group('clipped author summaries', () {
    const opening = 'Lets you pour credits, materials and story points';
    const ending = 'slot rare augments with effects of their own';
    const firstSentence = 'Lets you pour credits, materials and story points '
        'into the ships you love, until they are as overpowered as you can afford.';
    const aiSentence = 'Upgrades player ships using credits, materials and story points.';
    const aiParagraph = 'Upgrades player ships using credits, materials and story points. '
        'Friendly spaceports offer upgrade bays, hull improvements and rare augments.';

    test('Extra Systems keeps its full description and both summaries', () {
      final post = QbModDetailMapper.fromJson(
          File('test/llm_live/posts/36143.json').readAsStringSync());
      final data = buildFrom(
        mods: [
          forumMod(
            name: 'Extra Systems Reloaded',
            topicId: 36143,
            summary: 'An old announcement.',
            description: 'An old description.',
          ),
        ],
        bundle: bundleOf(
          index: [
            thread(topicId: 36143, llmMods: [
              LlmMod(
                name: 'Extra Systems Reloaded',
                descriptionAnchors: LlmDescriptionAnchors(
                    startsWith: opening, endsWith: ending),
                extras: LlmExtras(
                  summary: LlmModSummary(
                    sentence: aiSentence,
                    paragraph: aiParagraph,
                  ),
                ),
              ),
            ]),
          ],
          details: {'36143': post},
        ),
      );
      final detail = data.details.values.single;
      expect(detail.description, contains(firstSentence));
      expect(detail.description, contains(ending));
      expect(detail.description, contains('WHAT DOES THIS MOD DO?'));
      expect(detail.description, contains('Requires LunaLib'));
      expect(detail.description, contains('FAQ'));
      expect(detail.description, contains('Credits'));
      expect(detail.descriptionHtml, cleanPostHtml(post.contentHtml));
      expect(detail.description, plainWordsOf(detail.descriptionHtml));
      expect(detail.descriptionIsGenerated, isFalse);
      expect(detail.aiDescription, aiParagraph);
      // The opening sentences of the paragraph the anchors point at.
      expect(detail.listing.summary,
          '$firstSentence Only your ships. Enemy fleets never get any of it.');
      expect(detail.listing.summaryIsGenerated, isFalse);
      expect(detail.listing.aiSummary, aiSentence);
    });

    for (final anchors in [
      null,
      LlmDescriptionAnchors(
        startsWith: 'Words nobody wrote here',
        endsWith: 'Another invented ending',
      ),
    ]) {
      test(
          'keeps the full single-mod post with '
          '${anchors == null ? 'no' : 'invalid'} anchors', () {
        final data = buildFrom(
          mods: [forumMod(summary: null)],
          bundle: bundleOf(
            index: [
              thread(llmMods: [
                LlmMod(
                  name: 'Nexerelin',
                  descriptionAnchors: anchors,
                  extras: LlmExtras(
                    summary: LlmModSummary(
                      sentence: 'Adds diplomacy.',
                      paragraph: 'Adds diplomacy and invasions.',
                    ),
                  ),
                ),
              ]),
            ],
            details: {'9175': postOf('<p>The complete author post.</p>')},
          ),
        );
        final detail = data.details.values.single;
        expect(detail.description, 'The complete author post.');
        expect(detail.descriptionHtml, '<p>The complete author post.</p>');
        expect(detail.descriptionIsGenerated, isFalse);
        expect(detail.aiDescription, 'Adds diplomacy and invasions.');
        expect(detail.listing.summary, 'Adds diplomacy.');
        expect(detail.listing.aiSummary, 'Adds diplomacy.');
        expect(detail.listing.summaryIsGenerated, isTrue);
      });
    }
  });

  test('the name a reader sees has the thread-title noise taken off it', () {
    final data = buildFrom(
      mods: [forumMod(name: '[0.98a] Nexerelin v0.12.2')],
      bundle: bundleOf(),
    );

    final mod = data.list.mods.single;
    expect(mod.displayName, 'Nexerelin');
    expect(mod.name, '[0.98a] Nexerelin v0.12.2',
        reason: 'the title as written is still published, so a search for an '
            'old spelling finds the mod');
  });

  group('other names the post uses', () {
    test('are published for the search', () {
      final data = buildFrom(
        mods: [forumMod()],
        bundle: bundleOf(index: [
          thread(llmMods: [
            LlmMod(name: 'Nexerelin', nicknames: ['Nex', 'Exerelin']),
          ]),
        ]),
      );

      expect(data.list.mods.single.nicknames, ['Nex', 'Exerelin']);
    });

    test('leave out one that is only a name the mod already has', () {
      final data = buildFrom(
        mods: [forumMod()],
        bundle: bundleOf(index: [
          thread(llmMods: [
            LlmMod(name: 'Nexerelin', nicknames: ['NEXERELIN', 'Nex']),
          ]),
        ]),
      );

      expect(data.list.mods.single.nicknames, ['Nex']);
    });

    test('are left out entirely when there are none', () {
      final data = buildFrom(
        mods: [forumMod()],
        bundle: bundleOf(index: [
          thread(llmMods: [LlmMod(name: 'Nexerelin')]),
        ]),
      );

      final mod = data.list.mods.single;
      expect(mod.nicknames, isNull);
      expect(mod.toMap().containsKey('nicknames'), isFalse,
          reason: 'mods.json is fetched whole, so a field most mods would '
              'carry empty is not written');
    });
  });

  group('what the author says about AI use', () {
    PublicSiteData withAiUse(LlmAiUse? aiUse) => buildFrom(
          mods: [forumMod()],
          bundle: bundleOf(index: [
            thread(llmMods: [
              LlmMod(name: 'Nexerelin', extras: LlmExtras(aiUse: aiUse)),
            ]),
          ]),
        );

    test('AI use is published once per use, in order of area', () {
      final aiUse = LlmAiUse(
        quote: 'Portraits and code were made with AI.',
        usesAi: true,
        uses: [
          LlmAiUseEntry(area: AiUseArea.portraits, how: AiUseHow.edited),
          LlmAiUseEntry(area: AiUseArea.code, how: AiUseHow.assisted),
          LlmAiUseEntry(
            area: AiUseArea.portraits,
            how: AiUseHow.generated,
            extent: AiUseExtent.some,
            optional: true,
          ),
          LlmAiUseEntry(area: AiUseArea.code, how: AiUseHow.assisted),
        ],
        tools: ['ChatGPT'],
      );
      final data = withAiUse(aiUse);

      final mod = data.list.mods.single;
      expect(mod.usesAi, isTrue);
      expect(mod.aiUses!.map((use) => use.toMap()), [
        {'area': 'code', 'how': 'assisted'},
        {'area': 'portraits', 'how': 'edited'},
        {'area': 'portraits', 'how': 'generated', 'optional': true},
      ], reason: 'the filter reads how and optional, but never the amount');
      expect(data.details.values.single.aiUse, aiUse,
          reason: "the mod's own file carries the quote and the tools");
    });

    test('a no-AI statement is published with no areas', () {
      final data =
          withAiUse(LlmAiUse(quote: 'No AI Generation.', usesAi: false));

      final mod = data.list.mods.single;
      expect(mod.usesAi, isFalse);
      expect(mod.toMap().containsKey('aiUses'), isFalse);
      expect(data.details.values.single.aiUse!.quote, 'No AI Generation.');
    });

    test('a post read for AI use that says nothing is published as not stated',
        () {
      final data = withAiUse(LlmAiUse.notStated());

      final mod = data.list.mods.single;
      expect(mod.toMap().containsKey('usesAi'), isFalse);
      expect(mod.toMap().containsKey('aiUses'), isFalse);
      expect(data.details.values.single.toMap()['aiUse'], <String, dynamic>{},
          reason: "the mod's own file says the post was read, so the page can "
              'tell it from a post not read for this yet');
    });

    test('a post not read for AI use yet writes no field at all', () {
      final data = withAiUse(null);

      final mod = data.list.mods.single;
      expect(mod.toMap().containsKey('usesAi'), isFalse,
          reason: 'unknown is never written as false');
      expect(mod.toMap().containsKey('aiUses'), isFalse);
      expect(data.details.values.single.aiUse, isNull);
    });
  });

  group('a program run beside the game', () {
    test('is marked as a tool and shelved under Utilities', () {
      final data = buildFrom(
        mods: [
          forumMod(name: 'MOSS').copyWith(categories: ['Faction Mods']),
        ],
        bundle: bundleOf(index: [
          thread(llmMods: [LlmMod(name: 'MOSS', isTool: true)]),
        ]),
      );

      final mod = data.list.mods.single;
      expect(mod.isTool, isTrue);
      expect(mod.categories, ['Factions', 'Utilities'],
          reason: 'the sources filed it elsewhere; it is added to Utilities '
              'beside the mod managers the forum shelves there, and keeps '
              'what it already had');
    });

    test('an ordinary mod carries no tool field at all', () {
      final data = buildFrom(
        mods: [forumMod().copyWith(categories: ['Faction Mods'])],
        bundle: bundleOf(index: [
          thread(llmMods: [LlmMod(name: 'Nexerelin')]),
        ]),
      );

      final mod = data.list.mods.single;
      expect(mod.isTool, isNull);
      expect(mod.toMap().containsKey('isTool'), isFalse,
          reason: 'mods.json is fetched whole, so a field every mod would '
              'carry as false is not written');
      expect(mod.categories, ['Factions']);
    });
  });

  test('a name that needs no tidying is not published twice', () {
    final data =
        buildFrom(mods: [forumMod(name: 'Nexerelin')], bundle: bundleOf());
    expect(data.list.mods.single.displayName, isNull);
  });

  group("the LLM's name for the mod", () {
    const seaOfStars = 'Sea of Stars 0.5.1 - Go Beyond the Persean Sector';

    PublicMod builtWith(String title, List<LlmMod> llmMods) => buildFrom(
          mods: [forumMod(name: title, topicId: 36134)],
          bundle: bundleOf(index: [
            thread(topicId: 36134, title: title, llmMods: llmMods),
          ]),
        )
        .list
        .mods
        .single;

    test('is shown where it agrees with a title the rules cannot take apart',
        () {
      // A bare version in the middle, with a subtitle after it: the rules
      // leave this title whole.
      final mod = builtWith(seaOfStars, [LlmMod(name: 'Sea of Stars')]);
      expect(mod.displayName, 'Sea of Stars');
      expect(mod.name, seaOfStars);
    });

    test('loses any version the model left on it', () {
      final mod = builtWith(seaOfStars, [LlmMod(name: 'Sea of Stars v0.5.1')]);
      expect(mod.displayName, 'Sea of Stars');
    });

    test('is not shown where it is a different name from the title', () {
      // The thread's one main mod, so its facts are this mod's, but "Red" is
      // not a tidier spelling of "Red - the Oculian Armada".
      final mod = builtWith('Red - the Oculian Armada (0.10.2-RC4) Mod', [
        LlmMod(name: 'Red', role: LlmModRole.main),
      ]);
      expect(mod.displayName, isNot('Red'));
    });

    test('is not needed where the rules already give the name', () {
      final mod = builtWith('[0.98a] Nexerelin v0.12.2', [
        LlmMod(name: 'Nexerelin'),
      ]);
      expect(mod.displayName, 'Nexerelin');
    });

    test('uses the shown name in Requires links', () {
      final data = buildFrom(
        mods: [
          forumMod(name: seaOfStars, topicId: 36134),
          forumMod(name: 'Addon Mod', topicId: 2),
        ],
        bundle: bundleOf(index: [
          thread(
              topicId: 36134,
              title: seaOfStars,
              llmMods: [LlmMod(name: 'Sea of Stars')]),
          thread(topicId: 2, title: 'Addon Mod', llmMods: [
            LlmMod(
              name: 'Addon Mod',
              extras: LlmExtras(needs: ['Sea of Stars']),
            ),
          ]),
        ]),
      );
      final addon = data.details.values
          .firstWhere((d) => d.listing.name == 'Addon Mod');
      expect(addon.listing.needs.map((n) => n.name), contains('Sea of Stars'));
    });
  });

  group('a catalog newer than the bundle', () {
    /// The warnings [run] logs.
    List<String> warningsWhile(void Function() run) {
      final warnings = <String>[];
      final oldLevel = Logger.root.level;
      Logger.root.level = Level.ALL;
      final listening = Logger.root.onRecord.listen((r) {
        if (r.level >= Level.WARNING) warnings.add(r.message);
      });
      try {
        run();
      } finally {
        listening.cancel();
        Logger.root.level = oldLevel;
      }
      return warnings;
    }

    List<String> buildNaming(String nameInCatalog, String nameInBundle) => warningsWhile(() {
          final mod = forumMod(name: 'Peenemunde', topicId: 12535);
          builder.build(
            mods: [
              CatalogMod(
                id: 'peenemunde',
                mod: mod,
                sourcePosts: [CatalogSourcePost(kind: SourceKind.forum, id: '12535', llmModName: nameInCatalog)],
              ),
            ],
            bundle: bundleOf(index: [
              thread(topicId: 12535, title: 'Peenemunde', llmMods: [LlmMod(name: nameInBundle)]),
            ]),
          );
        });

    test('is said when a mod names an LLM answer the bundle does not have', () {
      final warnings = buildNaming('Peenemunde Mobile Battlestation', 'BSP Peenemunde');
      expect(warnings.where((w) => w.contains('forum:12535#Peenemunde Mobile Battlestation')), hasLength(1));
    });

    test('says nothing when the two agree', () {
      final warnings = buildNaming('BSP Peenemunde', 'BSP Peenemunde');
      expect(warnings.where((w) => w.contains('LLM answer')), isEmpty);
    });
  });

  test('the list is in order of the name a reader sees, not the raw title', () {
    final data = buildFrom(
      mods: [
        forumMod(name: 'Zebra Mod', topicId: 1),
        forumMod(name: '- Starter Pack v1.1.3', topicId: 2),
        forumMod(name: '[0.98a] Aardvark', topicId: 3),
      ],
      bundle: bundleOf(),
    );

    expect(data.list.mods.map((m) => m.displayName ?? m.name),
        ['Aardvark', 'Starter Pack', 'Zebra Mod']);
  });

  test('the release feed uses the tidied name too', () {
    final data = buildFrom(
      mods: [forumMod(name: '[0.98a] Nexerelin v0.12.2')],
      bundle: bundleOf(),
      threadReleases: [
        const ThreadRelease(
          topicId: 9175,
          modName: '[0.98a] Nexerelin v0.12.2',
          seenOn: '2026-08-14',
          newVersion: '0.12.2',
        ),
      ],
    );

    expect(data.feed.releases.single.modName, 'Nexerelin');
  });

  test('the description is the forum post, kept formatted and made safe', () {
    final data = buildFrom(
      mods: [
        forumMod(
          name: 'Nexerelin',
          description: 'Discord: 4X in Starsector. Download: https://x/y',
        ),
      ],
      bundle: bundleOf(
        index: [thread()],
        details: {
          '9175': postOf('<p>A campaign <b>overhaul</b>.</p>'
              '<script>alert(1)</script>'),
        },
      ),
    );

    final detail = data.details['nexerelin']!;
    expect(detail.descriptionHtml, '<p>A campaign <b>overhaul</b>.</p>');
    expect(detail.description, 'A campaign overhaul.');
    expect(detail.descriptionIsGenerated, isFalse);
  });

  test('a mod with no forum post falls back to the text the merge had', () {
    final discordOnly = ScrapedMod(
      name: 'Quality Captains',
      description: 'Officers gain skills you choose.',
      authorsList: const ['Sundog'],
      sources: const [ModSource.Discord],
      urls: const {ModUrlType.Discord: 'https://discord.com/channels/1/2'},
    );

    final detail = buildFrom(
        mods: [discordOnly], bundle: bundleOf()).details['quality-captains']!;
    expect(detail.description, 'Officers gain skills you choose.');
    expect(detail.descriptionHtml, '<p>Officers gain skills you choose.</p>');
    expect(detail.descriptionIsGenerated, isFalse);
  });

  test('the Discord post is published beside the forum post, markdown read', () {
    final mod = ScrapedMod(
      name: 'Nexerelin',
      description: 'Discord: 4X in Starsector.',
      gameVersionReq: '0.98a',
      authorsList: const ['Histidine'],
      sources: const [ModSource.Index, ModSource.Discord],
      urls: const {
        ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=9175.0',
        ModUrlType.Discord: 'https://discord.com/channels/1/2/3',
      },
    );

    final detail = buildFrom(
      mods: [mod],
      bundle: bundleOf(
        index: [thread()],
        details: {'9175': postOf('<p>A campaign overhaul.</p>')},
      ),
      discordPosts: const DiscordPostsFile(threads: {
        '2': DiscordThreadPost(threadId: '2', messages: [
          DiscordOpeningMessage(id: '3', content: '**4X** in Starsector.\n- Invade\n- Trade'),
        ]),
      }),
    ).details['nexerelin']!;

    expect(detail.descriptionIsForumPost, isTrue);
    expect(detail.descriptionHtml, '<p>A campaign overhaul.</p>');
    expect(detail.discordPostHtml,
        '<p><strong>4X</strong> in Starsector.</p><ul><li>Invade</li><li>Trade</li></ul>');
  });

  test('a description that is only the Discord post again is not shown twice', () {
    final discordOnly = ScrapedMod(
      name: 'Quality Captains',
      description: 'Officers gain skills you choose.',
      authorsList: const ['Sundog'],
      sources: const [ModSource.Discord],
      urls: const {ModUrlType.Discord: 'https://discord.com/channels/1/2'},
    );

    final detail = buildFrom(
      mods: [discordOnly],
      bundle: bundleOf(),
      // Still read from a file written the old way, filed under the link.
      discordPosts: const DiscordPostsFile(legacyTexts: {
        'https://discord.com/channels/1/2': 'Officers gain  skills you choose.',
      }),
    ).details['quality-captains']!;

    expect(detail.descriptionIsForumPost, isFalse);
    expect(detail.description, isNull);
    expect(detail.discordPostHtml, '<p>Officers gain  skills you choose.</p>');
  });

  test('a Discord-only mod publishes the link its announcement carried', () {
    // Before this, every download came off a forum thread, so a mod announced
    // only on Discord reached the site with no download button while its link
    // sat unread in ModRepo.json. The Astartes Minipack is the real case.
    final discordOnly = ScrapedMod(
      name: 'Astartes Minipack',
      authorsList: const ['woetothee'],
      sources: const [ModSource.Discord],
      urls: const {
        ModUrlType.Discord: 'https://discord.com/channels/1/2/3',
        ModUrlType.DirectDownload:
            'https://drive.google.com/file/d/1ANiXX8vidc9fZZAhuo2/view?usp=sharing',
      },
    );

    final built = buildFrom(mods: [discordOnly], bundle: bundleOf());
    final listing = built.list.mods.firstWhere((m) => m.id == 'astartes-minipack');

    expect(listing.downloadCount, 1);
    expect(listing.bestDownload!.url,
        'https://drive.google.com/file/d/1ANiXX8vidc9fZZAhuo2/view?usp=sharing');
    // Drive's preview page is a page, so the button must say so — and the
    // browse page's "goes straight to a file" switch must not claim it.
    expect(listing.bestDownload!.needsAnotherStep, isTrue);
    expect(listing.hasDirectDownload, isFalse);

    final detail = built.details['astartes-minipack']!;
    expect(detail.downloads.single.host, 'Google Drive');
  });

  test('a Discord download page that is really the forum thread is dropped',
      () {
    final discordOnly = ScrapedMod(
      name: 'Aegis Combat System',
      authorsList: const ['someone'],
      sources: const [ModSource.Discord],
      urls: const {
        ModUrlType.Discord: 'https://discord.com/channels/1/2/3',
        ModUrlType.Forum:
            'https://fractalsoftworks.com/forum/index.php?topic=25807',
        ModUrlType.DownloadPage:
            'https://fractalsoftworks.com/forum/index.php?topic=25807',
      },
    );

    final built = buildFrom(mods: [discordOnly], bundle: bundleOf());
    final listing =
        built.list.mods.firstWhere((m) => m.id == 'aegis-combat-system');

    // The honest "On the forum" button, not a "Download page" one that opens
    // the same thread.
    expect(listing.downloadCount, 0);
    expect(listing.bestDownload, isNull);
    expect(listing.forumUrl,
        'https://fractalsoftworks.com/forum/index.php?topic=25807');
  });

  test("a forum thread's own downloads still win over the announcement's", () {
    final both = ScrapedMod(
      name: 'Nexerelin',
      authorsList: const ['Histidine'],
      sources: const [ModSource.Index, ModSource.Discord],
      urls: const {
        ModUrlType.Forum:
            'https://fractalsoftworks.com/forum/index.php?topic=9175.0',
        ModUrlType.DirectDownload: 'https://example.com/from-discord.zip',
      },
    );

    final built = buildFrom(
      mods: [both],
      bundle: bundleOf(
        index: [thread()],
        downloads: {
          '9175': [
            AssumedDownloadCandidate(
              originalUrl: 'https://example.com/from-the-thread.zip',
              resolvedDirectUrl: 'https://example.com/from-the-thread.zip',
            ),
          ],
        },
      ),
    );

    final listing = built.list.mods.firstWhere((m) => m.id == 'nexerelin');
    expect(listing.bestDownload!.url,
        'https://example.com/from-the-thread.zip');
    expect(listing.downloadCount, 1);
  });

  test('the gallery marks buttons, badges and tiny pictures as small', () {
    const post = '<p>Look</p>'
        '<img src="https://i.imgur.com/shot.png" width="900">'
        '<img src="https://ko-fi.com/img/donate.png">'
        '<img src="https://i.imgur.com/tiny.png" width="88">'
        '<img src="https://fractalsoftworks.com/forum/Smileys/default/smiley.gif">';

    final data = buildFrom(
      mods: [forumMod(name: 'Nexerelin')],
      bundle: bundleOf(index: [
        thread()
      ], details: {
        '9175': postOf(post, images: [
          ImageRef(originalUrl: 'https://i.imgur.com/shot.png'),
          ImageRef(originalUrl: 'https://ko-fi.com/img/donate.png'),
          ImageRef(originalUrl: 'https://i.imgur.com/tiny.png'),
          ImageRef(
              originalUrl:
                  'https://fractalsoftworks.com/forum/Smileys/default/smiley.gif'),
          ImageRef(originalUrl: 'https://i.imgur.com/no-size.png'),
        ]),
      }),
    );

    final detail = data.details['nexerelin']!;
    // The forum's own smiley is not the author's, so it is left out entirely.
    expect(detail.gallery.map((i) => i.url), [
      'https://i.imgur.com/shot.png',
      'https://ko-fi.com/img/donate.png',
      'https://i.imgur.com/tiny.png',
      'https://i.imgur.com/no-size.png',
    ]);
    expect(detail.gallery.map((i) => i.small), [null, true, true, null]);
    // A screenshot carries no `small` field at all.
    expect(detail.gallery.first.toMap().containsKey('small'), isFalse);
  });

  test(
      'the card picture is the post\'s, and the announcement one rides beside '
      'it', () {
    // The picture the LLM found in the author's forum post leads, because it
    // is the one the author put at the top of their own thread; a Discord
    // picture is whatever was attached to an announcement. This is where the
    // site parts company with TriOS's catalog, which takes the merged picture
    // first — so both are published and the reader's setting picks.
    final withBoth = buildFrom(
      mods: [
        forumMod(images: const {
          '1': Image(id: '1', url: 'https://i.imgur.com/merged.png'),
        }),
      ],
      bundle: bundleOf(index: [
        thread(
            llmMods: [LlmMod(name: 'Nexerelin', image: 'ext:https://x/l.png')]),
      ], details: {
        '9175': postOf('<p>Look</p>', avatarPath: 'avatars/histidine.png'),
      }),
    );
    expect(withBoth.list.mods.single.imageUrl, 'https://x/l.png');
    expect(withBoth.list.mods.single.announcementImageUrl,
        'https://i.imgur.com/merged.png');

    // One picture and no other: the announcement field is left out, because
    // the same address twice would only make mods.json bigger.
    final withLlm = buildFrom(
      mods: [forumMod()],
      bundle: bundleOf(index: [
        thread(
            llmMods: [LlmMod(name: 'Nexerelin', image: 'ext:https://x/l.png')]),
      ], details: {
        '9175': postOf('<p>Look</p>', avatarPath: 'avatars/histidine.png'),
      }),
    );
    expect(withLlm.list.mods.single.imageUrl, 'https://x/l.png');
    expect(withLlm.list.mods.single.announcementImageUrl, isNull);

    // Neither: the author's forum avatar stands in.
    final withAvatar = buildFrom(
      mods: [forumMod()],
      bundle: bundleOf(index: [
        thread()
      ], details: {
        '9175': postOf('<p>Look</p>', avatarPath: 'avatars/histidine.png'),
      }),
    );
    expect(withAvatar.list.mods.single.imageUrl,
        'https://fractalsoftworks.com/forum/avatars/histidine.png',
        reason: 'an avatar path is written relative to the forum');
  });

  group("the post's own pictures", () {
    const banner = 'https://i.imgur.com/7k1QAas.png';
    const discordIcon = 'https://cdn.discordapp.com/attachments/1/2/mod_post_icon_indevo.png?ex=6ad88799';
    final postPictures = [
      ImageRef(originalUrl: 'https://trilink.wispborne.com/badges/install-badge-forthebadge.svg'),
      ImageRef(originalUrl: banner),
      ImageRef(originalUrl: 'https://i.imgur.com/second.png'),
    ];

    ScrapedMod announced() => forumMod(images: const {
          '1': Image(id: '1', url: discordIcon),
        });

    test("the post's first picture stands in when the LLM picked none", () {
      // Industrial Evolution: the LLM left the forum answer's picture empty,
      // so the card showed the Discord one, whose address runs out a day
      // after the Discord scrape. The post had a dozen screenshots.
      final data = buildFrom(
        mods: [announced()],
        bundle: bundleOf(index: [
          thread(llmMods: [LlmMod(name: 'Nexerelin')]),
        ], details: {
          '9175': postOf('<p>Look</p>', images: postPictures),
        }),
      );
      expect(data.list.mods.single.imageUrl, banner, reason: 'the install badge is skipped');
      expect(data.list.mods.single.announcementImageUrl, discordIcon);
    });

    test("the LLM's pick from the post still comes first", () {
      final data = buildFrom(
        mods: [announced()],
        bundle: bundleOf(index: [
          thread(llmMods: [LlmMod(name: 'Nexerelin', image: 'ext:https://i.imgur.com/second.png')]),
        ], details: {
          '9175': postOf('<p>Look</p>', images: postPictures),
        }),
      );
      expect(data.list.mods.single.imageUrl, 'https://i.imgur.com/second.png');
    });

    test("a picture the LLM picked off Discord comes after the post's own", () {
      final data = buildFrom(
        mods: [announced()],
        bundle: bundleOf(index: [
          thread(llmMods: [LlmMod(name: 'Nexerelin', image: 'ext:$discordIcon')]),
        ], details: {
          '9175': postOf('<p>Look</p>', images: postPictures),
        }),
      );
      expect(data.list.mods.single.imageUrl, banner);
    });

    /// The builder, reading [captions] for what the model saw in each picture.
    Future<void> seeing(Map<String, PictureCaption> captions, {Set<String> dead = const {}}) async {
      final store = PictureCaptionStore(p.join(dir.path, 'data'));
      for (final MapEntry(key: url, value: seen) in captions.entries) {
        await store.putCaption(url, seen);
      }
      for (final url in dead) {
        await store.putUnreadable(url, 'not found');
      }
      builder = PublicDataBuilder(
        outputPath: p.join(dir.path, 'outputs'),
        idStore: idStore,
        pictureCaptions: store,
      );
    }

    test('gallery publishes saved AI captions separately from author text', () async {
      await seeing({
        banner: const PictureCaption(kind: PictureKind.banner, caption: 'Generated description'),
        discordIcon: const PictureCaption(kind: PictureKind.art, caption: 'Discord art'),
      });
      final data = buildFrom(
        mods: [forumMod(images: const {
          '1': Image(id: '1', url: 'https://cdn.discordapp.com/attachments/1/2/mod_post_icon_indevo.png?ex=another'),
        })],
        bundle: bundleOf(index: [thread()], details: {
          '9175': postOf('<p>Look</p>', images: [
            ImageRef(originalUrl: banner, alt: 'Author caption'),
            ImageRef(originalUrl: 'https://example.com/unclassified.png'),
          ]),
        }),
      );
      final gallery = data.details['nexerelin']!.gallery;
      final image = gallery.firstWhere((image) => image.url == banner);
      expect(image.caption, 'Author caption');
      expect(image.aiCaption, 'Generated description');
      expect(image.toMap()['aiCaption'], 'Generated description');
      expect(gallery.first.aiCaption, 'Discord art');
      expect(gallery.last.aiCaption, isNull);
      expect(gallery.last.toMap().containsKey('aiCaption'), isFalse);
    });

    test('the earliest picture rated good is the card picture, whatever the LLM picked', () async {
      // The rating is saved per picture and never asked again, so this is the
      // same picture on every build. The LLM's pick can change each time the
      // post is read.
      await seeing({
        banner: const PictureCaption(kind: PictureKind.banner, caption: 'A thin title strip.', fit: CardFit.okay),
        'https://i.imgur.com/second.png':
            const PictureCaption(kind: PictureKind.screenshot, caption: 'The new market.', fit: CardFit.good),
      });
      final data = buildFrom(
        mods: [forumMod()],
        bundle: bundleOf(index: [
          thread(llmMods: [LlmMod(name: 'Nexerelin', image: 'ext:$banner')]),
        ], details: {
          '9175': postOf('<p>Look</p>', images: postPictures),
        }),
      );
      expect(data.list.mods.single.imageUrl, 'https://i.imgur.com/second.png');
    });

    test('with nothing rated good, the earliest rated okay is used', () async {
      await seeing({
        banner: const PictureCaption(kind: PictureKind.banner, caption: 'A thin title strip.', fit: CardFit.okay),
        'https://i.imgur.com/second.png':
            const PictureCaption(kind: PictureKind.screenshot, caption: 'A stats screen.', fit: CardFit.okay),
      });
      final data = buildFrom(
        mods: [forumMod()],
        bundle: bundleOf(index: [thread()], details: {'9175': postOf('<p>Look</p>', images: postPictures)}),
      );
      expect(data.list.mods.single.imageUrl, banner);
    });

    test('a removed-picture notice, a poor fit or a dead link is never a card picture', () async {
      // Old Photobucket links answer with Photobucket's own placeholder, which
      // nothing but the model can tell from a real picture.
      await seeing({
        banner: const PictureCaption(kind: PictureKind.missing, caption: "Photobucket's placeholder.", fit: CardFit.poor),
        discordIcon: const PictureCaption(kind: PictureKind.other, caption: 'A meme.', fit: CardFit.poor),
      }, dead: {'https://i.imgur.com/second.png'});
      final data = buildFrom(
        mods: [announced()],
        bundle: bundleOf(index: [
          thread(llmMods: [LlmMod(name: 'Nexerelin', image: 'ext:$banner')]),
        ], details: {
          '9175': postOf('<p>Look</p>', images: postPictures, avatarPath: 'avatars/histidine.png'),
        }),
      );
      expect(data.list.mods.single.imageUrl, 'https://fractalsoftworks.com/forum/avatars/histidine.png');
      expect(data.list.mods.single.announcementImageUrl, isNull);
    });

    test('a post with only badges gives no picture of its own', () {
      final data = buildFrom(
        mods: [forumMod()],
        bundle: bundleOf(index: [
          thread()
        ], details: {
          '9175': postOf('<p>Look</p>',
              images: [ImageRef(originalUrl: 'https://ko-fi.com/img/donate.png')]),
        }),
      );
      expect(data.list.mods.single.imageUrl, isNull);
    });
  });

  test('a summary that is only a download link gives way to the AI summary',
      () {
    final data = buildFrom(
      mods: [forumMod(name: 'Nexerelin', summary: 'Download: https://x/y.zip')],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            extras: LlmExtras(
              summary: LlmModSummary(sentence: 'Adds diplomacy and invasions.'),
            ),
          ),
        ]),
      ]),
    );

    final mod = data.list.mods.single;
    expect(mod.summary, 'Adds diplomacy and invasions.');
    expect(mod.summaryIsGenerated, isTrue);
  });

  test('the mods a mod needs are published, pointed at their own pages', () {
    final data = buildFrom(
      mods: [
        forumMod(name: 'Nexerelin', topicId: 9175),
        forumMod(name: 'LazyLib', topicId: 5444),
      ],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            extras: LlmExtras(needs: const ['LazyLib', 'Kadur Remnant']),
          ),
        ]),
      ]),
    );

    final nexerelin = data.list.mods.firstWhere((m) => m.id == 'nexerelin');
    expect(nexerelin.needs.map((n) => n.name), ['LazyLib', 'Kadur Remnant']);
    expect(nexerelin.needs.first.id, 'lazylib',
        reason: 'a mod we have a page for becomes a link');
    expect(nexerelin.needs.last.id, isNull,
        reason: 'a mod we do not publish is still worth naming');
  });

  test('a mod that names itself as a requirement is left alone', () {
    final data = buildFrom(
      mods: [forumMod(name: 'Nexerelin')],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            extras: LlmExtras(needs: const ['Nexerelin', 'LazyLib']),
          ),
        ]),
      ]),
    );

    expect(data.list.mods.single.needs.map((n) => n.name), ['LazyLib']);
  });

  test('a mod named twice is only needed once', () {
    final data = buildFrom(
      mods: [
        forumMod(name: 'Nexerelin', topicId: 9175),
        forumMod(name: 'LazyLib', topicId: 5444)
      ],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            extras: LlmExtras(needs: const ['LazyLib', 'lazylib v3.0']),
          ),
        ]),
      ]),
    );

    expect(data.list.mods.firstWhere((m) => m.id == 'nexerelin').needs,
        hasLength(1));
  });

  test('the site has its own categories, and keeps the raw names on the page',
      () {
    final data = buildFrom(
      mods: [
        ScrapedMod(
          name: 'Nexerelin',
          authorsList: const ['Histidine'],
          categories: const [
            'Ship Pack',
            'Weapon/Fighter Pack',
            'Discord Only'
          ],
          sources: const [ModSource.Index, ModSource.Discord],
          urls: const {
            ModUrlType.Forum:
                'https://fractalsoftworks.com/forum/index.php?topic=9175.0',
          },
        ),
      ],
      bundle: bundleOf(),
    );

    final mod = data.list.mods.single;
    expect(mod.categories, ['Ships and weapons'],
        reason: '"Discord Only" says where a mod was found, not what it is');
    expect(mod.sources, ['forum', 'discord']);

    expect(data.details['nexerelin']!.rawCategories,
        ['Ship Pack', 'Weapon/Fighter Pack'],
        reason: 'the page says which shelves it is filed under, and "Discord '
            'Only" is not one — it is published as a source instead');
  });

  test('the card carries one download, picked the same way TriOS picks it', () {
    final data = buildFrom(
      mods: [forumMod()],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            downloads: [
              LlmDownload(
                url: 'https://www.mediafire.com/file/abc/Nexerelin.zip',
                kind: LlmDownloadKind.mirror,
                requiresManualStep: true,
              ),
              LlmDownload(
                url: 'https://github.com/x/y/releases/download/v1/z.zip',
                resolvedDirectUrl: 'https://cdn.example.com/z.zip',
                kind: LlmDownloadKind.direct,
              ),
              LlmDownload(
                url: 'https://trilink.wispborne.com/open.html?mod=%7B%7D',
                kind: LlmDownloadKind.trios,
                requiresManualStep: true,
              ),
            ],
          ),
        ]),
      ]),
    );

    final mod = data.list.mods.single;
    expect(mod.bestDownload?.kind, 'trios',
        reason:
            'a TriOS link installs what the mod needs as well, so it leads');
    expect(mod.bestDownload?.needsAnotherStep, isFalse,
        reason: 'opening a TriOS link is the step, so it never counts as one');
    expect(mod.downloadCount, 3);

    expect(
      data.details['nexerelin']!.downloads.map((d) => d.kind),
      ['trios', 'direct', 'mirror'],
      reason: 'the page for the mod lists them best first as well',
    );
  });

  test('the card download is the resolved address, not the link as written',
      () {
    final data = buildFrom(
      mods: [forumMod()],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            downloads: [
              LlmDownload(
                url: 'https://github.com/x/y/releases/tag/v1',
                resolvedDirectUrl: 'https://cdn.example.com/z.zip',
                kind: LlmDownloadKind.direct,
              ),
            ],
          ),
        ]),
      ]),
    );

    expect(data.list.mods.single.bestDownload?.url,
        'https://cdn.example.com/z.zip');
  });

  test('a download that opens the host page says so', () {
    final data = buildFrom(
      mods: [forumMod()],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            downloads: [
              LlmDownload(
                url: 'https://www.mediafire.com/file/abc/Nexerelin.zip',
                kind: LlmDownloadKind.direct,
                requiresManualStep: true,
              ),
            ],
          ),
        ]),
      ]),
    );

    final mod = data.list.mods.single;
    expect(mod.bestDownload?.needsAnotherStep, isTrue);
    expect(mod.hasDirectDownload, isFalse);
  });

  test('a mod with nothing to download carries no download at all', () {
    final data = buildFrom(mods: [forumMod()], bundle: bundleOf());

    final mod = data.list.mods.single;
    expect(mod.bestDownload, isNull,
        reason: 'the site offers the forum thread instead');
    expect(mod.downloadCount, 0);
    expect(mod.forumUrl,
        'https://fractalsoftworks.com/forum/index.php?topic=9175.0',
        reason: 'a card with no download offers the thread, so the address has '
            'to be in the file the cards are drawn from');
  });

  test('a Discord-only mod carries its Discord post for the same reason', () {
    final data = buildFrom(
      mods: [
        ScrapedMod(
          name: 'Quality Captains',
          authorsList: const ['Sundog'],
          sources: const [ModSource.Discord],
          urls: const {
            ModUrlType.Discord: 'https://discord.com/channels/1/2',
          },
        ),
      ],
      bundle: bundleOf(),
    );

    final mod = data.list.mods.single;
    expect(mod.forumUrl, isNull);
    expect(mod.discordUrl, 'https://discord.com/channels/1/2');
  });

  test('a Nexus-only mod carries its Nexus page for summary actions', () {
    final data = buildFrom(
      mods: const [
        ScrapedMod(
          name: 'Nexus Mod',
          authorsList: ['Someone'],
          sources: [ModSource.NexusMods],
          urls: {
            ModUrlType.NexusMods:
                'https://www.nexusmods.com/starsector/mods/42',
          },
        ),
      ],
      bundle: bundleOf(),
    );

    final mod = data.list.mods.single;
    expect(mod.forumUrl, isNull);
    expect(mod.discordUrl, isNull);
    expect(mod.nexusUrl, 'https://www.nexusmods.com/starsector/mods/42');
    expect(mod.toMap()['nexusUrl'],
        'https://www.nexusmods.com/starsector/mods/42');
  });

  test('a category nobody has seen before is left off rather than guessed', () {
    final data = buildFrom(
      mods: [
        ScrapedMod(
          name: 'Some Mod',
          authorsList: const ['Someone'],
          categories: const ['Something New'],
          sources: const [ModSource.Discord],
          urls: const {ModUrlType.Discord: 'https://discord.com/channels/1/2'},
        ),
      ],
      bundle: bundleOf(),
    );

    expect(data.list.mods.single.categories, isEmpty);
    expect(data.details['some-mod']!.rawCategories, ['Something New']);
  });

  test('a mod is joined to its thread on the forum topic id', () {
    final data = buildFrom(
      mods: [forumMod()],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            downloads: [
              LlmDownload(
                url: 'https://github.com/x/y/releases/download/v1/z.zip',
                resolvedDirectUrl:
                    'https://github.com/x/y/releases/download/v1/z.zip',
                fileName: 'z.zip',
                sourceHost: 'GitHub',
              ),
            ],
            extras: LlmExtras(
              version: '0.12.2',
              license: 'CC BY-NC-SA 4.0',
              sourceCode: 'https://github.com/Histidine91/Nexerelin',
              saveCompatibility: 'Requires a new game.',
              updateNotes: [
                // About an old release: stays off the page.
                LlmUpdateNote(
                    version: '0.11.0',
                    quote: '0.11.0 is save compatible.',
                    answer: SaveAnswer.yes),
                // About the version the mod is on now.
                LlmUpdateNote(
                    version: 'v0.12.2',
                    quote: 'Not save compatible with 0.11.',
                    answer: SaveAnswer.no),
              ],
              removalCompatibility: 'Cannot be removed.',
              canRemove: SaveAnswer.no,
              changelog: LlmChangelog(entries: {'0.12.2': 'Fixed a crash.'}),
            ),
          ),
        ]),
      ]),
    );

    final mod = data.list.mods.single;
    expect(mod.id, 'nexerelin');
    expect(mod.modVersion, '0.12.2');
    expect(mod.gameVersion, '0.98a');
    expect(mod.hasDirectDownload, isTrue);
    expect(mod.sourceIsPublic, isTrue);
    expect(mod.saveCompatible, isFalse);

    final detail = data.details['nexerelin']!;
    expect(detail.license, 'CC BY-NC-SA 4.0');
    expect(detail.changelog, {'0.12.2': 'Fixed a crash.'});
    expect(detail.saveCompatibilityText, 'Requires a new game.');
    // Only the note for the version the mod is on now; the one about 0.11.0
    // stays off the page.
    expect(detail.updateCompatibilityText, 'Not save compatible with 0.11.');
    expect(detail.removalCompatibilityText, 'Cannot be removed.');
    // No short answer on adding was read, so it comes from the words.
    expect(detail.canAdd, SaveAnswer.no);
    expect(detail.canUpdate, SaveAnswer.no);
    expect(detail.canRemove, SaveAnswer.no);
    expect(detail.downloads.single.fileName, 'z.zip');
  });

  test('a mod with no forum thread leaves the bundle-only fields out', () {
    final discordOnly = ScrapedMod(
      name: 'Quality Captains',
      authorsList: const ['Sundog'],
      sources: const [ModSource.Discord],
      urls: const {
        ModUrlType.Discord: 'https://discord.com/channels/1/2',
      },
    );

    final data = buildFrom(mods: [discordOnly], bundle: bundleOf());

    final mod = data.list.mods.single;
    expect(mod.id, 'quality-captains');
    expect(mod.modVersion, isNull);
    expect(mod.saveCompatible, isNull);

    final detail = data.details['quality-captains']!;
    expect(detail.forumUrl, isNull);
    expect(detail.discordUrl, 'https://discord.com/channels/1/2');
    expect(detail.changelog, isEmpty);
    expect(detail.releases, isEmpty);
  });

  test('a multi-mod thread uses the main mod and lists the add-ons', () {
    final data = buildFrom(
      mods: [forumMod(name: 'Industrial.Evolution', topicId: 15380)],
      bundle: bundleOf(index: [
        thread(
            topicId: 15380,
            title: '[0.98a] Industrial.Evolution 3.5.2',
            llmMods: [
              LlmMod(
                name: 'Industrial.Evolution',
                extras: LlmExtras(version: '3.5.2'),
              ),
              LlmMod(
                name: 'IndEvo Vanilla Structures',
                role: LlmModRole.addon,
                requires: 'Industrial.Evolution',
                downloads: [LlmDownload(url: 'https://example.com/addon.zip')],
              ),
              LlmMod(
                name: 'Some Unrelated Mod',
                role: LlmModRole.separate,
              ),
            ]),
      ]),
    );

    final detail = data.details['industrial-evolution']!;
    expect(detail.listing.modVersion, '3.5.2');
    expect(detail.addons, hasLength(1));
    expect(detail.addons.single.name, 'IndEvo Vanilla Structures');
    expect(detail.addons.single.requires, 'Industrial.Evolution');
  });

  group('a thread that is several mods at once', () {
    /// "Hartley's Miscellaneous Mods": four mods on one thread, three of which
    /// the author also announced on Discord. The Discord names carry a version
    /// and the LLM's do not, which is the whole difficulty. The catalog reads
    /// the topic as a Collection of four and joins each announcement to its own
    /// mod; these tests are about the pages that come out of that.
    List<LlmMod> hartleysMods() => [
          LlmMod(
            name: 'Useful.Tithes',
            downloads: [LlmDownload(url: 'https://example.com/tithes.zip')],
            extras: LlmExtras(
              summary: LlmModSummary(paragraph: 'Pather tithes do something.'),
            ),
          ),
          LlmMod(
            name: 'Big Pilum Energy',
            downloads: [LlmDownload(url: 'https://example.com/pilum.zip')],
          ),
          LlmMod(
            name: 'Lost.Sector',
            downloads: [LlmDownload(url: 'https://example.com/lost.zip')],
            extras: LlmExtras(
              summary: LlmModSummary(paragraph: 'Derelict stations to clear.'),
            ),
          ),
          LlmMod(
            name: 'Disco.Balls',
            downloads: [LlmDownload(url: 'https://example.com/disco.zip')],
          ),
        ];

    ScrapedMod announced(String name, String threadId, {String? description}) => ScrapedMod(
          name: name,
          description: description,
          gameVersionReq: '0.98a',
          authorsList: const ['SirHartley'],
          sources: const [ModSource.Discord],
          urls: {
            ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=34161.0',
            ModUrlType.Discord: 'https://discord.com/channels/1/$threadId/$threadId',
          },
        );

    List<ScrapedMod> hartleyOnDiscord() => [
          announced('Useful.Tithes 1.0.a', '101'),
          announced('Big Pilum Energy 1.0.d', '102'),
          announced('Disco.Balls 1.1.c - More Lamp Colour Options', '103'),
        ];

    QbModSummary hartleysThread({List<LlmMod>? llmMods}) => thread(
          topicId: 34161,
          title: "Hartley's Miscellaneous Mods",
          author: 'SirHartley',
          llmMods: llmMods ?? hartleysMods(),
        );

    /// The post names all four mods, which is what lets them be published.
    QbModDetail hartleysPost([String words = 'Useful.Tithes, Big Pilum Energy, Lost.Sector and Disco.Balls.']) =>
        postOf('<p>$words Four small mods in one thread.</p>', topicId: 34161);

    Future<PublicSiteData> buildHartleys({List<ScrapedMod>? discordMods}) => buildThroughCatalog(
          bundle: bundleOf(index: [hartleysThread()], details: {'34161': hartleysPost()}),
          discordMods: discordMods ?? hartleyOnDiscord(),
        );

    test("a shared thread's first picture is not given to every mod on it", () async {
      // The first picture on a thread of four mods may be any one of them,
      // even when the model rated it a good card picture.
      final store = PictureCaptionStore(p.join(dir.path, 'data'));
      await store.putCaption('https://i.imgur.com/tithes.png',
          const PictureCaption(kind: PictureKind.screenshot, caption: 'Tithes.', fit: CardFit.good));
      builder = PublicDataBuilder(outputPath: p.join(dir.path, 'outputs'), idStore: idStore, pictureCaptions: store);
      final data = await buildThroughCatalog(
        bundle: bundleOf(index: [
          hartleysThread()
        ], details: {
          '34161': postOf('<p>Useful.Tithes, Big Pilum Energy, Lost.Sector and Disco.Balls. Four small mods in one thread.</p>',
              topicId: 34161, images: [ImageRef(originalUrl: 'https://i.imgur.com/tithes.png')]),
        }),
      );
      final lost = data.list.mods.singleWhere((m) => m.name == 'Lost.Sector');
      expect(lost.imageUrl, isNull);
    });

    test('every mod on the thread is published, and the thread itself is not a mod', () async {
      final data = await buildHartleys();

      expect(data.list.mods, hasLength(4));
      expect(data.list.mods.where((m) => m.name == "Hartley's Miscellaneous Mods"), isEmpty);

      final lost = data.list.mods.singleWhere((m) => m.name == 'Lost.Sector');
      expect(lost.partOfThreadTitle, "Hartley's Miscellaneous Mods");
      expect(lost.sources, ['forum']);
      expect(lost.bestDownload?.url, 'https://example.com/lost.zip');
      expect(lost.gameVersion, '0.98a');
    });

    test('a Discord announcement joins its own mod rather than making a second page', () async {
      final data = await buildHartleys();

      expect(data.list.mods.where((m) => m.name.startsWith('Useful.Tithes')), hasLength(1));
      expect(data.list.mods.where((m) => m.name.startsWith('Big Pilum')), hasLength(1));
      // The version sits in the middle of this one, with a subtitle behind it.
      expect(data.list.mods.where((m) => m.name.startsWith('Disco.Balls')), hasLength(1));

      final tithes = data.list.mods.singleWhere((m) => m.name.startsWith('Useful.Tithes'));
      expect(tithes.sources, containsAll(['forum', 'discord']));
      expect(tithes.discordUrl, contains('/101/'));
    });

    test("every mod on the thread gets its own facts, not a sibling's", () async {
      final data = await buildHartleys();
      String? downloadOf(String name) =>
          data.list.mods.singleWhere((m) => m.name.startsWith(name)).bestDownload?.url;

      expect(downloadOf('Useful.Tithes'), 'https://example.com/tithes.zip');
      expect(downloadOf('Big Pilum'), 'https://example.com/pilum.zip');
      expect(downloadOf('Disco.Balls'), 'https://example.com/disco.zip');
      expect(downloadOf('Lost.Sector'), 'https://example.com/lost.zip');
    });

    test("the shared post is nobody's description", () async {
      final data = await buildHartleys(discordMods: [
        // This one's announcement has words of its own; the others have none.
        announced('Useful.Tithes 1.0.a', '101', description: 'A small mod making pather tithes more useful.'),
        announced('Big Pilum Energy 1.0.d', '102'),
      ]);

      String idOf(String name) => data.list.mods.singleWhere((m) => m.name.startsWith(name)).id;

      final tithes = data.details[idOf('Useful.Tithes')]!;
      expect(tithes.description, 'A small mod making pather tithes more useful.');
      expect(tithes.descriptionIsGenerated, isFalse);
      expect(tithes.description, isNot(contains('Big Pilum')));

      // Nothing of its own and no AI paragraph: no description at all beats
      // three other mods' text.
      final pilum = data.details[idOf('Big Pilum')]!;
      expect(pilum.description, isNull);
      expect(pilum.descriptionHtml, isNull);

      // The AI paragraph where there is one, said to be AI.
      final lost = data.details[idOf('Lost.Sector')]!;
      expect(lost.description, 'Derelict stations to clear.');
      expect(lost.descriptionIsGenerated, isTrue);
    });

    test('a mod named on the thread but never in the post gets no page', () async {
      final data = await buildThroughCatalog(
        bundle: bundleOf(
          index: [hartleysThread()],
          // The post names three of the four. A model asked what a thread holds
          // will pad the list, and a made-up mod would get a permanent address.
          details: {'34161': hartleysPost('Useful.Tithes, Big Pilum Energy and Disco.Balls.')},
        ),
        discordMods: hartleyOnDiscord(),
      );

      expect(data.list.mods, hasLength(3));
      expect(data.list.mods.where((m) => m.name == 'Lost.Sector'), isEmpty);
    });

    test('a mod with no download gets no page', () async {
      final data = await buildThroughCatalog(
        bundle: bundleOf(
          index: [
            hartleysThread(llmMods: [
              for (final llmMod in hartleysMods())
                if (llmMod.name == 'Lost.Sector') LlmMod(name: llmMod.name, downloads: const []) else llmMod,
            ]),
          ],
          details: {'34161': hartleysPost()},
        ),
        discordMods: hartleyOnDiscord(),
      );

      expect(data.list.mods.where((m) => m.name == 'Lost.Sector'), isEmpty);
    });

    test('an add-on stays an add-on, and sits on the mod it needs', () async {
      final data = await buildThroughCatalog(
        bundle: bundleOf(
          index: [
            hartleysThread(llmMods: [
              ...hartleysMods(),
              LlmMod(
                name: 'Tithes Extra Icons',
                role: LlmModRole.addon,
                requires: 'Useful.Tithes',
                downloads: [LlmDownload(url: 'https://example.com/icons.zip')],
              ),
            ]),
          ],
          details: {
            '34161': hartleysPost('Useful.Tithes, Big Pilum Energy, Lost.Sector, Disco.Balls and Tithes Extra Icons.'),
          },
        ),
        discordMods: hartleyOnDiscord(),
      );

      expect(data.list.mods.where((m) => m.name == 'Tithes Extra Icons'), isEmpty);

      String idOf(String name) => data.list.mods.singleWhere((m) => m.name.startsWith(name)).id;

      // On the page of the mod it needs, and on no other.
      expect(data.details[idOf('Useful.Tithes')]!.addons.map((a) => a.name), ['Tithes Extra Icons']);
      expect(data.details[idOf('Big Pilum')]!.addons, isEmpty);
      expect(data.details[idOf('Lost.Sector')]!.addons, isEmpty);
    });

    test('two mods whose names clean alike keep separate pages', () async {
      final data = await buildThroughCatalog(
        bundle: bundleOf(
          index: [
            hartleysThread(),
            // Kissa_Mies's, a different mod on a thread of its own.
            thread(topicId: 27556, title: '[0.98a] LOST_SECTOR', author: 'Kissa_Mies'),
          ],
          details: {'34161': hartleysPost()},
        ),
        discordMods: hartleyOnDiscord(),
      );

      final hartleys = data.list.mods.singleWhere((m) => m.name == 'Lost.Sector');
      final kissas = data.list.mods.singleWhere((m) => m.name == 'LOST_SECTOR');
      expect(hartleys.id, isNot(kissas.id));
      expect(hartleys.partOfThreadTitle, "Hartley's Miscellaneous Mods");
      expect(kissas.partOfThreadTitle, isNull);
    });

    test('the same data read again gives every mod the id it had', () async {
      final first = await buildHartleys();
      final second = await buildHartleys();

      expect(
        {for (final m in second.list.mods) m.name: m.id},
        equals({for (final m in first.list.mods) m.name: m.id}),
      );
    });

    test('the thread contributes nothing to the release feed', () async {
      final data = await buildThroughCatalog(
        bundle: bundleOf(index: [hartleysThread()], details: {'34161': hartleysPost()}),
        discordMods: hartleyOnDiscord(),
        threadReleases: [
          const ThreadRelease(
            topicId: 34161,
            modName: "Hartley's Miscellaneous Mods",
            seenOn: '2026-08-14',
            oldVersion: '1.0.a',
            newVersion: '1.0.b',
          ),
        ],
      );

      // The detector believes one version for a whole thread and cannot say
      // which of four mods moved. Crediting one would announce a release that
      // mod never made.
      expect(data.feed.releases, isEmpty);
      for (final mod in data.list.mods) {
        expect(data.details[mod.id]!.releases, isEmpty);
        expect(mod.lastReleaseDate, isNull);
      }
    });

    test('a Collection that already had a page keeps it, listing its mods', () async {
      // Topic 34457 was published as one mod before it was known to be four.
      final startsThread = thread(
        topicId: 34457,
        title: '[0.98a] [WIP] Derelict Start, Remnant Start, Omega Start & Threat Start',
        author: 'Someone',
        llmMods: [
          for (final name in ['Derelict Start', 'Remnant Start', 'Omega Start', 'Threat Start'])
            LlmMod(name: name, downloads: [LlmDownload(url: 'https://example.com/${name.length}.zip')]),
        ],
      );
      final oldId = idStore.idFor('Derelict Start, Remnant Start, Omega Start & Threat Start',
          mark: 'topic:34457');
      idStore.linkIdToPost(oldId, const SourcePostRef(kind: SourceKind.forum, id: '34457'));

      final data = await buildThroughCatalog(bundle: bundleOf(index: [startsThread]));

      expect(data.list.mods.map((m) => m.name),
          containsAll(['Derelict Start', 'Remnant Start', 'Omega Start', 'Threat Start']));
      expect(data.list.mods.map((m) => m.id), isNot(contains(oldId)));
      final page = data.collections.single;
      expect(page.id, oldId);
      expect(page.mods.map((m) => m.name), hasLength(4));

      await builder.write(data);
      final file = File(p.join(builder.modsDir, '$oldId.json'));
      expect((jsonDecode(file.readAsStringSync()) as Map)['collection'], isNotNull);
      expect(File(p.join(builder.modsDir, oldId, 'index.html')).existsSync(), isTrue);
    });
  });

  test('an old address joined into another mod leads to its page, and is kept between writes', () async {
    final bundle = bundleOf();
    final mods = catalogOf([forumMod()], bundle: bundle);
    final id = mods.single.id;
    final data = builder.build(
      mods: mods,
      bundle: bundle,
      // One to a mod with no page, and one standing on a mod's own address.
      movedIds: {'old-page': id, 'gone-too': 'no-such-mod', id: 'old-page'},
    );
    expect(data.movedIds, {'old-page': id});
    expect(data.list.mods.map((m) => m.id), isNot(contains('old-page')));

    await builder.write(data);
    final file = File(p.join(builder.modsDir, 'old-page.json'));
    expect(jsonDecode(file.readAsStringSync()), {'movedTo': id});
    final page = File(p.join(builder.modsDir, 'old-page', 'index.html')).readAsStringSync();
    expect(page, contains('url=../$id/'));
    expect(page, contains('<link rel="canonical" href="https://starmodder.wispborne.com/mods/$id/">'));

    // Written again, the moved address is one of this run's and stays.
    await builder.write(data);
    expect(file.existsSync(), isTrue);
    expect(Directory(p.join(builder.modsDir, 'old-page')).existsSync(), isTrue);
  });

  group('a thread only QB knows about', () {
    /// Topic 35651, "Computica's Faction Forks": a thread whose title carries
    /// no bracketed game version, and whose author never posted the forks on
    /// Discord. The old forum scraper dropped it. The catalog reads every
    /// thread QB keeps, so it is a source post like any other.
    QbModSummary forksThread({List<LlmMod> llmMods = const []}) => thread(
          topicId: 35651,
          title: "Computica's Faction Forks",
          author: 'Computica',
          lastPostDate: 'August 12, 2026, 04:15:02 PM',
          llmMods: llmMods,
        );

    LlmMod fork(String name) => LlmMod(
          name: name,
          downloads: [LlmDownload(url: 'https://example.com/${name.toLowerCase().replaceAll(' ', '-')}.zip')],
        );

    test('a thread holding one mod is that mod, named from the thread', () async {
      final data = await buildThroughCatalog(
        bundle: bundleOf(
          index: [thread(), forksThread(llmMods: [fork('Kwin')])],
          details: {'35651': postOf('<p>Kwin, a fork kept up to date.</p>', topicId: 35651)},
        ),
      );

      // One main mod on a post is the mod the post is about, whatever either
      // is called. The rules' name stays; the LLM's facts come with it.
      final forks = data.list.mods.singleWhere((m) => m.forumUrl?.contains('topic=35651') ?? false);
      expect(forks.name, "Computica's Faction Forks");
      expect(forks.partOfThreadTitle, isNull, reason: 'a thread holding one mod is not a shared thread');
      expect(forks.sources, ['forum']);
      expect(forks.bestDownload?.url, 'https://example.com/kwin.zip');
    });

    test('every main mod on a thread of several is published', () async {
      final data = await buildThroughCatalog(
        bundle: bundleOf(
          index: [
            thread(),
            forksThread(llmMods: [fork('Kwin'), fork('Farsight Drive'), fork('FSF Military Corporation')]),
          ],
          details: {
            '35651': postOf('<p>Kwin, Farsight Drive and FSF Military Corporation.</p>', topicId: 35651),
          },
        ),
      );

      expect(
        data.list.mods.where((m) => m.partOfThreadTitle != null).map((m) => m.name),
        containsAll(['Kwin', 'Farsight Drive', 'FSF Military Corporation']),
      );
      expect(data.list.mods, hasLength(4));
    });

    test('a thread with nothing grounded on it is still its one rules listing', () async {
      Future<PublicSiteData> buildWith({required List<LlmMod> llmMods, required String post}) =>
          buildThroughCatalog(
            bundle: bundleOf(
              index: [thread(), forksThread(llmMods: llmMods)],
              details: {'35651': postOf(post, topicId: 35651)},
            ),
          );

      for (final data in [
        await buildWith(llmMods: const [], post: '<p>Does anybody know why?</p>'),
        await buildWith(llmMods: [fork('Chinese Translation Pack')], post: '<p>Nothing here says that name.</p>'),
        await buildWith(llmMods: [LlmMod(name: 'Kwin', downloads: const [])], post: '<p>Kwin is coming.</p>'),
      ]) {
        expect(data.list.mods.map((m) => m.name), unorderedEquals(['Nexerelin', "Computica's Faction Forks"]));
      }
    });

    test('an add-on or a variant on such a thread is not a mod of its own', () async {
      final data = await buildThroughCatalog(
        bundle: bundleOf(
          index: [
            thread(),
            forksThread(llmMods: [
              LlmMod(
                name: 'Kwin Extra Portraits',
                role: LlmModRole.addon,
                requires: 'Kwin',
                downloads: [LlmDownload(url: 'https://example.com/extra.zip')],
              ),
              LlmMod(
                name: 'Kwin Lite',
                role: LlmModRole.variant,
                downloads: [LlmDownload(url: 'https://example.com/lite.zip')],
              ),
            ]),
          ],
          details: {'35651': postOf('<p>Kwin Extra Portraits and Kwin Lite.</p>', topicId: 35651)},
        ),
      );

      expect(data.list.mods.map((m) => m.name), unorderedEquals(['Nexerelin', "Computica's Faction Forks"]));
    });

    test("a fork keeping the original's name gets a page of its own", () async {
      final original = thread(topicId: 161, title: '[0.98a] Junk Pirates', author: 'mendonca');
      // The original was published first and has the plain address.
      await buildThroughCatalog(bundle: bundleOf(index: [original]));

      final data = await buildThroughCatalog(
        bundle: bundleOf(
          index: [original, forksThread(llmMods: [fork('Junk Pirates'), fork('Valkyrians')])],
          details: {'35651': postOf('<p>Junk Pirates and Valkyrians, forked and kept working.</p>', topicId: 35651)},
        ),
      );

      final named = data.list.mods.where((m) => m.name == 'Junk Pirates').toList();
      expect(named, hasLength(2));
      final merged = named.singleWhere((m) => m.forumUrl?.contains('topic=161') ?? false);
      final forked = named.singleWhere((m) => m.forumUrl?.contains('topic=35651') ?? false);

      // Nobody's existing link moves: the original keeps the plain address.
      expect(merged.id, 'junk-pirates');
      expect(forked.id, 'junk-pirates-2');

      // And each page names the other.
      expect(data.details[merged.id]!.sameNameMods.single.id, forked.id);
      expect(data.details[forked.id]!.sameNameMods.single.id, merged.id);
    });
  });

  group('the day a thread was last posted on', () {
    test('is published when the forum gives a readable one', () {
      final data = buildFrom(
        mods: [forumMod()],
        bundle: bundleOf(
          index: [thread(lastPostDate: 'August 12, 2026, 04:15:02 PM')],
        ),
      );

      final mod = data.list.mods.single;
      expect(mod.threadLastPostOn, '2026-08-12');
      expect(data.details[mod.id]!.threadLastPostOn, mod.threadLastPostOn);
    });

    test('is absent for a date that names no day', () {
      // The forum writes "Today at 03:12:22 PM" for a recent post, which says
      // nothing about which day it means.
      final data = buildFrom(
        mods: [forumMod()],
        bundle: bundleOf(index: [thread(lastPostDate: 'Today at 03:12:22 PM')]),
      );

      expect(data.list.mods.single.threadLastPostOn, isNull);
    });

    test('is absent for a mod with no forum thread', () {
      final data = buildFrom(
        mods: const [
          ScrapedMod(
            name: 'Quality Captains',
            sources: [ModSource.Discord],
            urls: {ModUrlType.Discord: 'https://discord.com/x/y'},
          ),
        ],
        bundle: bundleOf(),
      );

      expect(data.list.mods.single.threadLastPostOn, isNull);
    });
  });

  group('mods that share a name', () {
    test('each page names the others, newest thread first', () {
      final data = buildFrom(
        mods: [
          forumMod(
            name: 'Scy',
            topicId: 29535,
            summary: null,
            authors: const ['Tartiflette'],
          ),
          forumMod(
            name: 'Scy',
            topicId: 8010,
            summary: null,
            authors: const ['Tartiflette'],
          ),
          forumMod(
            name: 'Kadur Remnant',
            topicId: 12000,
            summary: null,
            authors: const ['Mephyr'],
          ),
        ],
        bundle: bundleOf(index: [
          thread(
            topicId: 29535,
            title: '[0.98a] Scy v1.9',
            lastPostDate: 'August 12, 2026, 04:15:02 PM',
          ),
          thread(
            topicId: 8010,
            title: '[0.6.2a] Scy v0.4',
            lastPostDate: 'March 04, 2015, 01:33:25 AM',
          ),
          thread(topicId: 12000, title: '[0.98a] Kadur Remnant'),
        ]),
      );

      String idOfTopic(int topicId) => data.list.mods
          .singleWhere((m) => m.forumUrl!.contains('topic=$topicId'))
          .id;

      final live = data.details[idOfTopic(29535)]!;
      final archived = data.details[idOfTopic(8010)]!;

      final onTheLivePage = live.sameNameMods.single;
      expect(onTheLivePage.id, idOfTopic(8010));
      expect(onTheLivePage.authors, ['Tartiflette']);
      expect(onTheLivePage.threadLastPostOn, '2015-03-04');
      expect(onTheLivePage.url, contains('topic=8010'));

      expect(archived.sameNameMods.single.id, idOfTopic(29535));

      // A name nothing else carries says nothing about anybody.
      expect(data.details[idOfTopic(12000)]!.sameNameMods, isEmpty);
    });

    test('a name nothing else shares lists nothing', () {
      final data = buildFrom(mods: [forumMod()], bundle: bundleOf());
      expect(data.details[data.list.mods.single.id]!.sameNameMods, isEmpty);
    });

    test('the grouping reads two spellings of one name as one', () {
      final data = buildFrom(
        mods: [
          forumMod(name: 'Useful.Tithes 1.0.a', topicId: 100, summary: null),
          forumMod(name: 'Useful Tithes', topicId: 200, summary: null),
        ],
        bundle: bundleOf(),
      );

      for (final mod in data.list.mods) {
        expect(data.details[mod.id]!.sameNameMods, hasLength(1),
            reason: 'the version and the dot are not what tells two mods '
                'apart');
      }
    });
  });

  test('a thread about one mod keeps the post as its description', () {
    final data = buildFrom(
      mods: [forumMod(description: 'The merged text.')],
      bundle: bundleOf(
        index: [
          thread(llmMods: [
            LlmMod(
              name: 'Nexerelin',
              downloads: [LlmDownload(url: 'https://example.com/nex.zip')],
            ),
          ]),
        ],
        details: {'9175': postOf('<p>The author&#39;s own post.</p>')},
      ),
    );

    final detail = data.details[data.list.mods.single.id]!;
    expect(detail.description, "The author's own post.");
    expect(detail.descriptionHtml, contains('<p>'));
    expect(detail.descriptionIsGenerated, isFalse);
    expect(detail.partOfThreadTitle, isNull);
  });

  test('a thread naming one mod is that mod, whatever the two are called', () {
    // "Red - the Oculian Armada" is the mod called "Red". No comparing of
    // names would say so; that the thread names one mod is what says it.
    final data = buildFrom(
      mods: [forumMod(name: 'Red', topicId: 5000, summary: null)],
      bundle: bundleOf(index: [
        thread(
          topicId: 5000,
          title: '[0.98a] Red - the Oculian Armada (0.10.2-RC4) Mod',
          llmMods: [
            LlmMod(
              name: 'Red - the Oculian Armada',
              downloads: [LlmDownload(url: 'https://example.com/red.zip')],
              extras: LlmExtras(version: '0.10.2'),
            ),
          ],
        ),
      ]),
    );

    final mod = data.list.mods.single;
    expect(mod.modVersion, '0.10.2', reason: 'it took the thread mod\'s facts');
    expect(mod.bestDownload?.url, 'https://example.com/red.zip');
    expect(mod.partOfThreadTitle, isNull);
  });

  test('a mod merged from Discord alone still has the forum as a source', () {
    final data = buildFrom(
      mods: [
        ScrapedMod(
          name: 'Quality Captains',
          sources: const [ModSource.Discord],
          urls: {
            ModUrlType.Forum:
                'https://fractalsoftworks.com/forum/index.php?topic=9175.0',
            ModUrlType.Discord: 'https://discord.com/channels/1/2',
          },
        ),
      ],
      bundle: bundleOf(index: [thread()]),
    );

    // The merge learns about a mod from the board listings or from Discord, so
    // a mod announced only on Discord came out marked Discord-only while its
    // own page linked its forum thread.
    expect(data.list.mods.single.sources, ['forum', 'discord']);
  });

  test('a mod with no thread at all is still Discord alone', () {
    final data = buildFrom(
      mods: [
        ScrapedMod(
          name: 'Quality Captains',
          sources: const [ModSource.Discord],
          urls: {ModUrlType.Discord: 'https://discord.com/channels/1/2'},
        ),
      ],
      bundle: bundleOf(),
    );

    expect(data.list.mods.single.sources, ['discord']);
  });

  test('an LLM summary is marked as written, a copied one is not', () {
    final generated = buildFrom(
      mods: [forumMod(summary: null)],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            extras: LlmExtras(
              summary: LlmModSummary(
                  sentence: 'A campaign overhaul.',
                  paragraph: 'It adds diplomacy and invasions.'),
            ),
          ),
        ]),
      ]),
    );
    expect(generated.list.mods.single.summary, 'A campaign overhaul.');
    expect(generated.list.mods.single.summaryIsGenerated, isTrue);
    expect(generated.details['nexerelin']!.descriptionIsGenerated, isTrue);

    final copied = PublicDataBuilder(
      outputPath: p.join(dir.path, 'outputs2'),
      idStore: ModIdStore(p.join(dir.path, 'data2'))..load(),
    ).build(
      mods: catalogOf([forumMod(summary: 'The author\'s own words.')], bundle: bundleOf(index: [thread()])),
      bundle: bundleOf(index: [thread()]),
    );
    expect(copied.list.mods.single.summary, "The author's own words.");
    expect(copied.list.mods.single.summaryIsGenerated, isFalse);
  });

  test('the AI summary and paragraph are published beside the copied ones', () {
    // The reader can ask for the AI words always, even on a mod whose author
    // wrote their own. That choice is made in the browser, so both blocks of
    // words have to be in the file for it to pick between.
    final data = buildFrom(
      mods: [forumMod(summary: "The author's own words.")],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            extras: LlmExtras(
              summary: LlmModSummary(
                  sentence: 'A campaign overhaul.',
                  paragraph: 'It adds diplomacy and invasions.'),
            ),
          ),
        ]),
      ]),
    );

    final mod = data.list.mods.single;
    expect(mod.summary, "The author's own words.");
    expect(mod.summaryIsGenerated, isFalse);
    expect(mod.aiSummary, 'A campaign overhaul.');
    expect(data.details['nexerelin']!.aiDescription,
        'It adds diplomacy and invasions.');
  });

  test('a mod the LLM said nothing about carries no AI words', () {
    final data = buildFrom(
      mods: [forumMod(summary: "The author's own words.")],
      bundle: bundleOf(index: [thread()]),
    );

    expect(data.list.mods.single.aiSummary, isNull);
    expect(data.details['nexerelin']!.aiDescription, isNull);
  });

  test('the rules-based downloads are used when the LLM found none', () {
    final data = buildFrom(
      mods: [forumMod()],
      bundle: bundleOf(
        index: [thread()],
        downloads: {
          '9175': [
            AssumedDownloadCandidate(
              originalUrl: 'https://example.com/page',
              resolvedDirectUrl: 'https://example.com/mod.zip',
              sourceHost: 'example.com',
              fileName: 'mod.zip',
              confidence: 'high',
              linkText: 'Download',
            ),
          ],
        },
      ),
    );

    final detail = data.details['nexerelin']!;
    expect(detail.downloads.single.url, 'https://example.com/page');
    expect(detail.downloads.single.directUrl, 'https://example.com/mod.zip');
    expect(detail.listing.hasDirectDownload, isTrue);
  });

  test('a release gives the mod a last release date and its own history', () {
    final release = ThreadRelease(
      topicId: 9175,
      modName: 'Nexerelin',
      seenOn: '2026-08-14',
      oldVersion: '0.12.1e',
      newVersion: '0.12.2',
      gameVersion: '0.98a',
    );

    final data = buildFrom(
      mods: [forumMod()],
      bundle: bundleOf(index: [thread()]),
      threadReleases: [release],
    );

    expect(data.list.mods.single.lastReleaseDate, DateTime.utc(2026, 8, 14));
    expect(data.details['nexerelin']!.releases, hasLength(1));
    expect(data.details['nexerelin']!.releases.single.modId, 'nexerelin');
    expect(data.feed.releases, hasLength(1));
  });

  test('each release carries the update note written for its version', () {
    ThreadRelease releaseOf(String from, String to, String day) =>
        ThreadRelease(
          topicId: 9175,
          modName: 'Nexerelin',
          seenOn: day,
          oldVersion: from,
          newVersion: to,
        );

    final data = buildFrom(
      mods: [forumMod()],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(
            name: 'Nexerelin',
            extras: LlmExtras(version: '0.12.2', updateNotes: [
              LlmUpdateNote(
                  version: 'v0.12.1',
                  quote: 'Minor patch v0.12.1 is out. It is save-compatible.',
                  answer: SaveAnswer.yes),
              LlmUpdateNote(
                  quote: 'Not save compatible with versions before 0.12.',
                  answer: SaveAnswer.depends),
            ]),
          ),
        ]),
      ]),
      threadReleases: [
        releaseOf('0.12.0', '0.12.1', '2026-08-01'),
        releaseOf('0.12.1', '0.12.2', '2026-08-14'),
        releaseOf('0.11.9', '0.12.0', '2026-07-01'),
      ],
    );

    final byVersion = {
      for (final r in data.details['nexerelin']!.releases) r.newVersion: r,
    };
    // A note written for this release.
    expect(byVersion['0.12.1']!.updateCompatibilityText,
        'Minor patch v0.12.1 is out. It is save-compatible.');
    expect(byVersion['0.12.1']!.canUpdate, SaveAnswer.yes);
    // The version the mod is on now takes the note tied to no release.
    expect(byVersion['0.12.2']!.updateCompatibilityText,
        'Not save compatible with versions before 0.12.');
    expect(byVersion['0.12.2']!.canUpdate, SaveAnswer.depends);
    // An older release with no note of its own gets nothing — the note tied to
    // no release describes the mod as it is now, not as it was then.
    expect(byVersion['0.12.0']!.updateCompatibilityText, isNull);
    expect(byVersion['0.12.0']!.canUpdate, isNull);
  });

  test('the feed reads newest first and drops releases with no mod behind them',
      () {
    final data = buildFrom(
      mods: [forumMod(), forumMod(name: 'Second Mod', topicId: 100)],
      bundle: bundleOf(),
      threadReleases: [
        ThreadRelease(
            topicId: 9175,
            modName: 'Nexerelin',
            seenOn: '2026-08-10',
            newVersion: '0.12.1'),
        ThreadRelease(
            topicId: 100,
            modName: 'Second Mod',
            seenOn: '2026-08-14',
            newVersion: '2.0'),
        ThreadRelease(
            topicId: 999,
            modName: 'A thread nobody merged',
            seenOn: '2026-08-16',
            newVersion: '9.9'),
      ],
    );

    expect(data.feed.releases.map((r) => r.modId), ['second-mod', 'nexerelin']);
  });

  test('a picture stored as ext:<url> is published as a plain URL', () {
    final data = buildFrom(
      mods: [forumMod()],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(name: 'Nexerelin', image: 'ext:https://example.com/shot.png'),
        ]),
      ]),
    );
    expect(data.list.mods.single.imageUrl, 'https://example.com/shot.png');
  });

  test('a saved local image path is never published', () {
    final data = buildFrom(
      mods: [forumMod()],
      bundle: bundleOf(index: [
        thread(llmMods: [
          LlmMod(name: 'Nexerelin', image: 'images/9175/thumb.png'),
        ]),
      ]),
    );
    expect(data.list.mods.single.imageUrl, isNull);
  });

  test('the author\'s own words decide save compatibility', () {
    expect(PublicDataBuilder.readSaveCompatibility('Save compatible'), isTrue);
    expect(PublicDataBuilder.readSaveCompatibility('Not save compatible'),
        isFalse);
    expect(PublicDataBuilder.readSaveCompatibility('Requires a new game'),
        isFalse);
    expect(
        PublicDataBuilder.readSaveCompatibility('Can be added to an existing '
            'save'),
        isTrue);
    expect(PublicDataBuilder.readSaveCompatibility('Have fun!'), isNull);
    expect(PublicDataBuilder.readSaveCompatibility(null), isNull);
  });

  test('the short answer about adding decides the badge', () {
    PublicMod listingWith(LlmExtras extras) => buildFrom(
          mods: [forumMod()],
          bundle: bundleOf(index: [
            thread(llmMods: [
              LlmMod(name: 'Nexerelin', extras: extras),
            ]),
          ]),
        )
        .list
        .mods
        .single;

    // The words alone would read as "needs a new game"; the short answer wins.
    expect(
        listingWith(LlmExtras(
                saveCompatibility: 'Requires a new game to see the new '
                    'systems, otherwise save compatible',
                canAdd: SaveAnswer.depends))
            .saveCompatible,
        isNull);
    expect(
        listingWith(LlmExtras(
                saveCompatibility: 'Safe to add', canAdd: SaveAnswer.yes))
            .saveCompatible,
        isTrue);
    expect(
        listingWith(LlmExtras(
                saveCompatibility: 'Needs a fresh start', canAdd: SaveAnswer.no))
            .saveCompatible,
        isFalse);
    // An answer read before the short answer existed still reads its words.
    expect(
        listingWith(LlmExtras(saveCompatibility: 'Requires a new game'))
            .saveCompatible,
        isFalse);
  });

  test('words about updating say nothing about adding a mod', () {
    // These are about moving a save from an older version of the mod. None
    // of them says whether the mod can be added to a running game.
    for (final words in [
      'This update is not save compatible.',
      'Not save compatible with versions prior to 2.0.0.',
      'Save compatible with versions 1.6.0 and higher',
      'save-compatible with previous versions',
      'THIS UPDATE WILL BREAK SAVES!!',
    ]) {
      expect(PublicDataBuilder.readSaveCompatibility(words), isNull,
          reason: words);
    }
  });

  test('writing puts the files where the site asks for them', () async {
    final data = buildFrom(
      mods: [forumMod(), forumMod(name: 'Second Mod', topicId: 100)],
      bundle: bundleOf(),
    );
    await builder.write(data);

    expect(File(p.join(builder.siteDir, 'mods.json')).existsSync(), isTrue);
    expect(File(p.join(builder.siteDir, 'updates.json')).existsSync(), isTrue);
    expect(
        File(p.join(builder.modsDir, 'nexerelin.json')).existsSync(), isTrue);
    expect(
        File(p.join(builder.modsDir, 'second-mod.json')).existsSync(), isTrue);
  });

  test('the release feed is written out beside the rest', () async {
    final data = buildFrom(
      mods: [forumMod()],
      bundle: bundleOf(),
      threadReleases: [
        const ThreadRelease(
          topicId: 9175,
          modName: 'Nexerelin',
          seenOn: '2026-08-14',
          newVersion: '0.12.2',
        ),
      ],
    );
    await builder.write(data);

    final feed = File(p.join(builder.siteDir, 'updates.xml'));
    expect(feed.existsSync(), isTrue,
        reason: 'a reader who subscribed has nothing to read without it');
    expect(
        feed.readAsStringSync(), contains('<title>Nexerelin 0.12.2</title>'));
  });

  test('each mod gets a page of its own, which is also its address', () async {
    await builder.write(buildFrom(
      mods: [forumMod(name: 'Nexerelin')],
      bundle: bundleOf(),
    ));

    final page = File(p.join(builder.modsDir, 'nexerelin', 'index.html'));
    expect(page.existsSync(), isTrue);

    final html = page.readAsStringSync();
    // Named for the mod, so a shared link previews as that mod.
    expect(html, contains('<title>Nexerelin | Starmodder</title>'));
    // And it is the site itself, so the address is a page a reader can land
    // on rather than one that bounces them somewhere else.
    expect(html, contains('<base href="../../">'));
    expect(html, contains('src="app.js"'));
    expect(html, isNot(contains('location.replace')));
  });

  test('a mod page is built from the site\'s own document', () async {
    // Point the builder at a folder with no site in it: the pages still get
    // written, and still preview, but fall back to sending the reader to the
    // site's hash address for the mod. A missing site is a log line, not a
    // failed run.
    final without = PublicDataBuilder(
      outputPath: p.join(dir.path, 'outputs-without-site'),
      idStore: idStore,
      sitePath: p.join(dir.path, 'no-site-here'),
    );
    await without.write(without.build(
      mods: catalogOf([forumMod(name: 'Nexerelin')], bundle: bundleOf()),
      bundle: bundleOf(),
    ));

    final html = File(p.join(without.modsDir, 'nexerelin', 'index.html'))
        .readAsStringSync();
    expect(html, contains('<title>Nexerelin | Starmodder</title>'));
    expect(html, contains('../../#/mods/nexerelin'));
  });

  test('a mod that is gone loses its little page as well', () async {
    await builder.write(buildFrom(
      mods: [forumMod(), forumMod(name: 'Second Mod', topicId: 100)],
      bundle: bundleOf(),
    ));
    expect(
        Directory(p.join(builder.modsDir, 'second-mod')).existsSync(), isTrue);

    await builder.write(buildFrom(mods: [forumMod()], bundle: bundleOf()));
    expect(
        Directory(p.join(builder.modsDir, 'second-mod')).existsSync(), isFalse);
    expect(
        Directory(p.join(builder.modsDir, 'nexerelin')).existsSync(), isTrue);
  });

  test('a mod that is gone loses its page on the next write', () async {
    await builder.write(buildFrom(
      mods: [forumMod(), forumMod(name: 'Second Mod', topicId: 100)],
      bundle: bundleOf(),
    ));
    expect(
        File(p.join(builder.modsDir, 'second-mod.json')).existsSync(), isTrue);

    await builder.write(buildFrom(mods: [forumMod()], bundle: bundleOf()));
    expect(
        File(p.join(builder.modsDir, 'nexerelin.json')).existsSync(), isTrue);
    expect(
        File(p.join(builder.modsDir, 'second-mod.json')).existsSync(), isFalse);
  });

  test("other names are kept per person, not pooled across a mod's authors",
      () {
    // Kaleidoscope credits two people: SirHartley made the mod, pixel_rice_bowl
    // made the textures. When other names were one list for the whole mod, the
    // author page read it as one person and said SirHartley was also known as
    // pixel_rice_bowl.
    final mod = ScrapedMod(
      name: 'Nexerelin',
      gameVersionReq: '0.98a',
      authorsList: const ['Histidine', 'Zaphide'],
      sources: const [ModSource.Index],
      urls: {
        ModUrlType.Forum:
            'https://fractalsoftworks.com/forum/index.php?topic=9175.0',
      },
    );

    final record =
        buildFrom(mods: [mod], bundle: bundleOf()).list.mods.single;

    expect(record.otherAuthorNames.keys, ['Histidine']);
    expect(record.otherAuthorNames['Histidine'], contains('histidine_my'));
    expect(record.otherAuthorNames.containsKey('Zaphide'), isFalse);
    expect(
      record.otherAuthorNames.values.expand((names) => names),
      isNot(contains('Zaphide')),
    );
  });

  test('mods.json stays under 2 MB for a mod set the size of the real one', () {
    // The real set is around 1,100 mods, now that a thread the merge never saw
    // is published too. Twelve hundred, each with a long name, a full-length
    // summary, an AI summary beside it, several authors and categories, two
    // pictures (one from the post and one from Discord, since the reader can
    // ask for either), the day its thread was last posted on, and a TriOS link
    // for its download, is the worst case the browse page has to fetch whole —
    // a TriOS link carries the mod's details packed into the address, and the
    // longest real one runs to about 850 characters. One mod in ten also says
    // AI was used for three things; a scan of the real posts found 50 to 75
    // that say anything about AI use at all.
    final mods = [
      for (var i = 0; i < 1200; i++)
        ScrapedMod(
          name: 'A Rather Long Starsector Mod Name Number $i',
          summary: 'A one-line summary of what this mod does, written out at '
              'about the length the longest real ones run to, so the count is '
              'not flattered by short text. Mod number $i.',
          gameVersionReq: '0.98a',
          authorsList: const ['Some Author', 'Another Author'],
          categories: const ['Faction Mods', 'Ship Packs'],
          urls: {
            ModUrlType.Forum:
                'https://fractalsoftworks.com/forum/index.php?topic=$i.0',
          },
          images: {
            'a': Image(
              id: 'a',
              url: 'https://fractalsoftworks.com/forum/index.php?action='
                  'dlattach;topic=$i.0;attach=12345;image',
            ),
          },
        ),
    ];

    final trilink = 'https://trilink.wispborne.com/open.html?mod='
        '${'%7B%22url%22%3A%22https%3A%2F%2Fraw.githubusercontent.com%2F' * 4}';
    final data = buildFrom(
      mods: mods,
      bundle: bundleOf(index: [
        for (var i = 0; i < 1200; i++)
          thread(
            topicId: i,
            lastPostDate: 'August 12, 2026, 04:15:02 PM',
            llmMods: [
              LlmMod(
                name: 'A Rather Long Starsector Mod Name Number $i',
                image: 'https://cdn.discordapp.com/attachments/1090000000/'
                    '10900000$i/a-rather-long-screenshot-name-$i.png',
                downloads: [
                  LlmDownload(
                    url: '$trilink$i',
                    kind: LlmDownloadKind.trios,
                    requiresManualStep: true,
                  ),
                ],
                extras: LlmExtras(
                  summary: LlmModSummary(
                    sentence: 'The sentence an AI wrote about this mod, at '
                        'about the length these run to. Every mod carries one '
                        'beside its own summary, since the reader can ask for '
                        'either. Mod number $i.',
                  ),
                  aiUse: i % 10 != 0 ? null : LlmAiUse(
                    quote: 'Portraits, music and code were made with AI.',
                    usesAi: true,
                    uses: [
                      LlmAiUseEntry(area: AiUseArea.portraits),
                      LlmAiUseEntry(area: AiUseArea.music),
                      LlmAiUseEntry(area: AiUseArea.code),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ]),
    );
    final bytes = utf8
        .encode(const JsonEncoder.withIndent('  ').convert(data.list.toMap()))
        .length;

    expect(data.list.mods, hasLength(1200));
    expect(bytes, lessThan(2 * 1024 * 1024),
        reason: 'mods.json came to ${(bytes / 1024).round()} KB');
    expect(data.list.mods.first.bestDownload, isNotNull,
        reason: 'the worst case has to include what a card downloads');
    expect(data.list.mods.first.threadLastPostOn, isNotNull,
        reason: 'the day a thread was last posted on is one more field on the '
            'file with the size limit, so the worst case carries it');
    expect(data.list.mods.first.aiUses, hasLength(3));
  });

  test('nothing internal reaches the published files', () async {
    final data = buildFrom(
      mods: [forumMod()],
      bundle: bundleOf(
        index: [
          thread(llmMods: [
            LlmMod(
              name: 'Nexerelin',
              downloads: [
                LlmDownload(
                  url: 'https://example.com/mod.zip',
                  resolvedDirectUrl: 'https://example.com/mod.zip',
                  confidence: 'high',
                ),
              ],
              extras: LlmExtras(version: '0.12.2'),
            ),
          ]),
        ],
        details: {
          '9175': QbModDetail(
            topicId: 9175,
            contentHtml: '<p>the whole post</p>',
            images: [
              ImageRef(
                originalUrl: 'https://example.com/shot.png',
                localPath: r'F:\qb_data\images\9175\shot.png',
              ),
            ],
          ),
        },
      ),
    );
    await builder.write(data);

    final published = [
      File(builder.modsFilePath).readAsStringSync(),
      File(builder.updatesFilePath).readAsStringSync(),
      File(p.join(builder.modsDir, 'nexerelin.json')).readAsStringSync(),
    ].join('\n');

    // Config keys, tokens and anything only the scraper cares about.
    for (final banned in [
      'qb_data',
      'config.properties',
      'apiToken',
      'authToken',
      'discord_auth',
      'confidence',
      'runId',
      'localPath',
      'isPlaceholderDetail',
      'contentHtml',
      'scrapedAt',
    ]) {
      expect(published.contains(banned), isFalse,
          reason: '"$banned" reached the published files');
    }

    // No Windows or POSIX local path, either.
    expect(RegExp(r'[A-Za-z]:\\\\').hasMatch(published), isFalse);
    expect(published.contains(dir.path.replaceAll(r'\', r'\\')), isFalse);
  });

  test('every record in the list has a file, and the two agree', () async {
    final data = buildFrom(
      mods: [forumMod(), forumMod(name: 'Second Mod', topicId: 100)],
      bundle: bundleOf(),
    );
    await builder.write(data);

    final list = PublicModListMapper.fromJson(
        File(builder.modsFilePath).readAsStringSync());
    for (final mod in list.mods) {
      final file = File(p.join(builder.modsDir, '${mod.id}.json'));
      expect(file.existsSync(), isTrue, reason: '${mod.id} has no page');
    }
  });

  group('the day a mod was added', () {
    test('is the day the forum thread was posted', () {
      final data = buildFrom(
        mods: [forumMod()],
        bundle: bundleOf(
          index: [thread(createdDate: 'May 04, 2014, 01:33:25 AM')],
        ),
      );

      expect(data.list.mods.single.addedOn, '2014-05-04');
    });

    test('is the Discord message day for a mod that is only on Discord', () {
      final discordOnly = ScrapedMod(
        name: 'Quality Captains',
        authorsList: const ['Sundog'],
        sources: const [ModSource.Discord],
        urls: const {ModUrlType.Discord: 'https://discord.com/channels/1/2'},
        dateTimeCreated: DateTime.utc(2026, 6, 22, 13, 32),
      );

      final data = buildFrom(mods: [discordOnly], bundle: bundleOf());

      expect(data.list.mods.single.addedOn, '2026-06-22');
    });

    test('is the earliest date, not the latest', () {
      final onBoth = ScrapedMod(
        name: 'Nexerelin',
        authorsList: const ['Histidine'],
        sources: const [ModSource.Index, ModSource.Discord],
        urls: const {
          ModUrlType.Forum:
              'https://fractalsoftworks.com/forum/index.php?topic=9175.0',
        },
        // Announced on Discord this year; the thread has been up since 2014.
        dateTimeCreated: DateTime.utc(2026, 6, 22),
      );

      final data = buildFrom(
        mods: [onBoth],
        bundle: bundleOf(
          index: [thread(createdDate: 'May 04, 2014, 01:33:25 AM')],
        ),
      );

      expect(data.list.mods.single.addedOn, '2014-05-04');
    });

    test('is nothing at all when every mod was given its id in one go', () {
      // The id file is written in one batch, so "first seen today" here means
      // "was already here". A day nobody can stand behind is worse than none.
      final data = buildFrom(
        mods: [forumMod()],
        bundle: bundleOf(index: [thread()]),
      );

      expect(data.list.mods.single.addedOn, isNull);
    });

    test('falls back to the day we first saw a mod that came later', () {
      // A first run gives every mod an id on the same day.
      buildFrom(mods: [forumMod()], bundle: bundleOf(index: [thread()]));
      idStore.save();

      // A mod that turns up a day later, with no date of its own anywhere.
      final laterStore = ModIdStore(
        p.join(dir.path, 'data'),
        now: () => DateTime.utc(2030, 1, 2),
      )..load();
      final laterBuilder = PublicDataBuilder(
        outputPath: p.join(dir.path, 'outputs'),
        idStore: laterStore,
      );

      // Its thread was read, but the forum wrote the day as "Today", which
      // names no day.
      final laterBundle = bundleOf(
        index: [thread()],
        details: {
          '20': QbModDetail(topicId: 20, postDate: 'Today at 09:52:56 AM'),
        },
      );
      final data = laterBuilder.build(
        // The catalog hands out the newcomer's id from the same file the site
        // reads its first day from.
        mods: catalogOf([forumMod(), forumMod(name: 'Second Wave Options', topicId: 20)],
            bundle: laterBundle, ids: laterStore),
        bundle: laterBundle,
      );

      final newcomer =
          data.list.mods.firstWhere((m) => m.name == 'Second Wave Options');
      expect(newcomer.addedOn, '2030-01-02');
    });

    test('is nothing for an old thread we never read, even one listed later', () {
      // The mod index lists old threads whose posts were never saved. The day
      // we first listed one says nothing about when the mod came out.
      buildFrom(mods: [forumMod()], bundle: bundleOf(index: [thread()]));
      idStore.save();

      final laterStore = ModIdStore(
        p.join(dir.path, 'data'),
        now: () => DateTime.utc(2030, 1, 2),
      )..load();
      final laterBuilder = PublicDataBuilder(
        outputPath: p.join(dir.path, 'outputs'),
        idStore: laterStore,
      );

      final data = laterBuilder.build(
        mods: catalogOf(
            [forumMod(), forumMod(name: 'Apex Design Collective', topicId: 22704)],
            bundle: bundleOf(index: [thread()]),
            ids: laterStore),
        bundle: bundleOf(index: [thread()]),
      );

      final oldThread =
          data.list.mods.firstWhere((m) => m.name == 'Apex Design Collective');
      expect(oldThread.addedOn, isNull);
    });
  });
}
