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
import '../bot/scraper/qb/models/post_extraction.dart';
import '../bot/scraper/scraped_mod.dart';
import 'days.dart';
import 'description_slice.dart';
import 'display_name.dart';
import 'download_order.dart';
import 'gallery_filter.dart';
import 'mod_id_store.dart';
import 'mod_name_match.dart';
import 'models/mod_release.dart';
import 'models/public_mod.dart';
import 'mod_page_html.dart';
import 'models/public_mod_detail.dart';
import 'post_html.dart';
import 'public_categories.dart';
import 'release_feed_xml.dart';
import 'release_state_store.dart';
import 'summary_text.dart';

/// One mod with the id it was given and the forum thread it belongs to.
class _JoinedMod {
  final ScrapedMod mod;
  final String id;

  /// The forum topic id from the mod's forum link, or null when it has none.
  final String? topicId;

  /// The shared thread this mod was read out of. Null when the thread holds
  /// only this mod, and for a merged mod.
  final String? partOfThreadTitle;

  const _JoinedMod({
    required this.mod,
    required this.id,
    this.topicId,
    this.partOfThreadTitle,
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
  /// mod has no forum post. This is the thread's description, and it is the
  /// first post alone: a later post is the author writing again, not more of
  /// what the thread is about.
  final String? html;

  /// The same words with the tags taken off.
  final String? words;

  /// Every one of the author's opening posts, each rebuilt the same way. Used
  /// to cut one mod's own description out of a post that describes several.
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

    for (final post in posts) {
      final html = cleanPostHtml(post.contentHtml);
      if (html != null) postsHtml.add(html);
      final plain = plainWordsOf(html);
      if (plain != null) words.add(plain);
      sizes.addAll(pictureSizesInPost(post.contentHtml));
    }

    final firstHtml = cleanPostHtml(detail?.contentHtml);
    return _ReadPost._(
      firstHtml,
      plainWordsOf(firstHtml),
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

    // Reading a thread's posts is the dear part of a build, and two things
    // want the same reading: the check that a thread mod's name is really in
    // the post, and the page of every mod on that thread. So each thread is
    // read at most once, the first time somebody asks for it.
    final postsRead = <String, _ReadPost>{};
    _ReadPost postsOf(String? topicId) => topicId == null
        ? _ReadPost(null)
        : postsRead.putIfAbsent(
            topicId, () => _ReadPost(bundle?.details[topicId]));

    // The mods a thread holds beyond the ones the merge knew about. Worked out
    // before ids are handed out, so they go round the same loop as everything
    // else and get an id, a record and a page the same way.
    final threadOnly =
        _threadOnlyMods(mods: mods, threads: threads, postsOf: postsOf);

    // Work out every mod's id and thread first, so the releases — which are
    // filed against a forum topic — can be handed to the right mod.
    final joined = <_JoinedMod>[];
    final takenIds = <String>{};
    final everyMod = <({ScrapedMod mod, String? partOfThreadTitle})>[
      for (final mod in mods) (mod: mod, partOfThreadTitle: null),
      for (final standIn in threadOnly)
        (mod: standIn.mod, partOfThreadTitle: standIn.partOfThreadTitle),
    ];
    for (final (
          mod: mod,
          partOfThreadTitle: partOfThreadTitle,
        ) in everyMod) {
      final topicId =
          ModMerger.extractForumTopicId(mod.getUrls()[ModUrlType.Forum]);
      final id = idStore.idFor(mod.name, mark: markFor(mod, topicId));
      if (!takenIds.add(id)) {
        // Two mods that clean to one name. The first one keeps the page; saying
        // so is more use than quietly overwriting it.
        //
        // This is also the last catch for a stand-in built for a mod that is
        // already published: it would have to have got past the name matching
        // and then landed on the merged mod's id, which means the same cleaned
        // name and the same topic mark. Then the merged mod keeps the page and
        // the stand-in is dropped here. The warning is that net doing its job,
        // not a fault to go looking for.
        _log.warning('Two mods want the page "$id" — "${mod.name}" is the '
            'second, and has been left out.');
        continue;
      }
      joined.add(_JoinedMod(
        mod: mod,
        id: id,
        topicId: topicId,
        partOfThreadTitle: partOfThreadTitle,
      ));
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

      // Already read, if anything else on this thread has asked for it.
      final post = postsOf(topicId);
      final chosen = _mainLlmMod(mod, thread);

      final record = _listRecord(
        id: id,
        mod: mod,
        topicId: topicId,
        thread: thread,
        postDate: detail?.postDate,
        authorAvatarPath: detail?.authorAvatarPath,
        chosen: chosen,
        threadDownloads: threadDownloads,
        releases: modReleases,
        modsByName: modsByName,
        partOfThreadTitle: entry.partOfThreadTitle,
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

    // Which mods share a name, worked out once every mod has a record. It has
    // to wait: a page names the others by their id, their author and the day
    // their thread was last posted on, and none of that exists until then.
    _fillSameNameMods(listRecords, details);

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

  /// The mods a thread holds that no published mod accounts for.
  ///
  /// Some threads are several mods at once. "Hartley's Miscellaneous Mods" is
  /// four, and only the three the author also posted on Discord ever reached
  /// the merge — so Lost.Sector, which has its own download and is sitting in
  /// the bundle, was on the site nowhere at all. TriOS has built cards for
  /// these all along (`withSynthesizedAddonEntries`); this is the same idea.
  ///
  /// Every thread in the bundle is read, whether or not a published mod points
  /// at it. The merge only learns about a mod from the board listings or from
  /// Discord, so a thread whose title carries no bracketed game version, or one
  /// that has fallen behind the newest board pages, never reaches the merge —
  /// and its mods reached the site nowhere at all. Topic 35651, "Computica's
  /// Faction Forks", is seven mods that were scraped, read and then dropped for
  /// exactly that reason.
  ///
  /// What keeps an unvetted thread safe is the grounding, not the merge: a
  /// candidate has to be a `main` mod, have its name written in the author's
  /// own opening run, and have a download tied to it. Those three are the whole
  /// gate. The model's own mod-or-not answer is deliberately not used — over
  /// the current data not one thread it calls a non-mod lists a `main` mod with
  /// a download, so it would remove nothing, and it is wrong often enough
  /// ("Iron Legion Faction Mod" is a no, a thread titled "Delete." is a yes)
  /// that it is a poor gate.
  List<({ScrapedMod mod, String? partOfThreadTitle})> _threadOnlyMods({
    required List<ScrapedMod> mods,
    required Map<String, QbModSummary> threads,
    required _ReadPost Function(String? topicId) postsOf,
  }) {
    // Every published mod on each thread, not just one. A thread reached
    // through Useful.Tithes also holds Big Pilum Energy and Disco.Balls, and
    // comparing a candidate against only the mod we arrived by is what makes
    // TriOS draw a second card for the other two.
    final publishedByTopic = <String, List<ScrapedMod>>{};
    for (final mod in mods) {
      final topicId =
          ModMerger.extractForumTopicId(mod.getUrls()[ModUrlType.Forum]);
      if (topicId == null) continue;
      publishedByTopic.putIfAbsent(topicId, () => []).add(mod);
    }

    final standIns = <({ScrapedMod mod, String? partOfThreadTitle})>[];
    for (final entry in threads.entries) {
      final topicId = entry.key;
      final thread = entry.value;
      final published = publishedByTopic[topicId] ?? const <ScrapedMod>[];

      final mainMods = [
        for (final llmMod in thread.llm?.mods ?? const <LlmMod>[])
          if (llmMod.role == LlmModRole.main) llmMod,
      ];
      // One main mod is the mod the thread is about, whatever either of them is
      // called — that is what a published mod pointing at this thread means.
      // TriOS reads a single-main thread the same way, and it is what keeps a
      // thread called "Red - the Oculian Armada" tied to the mod called "Red".
      //
      // With no published mod behind the thread there is nothing for that
      // single entry to be, so the rule stands down. Most of the mods this
      // change brings in are single-mod threads: ExtendedControls, Custom
      // Start, Ship Editor, ThirstSector.
      if (published.isNotEmpty && mainMods.length < 2) continue;
      if (mainMods.isEmpty) continue;

      final claimed = <String>[];

      for (final llmMod in mainMods) {
        final name = llmMod.name.trim();
        if (name.isEmpty) continue;

        // Already on the site under the name the merge gave it.
        if (published.any((m) => modNamesMatch(m.name, name))) continue;
        // The same mod named twice in one thread's reading.
        if (claimed.any((taken) => modNamesMatch(taken, name))) continue;

        // A model asked what a thread holds will pad the list out, and a mod
        // invented here would get a permanent address nobody can take back. So
        // the post has to name it, the way `_groundNeeds` makes the post name
        // anything a mod is said to need.
        // Every one of the author's opening posts. A thread that lists its
        // mods in the first post and describes them in a second names them in
        // both, and reading only the first would leave the second post's mods
        // looking invented.
        if (!_postNames(name, postsOf(topicId).allWords)) {
          // Ordinary news, not a warning: every thread in the bundle comes
          // through here, so this is hundreds of lines a run, and a run's log
          // is read to see what was published.
          _log.info('Left out "$name" (topic $topicId): the post never '
              'names it.');
          continue;
        }
        // No download is no page: the download is what a reader came for, and
        // without one there is nothing here the thread does not already say.
        if (llmMod.downloads.isEmpty) {
          _log.info('Left out "$name" (topic $topicId): no download was tied '
              'to it. If that is a real mod, its download was missed.');
          continue;
        }

        claimed.add(name);
        standIns.add((
          mod: _standInFor(llmMod, thread, published),
          partOfThreadTitle: mainMods.length > 1 ? thread.title : null,
        ));
        // Which kind of thread it came off, so a run's log tells the two apart:
        // a thread the merge already knows, or one it has never heard of.
        final kindOfThread = published.isEmpty
            ? 'a thread no published mod points at'
            : 'a thread a published mod already stands on';
        _log.info('Publishing "$name" as a mod of its own, from topic '
            '$topicId ("${thread.title}") — $kindOfThread.');
      }
    }
    return standIns;
  }

  /// A mod the merge never saw, made to look enough like a merged one that the
  /// rest of the builder needs to know nothing about it.
  ///
  /// It carries no summary and no description of its own: the only words a
  /// thread mod has are the ones the LLM wrote, and those belong in the fields
  /// that say so rather than passed off as the author's. Its game version falls
  /// back to a mod already published from the same thread, because Browse hides
  /// mods built for older releases and a mod with no version at all would be
  /// hidden on the very page meant to show it. TriOS falls back the same way.
  ScrapedMod _standInFor(
    LlmMod llmMod,
    QbModSummary thread,
    List<ScrapedMod> published,
  ) {
    final author = thread.author.trim();
    return ScrapedMod(
      name: llmMod.name.trim(),
      gameVersionReq: _firstNonEmpty([
        thread.gameVersion,
        for (final mod in published) mod.gameVersionReq,
      ]),
      modVersion: _firstNonEmpty([llmMod.extras?.version]),
      authorsList: author.isEmpty ? const [] : [author],
      urls: {ModUrlType.Forum: thread.topicUrl},
      sources: const [ModSource.ModdingSubforum],
    );
  }

  /// True when the post really writes this name.
  ///
  /// The same reading as the extractor's own check: `&nbsp;` in any of its
  /// spellings counts as a space, capitals do not matter, and runs of space are
  /// one space.
  static bool _postNames(String name, String? postWords) {
    if (postWords == null || postWords.isEmpty) return false;
    String tidy(String s) => s
        .replaceAll(_nbsp, ' ')
        .toLowerCase()
        .replaceAll(_spacesAnywhere, ' ')
        .trim();
    final wanted = tidy(name);
    return wanted.isNotEmpty && tidy(postWords).contains(wanted);
  }

  static final RegExp _nbsp =
      RegExp(r'&nbsp;|&#0*160;|&#x0*a0;', caseSensitive: false);
  static final RegExp _spacesAnywhere = RegExp(r'\s+');

  /// Each mod's releases, newest first, joined from the detector's list on the
  /// forum topic id. A release for a thread with no merged mod behind it is left
  /// out — there is no page for it to point at.
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

      // A small page of its own, so a link shared in Discord shows the mod's
      // name and picture, and a search engine sees one page per mod rather
      // than one page for all of them.
      final folder = Directory(p.join(modsDir, entry.key));
      if (!folder.existsSync()) folder.createSync(recursive: true);
      await File(p.join(folder.path, 'index.html'))
          .writeAsString(buildModPageHtml(entry.value.listing));
    }

    var dropped = 0;
    for (final fileOrFolder in mods.listSync()) {
      final name = p.basename(fileOrFolder.path);
      if (fileOrFolder is File) {
        if (!name.endsWith('.json')) continue;
        final id = name.substring(0, name.length - '.json'.length);
        if (data.details.containsKey(id)) continue;
        fileOrFolder.deleteSync();
        dropped++;
      } else if (fileOrFolder is Directory) {
        // A mod's own little page. It is named for the mod, so a folder no mod
        // answers to belongs to one that has gone.
        if (data.details.containsKey(name)) continue;
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
    required String? authorAvatarPath,
    required LlmMod? chosen,
    required List<AssumedDownloadCandidate> threadDownloads,
    required List<ModRelease> releases,
    required Map<String, _JoinedMod> modsByName,
    required String? partOfThreadTitle,
  }) {
    final extras = chosen?.extras;
    final downloads = _downloadsFor(chosen, threadDownloads);

    final lastPost = parseForumDate(thread?.lastPostDate);
    final copiedSummary = usableSummary(mod.summary);
    final generatedSummary = usableSummary(extras?.summary?.sentence);
    final shownName = displayName(mod.name);
    final pictures = _picturesFor(mod, chosen, authorAvatarPath);

    return PublicMod(
      id: id,
      name: mod.name,
      displayName: shownName == mod.name ? null : shownName,
      authors: mod.getAuthors(),
      otherAuthorNames: _otherNamesFor(mod.getAuthors()),
      categories: publicCategoriesFor(mod.getCategories()),
      sources: _sourcesFor(mod, thread),
      gameVersion: _firstNonEmpty([mod.gameVersionReq, thread?.gameVersion]),
      modVersion: _firstNonEmpty([extras?.version, mod.modVersion]),
      imageUrl: pictures.shown,
      announcementImageUrl: pictures.announcement,
      summary: copiedSummary ?? generatedSummary,
      summaryIsGenerated: copiedSummary == null && generatedSummary != null,
      aiSummary: generatedSummary,
      saveCompatible: readSaveCompatibility(extras?.saveCompatibility),
      hasDirectDownload: downloads.any((d) => d.directUrl != null),
      bestDownload: _bestDownloadFor(downloads),
      downloadCount: downloads.length,
      forumUrl: _firstNonEmpty([mod.getUrls()[ModUrlType.Forum]]),
      discordUrl: _firstNonEmpty([mod.getUrls()[ModUrlType.Discord]]),
      nexusUrl: _firstNonEmpty([mod.getUrls()[ModUrlType.NexusMods]]),
      sourceIsPublic: _firstNonEmpty([extras?.sourceCode]) != null,
      isWorkInProgress: thread?.isWip ?? false,
      lastReleaseDate: releases.isEmpty ? null : _lastReleaseDate(releases),
      addedOn: _addedOn(mod, thread, postDate, topicId),
      threadLastPostOn: lastPost == null ? null : writeDay(lastPost),
      needs: _neededMods(extras?.needs, id, modsByName),
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
  String? _addedOn(
    ScrapedMod mod,
    QbModSummary? thread,
    String? postDate,
    String? topicId,
  ) {
    final dates = <DateTime>[
      if (parseForumDate(thread?.createdDate) case final posted?) posted,
      if (parseForumDate(postDate) case final written?) written,
      if (mod.dateTimeCreated case final made?) made.toUtc(),
    ];
    if (dates.isEmpty) {
      // The day we first saw it, unless that is the day the id file was seeded
      // — every mod that already existed shares that one, so it says nothing.
      final seen = idStore.firstSeenFor(mod.name, mark: markFor(mod, topicId));
      return seen == idStore.seedDay ? null : seen;
    }
    dates.sort();
    return writeDay(dates.first);
  }

  /// The stretch of the author's post that describes this one mod, or null.
  ///
  /// Only for a thread carrying several mods: a thread about one mod publishes
  /// the whole post and needs none of this. The model said where the words
  /// start and end and the extractor found them in one of the posts, so all
  /// that is left is to cut them out. It is tried against each post in turn
  /// because the extractor only promised the words are in one of them.
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

    // A post about four mods is not any one of their descriptions. It is why
    // Useful.Tithes' page opened with three other mods' text, and it is just as
    // wrong for the mods on that thread the merge did know about — so the post
    // is set aside for every mod on a shared thread, not only the new ones.
    final sharesItsThread = _isSharedThread(thread);
    final usablePost = sharesItsThread ? null : post;

    // On a shared thread the post is about every mod at once — but plenty of
    // authors write a paragraph about each mod under its own name, and that
    // paragraph is that mod's description. Where the model pointed at one and
    // the words were found in the post, they are cut out and published as the
    // author's, because they are.
    final ownSection = sharesItsThread ? _sectionAbout(chosen, post) : null;

    // The author's own post first. Before this, the description was whichever
    // text the merge liked best, which for the bigger mods was the Discord
    // announcement — Nexerelin's page said "4X in Starsector. Download: ..."
    // rather than anything about the mod. On a shared thread the fallback is
    // the mod's own merged text, which for a mod posted on Discord is its own
    // announcement: still the author's words, and about this mod alone.
    final copiedDescription = usablePost?.words ??
        plainWordsOf(ownSection) ??
        _firstNonEmpty([mod.description]);
    final generatedDescription = _firstNonEmpty([extras?.summary?.paragraph]);
    final isGenerated = copiedDescription == null && generatedDescription != null;

    return PublicModDetail(
      generatedAt: builtAt,
      listing: listing,
      description: copiedDescription ?? generatedDescription,
      descriptionHtml: usablePost?.html ??
          ownSection ??
          plainTextAsHtml(copiedDescription ?? generatedDescription),
      descriptionIsGenerated: isGenerated,
      aiDescription: generatedDescription,
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
      threadLastPostOn: listing.threadLastPostOn,
      // Filled once every mod has a record — see [_fillSameNameMods].
      sameNameMods: const [],
      addons: _addonsFor(chosen, thread),
      partOfThreadTitle: listing.partOfThreadTitle,
    );
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

  /// The mod on the thread this page is about, or null when the thread cannot
  /// say which of its mods this is.
  ///
  /// Two ways to know, and no third. The names may agree once the version is
  /// off them, which is the usual one. Or the thread names a single mod, and
  /// then it is this mod whatever the two are called — a thread titled
  /// "Red - the Oculian Armada (0.10.2-RC4) Mod" is the mod called "Red", and
  /// no comparison of names would ever say so. TriOS reads it the same way.
  ///
  /// Where the thread names several mods and none of them matches, the answer
  /// is nothing. It used to be "the first one the LLM called main", which put
  /// one mod's downloads, changelog, version and picture on another mod's page:
  /// every mod on "Hartley's Miscellaneous Mods" whose name carried a version
  /// took Useful.Tithes' facts. A page with no facts is honest; a page with
  /// somebody else's is not.
  LlmMod? _mainLlmMod(ScrapedMod mod, QbModSummary? thread) {
    final llmMods = thread?.llm?.mods ?? const <LlmMod>[];
    if (llmMods.isEmpty) return null;

    for (final candidate in llmMods) {
      if (modNamesMatch(candidate.name, mod.name)) return candidate;
    }

    final mainMods = [
      for (final candidate in llmMods)
        if (candidate.role == LlmModRole.main) candidate,
    ];
    if (mainMods.length == 1) return mainMods.first;
    if (mainMods.isEmpty && llmMods.length == 1) return llmMods.first;
    return null;
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
        .where((m) => !identical(m, chosen))
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
  List<PublicDownload> _downloadsFor(
    LlmMod? chosen,
    List<AssumedDownloadCandidate> threadDownloads,
  ) {
    if (chosen != null && chosen.downloads.isNotEmpty) {
      return sortedDownloads(chosen.downloads.map(_fromLlmDownload).toList());
    }
    return sortedDownloads(threadDownloads.map(_fromAssumedDownload).toList());
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
    // Every one of the author's opening posts: a thread that keeps its
    // downloads in a second post usually keeps its screenshots there too.
    for (final image in detail?.allImages ?? const <ImageRef>[]) {
      add(image.originalUrl, image.alt);
    }
    return gallery;
  }

  /// The picture the site shows, and the picture from the mod's announcement.
  ///
  /// Two pictures can be on offer. One is the picture the LLM found in the
  /// author's forum post; the other is the picture the merge kept, which comes
  /// from the Discord or Nexus post announcing the mod, since the forum
  /// scraper collects none. The post's picture is shown by default: it is the
  /// one the author put at the top of their own thread, where an announcement
  /// picture is whatever was attached to a message. The announcement one is
  /// published beside it, so the reader's choice costs the site no extra
  /// fetch.
  ///
  /// This is where the site parts company with TriOS's catalog, which takes
  /// the merged picture first. A mod can therefore look different in the two,
  /// which is the point of the setting.
  ///
  /// Where the announcement picture is the only one there is, it is what
  /// [_Pictures.shown] holds and [_Pictures.announcement] is left null — the
  /// same address twice would only make `mods.json` bigger. The author's forum
  /// avatar stands in when there is no picture at all. TriOS falls back to the
  /// installed mod's icon after that, which a website has no way to read.
  ///
  /// Anything that is not a plain web address is dropped, and only then does it
  /// fall through to the next one.
  _Pictures _picturesFor(
    ScrapedMod mod,
    LlmMod? chosen,
    String? authorAvatarPath,
  ) {
    final merged = mod.getImages().values;
    final fromPost = stripExternalPrefix(chosen?.image);
    final fromAnnouncement =
        stripExternalPrefix(merged.isEmpty ? null : merged.first.url);
    final avatar = stripExternalPrefix(_avatarUrl(authorAvatarPath));

    final shown = fromPost ?? fromAnnouncement ?? avatar;
    return _Pictures(
      shown: shown,
      announcement: fromAnnouncement == shown ? null : fromAnnouncement,
    );
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
