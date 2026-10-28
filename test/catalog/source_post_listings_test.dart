import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:mod_repo_scraper/catalog/discord_posts.dart';
import 'package:mod_repo_scraper/catalog/forum_listing.dart';
import 'package:mod_repo_scraper/catalog/listing.dart';
import 'package:mod_repo_scraper/catalog/other_listings.dart';
import 'package:mod_repo_scraper/catalog/source_post.dart';
import 'package:mod_repo_scraper/catalog/source_post_listings.dart';
import 'package:test/test.dart';

/// A real topic: its summary, the author's opening posts and the LLM's real
/// answer, copied out of a real run into `test/catalog/fixtures/`.
class _Topic {
  final QbModSummary summary;
  final List<String> posts;
  final List<LlmMod> llmMods;

  _Topic(this.summary, this.posts, this.llmMods);

  factory _Topic.load(int topicId, {List<QbIndexLine>? indexLines}) {
    final json = jsonDecode(File('test/catalog/fixtures/$topicId.json').readAsStringSync()) as Map<String, dynamic>;
    final summary = QbModSummaryMapper.fromMap(json['summary'] as Map<String, dynamic>);
    return _Topic(
      indexLines == null ? summary : summary.copyWith(indexLines: indexLines, inModIndex: true),
      [for (final html in json['posts'] as List) html as String],
      [for (final m in json['llmMods'] as List) LlmModMapper.fromMap(m as Map<String, dynamic>)],
    );
  }

  String? get words => SourcePostListings.openingRunWords(SourcePost(
        kind: SourceKind.forum,
        id: '${summary.topicId}',
        title: summary.title,
        posts: [for (final html in posts) QbForumPost(contentHtml: html)],
      ));

  PostListings listings({required bool llmOn}) => SourcePostListings.combine(
        rules: forumRulesListing(summary),
        llmMods: llmOn ? llmMods : const [],
        postWords: words,
      );
}

List<String> _names(PostListings result) => [for (final l in result.listings) l.mod.name];

