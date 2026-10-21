import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../bot/scraper/qb/download_resolver.dart';
import '../bot/scraper/qb/json_data_store.dart';
import '../bot/scraper/qb/llm/extraction_store.dart';
import '../bot/scraper/qb/mod_thread_filter.dart';
import '../bot/scraper/qb/models/mod_summary.dart';
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

  /// Forum topics left out because the LLM said they are not a mod and the
  /// rules found nothing to download in them, by topic id, with their titles.
  /// Kept so the comparison with the published site can tell a page dropped
  /// on purpose from one lost by mistake.
  final Map<String, String> notMods;

  /// Mods on a forum topic that only link to a topic of their own, so they
  /// made no listing (see `SourcePostListings.combine`): the key of the ref
  /// each would have had to the key of the topic it links to.
  final Map<String, String> pointers;

  /// How many forum topics and Discord threads gave listings, for the log.
  final int forumTopics;
  final int discordThreads;
  final int nexusPages;

  const CatalogListings({
    this.listings = const [],
    this.collections = const [],
    this.notMods = const {},
    this.pointers = const {},
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
    final notMods = <String, String>{};

    // Only the saved answers are read; the client is never used.
    final client = http.Client();
    final downloads = QbDownloadResolver(client: client, dataPath: qbDataPath);
    try {
      await downloads.loadCache();
    } finally {
      client.close();
    }

    final pointers = <String, String>{};

    // --- Forum: every topic the bundle keeps ---
    var forumTopics = 0;
    final storeDir = Directory(qbDataPath);
    if (File(p.join(qbDataPath, 'mods-index.json')).existsSync() && storeDir.existsSync()) {
      final store = JsonDataStore(qbDataPath);
      // Read first and combined after, because a post can point at another
      // topic's mod only once every topic in the build is known.
      final kept = <(QbModSummary, LlmStoreEntry?, String?)>[];
      for (final summary in await store.loadIndex()) {
        final answer = llmStore.get(summary.topicId);
        if (!keepThreadInBundle(title: summary.title, llmSaidMod: answer?.isMod, inModIndex: summary.inModIndex)) {
          continue;
        }
        if (!keepThreadInCatalog(
          title: summary.title,
          llmSaidMod: answer?.isMod,
          inModIndex: summary.inModIndex,
          hasDownload: downloads.getCachedCandidates(summary.topicId)?.isNotEmpty ?? false,
        )) {
          notMods['${summary.topicId}'] = summary.title;
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
        kept.add((summary, answer, words));
      }
      final topicsInBuild = {for (final (summary, _, _) in kept) '${summary.topicId}'};
      for (final (summary, answer, words) in kept) {
        final result = SourcePostListings.combine(
          rules: forumRulesListing(summary),
          llmMods: answer?.mods ?? const <LlmMod>[],
          postWords: words,
          forumTopicsInBuild: topicsInBuild,
        );
        listings.addAll(result.listings);
        if (result.collection != null) collections.add(result.collection!);
        pointers.addAll(result.pointers);
        forumTopics++;
      }
      if (pointers.isNotEmpty) {
        _log.info('${pointers.length} mod(s) on a list of mods only link to a forum topic '
            'of their own, so they are that topic\'s mod: ${pointers.keys.join(', ')}');
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

    if (notMods.isNotEmpty) {
      _log.info('Left out ${notMods.length} forum topic(s) the LLM said are not '
          'a mod and that have nothing to download.');
    }

    return CatalogListings(
      listings: listings,
      collections: collections,
      notMods: notMods,
      pointers: pointers,
      forumTopics: forumTopics,
      discordThreads: discordThreads,
      nexusPages: nexusPages,
    );
  }
}
