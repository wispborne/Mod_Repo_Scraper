import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../bot/scraper/qb/json_data_store.dart';
import '../bot/scraper/qb/llm/extraction_store.dart';
import '../bot/scraper/qb/mod_thread_filter.dart';
import '../bot/scraper/qb/models/post_extraction.dart';
import '../bot/scraper/scraped_mod.dart';
import 'discord_posts.dart';
import 'forum_listing.dart';
import 'listing.dart';
import 'other_listings.dart';
import 'source_post.dart';
import 'source_post_listings.dart';

/// Every listing the merge reads, and the Collections found on the way.
class CatalogListings {
  final List<Listing> listings;

  /// The rules listings of posts that turned out to be Collections. Each one's
  /// permanent id, if it already had one, stays reserved for a page listing the
  /// mods it holds.
  final List<Listing> collections;

  /// How many forum topics and Discord threads gave listings, for the log.
  final int forumTopics;
  final int discordThreads;
  final int nexusPages;

  const CatalogListings({
    this.listings = const [],
    this.collections = const [],
    this.forumTopics = 0,
    this.discordThreads = 0,
    this.nexusPages = 0,
  });
}

/// Reads what the merge needs from saved files only — the QB store, the
/// Discord and Nexus results, `discord-posts.json` and the LLM's answers — and
/// turns each source post into its listings. No network call is made.
class CatalogInputs {
  CatalogInputs._();

  static final Logger _log = Logger('CatalogInputs');

  /// [qbDataPath] holds the QB store, the LLM's answers and the saved Discord
  /// threads. [discordMods] and [nexusMods] are what those two readers made,
  /// from their cache files or a fresh scrape.
  static Future<CatalogListings> read({
    required String qbDataPath,
    List<ScrapedMod> discordMods = const [],
    List<ScrapedMod> nexusMods = const [],
  }) async {
    final llmStore = LlmExtractionStore(qbDataPath);
    await llmStore.load();

    final listings = <Listing>[];
    final collections = <Listing>[];

    // --- Forum: every topic the bundle keeps ---
    var forumTopics = 0;
    final storeDir = Directory(qbDataPath);
    if (File(p.join(qbDataPath, 'mods-index.json')).existsSync() && storeDir.existsSync()) {
      final store = JsonDataStore(qbDataPath);
      for (final summary in await store.loadIndex()) {
        final answer = llmStore.get(summary.topicId);
        if (!keepThreadInBundle(title: summary.title, llmSaidMod: answer?.isMod, inModIndex: summary.inModIndex)) {
          continue;
        }
        final detail = await store.loadDetail(summary.topicId);
        // A topic whose post was never saved is only a title on a board page,
        // and the bundle leaves it out for the same reason. The mod index is
        // the exception: its line names the mod, its author and its version,
        // and some indexed topics sit on boards only members can read.
        if (detail == null && !summary.inModIndex) continue;
        final words = detail == null
            ? summary.title
            : SourcePostListings.openingRunWords(SourcePost.fromForumDetail(detail));
        final result = SourcePostListings.combine(
          rules: forumRulesListing(summary),
          llmMods: answer?.mods ?? const <LlmMod>[],
          postWords: words,
        );
        listings.addAll(result.listings);
        if (result.collection != null) collections.add(result.collection!);
        forumTopics++;
      }
    }

    // --- Discord: each thread the reader made a mod from ---
    var discordThreads = 0;
    DiscordPostsFile saved;
    try {
      saved = DiscordPostsFile.read(File(p.join(qbDataPath, DiscordPostsFile.fileName)));
    } catch (e) {
      _log.warning('Could not read the saved Discord threads, so Discord mods '
          'are merged from the rules alone: $e');
      saved = const DiscordPostsFile();
    }
    final knownThreads = saved.threads.keys.toSet();
    for (final mod in discordMods) {
      final rules = discordRulesListing(mod, knownThreadIds: knownThreads);
      if (rules == null) {
        // No thread to name, so nothing to look up; it still goes in.
        listings.add(Listing(mod: mod, ref: const SourcePostRef(kind: SourceKind.discord, id: '')));
        continue;
      }
      final thread = saved.threads[rules.ref.id];
      final answer = llmStore.getDiscord(rules.ref.id);
      final result = SourcePostListings.combine(
        rules: rules,
        // A thread saved in the old format has no opening run, so its answer —
        // if one somehow exists — cannot be checked against the author's words.
        llmMods: thread == null ? const [] : (answer?.mods ?? const <LlmMod>[]),
        postWords: thread == null ? null : SourcePostListings.openingRunWords(thread.toSourcePost()),
      );
      listings.addAll(result.listings);
      if (result.collection != null) collections.add(result.collection!);
      discordThreads++;
    }

    // --- Nexus: one listing per page ---
    var nexusPages = 0;
    for (final mod in nexusMods) {
      final listing = nexusListing(mod) ??
          Listing(mod: mod, ref: const SourcePostRef(kind: SourceKind.nexus, id: ''));
      listings.add(listing);
      nexusPages++;
    }

    return CatalogListings(
      listings: listings,
      collections: collections,
      forumTopics: forumTopics,
      discordThreads: discordThreads,
      nexusPages: nexusPages,
    );
  }
}