void main() {
  group('with the LLM off, every post gives exactly its rules listing', () {
    for (final topicId in [34161, 34457, 35651, 21968, 9035, 9175]) {
      test('topic $topicId', () {
        final result = _Topic.load(topicId).listings(llmOn: false);
        expect(result.listings, hasLength(1));
        expect(result.isCollection, isFalse);
        expect(result.listings.single.origin, ListingOrigin.rules);
        expect(result.listings.single.ref, SourcePostRef(kind: SourceKind.forum, id: '$topicId'));
      });
    }
  });

  test("topic 34161 is a Collection: Hartley's four mods, and no mod called the topic's name", () {
    final result = _Topic.load(34161).listings(llmOn: true);

    expect(result.isCollection, isTrue);
    expect(result.collection!.mod.name, "Hartley's Miscellaneous Mods");
    expect(_names(result), ['Useful.Tithes', 'Big Pilum Energy', 'Lost.Sector', 'Disco.Balls']);
    for (final listing in result.listings) {
      expect(listing.origin, ListingOrigin.llm);
      expect(listing.ref.llmModName, listing.mod.name);
      expect(listing.mod.getUrls()[ModUrlType.Forum], contains('topic=34161'));
      expect(listing.mod.gameVersionReq, '0.98a',
          reason: 'the post heads each mod "[0.98a] <name>", and the title has no version');
    }
  });

  test("a topic summary with no author takes the saved post's author", () {
    final summary = _Topic.load(34161).summary.copyWith(author: '');
    expect(forumRulesListing(summary).mod.authorsList, isEmpty);
    expect(forumRulesListing(summary, postAuthor: 'SirHartley').mod.authorsList, ['SirHartley']);
    expect(forumRulesListing(summary.copyWith(author: 'Hartley'), postAuthor: 'SirHartley').mod.authorsList,
        ['Hartley'], reason: "the summary's own author still wins");
  });

  test('topic 34457 is a Collection whose rules listing (which already has a page) is kept aside', () {
    final result = _Topic.load(34457).listings(llmOn: true);

    expect(result.isCollection, isTrue);
    expect(result.collection!.mod.name, 'Derelict Start, Remnant Start, Omega Start & Threat Start');
    expect(_names(result), ['Derelict Start', 'Remnant Start', 'Omega Start', 'Threat Start']);
  });

  test('topic 35651 gives its seven forks, though its title has no bracketed game version', () {
    final result = _Topic.load(35651).listings(llmOn: true);

    expect(result.listings, hasLength(7));
    expect(_names(result), contains("Kwin's Sector Industry Compilation"));
    expect(_names(result), contains('Stellar Networks'));
  });

  test('topic 21968 is one listing named from the first index line, its library and add-ons together', () {
    final result = _Topic.load(21968, indexLines: const [
      QbIndexLine(name: 'Midline Expansion', author: 'Yunru', gameVersion: '0.95a', category: 'Faction Mods'),
      QbIndexLine(name: 'Pirate Collection', author: 'Yunru', gameVersion: '0.95a', category: 'Faction Mods'),
      QbIndexLine(name: 'Yunru Mods', author: 'Yunru', gameVersion: '0.98a', category: 'Content Expansions'),
    ]).listings(llmOn: true);

    expect(result.isCollection, isFalse);
    expect(result.listings, hasLength(1), reason: 'the five add-ons are not mods of their own');
    final listing = result.listings.single;
    expect(listing.mod.name, 'Midline Expansion');
    expect(listing.mod.sources, [ModSource.Index]);
    expect(listing.otherNames, containsAll(['Pirate Collection', 'Yunru Mods']));
    expect(listing.origin, ListingOrigin.rulesAndLlm);
    expect(listing.ref.llmModName, 'YunruCore');
  });

  test('topic 9035 is one listing: "Red" carries the facts of "Red - the Oculian Armada"', () {
    final result = _Topic.load(9035, indexLines: const [
      QbIndexLine(name: 'Red', author: 'Protonus', gameVersion: '0.98a', category: 'Faction Mods'),
    ]).listings(llmOn: true);

    expect(result.listings, hasLength(1));
    final listing = result.listings.single;
    expect(listing.mod.name, 'Red', reason: 'the LLM cannot rename the rules listing');
    expect(listing.ref.llmModName, 'Red - the Oculian Armada');
    expect(listing.origin, ListingOrigin.rulesAndLlm);
  });

  test('a plain one-mod topic (Nexerelin, 9175) is its index line with the LLM joined on', () {
    final result = _Topic.load(9175, indexLines: const [
      QbIndexLine(name: 'Nexerelin', author: 'Histidine', gameVersion: '0.98a', category: 'Megamods'),
    ]).listings(llmOn: true);

    final listing = result.listings.single;
    expect(listing.mod.name, 'Nexerelin');
    expect(listing.mod.gameVersionReq, '0.98a');
    expect(listing.mod.categories, ['Megamods']);
    expect(listing.ref.llmModName, 'Nexerelin');
  });

  group('the combine rule on its own', () {
    Listing rules(String name, {List<String> otherNames = const []}) => Listing(
          mod: ScrapedMod(name: name, urls: const {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=1.0'}),
          ref: const SourcePostRef(kind: SourceKind.forum, id: '1'),
          otherNames: otherNames,
        );
    LlmMod main(String name, {List<String>? nicknames, bool download = true}) => LlmMod(
          name: name,
          nicknames: nicknames,
          downloads: download ? [LlmDownload(url: 'https://example.com/${Uri.encodeComponent(name)}.zip')] : const [],
        );
    const words = 'Useful.Tithes 1.0.a is here. Big Pilum Energy too. Disco.Balls and Lost.Sector. '
        'Formerly known as the Pirate Collection, now Yunru Pirates.';

    test('several mains, one matching the rules name: it joins, the others are their own', () {
      final result = SourcePostListings.combine(
        rules: rules('Useful.Tithes 1.0.a'),
        llmMods: [main('Useful.Tithes'), main('Big Pilum Energy'), main('Disco.Balls'), main('Lost.Sector')],
        postWords: words,
      );
      expect(result.isCollection, isFalse);
      expect(_names(result), ['Useful.Tithes 1.0.a', 'Big Pilum Energy', 'Disco.Balls', 'Lost.Sector']);
      expect(result.listings.first.origin, ListingOrigin.rulesAndLlm);
      expect(result.listings.first.ref.llmModName, 'Useful.Tithes');
    });

    test("a rules name that is an LLM mod's grounded former name joins that mod", () {
      final result = SourcePostListings.combine(
        rules: rules('Pirate Collection'),
        llmMods: [main('Yunru Pirates', nicknames: ['Pirate Collection']), main('Disco.Balls')],
        postWords: words,
      );
      expect(result.isCollection, isFalse);
      expect(result.listings.first.ref.llmModName, 'Yunru Pirates');
      expect(result.listings.first.mod.name, 'Pirate Collection');
    });

    test('a main mod the post never names, or with no download, does not count', () {
      final result = SourcePostListings.combine(
        rules: rules('Big Pilum Energy'),
        llmMods: [main('Invented Mod'), main('Disco.Balls', download: false)],
        postWords: words,
      );
      expect(result.listings, hasLength(1));
      expect(result.listings.single.origin, ListingOrigin.rules);
      expect(result.isCollection, isFalse);
    });

    test('a game version written before a name belongs to that name only', () {
      const headings = '[0.97a] Lost.Sector Extended\nMore of it.\n\n[0.98a] Disco.Balls 1.1.c\nLamps.\n\n'
          '[0.95.1a] Useful.Tithes - pay up\nTithes.\n\nLost.Sector is here too.';
      final result = SourcePostListings.combine(
        rules: rules('Hartley'),
        llmMods: [main('Lost.Sector'), main('Disco.Balls'), main('Useful.Tithes')],
        postWords: headings,
      );
      final versions = {for (final l in result.listings) l.mod.name: l.mod.gameVersionReq};
      expect(versions, {'Lost.Sector': null, 'Disco.Balls': '0.98a', 'Useful.Tithes': '0.95.1a'});
    });

    test('add-ons, variants and separate mods make no listings', () {
      final result = SourcePostListings.combine(
        rules: rules('Disco.Balls'),
        llmMods: [
          main('Disco.Balls'),
          LlmMod(name: 'Big Pilum Energy', role: LlmModRole.addon, downloads: [LlmDownload(url: 'https://e/a.zip')]),
          LlmMod(name: 'Lost.Sector', role: LlmModRole.variant, downloads: [LlmDownload(url: 'https://e/b.zip')]),
          LlmMod(name: 'Useful.Tithes', role: LlmModRole.separate, downloads: [LlmDownload(url: 'https://e/c.zip')]),
        ],
        postWords: words,
      );
      expect(_names(result), ['Disco.Balls']);
    });
  });

  group("a list of mods that links to each mod's own thread (topic 36175)", () {
    const hubWords = "Oddisz's Mods. Every mod I've made is in this list. Cloning: a cloning industry. "
        'Sol Renewed: adds Sol. Coalesced Little Mods (no thread yet, links to GitHub).';
    final hub = Listing(
      mod: const ScrapedMod(
        name: "Oddish's Mods",
        urls: {ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=36175.0'},
      ),
      ref: const SourcePostRef(kind: SourceKind.forum, id: '36175'),
    );
    LlmMod linking(String name, List<String> urls) =>
        LlmMod(name: name, downloads: [for (final url in urls) LlmDownload(url: url)]);
    String thread(int topic) =>
        'https://fractalsoftworks.com/forum/index.php?PHPSESSID=49bdf1e17287b62ad790769849bb727e&topic=$topic';
    const pack = 'https://github.com/andrzejsokolowski/starsector-coalesced-little-mods/releases/latest';
    const inBuild = {'36175', '35130', '35983'};

    test('a mod that only links to its own thread is that thread\'s mod; the rest is a Collection', () {
      final result = SourcePostListings.combine(
        rules: hub,
        llmMods: [
          linking('Cloning', [thread(35130)]),
          linking('Sol Renewed', [thread(35983)]),
          linking('Coalesced Little Mods', [pack]),
        ],
        postWords: hubWords,
        forumTopicsInBuild: inBuild,
      );

      expect(_names(result), ['Coalesced Little Mods']);
      expect(result.isCollection, isTrue, reason: "no mod is called the list's name");
      expect(result.pointers, {
        'forum:36175#Cloning': 'forum:35130',
        'forum:36175#Sol Renewed': 'forum:35983',
      });
    });

    test('a list whose every mod has its own thread gives no listings at all', () {
      final result = SourcePostListings.combine(
        rules: hub,
        llmMods: [linking('Cloning', [thread(35130)]), linking('Sol Renewed', [thread(35983)])],
        postWords: hubWords,
        forumTopicsInBuild: inBuild,
      );
      expect(result.listings, isEmpty);
      expect(result.isCollection, isTrue);
    });

    test('a thread we do not have, a real file beside the link, or a file attached to another topic: still a mod here',
        () {
      final result = SourcePostListings.combine(
        rules: hub,
        llmMods: [
          linking('Cloning', [thread(99999)]),
          linking('Sol Renewed', [thread(35983), 'https://example.com/sol.zip']),
          linking('Coalesced Little Mods',
              ['https://fractalsoftworks.com/forum/index.php?action=dlattach;topic=35130.0;attach=1']),
        ],
        postWords: hubWords,
        forumTopicsInBuild: inBuild,
      );
      expect(_names(result), ['Cloning', 'Sol Renewed', 'Coalesced Little Mods']);
      expect(result.pointers, isEmpty);
    });

    test("a post with one mod linking elsewhere is left alone: an old thread's link to its new one", () {
      final result = SourcePostListings.combine(
        rules: hub,
        llmMods: [linking('Cloning', [thread(35130)])],
        postWords: hubWords,
        forumTopicsInBuild: inBuild,
      );
      expect(result.listings.single.ref.llmModName, 'Cloning');
      expect(result.pointers, isEmpty);
    });

    test('a Discord thread is left alone: the merge joins it to the forum mod by name', () {
      final discordRules = Listing(
        mod: const ScrapedMod(name: 'Two Mods Thread'),
        ref: const SourcePostRef(kind: SourceKind.discord, id: '900'),
      );
      final result = SourcePostListings.combine(
        rules: discordRules,
        llmMods: [linking('Cloning', [thread(35130)]), linking('Sol Renewed', [thread(35983)])],
        postWords: hubWords,
        forumTopicsInBuild: inBuild,
      );
      expect(_names(result), ['Cloning', 'Sol Renewed']);
      expect(result.pointers, isEmpty);
    });
  });

  group('Discord threads go through the same rule', () {
    final thread = DiscordThreadPost(
      threadId: '900',
      name: 'Two Mods Thread',
      url: 'https://discord.com/channels/1/900/900',
      forumUrl: 'https://fractalsoftworks.com/forum/index.php?topic=34161',
      messages: const [
        DiscordOpeningMessage(id: '900', content: 'Big Pilum Energy: https://e/bpe.zip\nLost.Sector: https://e/ls.zip'),
      ],
    );
    final discordMod = ScrapedMod(
      name: 'Two Mods Thread',
      authorsList: const ['SirHartley'],
      sources: const [ModSource.Discord],
      urls: const {
        ModUrlType.Discord: 'https://discord.com/channels/1/900/900',
        ModUrlType.Forum: 'https://fractalsoftworks.com/forum/index.php?topic=34161',
        ModUrlType.DirectDownload: 'https://e/bpe.zip',
      },
    );
    final rules = discordRulesListing(discordMod)!;
    final words = SourcePostListings.openingRunWords(thread.toSourcePost());

    test('with no LLM answer, one rules listing referring to the thread', () {
      final result = SourcePostListings.combine(rules: rules, llmMods: const [], postWords: words);
      expect(result.listings.single.ref, const SourcePostRef(kind: SourceKind.discord, id: '900'));
      expect(result.listings.single.mod, discordMod);
    });

    test('one mod: the thread is that mod, whatever it is called', () {
      final result = SourcePostListings.combine(
        rules: rules,
        llmMods: [LlmMod(name: 'Big Pilum Energy', downloads: [LlmDownload(url: 'https://e/bpe.zip')])],
        postWords: words,
      );
      expect(result.listings.single.mod.name, 'Two Mods Thread');
      expect(result.listings.single.ref.llmModName, 'Big Pilum Energy');
    });

    test("two mods, neither the thread's name: a Collection, each mod keeping the thread's forum link", () {
      final result = SourcePostListings.combine(
        rules: rules,
        llmMods: [
          LlmMod(name: 'Big Pilum Energy', downloads: [LlmDownload(url: 'https://e/bpe.zip')]),
          LlmMod(name: 'Lost.Sector', downloads: [LlmDownload(url: 'https://e/ls.zip')]),
        ],
        postWords: words,
      );
      expect(result.isCollection, isTrue);
      expect(_names(result), ['Big Pilum Energy', 'Lost.Sector']);
      for (final listing in result.listings) {
        expect(listing.mod.getUrls()[ModUrlType.Forum], contains('topic=34161'));
        expect(listing.mod.getUrls()[ModUrlType.Discord], contains('/900/'));
        expect(listing.mod.getUrls().containsKey(ModUrlType.DirectDownload), isFalse,
            reason: "the thread's one download link belongs to whichever mod the rules picked it for");
        expect(listing.mod.sources, [ModSource.Discord]);
      }
    });
  });

  test('a Nexus result is one listing referring to its page', () {
    const mod = ScrapedMod(name: 'X', urls: {ModUrlType.NexusMods: 'https://www.nexusmods.com/starsector/mods/12'});
    expect(nexusListing(mod)!.ref, const SourcePostRef(kind: SourceKind.nexus, id: '12'));
  });
}
