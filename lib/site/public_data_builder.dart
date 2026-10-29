import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../bot/scraper/mod_merger.dart';
import '../bot/scraper/mod_repo_utils.dart';
import '../bot/scraper/qb/models/assumed_download.dart';
import '../bot/scraper/qb/models/forum_data_bundle.dart';
import '../bot/scraper/qb/models/forum_date.dart';
import '../bot/scraper/qb/models/mod_detail.dart';
import '../bot/scraper/qb/models/mod_summary.dart';
import '../bot/scraper/qb/llm/picture_caption_store.dart';
import '../bot/scraper/qb/llm/picture_captioner.dart';
import '../bot/scraper/qb/models/post_extraction.dart';
import '../bot/scraper/scraped_mod.dart';
import '../catalog/discord_posts.dart';
import '../catalog/fact_choice.dart';
import '../catalog/listing.dart';
import '../catalog/mod_catalog.dart';
import '../catalog/source_post.dart';
import 'catalog_extras.dart';
import 'days.dart';
import 'description_slice.dart';
import 'discord_markdown.dart';
import 'discord_download.dart';
import 'display_name.dart';
import 'download_order.dart';
import 'gallery_filter.dart';
import 'guide_page_html.dart';
import 'not_found_page_html.dart';
import 'mod_id_store.dart';
import 'mod_name_match.dart';
import 'models/mod_release.dart';
import 'models/public_mod.dart';
import 'mod_page_html.dart';
import 'models/public_mod_detail.dart';
import 'update_note.dart';
import 'post_html.dart';
import 'public_categories.dart';
import 'release_feed_xml.dart';
import 'sitemap.dart';
import 'release_state_store.dart';
import 'requirement_names.dart';
import 'summary_text.dart';

/// One catalog mod with its forum thread and its facts looked up.
class _JoinedMod {
  final ScrapedMod mod;
  final String id;

  /// The forum topic this mod was read from, from its saved source posts. Null
  /// when it has no forum post.
  final String? topicId;

  /// The thread this mod was read out of, when the LLM found it as one of the
  /// mods on that thread rather than the thread being about it.
  final String? partOfThreadTitle;

  /// The name a reader sees. See [PublicDataBuilder._shownNameFor].
  final String shownName;

  /// The mod's facts, put together from the LLM's answers for each of its
  /// source posts. Null when none of them has one.
  final LlmMod? facts;

  /// The LLM's answer for the mod's Discord thread, when it has one. A
  /// Discord-only mod's add-ons are read off it.
  final DiscordThreadAnswer? discordAnswer;

  const _JoinedMod({
    required this.mod,
    required this.id,
    required this.shownName,
    this.topicId,
    this.partOfThreadTitle,
    this.facts,
    this.discordAnswer,
  });
}

/// The two pictures a mod can be shown with: the one the site shows, and the
/// one from the post announcing the mod on Discord or Nexus. [announcement] is
/// null when it is already what [shown] holds.
class _Pictures {
  final String? shown;
  final String? announcement;

  const _Pictures({required this.shown, required this.announcement});
}

/// One forum post, read once.
///
/// The gallery wants to know how big the post said its pictures are, and the
/// description wants the post as both formatted HTML and plain words. Reading a
/// post is the dear part of a build — 900 of them every run — so it is read
/// once here and the answers passed around.
class _ReadPost {
  /// The first post rebuilt from the tags the site publishes, or null when the
  /// mod has no forum post. A single-mod thread keeps this as its full
  /// description, independently of the excerpt used for its listing summary.
  final String? html;

  /// The same words with the tags taken off.
  final String? words;

  /// Every one of the author's opening posts, each rebuilt the same way. Used
  /// to cut out a focused description of one mod.
  final List<String> postsHtml;

  /// The words of every opening post, run together.
  ///
  /// Anything that checks the post *named* something — a mod on a shared
  /// thread, a mod this one needs — reads this rather than the first post
  /// alone, because a name is just as real in the author's second post.
  final String? allWords;

  /// How wide the posts said each of their pictures is.
  final Map<String, int> pictureSizes;

  _ReadPost._(
    this.html,
    this.words,
    this.postsHtml,
    this.allWords,
    this.pictureSizes,
  );

  factory _ReadPost(QbModDetail? detail) {
    final posts = detail?.openingPosts ?? const <QbForumPost>[];
    final postsHtml = <String>[];
    final words = <String>[];
    final sizes = <String, int>{};
    String? firstHtml;
    String? firstWords;

    for (final (index, post) in posts.indexed) {
      final html = cleanPostHtml(post.contentHtml);
      if (html != null) postsHtml.add(html);
      final plain = plainWordsOf(html);
      if (index == 0) {
        firstHtml = html;
        firstWords = plain;
      }
      if (plain != null) words.add(plain);
      sizes.addAll(pictureSizesInPost(post.contentHtml));
    }

    return _ReadPost._(
      firstHtml,
      firstWords,
      postsHtml,
      words.isEmpty ? null : words.join('\n\n'),
      sizes,
    );
  }
}

/// The three files the public website reads, held together before they are
/// written.
class PublicSiteData {
  final PublicModList list;
  final Map<String, PublicModDetail> details;
  final ModReleaseFeed feed;

  /// The Collections that keep an address from before they were known to be
  /// one. Each gets a page at that address linking to the mods it holds.
  final List<PublicCollection> collections;

  /// Old addresses that lead to another mod's page, each with the id of that
  /// mod. Only ids whose mod has a page here.
  final Map<String, String> movedIds;

  /// Ids of taken-down mods and Collections with no page or redirect here.
  /// Each gets files that show the not-found view.
  /// Cloudflare Pages keeps serving deleted files for up to a week.
  /// Changed files are served right away.
  final Set<String> goneIds;

  /// Requirement names with no rule match or saved match to one of our mods.
  /// Keyed by [requirementKey]. Each entry has the first spelling seen and the
  /// number of mods that used it. Includes names the LLM said match none of ours.
  final Map<String, ({String written, int count})> unmatchedNeeds;

  /// Every library and every mod required by at least
  /// [PublicDataBuilder.requiredByAtLeast] other mods. The LLM chooses from
  /// this list when asked to match a requirement name.
  final List<RequiredModNames> requiredMods;

  /// Every requirement name the build looked up, by [requirementKey], and
  /// which mod it was matched to and how. Written to the viewer's report.
  final Map<String, RequirementNameSeen> requirementNames;

  const PublicSiteData({
    required this.list,
    required this.details,
    required this.feed,
    this.collections = const [],
    this.movedIds = const {},
    this.goneIds = const {},
    this.unmatchedNeeds = const {},
    this.requiredMods = const [],
    this.requirementNames = const {},
  });
}

/// A Collection's page: the post's name and where it is, and the mods it holds.
class PublicCollection {
  final String id;
  final String name;
  final String? forumUrl;
  final String? discordUrl;
  final List<PublicMod> mods;

  const PublicCollection({
    required this.id,
    required this.name,
    this.forumUrl,
    this.discordUrl,
    this.mods = const [],
  });

  /// `mods/<id>.json` for a Collection. A mod's file has a `listing`; this has
  /// a `collection`, which is how the page tells the two apart.
  Map<String, dynamic> toMap() => {
        'collection': {
          'id': id,
          'name': name,
          if (forumUrl != null) 'forumUrl': forumUrl,
          if (discordUrl != null) 'discordUrl': discordUrl,
          'mods': [for (final mod in mods) mod.toMap()],
        },
      };
}

/// Builds the website's data files out of what the scraper already has: the
/// catalog (`mod-catalog.json`) and the forum data bundle
/// (`mod-catalog-details.json`). Neither is changed by this — they are read,
/// and the website's files are written beside them.
///
/// The two are joined through each mod's saved source posts: a forum topic id
/// and the LLM's name for the mod on it, or a Discord thread id and the same.
/// Nothing here decides by name which LLM mod belongs to which mod, and nothing
/// adds a mod the catalog does not have — the catalog has done both. A mod
/// with no forum thread still gets a record and a page, with the bundle-only
/// fields left out rather than guessed at.
///
/// Nothing from `config.properties` reaches these files. No token, no local
/// path, no run id, no confidence score, and no flag that only means something
/// inside the scraper.
class PublicDataBuilder {
  /// The folder the existing outputs go in. The website's files go in a `site`
  /// folder under it.
  final String outputPath;

  /// The website's own files — the folder holding `index.html`, the stylesheet
  /// and the scripts. Each mod's page is that `index.html` with one region of
  /// its head swapped, so the site's chrome is written once and a mod's page
  /// can never drift from the rest of the site. The same folder
  /// `publish_site_path` names; both default to `site`.
  final String sitePath;

  /// Read for the day a mod was first seen, the last fallback for when it was
  /// added. Ids come from the catalog; nothing is handed out here.
  final ModIdStore? idStore;

