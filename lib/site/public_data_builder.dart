import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../bot/scraper/mod_merger.dart';
import '../bot/scraper/mod_repo_utils.dart';
import '../bot/scraper/qb/models/assumed_download.dart';
import '../bot/scraper/qb/models/forum_data_bundle.dart';
import '../bot/scraper/qb/models/mod_detail.dart';
import '../bot/scraper/qb/models/mod_summary.dart';
import '../bot/scraper/qb/models/post_extraction.dart';
import '../bot/scraper/scraped_mod.dart';
import 'days.dart';
import 'display_name.dart';
import 'gallery_filter.dart';
import 'mod_id_store.dart';
import 'models/mod_release.dart';
import 'models/public_mod.dart';
import 'models/public_mod_detail.dart';
import 'post_html.dart';
import 'public_categories.dart';
import 'release_feed_xml.dart';
import 'release_state_store.dart';
import 'summary_text.dart';

/// One merged mod with the id it was given and the forum thread it belongs to.
class _JoinedMod {
  final ScrapedMod mod;
  final String id;

  /// The forum topic id from the mod's forum link, or null when it has none.
  final String? topicId;

  const _JoinedMod({required this.mod, required this.id, this.topicId});
}

/// One forum post, read once.
///
/// The card wants to know how big the post said its pictures are, the gallery
/// wants the same, and the description wants the post as both formatted HTML
/// and plain words. Reading a post is the dear part of a build — 900 of them
/// every run — so it is read once here and the answers passed around.
class _ReadPost {
  /// The post rebuilt from the tags the site publishes, or null when the mod
  /// has no forum post.
  final String? html;

  /// The same words with the tags taken off.
  final String? words;

  /// How wide the post said each of its pictures is.
  final Map<String, int> pictureSizes;

  /// The pictures in the post, in the order it showed them.
  final List<String> pictures;

  _ReadPost._(this.html, this.words, this.pictureSizes, this.pictures);

  factory _ReadPost(QbModDetail? detail) {
    final html = cleanPostHtml(detail?.contentHtml);
    final pictures = <String>[];
    for (final image in detail?.images ?? const <ImageRef>[]) {
      final url = PublicDataBuilder.stripExternalPrefix(image.originalUrl);
      if (url != null) pictures.add(url);
    }
    return _ReadPost._(
      html,
      plainWordsOf(html),
      pictureSizesInPost(detail?.contentHtml),
      pictures,
    );
  }
}

/// The three files the public website reads, held together before they are
/// written.
class PublicSiteData {
  final PublicModList list;
  final Map<String, PublicModDetail> details;
  final ModReleaseFeed feed;

  const PublicSiteData({
    required this.list,
    required this.details,
    required this.feed,
  });
}

/// Builds the website's data files out of what the scraper already has: the
/// merged mods from the ModRepo pipeline, and the forum data bundle from the QB
/// pipeline. Neither of those is changed by this — they are read, and three new
/// files are written beside them.
///
/// The two halves are joined on the forum topic id: a merged mod's forum URL
/// carries `topic=<id>`, which is the same id the bundle files a thread under. A
/// mod with no forum thread — Discord or Nexus only — still gets a record and a
/// page, with the bundle-only fields left out rather than guessed at.
///
/// Nothing from `config.properties` reaches these files. No token, no local
/// path, no run id, no confidence score, and no flag that only means something
/// inside the scraper.
class PublicDataBuilder {
  /// The folder the existing outputs go in. The website's files go in a `site`
  /// folder under it.
  final String outputPath;

  final ModIdStore idStore;

  final Logger _log;

  PublicDataBuilder({
    required this.outputPath,
    required this.idStore,
    Logger? logger,
  }) : _log = logger ?? Logger('PublicDataBuilder');

  /// Where the website's files are written.
  String get siteDir => p.join(outputPath, 'site');

  String get modsFilePath => p.join(siteDir, 'mods.json');

  String get updatesFilePath => p.join(siteDir, 'updates.json');

  /// The same releases as a feed file, for anyone who would rather subscribe
  /// than visit.
  String get updatesXmlFilePath => p.join(siteDir, 'updates.xml');

  String get modsDir => p.join(siteDir, 'mods');