  /// What the model saw in each post's pictures, and how well it judged each
  /// would do on a mod's card. This is what picks the card picture on a
  /// thread about one mod, so the same picture is chosen on every build.
  /// Left out, the card picture is chosen as it was before pictures were
  /// looked at.
  final PictureCaptionStore? pictureCaptions;

  /// Saved matches for requirement names the rules cannot match.
  /// If omitted, only the rules are used.
  final RequirementNameStore? requirementNames;

  /// The minimum number of mods that must require a non-library mod
  /// for it to be included in the list of required mods.
  static const requiredByAtLeast = 3;

  final Logger _log;

  PublicDataBuilder({
    required this.outputPath,
    this.idStore,
    this.sitePath = 'site',
    this.pictureCaptions,
    this.requirementNames,
    Logger? logger,
  }) : _log = logger ?? Logger('PublicDataBuilder');

  /// Where the website's files are written.
  String get siteDir => p.join(outputPath, 'site');

  String get modsFilePath => p.join(siteDir, 'mods.json');

  /// Mod details for TriOS, saved beside `mod-catalog.json`.
  /// The site does not read this file.
  String get catalogExtrasFilePath => p.join(outputPath, catalogExtrasFileName);

  String get updatesFilePath => p.join(siteDir, 'updates.json');

  /// The same releases as a feed file, for anyone who would rather subscribe
  /// than visit.
  String get updatesXmlFilePath => p.join(siteDir, 'updates.xml');

  String get modsDir => p.join(siteDir, 'mods');

  /// Every page's whole address, for search engines.
  String get sitemapFilePath => p.join(siteDir, 'sitemap.xml');

  /// Tells search engines they may read every page, and where the sitemap is.
  String get robotsFilePath => p.join(siteDir, 'robots.txt');

  /// Turns the catalog and the bundle into the website's files' contents.
  ///
  /// [threadReleases] is what the release detector worked out, filed against
  /// forum topic ids. Joining them to mods is this builder's job, through each
  /// mod's forum post. Pass an empty list when the detector has not run — the
  /// feed file is still written, just with nothing in it.
  ///
  /// [goneIds] are the ids removed by a takedown.
  /// Ids with no page or redirect get not-found files (see [PublicSiteData.goneIds]).
  PublicSiteData build({
    required List<CatalogMod> mods,
    List<CatalogCollection> collections = const [],
    Map<String, String> movedIds = const {},
    Set<String> goneIds = const {},
    ForumDataBundle? bundle,
    List<ThreadRelease> threadReleases = const [],
    DiscordPostsFile discordPosts = const DiscordPostsFile(),
    DateTime? generatedAt,
  }) {
    final builtAt = (generatedAt ?? DateTime.now()).toUtc();

    final threads = <String, QbModSummary>{};
    for (final thread in bundle?.index ?? const <QbModSummary>[]) {
      threads['${thread.topicId}'] = thread;
    }
    final discordAnswers = <String, DiscordThreadAnswer>{
      for (final answer in bundle?.discordThreads ?? const <DiscordThreadAnswer>[]) answer.threadId: answer,
    };

    // Reading a thread's posts is the dear part of a build, and every mod on a
    // thread wants the same reading. So each thread is read at most once, the
    // first time somebody asks for it.
    final postsRead = <String, _ReadPost>{};
    _ReadPost postsOf(String? topicId) => topicId == null
        ? _ReadPost(null)
        : postsRead.putIfAbsent(
            topicId, () => _ReadPost(bundle?.details[topicId]));

    // Every mod's thread and facts first, so the releases — which are filed
    // against a forum topic — can be handed to the right mod.
    final joined = <_JoinedMod>[];
    final takenIds = <String>{};
    final missingFacts = <String>[];
    for (final catalogMod in mods) {
      final mod = catalogMod.mod;
      final id = catalogMod.id;
      if (!takenIds.add(id)) {
        // The catalog never hands one id out twice. Saying so is more use than
        // quietly overwriting a page.
        _log.warning('Two mods want the page "$id" — "${mod.name}" is the '
            'second, and has been left out.');
        continue;
      }
      final forumPost = _forumPostOf(catalogMod);
      final topicId = forumPost?.id;
      final thread = topicId == null ? null : threads[topicId];
      final discordPost = catalogMod.discordPost;
      final facts = _factsFor(catalogMod, threads, discordAnswers,
          onMissing: (post) => missingFacts.add('"$id" ($post)'));
      joined.add(_JoinedMod(
        mod: mod,
        id: id,
        shownName: _shownNameFor(mod, facts),
        topicId: topicId,
        // A mod the LLM read off a thread that holds others: the thread is not
        // about it, so its page says which thread it came from. A Discord post
        // counts only for a mod with no forum thread.
        partOfThreadTitle: forumPost != null
            ? (forumPost.foundBy == ListingOrigin.llm ? thread?.title : null)
            : (discordPost?.foundBy == ListingOrigin.llm
                ? switch (discordAnswers[discordPost!.id]?.name.trim()) {
                    final name? when name.isNotEmpty => name,
                    _ => null,
                  }
                : null),
        facts: facts,
        discordAnswer: discordPost == null ? null : discordAnswers[discordPost.id],
      ));
    }

    // The catalog names each mod's LLM answer, and the bundle should hold every
    // one of them: both are built from the same saved answers. One missing
    // means the catalog was built from newer answers than the bundle — a run
    // that saved LLM answers and died before publishing the bundle, then a
    // merge. Those mods go out without the LLM's facts until the bundle is
    // rebuilt, so it is said rather than left to be noticed on the site.
    if (missingFacts.isNotEmpty) {
      _log.warning('${missingFacts.length} mods name an LLM answer the bundle '
          "does not have, so their pages are built without the LLM's facts "
          '(downloads, version, save notes): '
          '${missingFacts.take(5).join(', ')}${missingFacts.length > 5 ? ' and more' : ''}. '
          'The catalog was built from newer LLM answers than the bundle; '
          'rebuilding the bundle puts it right.');
    }

    // Which mod each name belongs to, so "Requires LazyLib" can be a link.
    // Built from every mod at once, so it has to wait until they all have ids.
    final requirements = RequirementResolver(
      [for (final entry in joined) _namesOf(entry)],
      store: requirementNames,
    );

    final releasesByMod = _releasesByMod(threadReleases, joined);
    final feed = _feedOrder(releasesByMod);

    final listRecords = <PublicMod>[];
    final details = <String, PublicModDetail>{};

    for (final entry in joined) {
      final mod = entry.mod;
      final id = entry.id;
      final topicId = entry.topicId;
      final thread = topicId == null ? null : threads[topicId];
      final detail = topicId == null ? null : bundle?.details[topicId];
      final threadDownloads = topicId == null
          ? const <AssumedDownloadCandidate>[]
          : (bundle?.assumedDownloads[topicId] ?? const []);

      final modReleases = releasesByMod[id] ?? const <ModRelease>[];

      // Already read, if anything else on this thread has asked for it.
      final post = postsOf(topicId);
      final chosen = entry.facts;
      final ownSection = _sectionAbout(chosen, post);
      // A Discord-only mod's add-ons are on its Discord thread's answer.
      final addonSource = thread ??
          (entry.discordAnswer == null
              ? null
              : QbModSummary(topicId: 0, llm: LlmThreadData(mods: entry.discordAnswer!.mods)));

      final record = _listRecord(
        id: id,
        mod: mod,
        topicId: topicId,
        thread: thread,
        postDate: detail?.postDate,
        forumEdits: [
          for (final post in detail?.openingPosts ?? const <QbForumPost>[])
            post.lastEditDate,
        ],
        threadWasRead: detail != null,
        authorAvatarPath: detail?.authorAvatarPath,
        postPictures: detail?.allImages ?? const [],
        pictureSizes: post.pictureSizes,
        chosen: chosen,
        ownSection: ownSection,
        threadDownloads: threadDownloads,
        releases: modReleases,
        requirements: requirements,
        partOfThreadTitle: entry.partOfThreadTitle,
        shownName: entry.shownName,
        discordPosts: discordPosts,
      );
      listRecords.add(record);
      details[id] = _detailRecord(
        builtAt: builtAt,
        listing: record,
        mod: mod,
        thread: thread,
        detail: detail,
        chosen: chosen,
        post: post,
        ownSection: ownSection,
        threadDownloads: threadDownloads,
        releases: modReleases,
        discordPosts: discordPosts,
        addonSource: addonSource,
        requirements: requirements,
      );
    }

    // Which mods share a name, worked out once every mod has a record. It has
    // to wait: a page names the others by their id, their author and the day
    // their thread was last posted on, and none of that exists until then.
    _fillSameNameMods(listRecords, details);

    // Sorted by the name a reader sees, so the leading dashes and brackets a
    // thread title carries no longer decide who is on page one.
    listRecords.sort((a, b) => (a.displayName ?? a.name)
        .toLowerCase()
        .compareTo((b.displayName ?? b.name).toLowerCase()));

    final collectionPages = _collectionPages(collections, listRecords, takenIds);
    final pageIds = {...details.keys, for (final page in collectionPages) page.id};
    _logUnmatchedNeeds(requirements.unmatched);
    final moved = {
      for (final MapEntry(key: old, value: to) in movedIds.entries)
        if (!pageIds.contains(old) && details.containsKey(to)) old: to,
    };
    return PublicSiteData(
      list: PublicModList(generatedAt: builtAt, mods: listRecords),
      details: details,
      feed: ModReleaseFeed(generatedAt: builtAt, releases: feed),
      collections: collectionPages,
      movedIds: moved,
      goneIds: {
        for (final id in goneIds)
          if (!pageIds.contains(id) && !moved.containsKey(id)) id,
      },
      unmatchedNeeds: Map.of(requirements.unmatched),
      requiredMods: _requiredMods(joined, listRecords),
      requirementNames: Map.of(requirements.seen),
    );
  }