  /// Turns the merged mods and the bundle into the three files' contents.
  ///
  /// [threadReleases] is what the release detector worked out, filed against
  /// forum topic ids. Joining them to mods is this builder's job, because the
  /// topic-to-mod join is the one it already does. Pass an empty list when the
  /// detector has not run — the feed file is still written, just with nothing in
  /// it.
  PublicSiteData build({
    required List<ScrapedMod> mods,
    ForumDataBundle? bundle,
    List<ThreadRelease> threadReleases = const [],
    DateTime? generatedAt,
  }) {
    final builtAt = (generatedAt ?? DateTime.now()).toUtc();

    final threads = <String, QbModSummary>{};
    for (final thread in bundle?.index ?? const <QbModSummary>[]) {
      threads['${thread.topicId}'] = thread;
    }

    // Work out every mod's id and thread first, so the releases — which are
    // filed against a forum topic — can be handed to the right mod.
    final joined = <_JoinedMod>[];
    final takenIds = <String>{};
    for (final mod in mods) {
      final topicId =
          ModMerger.extractForumTopicId(mod.getUrls()[ModUrlType.Forum]);
      final id = idStore.idFor(mod.name, mark: markFor(mod, topicId));
      if (!takenIds.add(id)) {
        // Two merged mods that clean to one name. The first one keeps the page;
        // saying so is more use than quietly overwriting it.
        _log.warning('Two mods want the page "$id" — "${mod.name}" is the '
            'second, and has been left out.');
        continue;
      }
      joined.add(_JoinedMod(mod: mod, id: id, topicId: topicId));
    }

    // Which mod each name belongs to, so "Requires LazyLib" can be a link.
    // Built from every mod at once, so it has to wait until they all have ids.
    final modsByName = <String, _JoinedMod>{};
    for (final entry in joined) {
      modsByName.putIfAbsent(ModIdStore.cleanName(entry.mod.name), () => entry);
    }

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

      // Reading a post is the dear part of this loop, so it is done once here
      // and the answers handed to both records. The card, the gallery and the
      // description all want something out of the same post.
      final post = _ReadPost(detail);
      final chosen = _mainLlmMod(mod, thread);

      final record = _listRecord(
        id: id,
        mod: mod,
        topicId: topicId,
        thread: thread,
        chosen: chosen,
        post: post,
        threadDownloads: threadDownloads,
        releases: modReleases,
        modsByName: modsByName,
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
        threadDownloads: threadDownloads,
        releases: modReleases,
      );
    }

    // Sorted by the name a reader sees, so the leading dashes and brackets a
    // thread title carries no longer decide who is on page one.
    listRecords.sort((a, b) => (a.displayName ?? a.name)
        .toLowerCase()
        .compareTo((b.displayName ?? b.name).toLowerCase()));