  /// All names for [entry], used to match requirement names.
  static RequiredModNames _namesOf(_JoinedMod entry) => RequiredModNames(
        id: entry.id,
        shownName: entry.shownName,
        names: [entry.mod.name, if (entry.facts?.name case final name?) name],
        nicknames: entry.facts?.nicknames ?? const [],
      );

  /// The mods other mods need. See [PublicSiteData.requiredMods].
  static List<RequiredModNames> _requiredMods(
      List<_JoinedMod> joined, List<PublicMod> records) {
    final neededBy = <String, int>{};
    for (final record in records) {
      for (final need in record.needs) {
        if (need.id case final id?) neededBy[id] = (neededBy[id] ?? 0) + 1;
      }
    }
    final libraries = {
      for (final record in records)
        if (record.categories.contains('Libraries')) record.id,
    };
    // Two mods can share a name, such as a fork or an old thread. Show the LLM
    // only the one required by more mods. It does not have to tell them apart.
    final byName = <String, _JoinedMod>{};
    for (final entry in joined) {
      if (!libraries.contains(entry.id) &&
          (neededBy[entry.id] ?? 0) < requiredByAtLeast) {
        continue;
      }
      final key = requirementKey(entry.shownName);
      final there = byName[key];
      if (there == null || (neededBy[entry.id] ?? 0) > (neededBy[there.id] ?? 0)) {
        byName[key] = entry;
      }
    }
    return [for (final entry in byName.values) _namesOf(entry)];
  }

  /// Logs requirement names that matched none of our mods, most-used first.
  /// This helps find new misspellings of library names.
  void _logUnmatchedNeeds(Map<String, ({String written, int count})> unmatched) {
    if (unmatched.isEmpty) return;
    final names = unmatched.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    _log.info('${names.length} dependency names match none of our mods: '
        '${names.take(30).map((n) => '"${n.written}" (${n.count})').join(', ')}'
        '${names.length > 30 ? ' and more' : ''}.');
  }

  /// The pages of Collections that keep an old address. A Collection whose id
  /// some mod now has is skipped — that cannot happen, since the catalog holds
  /// a Collection's id back, but a page must never stand on a mod's address.
  List<PublicCollection> _collectionPages(
    List<CatalogCollection> collections,
    List<PublicMod> records,
    Set<String> modIds,
  ) {
    final byId = {for (final record in records) record.id: record};
    return [
      for (final collection in collections)
        if (!modIds.contains(collection.id))
          PublicCollection(
            id: collection.id,
            name: collection.name,
            forumUrl: collection.post.kind == SourceKind.forum
                ? 'https://fractalsoftworks.com/forum/index.php?topic=${collection.post.id}.0'
                : null,
            discordUrl: collection.post.kind == SourceKind.discord
                ? (byId.values
                    .map((r) => r.discordUrl)
                    .whereType<String>()
                    .firstWhere((url) => url.contains('/${collection.post.id}/'), orElse: () => ''))
                : null,
            mods: [
              for (final id in collection.modIds)
                if (byId[id] case final record?) record,
            ],
          ),
    ];
  }

  /// The mod's forum post: the one its forum link names, where it has several
  /// (a mod's old thread and its new one), else the first.
  static CatalogSourcePost? _forumPostOf(CatalogMod catalogMod) {
    final forumPosts = [for (final post in catalogMod.sourcePosts) if (post.kind == SourceKind.forum) post];
    if (forumPosts.isEmpty) return null;
    final linked = ModMerger.extractForumTopicId(catalogMod.mod.getUrls()[ModUrlType.Forum]);
    return forumPosts.firstWhere((post) => post.id == linked, orElse: () => forumPosts.first);
  }

  /// The mod's facts: the LLM's answer for each of its source posts, looked up
  /// by the post's id and the LLM's name for the mod, and put together by
  /// [chooseFacts] — the forum's answer first, Discord's filling its gaps.
  static LlmMod? _factsFor(
    CatalogMod catalogMod,
    Map<String, QbModSummary> threads,
    Map<String, DiscordThreadAnswer> discordAnswers, {
    void Function(String post)? onMissing,
  }) {
    final sources = <FactSource>[];
    for (final post in catalogMod.sourcePosts) {
      final name = post.llmModName;
      if (name == null) continue;
      switch (post.kind) {
        case SourceKind.forum:
          final thread = threads[post.id];
          final llmMod = _named(thread?.llm?.mods, name);
          if (llmMod != null) {
            sources.add(FactSource(llmMod, SourceKind.forum, postedAt: parseForumDate(thread?.lastPostDate)));
          } else {
            onMissing?.call(post.ref.key);
          }
        case SourceKind.discord:
          final llmMod = _named(discordAnswers[post.id]?.mods, name);
          if (llmMod != null) {
            sources.add(FactSource(llmMod, SourceKind.discord));
          } else {
            onMissing?.call(post.ref.key);
          }
        case SourceKind.nexus:
          break;
      }
    }
    return chooseFacts(sources);
  }

  /// The LLM mod with exactly this name. The catalog wrote the name down from
  /// the same answer, so it is the same string; capitals are forgiven in case
  /// an answer was re-read with different ones.
  static LlmMod? _named(List<LlmMod>? mods, String name) {
    if (mods == null) return null;
    final wanted = name.trim();
    for (final mod in mods) {
      if (mod.name.trim() == wanted) return mod;
    }
    for (final mod in mods) {
      if (mod.name.trim().toLowerCase() == wanted.toLowerCase()) return mod;
    }
    return null;
  }

  /// Puts the other published mods of a name on each of their pages.
  ///
  /// Two pages carrying one name is not an oddity to be tidied away. Some are a
  /// mod's own older thread, which often holds the last build that ran on an
  /// older game version; some are a fork that kept the name of the mod it
  /// forked, which is often the only build that runs on the current one; and
  /// some are two people who happened to pick the same name. All three are
  /// worth keeping, so the site keeps them and says which is which instead.
  ///
  /// The grouping is the same comparison the thread-mod rule uses, so a page
  /// says "the same name" about exactly the mods that rule would call one mod.
  /// Newest thread first, because the reader's usual question is which of these
  /// is still alive.
  void _fillSameNameMods(
    List<PublicMod> records,
    Map<String, PublicModDetail> details,
  ) {
    final byName = <String, List<PublicMod>>{};
    for (final record in records) {
      // A mod with no name at all is nobody's namesake, and every one of them
      // would come down to the same empty key.
      if (record.name.trim().isEmpty) continue;
      byName.putIfAbsent(sameNameKey(record.name), () => []).add(record);
    }

    for (final group in byName.values) {
      if (group.length < 2) continue;
      for (final record in group) {
        final others = [
          for (final other in group)
            if (other.id != record.id) other,
        ]..sort(_newestThreadFirst);
        details[record.id] = details[record.id]!.copyWith(
          sameNameMods: [
            for (final other in others)
              PublicSameNameMod(
                title: other.displayName ?? other.name,
                url: other.forumUrl ?? other.discordUrl,
                id: other.id,
                authors: other.authors,
                gameVersion: other.gameVersion,
                modVersion: other.modVersion,
                threadLastPostOn: other.threadLastPostOn,
              ),
          ],
        );
      }
    }
  }

  /// The mod whose thread was posted on most recently first. A mod with no
  /// readable date goes last — it says nothing, and a page led by it would
  /// answer the reader's question with a blank.
  static int _newestThreadFirst(PublicMod a, PublicMod b) {
    final left = a.threadLastPostOn;
    final right = b.threadLastPostOn;
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    // Days are written `YYYY-MM-DD`, so sorting the text backwards is sorting
    // by day.
    return right.compareTo(left);
  }

  /// Each mod's releases, newest first, joined from the detector's list on the
  /// forum topic id. A release for a thread with no merged mod behind it is left
  /// out — there is no page for it to point at.
  ///
  /// Each release also carries what the post says about updating to it, where
  /// the post has a note for that version — or, for the version the mod is on
  /// now, a note tied to no release. See [updateNoteFor].
  Map<String, List<ModRelease>> _releasesByMod(
    List<ThreadRelease> threadReleases,
    List<_JoinedMod> joined,
  ) {
    // A thread's releases belong to the one mod that thread is about. Where it
    // is about several, they belong to none of them: the detector believes one
    // version for a whole thread and cannot say which of four mods moved, so
    // crediting one would announce a release the mod never made. A missing
    // entry in the feed is the lesser wrong.
    //
    // The map used to keep one mod per topic, which quietly gave a shared
    // thread's releases to whichever of its mods came last in the list.
    final modsByTopic = <String, _JoinedMod>{};
    final sharedTopics = <String>{};
    for (final entry in joined) {
      final topicId = entry.topicId;
      if (topicId == null) continue;
      if (modsByTopic.containsKey(topicId)) {
        sharedTopics.add(topicId);
        continue;
      }
      modsByTopic[topicId] = entry;
    }
    for (final topicId in sharedTopics) {
      modsByTopic.remove(topicId);
    }

    final byMod = <String, List<ModRelease>>{};
    for (final release in threadReleases) {
      final owner = modsByTopic['${release.topicId}'];
      if (owner == null) continue;
      final extras = owner.facts?.extras;
      final currentVersion =
          _firstNonEmpty([extras?.version, owner.mod.modVersion]);
      final note = updateNoteFor(
        extras?.updateNotes,
        version: release.newVersion,
        isCurrent: sameVersion(release.newVersion, currentVersion),
      );
      byMod.putIfAbsent(owner.id, () => []).add(ModRelease(
            modId: owner.id,
            modName: owner.shownName,
            seenOn: release.seenOn,
            oldVersion: release.oldVersion,
            newVersion: release.newVersion,
            gameVersion: release.gameVersion,
            changelogNotes: release.changelogNotes,
            updateCompatibilityText: note?.quote,
            canUpdate: note?.answer,
          ));
    }

    for (final list in byMod.values) {
      list.sort((a, b) => b.seenOn.compareTo(a.seenOn));
    }
    return byMod;
  }

  /// The whole feed, newest first. Days are written `YYYY-MM-DD`, so sorting the
  /// text backwards is sorting by day.
  List<ModRelease> _feedOrder(Map<String, List<ModRelease>> byMod) {
    final all = byMod.values.expand((r) => r).toList();
    all.sort((a, b) => b.seenOn.compareTo(a.seenOn));
    return all;
  }

  /// The site's own front document, which every mod's page is built out of.
  ///
  /// Null when it cannot be read or has lost the marks around the region a mod's
  /// page swaps. That is a log line, not a failure: each mod then gets the small
  /// redirecting page instead, which still carries the preview tags and still
  /// reaches the mod — only the address bar keeps the site's hash address rather
  /// than the mod's own.
  String? _readShell() {
    final file = File(p.join(sitePath, 'index.html'));
    if (!file.existsSync()) {
      _log.warning('There is no ${file.path} to build the mod pages from, so '
          'each mod gets a small redirecting page instead.');
      return null;
    }
    final text = file.readAsStringSync();
    if (!text.contains(modPageHeadStart) || !text.contains(modPageHeadEnd)) {
      _log.warning('${file.path} has lost its $modPageHeadStart marks, so each '
          'mod gets a small redirecting page instead.');
      return null;
    }
    return text;
  }

  /// The "How to install mods" page, built from the site's own document with
  /// the guide's words from `site/` in its body. A missing words file still
  /// gives a page, which the script fills in; a missing shell gives none, and
  /// says so.
  Future<void> _writeGuidePage(String? shell) async {
    if (shell == null) {
      _log.warning('There is no site document to build the $guideFolder page from.');
      return;
    }
    final wordsFile = File(p.join(sitePath, guideWordsFile));
    final words = wordsFile.existsSync() ? wordsFile.readAsStringSync() : null;
    if (words == null) {
      _log.warning('There is no ${wordsFile.path}, so the $guideFolder page '
          'has no words in it for search engines.');
    }
    final page = buildGuidePageHtml(shell: shell, words: words);
    if (page == null) return;
    final folder = Directory(p.join(siteDir, guideFolder));
    if (!folder.existsSync()) folder.createSync(recursive: true);
    await File(p.join(folder.path, 'index.html')).writeAsString(page);
  }

  /// `404.html`, which the host answers every missing address with. Built from
  /// the site's own document; a small plain page when that cannot be read.
  Future<void> _writeNotFoundPage(String? shell) async {
    final page = shell == null ? null : buildNotFoundPageHtml(shell);
    if (page == null) {
      _log.warning('There is no usable site document to build $notFoundFileName from, so it is a small '
          'plain page instead.');
    }
    await File(p.join(siteDir, notFoundFileName)).writeAsString(page ?? plainNotFoundPage());
  }

  /// Writes the three files into `<outputs>/site/`. Per-mod files for mods that
  /// are no longer produced are removed, so the folder holds exactly this run's
  /// mods and nothing older.
  Future<void> write(PublicSiteData data) async {
    final mods = Directory(modsDir);
    if (!mods.existsSync()) mods.createSync(recursive: true);

    const encoder = JsonEncoder.withIndent('  ');

    await File(modsFilePath).writeAsString(encoder.convert(data.list.toMap()));
    await File(catalogExtrasFilePath)
        .writeAsString(encoder.convert(buildCatalogExtras(data).toMap()));
    await File(updatesFilePath)
        .writeAsString(encoder.convert(data.feed.toMap()));
    await File(updatesXmlFilePath)
        .writeAsString(buildReleaseFeedXml(data.feed));
    await File(sitemapFilePath).writeAsString(buildSitemapXml(data.list));
    await File(robotsFilePath).writeAsString(buildRobotsTxt());

    // Read once for the whole run: every mod's page is this same document.
    final shell = _readShell();

    await _writeGuidePage(shell);
    await _writeNotFoundPage(shell);

    for (final entry in data.details.entries) {
      await File(p.join(modsDir, '${entry.key}.json'))
          .writeAsString(encoder.convert(entry.value.toMap()));

      // A page of its own, which is also the mod's address. A link shared in
      // Discord shows the mod's name and picture, and a search engine sees one
      // page per mod rather than one page for all of them.
      final folder = Directory(p.join(modsDir, entry.key));
      if (!folder.existsSync()) folder.createSync(recursive: true);
      await File(p.join(folder.path, 'index.html')).writeAsString(
          buildModPageHtml(entry.value.listing,
              shell: shell, detail: entry.value));
    }

    // A Collection keeps the address it had, as a page listing its mods.
    final collectionIds = <String>{};
    for (final collection in data.collections) {
      collectionIds.add(collection.id);
      await File(p.join(modsDir, '${collection.id}.json'))
          .writeAsString(encoder.convert(collection.toMap()));
      final folder = Directory(p.join(modsDir, collection.id));
      if (!folder.existsSync()) folder.createSync(recursive: true);
      await File(p.join(folder.path, 'index.html')).writeAsString(
          buildCollectionPageHtml(
        id: collection.id,
        name: collection.name,
        mods: collection.mods,
        threadUrl: collection.forumUrl,
        shell: shell,
      ));
    }

    // An old address whose mod was joined into another leads to that mod's
    // page: a file the site's own pages follow, and a page of its own for a
    // link from outside.
    for (final MapEntry(key: old, value: to) in data.movedIds.entries) {
      await File(p.join(modsDir, '$old.json')).writeAsString(encoder.convert({'movedTo': to}));
      final folder = Directory(p.join(modsDir, old));
      if (!folder.existsSync()) folder.createSync(recursive: true);
      await File(p.join(folder.path, 'index.html'))
          .writeAsString(buildMovedPageHtml(to: data.details[to]!.listing));
    }

    // Replace a taken-down mod's files to show the not-found view.
    // Cloudflare Pages keeps serving deleted files for up to a week.
    // Changed files are served right away.
    final notFoundPage = (shell == null ? null : buildNotFoundPageHtml(shell)) ?? plainNotFoundPage();
    for (final id in data.goneIds) {
      await File(p.join(modsDir, '$id.json')).writeAsString(encoder.convert({'gone': true}));
      final folder = Directory(p.join(modsDir, id));
      if (!folder.existsSync()) folder.createSync(recursive: true);
      await File(p.join(folder.path, 'index.html')).writeAsString(notFoundPage);
    }

    bool kept(String id) =>
        data.details.containsKey(id) ||
        collectionIds.contains(id) ||
        data.movedIds.containsKey(id) ||
        data.goneIds.contains(id);

    var dropped = 0;
    for (final fileOrFolder in mods.listSync()) {
      final name = p.basename(fileOrFolder.path);
      if (fileOrFolder is File) {
        if (!name.endsWith('.json')) continue;
        final id = name.substring(0, name.length - '.json'.length);
        if (kept(id)) continue;
        fileOrFolder.deleteSync();
        dropped++;
      } else if (fileOrFolder is Directory) {
        // A mod's own little page. It is named for the mod, so a folder no mod,
        // Collection or moved address answers to belongs to one that has gone.
        if (kept(name)) continue;
        fileOrFolder.deleteSync(recursive: true);
        dropped++;
      }
    }

    _log.info('Wrote the website files: ${data.list.mods.length} mods, '
        '${data.feed.releases.length} releases'
        '${dropped == 0 ? '' : ', $dropped mod pages dropped'}.');
  }