    return PublicSiteData(
      list: PublicModList(generatedAt: builtAt, mods: listRecords),
      details: details,
      feed: ModReleaseFeed(generatedAt: builtAt, releases: feed),
    );
  }

  /// Each mod's releases, newest first, joined from the detector's list on the
  /// forum topic id. A release for a thread with no merged mod behind it is left
  /// out — there is no page for it to point at.
  Map<String, List<ModRelease>> _releasesByMod(
    List<ThreadRelease> threadReleases,
    List<_JoinedMod> joined,
  ) {
    final modsByTopic = <String, _JoinedMod>{};
    for (final entry in joined) {
      final topicId = entry.topicId;
      if (topicId != null) modsByTopic[topicId] = entry;
    }

    final byMod = <String, List<ModRelease>>{};
    for (final release in threadReleases) {
      final owner = modsByTopic['${release.topicId}'];
      if (owner == null) continue;
      byMod.putIfAbsent(owner.id, () => []).add(ModRelease(
            modId: owner.id,
            modName: displayName(owner.mod.name),
            seenOn: release.seenOn,
            oldVersion: release.oldVersion,
            newVersion: release.newVersion,
            gameVersion: release.gameVersion,
            changelogNotes: release.changelogNotes,
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

  /// Writes the three files into `<outputs>/site/`. Per-mod files for mods that
  /// are no longer produced are removed, so the folder holds exactly this run's
  /// mods and nothing older.
  Future<void> write(PublicSiteData data) async {
    final mods = Directory(modsDir);
    if (!mods.existsSync()) mods.createSync(recursive: true);

    const encoder = JsonEncoder.withIndent('  ');

    await File(modsFilePath).writeAsString(encoder.convert(data.list.toMap()));
    await File(updatesFilePath)
        .writeAsString(encoder.convert(data.feed.toMap()));
    await File(updatesXmlFilePath).writeAsString(buildReleaseFeedXml(data.feed));

    for (final entry in data.details.entries) {
      await File(p.join(modsDir, '${entry.key}.json'))
          .writeAsString(encoder.convert(entry.value.toMap()));
    }

    var dropped = 0;
    for (final file in mods.listSync().whereType<File>()) {
      final name = p.basename(file.path);
      if (!name.endsWith('.json')) continue;
      final id = name.substring(0, name.length - '.json'.length);
      if (data.details.containsKey(id)) continue;
      file.deleteSync();
      dropped++;
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
    required LlmMod? chosen,
    required _ReadPost post,
    required List<AssumedDownloadCandidate> threadDownloads,
    required List<ModRelease> releases,
    required Map<String, _JoinedMod> modsByName,
  }) {
    final extras = chosen?.extras;
    final downloads = _downloadsFor(chosen, threadDownloads);

    final copiedSummary = usableSummary(mod.summary);
    final generatedSummary = usableSummary(extras?.summary?.sentence);
    final shownName = displayName(mod.name);

    return PublicMod(
      id: id,
      name: mod.name,
      displayName: shownName == mod.name ? null : shownName,
      authors: mod.getAuthors(),
      otherAuthorNames: _otherNamesFor(mod.getAuthors()),
      categories: publicCategoriesFor(mod.getCategories()),
      sources: _sourcesFor(mod),
      gameVersion: _firstNonEmpty([mod.gameVersionReq, thread?.gameVersion]),
      modVersion: _firstNonEmpty([extras?.version, mod.modVersion]),
      imageUrl: _imageUrlFor(mod, chosen, thread, post),
      summary: copiedSummary ?? generatedSummary,
      summaryIsGenerated: copiedSummary == null && generatedSummary != null,
      saveCompatible: readSaveCompatibility(extras?.saveCompatibility),
      hasDirectDownload: downloads.any((d) => d.directUrl != null),
      sourceIsPublic: _firstNonEmpty([extras?.sourceCode]) != null,
      isWorkInProgress: thread?.isWip ?? false,
      lastReleaseDate: releases.isEmpty ? null : _lastReleaseDate(releases),
      addedOn: idStore.firstSeenFor(mod.name, mark: markFor(mod, topicId)),
      needs: _neededMods(extras?.needs, id, modsByName),
    );
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
    Map<String, _JoinedMod> modsByName,
  ) {
    if (names == null || names.isEmpty) return const [];

    final needed = <PublicNeededMod>[];
    final seen = <String>{};
    for (final raw in names) {
      final written = raw.trim();
      if (written.isEmpty) continue;

      final known = modsByName[ModIdStore.cleanName(written)];
      if (known != null && known.id == ownId) continue;

      final name = known == null ? written : displayName(known.mod.name);
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
    required List<AssumedDownloadCandidate> threadDownloads,
    required List<ModRelease> releases,
  }) {
    final extras = chosen?.extras;

    // The author's own post first. Before this, the description was whichever
    // text the merge liked best, which for the bigger mods was the Discord
    // announcement — Nexerelin's page said "4X in Starsector. Download: ..."
    // rather than anything about the mod.
    final copiedDescription = post.words ?? _firstNonEmpty([mod.description]);
    final generatedDescription = _firstNonEmpty([extras?.summary?.paragraph]);
    final isGenerated = copiedDescription == null && generatedDescription != null;

    return PublicModDetail(
      generatedAt: builtAt,
      listing: listing,
      description: copiedDescription ?? generatedDescription,
      descriptionHtml: post.html ??
          plainTextAsHtml(copiedDescription ?? generatedDescription),
      descriptionIsGenerated: isGenerated,
      saveCompatibilityText: _firstNonEmpty([extras?.saveCompatibility]),
      rawCategories: _shelvesFor(mod),
      gallery: _galleryFor(mod, detail, post.pictureSizes),
      downloads: _downloadsFor(chosen, threadDownloads),
      changelog: extras?.changelog?.entries ?? const {},
      changelogUrl: _firstNonEmpty([extras?.changelog?.link]),
      license: _firstNonEmpty([extras?.license]),
      sourceCodeUrl: _firstNonEmpty([extras?.sourceCode]),
      supportLinks: (extras?.supportLinks ?? const [])
          .map((l) => PublicSupportLink(url: l.url, type: l.type))
          .toList(),
      forumUrl: _firstNonEmpty([mod.getUrls()[ModUrlType.Forum]]),
      discordUrl: _firstNonEmpty([mod.getUrls()[ModUrlType.Discord]]),
      nexusUrl: _firstNonEmpty([mod.getUrls()[ModUrlType.NexusMods]]),
      releases: releases,
      olderVersions: const [],
      addons: _addonsFor(chosen, thread),
    );
  }

  /// The mod on the thread this page is about. A thread usually holds one, and
  /// then there is nothing to choose. Where it holds several, the one whose name
  /// matches the merged mod wins; failing that, the one the LLM called the main
  /// mod. The rest are listed on the page as add-ons.
  LlmMod? _mainLlmMod(ScrapedMod mod, QbModSummary? thread) {
    final llmMods = thread?.llm?.mods ?? const <LlmMod>[];
    if (llmMods.isEmpty) return null;
    if (llmMods.length == 1) return llmMods.first;

    final wanted = ModIdStore.cleanName(mod.name);
    for (final candidate in llmMods) {
      if (ModIdStore.cleanName(candidate.name) == wanted) return candidate;
    }
    for (final candidate in llmMods) {
      if (candidate.role == LlmModRole.main) return candidate;
    }
    return llmMods.first;
  }

  /// The other mods on the same thread that lean on this one. Mods the LLM
  /// called separate are left off — they are their own mod, not an add-on.
  List<PublicAddon> _addonsFor(LlmMod? chosen, QbModSummary? thread) {
    final llmMods = thread?.llm?.mods ?? const <LlmMod>[];
    if (llmMods.length < 2) return const [];

    return llmMods
        .where((m) => !identical(m, chosen))
        .where(
            (m) => m.role == LlmModRole.addon || m.role == LlmModRole.variant)
        .map((m) => PublicAddon(
              name: m.name,
              requires: _firstNonEmpty([m.requires]),
              downloads: m.downloads.map(_fromLlmDownload).toList(),
            ))
        .toList();
  }

  /// The mod's downloads. The LLM's list is used when there is one, because it
  /// knows which download belongs to which mod on the thread; the rules-based
  /// list is the fallback.
  List<PublicDownload> _downloadsFor(
    LlmMod? chosen,
    List<AssumedDownloadCandidate> threadDownloads,
  ) {
    if (chosen != null && chosen.downloads.isNotEmpty) {
      return chosen.downloads.map(_fromLlmDownload).toList();
    }
    return threadDownloads.map(_fromAssumedDownload).toList();
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

    void add(String? url, String? caption) {
      final cleaned = stripExternalPrefix(url);
      if (cleaned == null || !seen.add(cleaned)) return;
      // Every picture in a post used to be published as a screenshot, so a
      // gallery was as likely to be a "Buy me a coffee" button and a build
      // badge as anything from the game.
      if (!looksLikeAScreenshot(cleaned, sizes: sizes)) return;
      gallery.add(PublicImage(url: cleaned, caption: _firstNonEmpty([caption])));
    }

    for (final image in mod.getImages().values) {
      add(image.url ?? image.proxyUrl, image.description);
    }
    for (final image in detail?.images ?? const <ImageRef>[]) {
      add(image.originalUrl, image.alt);
    }
    return gallery;
  }

  /// The one picture the card shows.
  ///
  /// A screenshot first, under the same rules as the gallery. Where the mod has
  /// none, anything else it has will do — a logo or a banner is a poor
  /// screenshot but a perfectly good card picture, and an empty card is worse
  /// than either.
  String? _imageUrlFor(
    ScrapedMod mod,
    LlmMod? chosen,
    QbModSummary? thread,
    _ReadPost post,
  ) {
    final candidates = <String>[];
    void offer(String? value) {
      final url = stripExternalPrefix(value);
      if (url != null) candidates.add(url);
    }

    for (final image in mod.getImages().values) {
      offer(image.url ?? image.proxyUrl);
    }
    for (final url in post.pictures) {
      offer(url);
    }
    offer(chosen?.image);
    offer(thread?.thumbnailPath);

    for (final url in candidates) {
      if (looksLikeAScreenshot(url, sizes: post.pictureSizes)) return url;
    }
    return candidates.isEmpty ? null : candidates.first;
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
  static List<String> _sourcesFor(ScrapedMod mod) {
    final found = <String>{};
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
  /// published.
  static String? stripExternalPrefix(String? value) {
    var url = value?.trim();
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('ext:')) url = url.substring('ext:'.length).trim();
    if (url.isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return null;
    return url;
  }

  /// Reads the author's own words about save compatibility into a yes, a no, or
  /// a "nobody said". The words are kept as well, on the mod's own page — this
  /// is only so the browse page can filter on it.
  static bool? readSaveCompatibility(String? text) {
    final words = text?.toLowerCase().trim();
    if (words == null || words.isEmpty) return null;

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