  // ---------------------------------------------------------------------------

  PublicMod _listRecord({
    required String id,
    required ScrapedMod mod,
    required String? topicId,
    required QbModSummary? thread,
    required String? postDate,
    required List<String?> forumEdits,
    required bool threadWasRead,
    required String? authorAvatarPath,
    required List<ImageRef> postPictures,
    required Map<String, int> pictureSizes,
    required LlmMod? chosen,
    required String? ownSection,
    required List<AssumedDownloadCandidate> threadDownloads,
    required List<ModRelease> releases,
    required RequirementResolver requirements,
    required String? partOfThreadTitle,
    required String shownName,
    required DiscordPostsFile discordPosts,
  }) {
    final extras = chosen?.extras;
    final downloads = _downloadsFor(mod, chosen, threadDownloads);
    final isTool = chosen?.isTool == true;

    final lastPost = parseForumDate(thread?.lastPostDate);
    final discordUrl = _firstNonEmpty([mod.getUrls()[ModUrlType.Discord]]);
    final copiedSummary = summaryOfExcerpt(plainWordsOf(ownSection)) ??
        usableSummary(mod.summary) ??
        summaryOfDiscordPost(
            discordPosts.firstTextFor(discordUrl));
    final generatedSummary = usableSummary(extras?.summary?.sentence);
    final pictures = _picturesFor(
      mod,
      chosen,
      authorAvatarPath,
      postPictures: postPictures,
      sizes: pictureSizes,
      sharedThread: partOfThreadTitle != null,
    );

    return PublicMod(
      id: id,
      name: mod.name,
      displayName: shownName == mod.name ? null : shownName,
      authors: mod.getAuthors(),
      otherAuthorNames: _otherNamesFor(mod.getAuthors()),
      categories: _categoriesFor(mod, isTool: isTool),
      sources: _sourcesFor(mod, thread),
      onModIndex: thread != null && thread.inModIndex && !thread.isArchivedModIndex ? true : null,
      gameVersion: _firstNonEmpty(
          [mod.gameVersionReq, thread?.gameVersion].where(_namesAVersion).toList()),
      modVersion: _firstNonEmpty([extras?.version, mod.modVersion]),
      imageUrl: pictures.shown,
      announcementImageUrl: pictures.announcement,
      summary: copiedSummary ?? generatedSummary,
      summaryIsGenerated: copiedSummary == null && generatedSummary != null,
      aiSummary: generatedSummary,
      saveCompatible: _canAddToSave(extras),
      hasDirectDownload: downloads.any((d) => d.directUrl != null),
      bestDownload: _bestDownloadFor(downloads),
      downloadCount: downloads.length,
      forumUrl: _firstNonEmpty([mod.getUrls()[ModUrlType.Forum]]),
      discordUrl: _firstNonEmpty([mod.getUrls()[ModUrlType.Discord]]),
      nexusUrl: _firstNonEmpty([mod.getUrls()[ModUrlType.NexusMods]]),
      sourceIsPublic: _firstNonEmpty([extras?.sourceCode]) != null,
      isWorkInProgress: thread?.isWip ?? false,
      isTool: isTool ? true : null,
      nicknames: _nicknamesFor(chosen, [mod.name, shownName]),
      usesAi: extras?.aiUse?.usesAi,
      aiUses: _aiUsesFor(extras?.aiUse),
      lastReleaseDate: releases.isEmpty ? null : _lastReleaseDate(releases),
      addedOn: _addedOn(mod, thread, postDate, id,
          threadNeverRead: topicId != null && !threadWasRead),
      threadLastPostOn: lastPost == null ? null : writeDay(lastPost),
      editedOn: _editedOn(forumEdits, discordPosts.threadFor(discordUrl)),
      needs: _neededMods(extras?.needs, id, requirements),
      partOfThreadTitle: partOfThreadTitle,
    );
  }

  /// The day this mod first showed up anywhere, as `YYYY-MM-DD`.
  ///
  /// The day we first gave it an id is a poor answer on its own: the id file
  /// was written in one go, so every mod that existed then shares that day and
  /// "recently added" comes out as whatever the list happened to be sorted by.
  /// The real evidence is in the data — the day the forum thread was posted
  /// (the topic list says, and where it does not the first post itself does),
  /// and the day of the Discord message or Nexus page we read it from. The
  /// earliest of those wins, because a mod on the forum since 2014 and
  /// announced on Discord last month has been around since 2014. Only when
  /// there is no such date at all does the day we first saw it stand in, and
  /// then only if it was not the day the id file was seeded — see
  /// [ModIdStore.seedDay]. A mod we know no date for is published with none,
  /// which keeps it out of "recently added" rather than putting it at the top.
  ///
  /// A forum thread we have never read gets no first-seen day either. The mod
  /// index still lists old threads whose posts we never saved (theDragn's
  /// 0.95a threads, topics 22704 and 19548), and the day we first listed one
  /// is the day we started reading the index, not the day the mod came out.
  String? _addedOn(
    ScrapedMod mod,
    QbModSummary? thread,
    String? postDate,
    String id, {
    required bool threadNeverRead,
  }) {
    final dates = <DateTime>[
      if (parseForumDate(thread?.createdDate) case final posted?) posted,
      if (parseForumDate(postDate) case final written?) written,
      if (mod.dateTimeCreated case final made?) made.toUtc(),
    ];
    if (dates.isEmpty) {
      if (threadNeverRead) return null;
      // The day we first saw it, unless that is the day the id file was seeded
      // — every mod that already existed shares that one, so it says nothing.
      final ids = idStore;
      if (ids == null) return null;
      final seen = ids.firstSeenOfId(id);
      return seen == ids.seedDay ? null : seen;
    }
    dates.sort();
    return writeDay(dates.first);
  }

  /// The day the author last edited the mod's post, as `YYYY-MM-DD`, or null
  /// when it was never edited. [forumEdits] are the forum's "Last Edit" lines
  /// for the first post and the author's follow-ups ("July 16, 2026, 08:21:44
  /// AM by Computica"); the Discord thread's messages carry their own. A
  /// follow-up post is not an edit, so only edits count.
  static String? _editedOn(List<String?> forumEdits, DiscordThreadPost? discordThread) {
    final edits = <DateTime>[
      for (final text in forumEdits)
        if (parseForumDate(text) case final edited?) edited,
      for (final message in discordThread?.messages ?? const <DiscordOpeningMessage>[])
        if (message.editedTimestamp case final edited?) edited.toUtc(),
    ];
    if (edits.isEmpty) return null;
    edits.sort();
    return writeDay(edits.last);
  }

  /// The stretch of the author's post that describes this one mod, or null.
  ///
  /// The model said where the words start and end and the extractor found them
  /// in one of the posts. Try each post because the extractor only promised
  /// the words are in one of them.
  static String? _sectionAbout(LlmMod? chosen, _ReadPost post) {
    final anchors = chosen?.descriptionAnchors;
    if (anchors == null || anchors.isEmpty) return null;

    for (final html in post.postsHtml) {
      final section =
          sliceDescriptionHtml(html, anchors.startsWith, anchors.endsWith);
      if (section != null) return section;
    }
    return null;
  }

  /// The mods this one needs, each pointed at its own page where we have one.
  ///
  /// A mod we publish is called what this site calls it, not what this post
  /// happened to write — "Lazy Lib" and "LazyLib" are the same mod, and the
  /// site's filter would otherwise offer both. A name we have no page for is
  /// still listed as the post wrote it: knowing a mod needs "Kadur Remnant" is
  /// useful whether or not this site can link it. A mod that names itself is
  /// left out.
  static List<PublicNeededMod> _neededMods(
    List<String>? names,
    String ownId,
    RequirementResolver requirements,
  ) {
    if (names == null || names.isEmpty) return const [];

    final needed = <PublicNeededMod>[];
    final seen = <String>{};
    for (final raw in names) {
      final written = raw.trim();
      if (written.isEmpty) continue;

      final known = requirements.resolve(written);
      if (known != null && known.id == ownId) continue;

      final name = known == null ? written : known.name;
      if (!seen.add((known?.id ?? name).toLowerCase())) continue;
      needed.add(PublicNeededMod(name: name, id: known?.id));
    }
    return needed;
  }

  PublicModDetail _detailRecord({
    required DateTime builtAt,
    required PublicMod listing,
    required ScrapedMod mod,
    required QbModSummary? thread,
    required QbModDetail? detail,
    required LlmMod? chosen,
    required _ReadPost post,
    required String? ownSection,
    required List<AssumedDownloadCandidate> threadDownloads,
    required List<ModRelease> releases,
    required DiscordPostsFile discordPosts,
    required QbModSummary? addonSource,
    required RequirementResolver requirements,
  }) {
    final extras = chosen?.extras;

    // A post about four mods is not any one of their descriptions. It is why
    // Useful.Tithes' page opened with three other mods' text, and it is just as
    // wrong for the mods on that thread the merge did know about — so the post
    // is set aside for every mod on a shared thread, not only the new ones.
    final sharesItsThread = _isSharedThread(thread);
    final usablePost = sharesItsThread ? null : post;

    // Single-mod threads keep the full post. On a shared thread only this
    // mod's section belongs in its description. The listing's clipped summary
    // and the generated summary are independent of the full description.
    final descriptionSection = sharesItsThread ? ownSection : null;
    final fromForum = usablePost?.words != null || descriptionSection != null;

    // The Discord post has a place of its own on the page. Where the merge's
    // description is only that same post again, it is not shown twice.
    final discordUrl = _firstNonEmpty([mod.getUrls()[ModUrlType.Discord]]);
    final discordPost = discordPosts.firstTextFor(discordUrl);
    final mergedDescription =
        !fromForum && sameWords(mod.description, discordPost)
            ? null
            : _firstNonEmpty([mod.description]);

    final copiedDescription = usablePost?.words ??
        plainWordsOf(descriptionSection) ??
        mergedDescription;
    final generatedDescription = _firstNonEmpty([extras?.summary?.paragraph]);
    final isGenerated =
        copiedDescription == null && generatedDescription != null;

    final addingWords = _firstNonEmpty([extras?.saveCompatibility]);
    final removingWords = _firstNonEmpty([extras?.removalCompatibility]);
    final updateNote = updateNoteFor(
      extras?.updateNotes,
      version: listing.modVersion,
      isCurrent: true,
    );

    return PublicModDetail(
      generatedAt: builtAt,
      listing: listing,
      description: copiedDescription ?? generatedDescription,
      descriptionHtml: usablePost?.html ??
          descriptionSection ??
          plainTextAsHtml(copiedDescription ?? generatedDescription),
      descriptionIsGenerated: isGenerated,
      descriptionIsForumPost: fromForum,
      discordPostHtml: discordMarkdownAsHtml(discordPost),
      aiDescription: generatedDescription,
      saveCompatibilityText: addingWords,
      // Only the note that speaks for the version this page is about. A note
      // about an older release stays in the bundle and off the page.
      updateCompatibilityText: updateNote?.quote,
      removalCompatibilityText: removingWords,
      // Each short answer only rides with its words, so the page never shows a
      // yes or no it cannot back up with what the author said.
      canAdd: addingWords == null ? null : _addAnswer(extras),
      canUpdate: updateNote?.answer,
      canRemove: removingWords == null ? null : extras?.canRemove,
      aiUse: extras?.aiUse,
      rawCategories: _shelvesFor(mod),
      gallery: _galleryFor(mod, detail, post.pictureSizes),
      downloads: _downloadsFor(mod, chosen, threadDownloads),
      changelog: extras?.changelog?.entries ?? const {},
      changelogUrl: _firstNonEmpty([extras?.changelog?.link]),
      license: _firstNonEmpty([extras?.license]),
      sourceCodeUrl: _firstNonEmpty([extras?.sourceCode]),
      // A thread or a form is never a place to support anybody. The extractor
      // drops them now; this also clears them out of answers read before it
      // did.
      supportLinks: (extras?.supportLinks ?? const [])
          .where((l) => !SupportLinkType.isNeverSupport(l.url))
          .map((l) =>
              PublicSupportLink(url: l.url, type: l.type, label: l.label))
          .toList(),
      forumUrl: _firstNonEmpty([mod.getUrls()[ModUrlType.Forum]]),
      discordUrl: discordUrl,
      nexusUrl: _firstNonEmpty([mod.getUrls()[ModUrlType.NexusMods]]),
      releases: releases,
      threadLastPostOn: listing.threadLastPostOn,
      // Filled once every mod has a record — see [_fillSameNameMods].
      sameNameMods: const [],
      addons: _addonsFor(chosen, addonSource),
      optionalNeeds: _optionalMods(extras?.optionalNeeds, listing, requirements),
      partOfThreadTitle: listing.partOfThreadTitle,
    );
  }

  /// Matches optional or recommended mods from the post to our mods, as in
  /// [_neededMods]. Excludes required mods so a page never lists a mod as both.
  static List<PublicNeededMod>? _optionalMods(
    List<String>? names,
    PublicMod listing,
    RequirementResolver requirements,
  ) {
    final required = {
      for (final need in listing.needs) (need.id ?? need.name).toLowerCase(),
    };
    final optional = [
      for (final mod in _neededMods(names, listing.id, requirements))
        if (!required.contains((mod.id ?? mod.name).toLowerCase())) mod,
    ];
    return optional.isEmpty ? null : optional;
  }

  /// True when this thread is several mods at once — more than one mod the LLM
  /// called a main mod rather than an add-on or a variant.
  static bool _isSharedThread(QbModSummary? thread) {
    var mains = 0;
    for (final llmMod in thread?.llm?.mods ?? const <LlmMod>[]) {
      if (llmMod.role == LlmModRole.main) mains++;
      if (mains > 1) return true;
    }
    return false;
  }

  /// Prefer the extracted name only when it matches the title. The sole-mod
  /// fallback identifies a mod but does not justify replacing its name.
  String _shownNameFor(ScrapedMod mod, LlmMod? chosen) {
    final fromRules = displayName(mod.name);
    final written = chosen?.name.trim() ?? '';
    if (written.isEmpty || !modNamesMatch(written, mod.name)) return fromRules;
    final fromLlm = displayName(written);
    return fromLlm.isEmpty ? fromRules : fromLlm;
  }

  /// The other downloads on the same thread that are not mods of their own:
  /// add-ons that need this mod, and other builds of it. Each carries which of
  /// the two it is, so the page can keep them apart. Mods the LLM called
  /// separate are left off — they are their own mod, not an add-on.
  ///
  /// On a thread that is several mods at once, an add-on belongs to whichever
  /// of them it says it needs, and is left off the others: four mods sharing a
  /// thread would otherwise each list all four's add-ons. An add-on that names
  /// nothing we recognise stays on every page, because leaving a real add-on
  /// off the page of the mod it belongs to is the worse mistake.
  List<PublicAddon> _addonsFor(LlmMod? chosen, QbModSummary? thread) {
    final llmMods = thread?.llm?.mods ?? const <LlmMod>[];
    if (llmMods.length < 2) return const [];

    final mainNames = [
      for (final m in llmMods)
        if (m.role == LlmModRole.main) m.name,
    ];
    bool belongsHere(LlmMod addon) {
      if (mainNames.length < 2) return true;
      final requires = addon.requires?.trim();
      if (requires == null || requires.isEmpty) return true;
      // Named a mod on this thread: it is that mod's add-on and nobody else's.
      final named = mainNames.any((name) => modNamesMatch(name, requires));
      if (!named) return true;
      return chosen != null && modNamesMatch(chosen.name, requires);
    }

    return llmMods
        .where((m) => chosen == null || m.name.trim() != chosen.name.trim())
        .where(
            (m) => m.role == LlmModRole.addon || m.role == LlmModRole.variant)
        .where(belongsHere)
        .map((m) => PublicAddon(
              name: m.name,
              // The LLM's own two words, carried through rather than flattened
              // to one. A variant is another build of the mod and is installed
              // instead of it, so a page that calls it an add-on is telling the
              // reader to install both.
              role: m.role == LlmModRole.variant
                  ? PublicAddonRole.variant
                  : PublicAddonRole.addon,
              requires: _firstNonEmpty([m.requires]),
              downloads:
                  sortedDownloads(m.downloads.map(_fromLlmDownload).toList()),
            ))
        .toList();
  }

  /// The mod's downloads. The LLM's list is used when there is one, because it
  /// knows which download belongs to which mod on the thread; the rules-based
  /// list is the fallback.
  ///
  /// Both of those come off a forum thread, so a mod announced only on Discord
  /// used to end up here with nothing — a quarter of the site's mods, each
  /// falling back to an "On Discord" button while its download link sat unread
  /// in `ModRepo.json`. The announcement's own link is the last fallback. It is
  /// last on purpose: a forum thread's downloads are read from the author's own
  /// post and are better than one link scraped out of an announcement, so a mod
  /// that has both is unchanged by this.
  List<PublicDownload> _downloadsFor(
    ScrapedMod mod,
    LlmMod? chosen,
    List<AssumedDownloadCandidate> threadDownloads,
  ) {
    if (chosen != null && chosen.downloads.isNotEmpty) {
      return sortedDownloads(chosen.downloads.map(_fromLlmDownload).toList());
    }
    if (threadDownloads.isNotEmpty) {
      return sortedDownloads(
          threadDownloads.map(_fromAssumedDownload).toList());
    }
    final announced = discordDownloadFor(mod.getUrls());
    return announced == null ? const [] : [announced];
  }

  /// The one download a card or a row offers. Every list on the site shows this
  /// and nothing else, so the reader is never asked to choose between four
  /// buttons that all say "Download".
  PublicBestDownload? _bestDownloadFor(List<PublicDownload> downloads) {
    final best = bestDownloadOf(downloads);
    if (best == null) return null;
    return PublicBestDownload(
      url: best.directUrl ?? best.url,
      kind: best.kind,
      // A TriOS link is never counted as needing another step: opening it is
      // the whole point of it. See `download_order.dart`.
      needsAnotherStep: !goesStraightToAFile(best),
    );
  }

  PublicDownload _fromLlmDownload(LlmDownload d) => PublicDownload(
        url: d.url,
        directUrl: _firstNonEmpty([d.resolvedDirectUrl]),
        fileName: _firstNonEmpty([d.fileName]),
        kind: d.kind,
        label: d.label,
        host: _firstNonEmpty([d.sourceHost]),
        needsAnotherStep: d.requiresManualStep,
      );

  PublicDownload _fromAssumedDownload(AssumedDownloadCandidate d) =>
      PublicDownload(
        url: d.originalUrl,
        directUrl: _firstNonEmpty([d.resolvedDirectUrl]),
        fileName: _firstNonEmpty([d.fileName]),
        kind: LlmDownloadKind.direct,
        label: d.linkText,
        host: _firstNonEmpty([d.sourceHost]),
        needsAnotherStep: d.requiresManualStep,
      );

  List<PublicImage> _galleryFor(
    ScrapedMod mod,
    QbModDetail? detail,
    Map<String, int> sizes,
  ) {
    final seen = <String>{};
    final gallery = <PublicImage>[];

    void add(String? url, String? caption, String source) {
      final cleaned = stripExternalPrefix(url);
      if (cleaned == null || !seen.add(cleaned)) return;
      // The forum's own smileys and theme graphics are not the author's.
      if (isForumFurniture(cleaned)) return;
      // A "Buy me a coffee" button or a build badge is still published, but
      // marked, so the page can keep it out of the way of the screenshots.
      final small = !looksLikeAScreenshot(cleaned, sizes: sizes);
      final looked = pictureCaptions?.captionFor(cleaned);
      gallery.add(PublicImage(
        url: cleaned,
        caption: _firstNonEmpty([caption]),
        aiCaption: _firstNonEmpty([looked?.caption]),
        aiKind: looked?.kind.name,
        aiFit: looked?.fit.name,
        aiUnreadable: looked == null && pictureCaptions?.isUnreadable(cleaned) == true ? true : null,
        small: small ? true : null,
        source: source,
      ));
    }

    for (final image in mod.getImages().values) {
      final url = image.url ?? image.proxyUrl;
      add(url, image.description, _announcementSource(url));
    }
    // Every one of the author's opening posts: a thread that keeps its
    // downloads in a second post usually keeps its screenshots there too.
    for (final image in detail?.allImages ?? const <ImageRef>[]) {
      add(image.originalUrl, image.alt, 'forum');
    }
    return gallery;
  }

  /// Where a merged mod's picture came from. Only Discord and Nexus give the
  /// merge pictures, and Nexus serves its own from nexusmods.com.
  static String _announcementSource(String? url) {
    final host = Uri.tryParse(url ?? '')?.host ?? '';
    return host == 'nexusmods.com' || host.endsWith('.nexusmods.com')
        ? 'nexus'
        : 'discord';
  }

  /// The picture the site shows, and the picture from the mod's announcement.
  ///
  /// Two pictures can be on offer. One is from the author's forum post; the
  /// other is the picture the merge kept, which comes from the Discord or
  /// Nexus post announcing the mod, since the forum scraper collects none. The
  /// post's picture is shown by default: it is the one the author put at the
  /// top of their own thread, where an announcement picture is whatever was
  /// attached to a message. The announcement one is published beside it, so
  /// the reader's choice costs the site no extra fetch.
  ///
  /// The shown picture is the first of these there is:
  ///
  /// 1. On a thread about this one mod, the earliest of the post's pictures
  ///    the model rated a good fit for a card, else the earliest it rated an
  ///    okay one ([pictureCaptions]). This comes first because it is the same
  ///    on every build: a rating is saved per picture and never asked again,
  ///    where the LLM's pick below can change whenever the post is read again.
  /// 2. The picture the LLM picked, when it is one of the forum post's own.
  /// 3. The forum post's first picture that is not a badge, a button or an
  ///    icon, again only on a thread about this one mod: on a shared thread
  ///    the first picture may be another mod's.
  /// 4. The picture the LLM picked from the mod's Discord thread.
  /// 5. The announcement picture.
  /// 6. The author's forum avatar. TriOS falls back to the installed mod's
  ///    icon after that, which a website has no way to read.
  ///
  /// A picture is never chosen at all when the model's server could not fetch
  /// it, or when the model rated it a poor fit or saw a button, a badge, a
  /// divider or a host's "picture removed" notice. Old Photobucket and Imgur
  /// links answer with such a notice rather than an error, so nothing else
  /// can tell them from a real picture.
  ///
  /// This is where the site parts company with TriOS's catalog, which takes
  /// the merged picture first. A mod can therefore look different in the two,
  /// which is the point of the setting.
  ///
  /// Where the announcement picture is the one shown, [_Pictures.announcement]
  /// is left null — the same address twice would only make `mods.json`
  /// bigger.
  ///
  /// Anything that is not a plain web address is dropped, and only then does it
  /// fall through to the next one.
  _Pictures _picturesFor(
    ScrapedMod mod,
    LlmMod? chosen,
    String? authorAvatarPath, {
    required List<ImageRef> postPictures,
    required Map<String, int> sizes,
    required bool sharedThread,
  }) {
    String? allowed(String? url) => url == null || _barredFromCards(url) ? null : url;

    final inPost = [
      for (final image in postPictures)
        if (stripExternalPrefix(image.originalUrl) case final url?) url,
    ];
    final rated = sharedThread ? null : _bestRatedPicture(inPost);
    final picked = allowed(stripExternalPrefix(chosen?.image));
    final pickedFromPost = picked != null && inPost.contains(picked) ? picked : null;
    final firstInPost = sharedThread
        ? null
        : inPost
            .where((url) => looksLikeAScreenshot(url, sizes: sizes) && !_barredFromCards(url))
            .firstOrNull;

    final merged = mod.getImages().values;
    final fromAnnouncement =
        allowed(stripExternalPrefix(merged.isEmpty ? null : merged.first.url));
    final avatar = stripExternalPrefix(_avatarUrl(authorAvatarPath));

    final shown =
        rated ?? pickedFromPost ?? firstInPost ?? picked ?? fromAnnouncement ?? avatar;
    return _Pictures(
      shown: shown,
      announcement: fromAnnouncement == shown ? null : fromAnnouncement,
    );
  }

  /// The earliest of the post's pictures the model rated a good fit for a
  /// card, else the earliest it rated an okay one. Only the pictures the model
  /// is shown count: the first [PictureCaptioner.maxPicturesPerPost] that are
  /// not a badge or a button by their address.
  String? _bestRatedPicture(List<String> inPost) {
    final captions = pictureCaptions;
    if (captions == null) return null;
    final looked = [
      for (final url in inPost.where((u) => !isBadgeOrDonationImage(u)).take(PictureCaptioner.maxPicturesPerPost))
        if (captions.captionFor(url) case final seen? when !seen.neverOnACard) (url: url, fit: seen.fit),
    ];
    return looked.where((p) => p.fit == CardFit.good).firstOrNull?.url ??
        looked.where((p) => p.fit == CardFit.okay).firstOrNull?.url;
  }

  /// True when [url] may never be a mod's card picture: the model's server
  /// could not fetch it, or the model saw that it is not a picture of the mod.
  bool _barredFromCards(String url) {
    final captions = pictureCaptions;
    if (captions == null) return false;
    return captions.isUnreadable(url) || (captions.captionFor(url)?.neverOnACard ?? false);
  }

  /// A forum avatar path is written relative to the forum, so it is made into a
  /// full address before it can be published.
  static String? _avatarUrl(String? path) {
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    try {
      return Uri.parse('https://fractalsoftworks.com/forum/')
          .resolve(trimmed)
          .toString();
    } catch (_) {
      return null;
    }
  }

  DateTime? _lastReleaseDate(List<ModRelease> releases) {
    DateTime? newest;
    for (final release in releases) {
      final day = readDay(release.seenOn);
      if (day == null) continue;
      if (newest == null || day.isAfter(newest)) newest = day;
    }
    return newest;
  }

  /// What tells one mod apart from another of the same name: its forum thread
  /// where it has one, and failing that the person credited. A dozen real mods
  /// share their name with something unrelated, and each of them needs its own
  /// page.
  static String markFor(ScrapedMod mod, String? topicId) {
    if (topicId != null && topicId.isNotEmpty) return 'topic:$topicId';
    final authors = mod.getAuthors();
    if (authors.isNotEmpty) return 'author:${authors.first.toLowerCase()}';
    return '';
  }

  /// The other names the author's post uses for a mod, for the search. The
  /// extractor has already checked each one is in the post; this only leaves
  /// out one that says the same as a name the mod is already published under,
  /// since the LLM's name for a mod is not always the one the site shows. Null
  /// when nothing is left, so most mods carry no field at all.
  static List<String>? _nicknamesFor(LlmMod? chosen, List<String> names) {
    String key(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
    final taken = {for (final name in names) key(name)};
    final kept = [
      for (final nickname in chosen?.nicknames ?? const <String>[])
        if (taken.add(key(nickname))) nickname,
    ];
    return kept.isEmpty ? null : kept;
  }

  /// AI uses for the Browse filter: area, how and optional, and the amount
  /// only when AI did all of that part, which "No vibecode" needs. Other
  /// amounts are left out to keep `mods.json` small.
  /// Sorted by area, with duplicates removed. Null unless the author states
  /// AI use. A missing statement does not mean no AI was used.
  static List<LlmAiUseEntry>? _aiUsesFor(LlmAiUse? aiUse) {
    if (aiUse?.usesAi != true) return null;
    final seen = <String>{};
    final uses = [
      for (final use in aiUse!.uses ?? const <LlmAiUseEntry>[])
        LlmAiUseEntry(
          area: use.area,
          how: use.how,
          extent: use.extent == AiUseExtent.all ? AiUseExtent.all : null,
          optional: use.optional,
        ),
    ]
        .where((use) => seen.add('${use.area.name}/${use.how?.name}/'
            '${use.extent?.name}/${use.optional}'))
        .toList()
      ..sort((a, b) {
        final byArea = a.area.name.compareTo(b.area.name);
        if (byArea != 0) return byArea;
        return (a.how?.name ?? '').compareTo(b.how?.name ?? '');
      });
    return uses.isEmpty ? null : uses;
  }

  /// The site's categories for a mod. A tool is always under Utilities, which
  /// is where the forum shelves mod managers and editors and where the site
  /// folds Discord's "Mod Manager" tag — so a tool the sources filed nowhere,
  /// or somewhere else, can still be found beside the others.
  static List<String> _categoriesFor(ScrapedMod mod, {required bool isTool}) {
    final found = publicCategoriesFor(mod.getCategories());
    if (!isTool || found.contains(_toolCategory)) return found;
    return [
      for (final category in publicCategories)
        if (found.contains(category) || category == _toolCategory) category,
    ];
  }

  static const String _toolCategory = 'Utilities';

  /// The shelves the sources file a mod under, for its own page. The merge has
  /// already folded plain synonyms together ("Faction" into "Faction Mods"), so
  /// these are the sources' names as the merge holds them rather than the exact
  /// words each source used. Anything that says where a mod was found rather
  /// than what it is comes out — that is published as a source instead.
  static List<String> _shelvesFor(ScrapedMod mod) => [
        for (final name in mod.getCategories())
          if (!isSourceMarker(name)) name,
      ];

  /// Where a mod was found, in plain words. The merge's own source list is a
  /// mix of how it was found ("Index", "ModdingSubforum") and where; the site
  /// only cares where, so the two forum ones fold into one.
  ///
  /// A mod whose forum thread we scraped and read was found on the forum,
  /// whatever the merge made of it. The merge learns about a mod from the board
  /// listings or from Discord, so a mod announced on Discord and never on a
  /// board came out marked Discord-only while its own page linked its forum
  /// thread.
  static List<String> _sourcesFor(ScrapedMod mod, QbModSummary? thread) {
    final found = <String>{};
    if (thread != null) found.add('forum');
    for (final source in mod.sources ?? const <ModSource>[]) {
      switch (source) {
        case ModSource.Index:
        case ModSource.ModdingSubforum:
          found.add('forum');
        case ModSource.Discord:
          found.add('discord');
        case ModSource.NexusMods:
          found.add('nexus');
      }
    }
    return [
      for (final name in const ['forum', 'discord', 'nexus'])
        if (found.contains(name)) name,
    ];
  }

  /// The other names a mod's authors go by, from the alias table the merge
  /// already keeps, kept one list per person. The site searches these as well
  /// as the credited names, so looking for "histidine_my" still finds
  /// Histidine's mods.
  ///
  /// Each person gets their own list because a mod can credit two people. When
  /// this was one list for the whole mod, the site read it as "these are all
  /// the same person": Kaleidoscope credits SirHartley and pixel_rice_bowl,
  /// and SirHartley's page said he was also known as pixel_rice_bowl.
  ///
  /// A person with no other names is left out rather than given an empty list.
  static Map<String, List<String>> _otherNamesFor(List<String> authors) {
    final credited = {for (final a in authors) a.toLowerCase()};
    final byAuthor = <String, List<String>>{};
    for (final author in authors) {
      final others = <String>{};
      for (final alias in ModRepoUtils.getOtherMatchingAliases(author)) {
        if (!credited.contains(alias.toLowerCase())) others.add(alias);
      }
      if (others.isNotEmpty) byAuthor[author] = others.toList()..sort();
    }
    return byAuthor;
  }

  /// Skip versions with no digits, such as "-".
  /// Use the thread's game version if it has one.
  static bool _namesAVersion(String? value) =>
      value != null && value.contains(RegExp(r'\d'));

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  /// The bundle stores an image that came from the post as `ext:<url>`. The
  /// website wants the plain URL. Anything that is not a web address — a local
  /// path the scraper saved a copy at, for instance — is dropped rather than
  /// published. An `&amp;` is put back to `&`: the LLM's saved picture pick
  /// was copied from addresses the scraper had saved that way.
  static String? stripExternalPrefix(String? value) {
    var url = value?.trim().replaceAll('&amp;', '&');
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('ext:')) url = url.substring('ext:'.length).trim();
    if (url.isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;
    return url;
  }

  /// Whether the mod can be added to a running game, for the badge and the
  /// browse filter. The LLM's short answer decides it where there is one; a
  /// "depends" gives no badge, since the badge cannot carry the condition and
  /// the words are on the mod's page. Answers read before the short answer
  /// existed fall back to reading the words.
  static bool? _canAddToSave(LlmExtras? extras) => switch (extras?.canAdd) {
        SaveAnswer.yes => true,
        SaveAnswer.no => false,
        SaveAnswer.depends => null,
        null => readSaveCompatibility(extras?.saveCompatibility),
      };

  /// The short answer on adding, for the mod's own page. Unlike the badge, a
  /// "depends" is kept, since the page shows the words beside it.
  static SaveAnswer? _addAnswer(LlmExtras? extras) =>
      extras?.canAdd ??
      switch (readSaveCompatibility(extras?.saveCompatibility)) {
        true => SaveAnswer.yes,
        false => SaveAnswer.no,
        null => null,
      };

  /// Reads the author's own words about adding the mod to a running game into
  /// a yes, a no, or a "nobody said". The words are kept as well, on the mod's
  /// own page — this is only so the browse page can filter on it.
  ///
  /// Words that talk about updating or about older versions give "nobody
  /// said". The LLM is asked to keep those in `updateNotes`, but
  /// answers read before that split, and the odd slip since, still carry them
  /// here. "This update is not save compatible" says nothing about adding the
  /// mod, and reading it as "needs a new game" would be wrong.
  static bool? readSaveCompatibility(String? text) {
    final words = text?.toLowerCase().trim();
    if (words == null || words.isEmpty) return null;

    const aboutUpdating = [
      'update',
      'upgrad',
      'version',
      'previous',
      'older',
      'prior to',
    ];
    if (aboutUpdating.any(words.contains)) return null;

    const saysNo = [
      'not save',
      "isn't save",
      'is not save',
      'save incompatible',
      'save-incompatible',
      'new game',
      'new save',
      'not compatible with existing',
      'breaks save',
      'save breaking',
      'save-breaking',
    ];
    for (final phrase in saysNo) {
      if (words.contains(phrase)) return false;
    }

    const saysYes = [
      'save compatible',
      'save-compatible',
      'save safe',
      'save-safe',
      'can be added',
      'safe to add',
      'add to an existing',
      'add it to an existing',
      'existing save',
      'ongoing game',
      'ongoing save',
    ];
    for (final phrase in saysYes) {
      if (words.contains(phrase)) return true;
    }
    return null;
  }
}
