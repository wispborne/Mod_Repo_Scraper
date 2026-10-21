import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../bot/scraper/mod_merger.dart';
import 'discord_posts.dart';
import 'listing.dart';
import 'mod_catalog.dart';
import 'source_post.dart';

/// One mod page on the published site, as far as the comparison cares: its id,
/// its name and the posts it was published from.
class PublishedPage {
  final String id;
  final String name;
  final String? forumTopic;
  final String? discordThread;

  const PublishedPage({required this.id, required this.name, this.forumTopic, this.discordThread});
}

/// What changed between the published site and a new catalog, by permanent id.
class CatalogComparison {
  /// Ids the site has that the catalog has neither as a mod nor as a
  /// Collection page. Each is a link somebody saved that would stop working.
  /// The switch must not happen while this is not empty.
  final List<PublishedPage> missing;

  /// The missing ids whose forum topic or Discord thread is now part of
  /// another mod: two pages joined into one. Each needs a person's look —
  /// either the two pages were one mod all along, or the merge joined two.
  final Map<String, CatalogMod> joinedInto;

  /// Ids that are no mod's any more but lead to the mod they were joined into
  /// (`ModCatalog.movedIds`). A saved link still reaches the mod, so these do
  /// not block the switch, but each is worth a look: the join could be wrong.
  final List<(PublishedPage, CatalogMod)> moved;

  /// Ids whose only post is a forum topic the catalog leaves out on purpose:
  /// the LLM said it is not a mod and it has nothing to download. A question
  /// thread or a showcase with nothing to install. These do not block the
  /// switch; the ids stay in `mod-ids.json`, so a showcase that later puts out
  /// a download gets its old address back.
  final List<PublishedPage> removedOnPurpose;

  /// Ids that are now a Collection's page rather than a mod.
  final List<(PublishedPage, CatalogCollection)> becameCollections;

  /// Ids whose forum topic or Discord thread is not the one the site had.
  final List<(PublishedPage, CatalogMod)> postsChanged;

  /// Mods the site never had.
  final List<CatalogMod> added;

  /// Discord threads that gave two or more mods.
  final Map<String, List<CatalogMod>> discordThreadsWithSeveral;

  /// Ids where the name the site showed and the catalog's name are not the
  /// same, for a person to judge whether the mod index's first line reads
  /// worse.
  final List<(PublishedPage, CatalogMod)> renamed;

  const CatalogComparison({
    this.missing = const [],
    this.joinedInto = const {},
    this.moved = const [],
    this.removedOnPurpose = const [],
    this.becameCollections = const [],
    this.postsChanged = const [],
    this.added = const [],
    this.discordThreadsWithSeveral = const {},
    this.renamed = const [],
  });

  bool get blocksTheSwitch => missing.isNotEmpty;

  /// A plain report, for a person to read before switching.
  String toMarkdown() {
    final b = StringBuffer('# Catalog comparison\n\n');
    b.writeln(blocksTheSwitch
        ? '**The switch is blocked:** ${missing.length} published id(s) would stop working.\n'
        : 'Every published id still leads to its mod, to the mod it was joined into, or to a Collection page.\n');
    void section(String title, Iterable<String> lines) {
      final all = lines.toList();
      b.writeln('## $title (${all.length})\n');
      if (all.isEmpty) {
        b.writeln('None.\n');
        return;
      }
      for (final line in all) {
        b.writeln('- $line');
      }
      b.writeln();
    }

    section('Published ids missing from the catalog', [
      for (final page in missing)
        '`${page.id}` — ${page.name}${_where(page)}'
            '${joinedInto[page.id] == null ? '' : ' — joined into `${joinedInto[page.id]!.id}`'}',
    ]);
    section('Published ids leading to the mod they were joined into', [
      for (final (page, mod) in moved) '`${page.id}` — ${page.name}${_where(page)} → `${mod.id}` ${mod.mod.name}',
    ]);
    section('Removed on purpose: not a mod, nothing to download', [
      for (final page in removedOnPurpose) '`${page.id}` — ${page.name}${_where(page)}',
    ]);
    section('Ids that become Collection pages', [
      for (final (page, collection) in becameCollections)
        '`${page.id}` — ${collection.name}: ${collection.modIds.map((id) => '`$id`').join(', ')}',
    ]);
    section('Ids whose source posts changed', [
      for (final (page, mod) in postsChanged)
        '`${page.id}` — ${page.name}: was${_where(page)}, now ${_postsOf(mod)}',
    ]);
    section('Discord threads giving several mods', [
      for (final entry in discordThreadsWithSeveral.entries)
        'thread ${entry.key}: ${entry.value.map((m) => '`${m.id}` ${m.mod.name}').join(', ')}',
    ]);
    section('New mods', [
      for (final mod in added) '`${mod.id}` — ${mod.mod.name} (${_postsOf(mod)})',
    ]);
    section('Names that differ from the published page', [
      for (final (page, mod) in renamed) '`${page.id}`: "${page.name}" → "${mod.mod.name}"',
    ]);
    return b.toString();
  }

  static String _where(PublishedPage page) => [
        if (page.forumTopic != null) ' topic ${page.forumTopic}',
        if (page.discordThread != null) ' Discord ${page.discordThread}',
      ].join(',');

  static String _postsOf(CatalogMod mod) => mod.sourcePosts
      .map((post) => '${post.kind.name} ${post.id}${post.llmModName == null ? '' : ' "${post.llmModName}"'}')
      .join(', ');
}

/// Reads the published site's mod pages: every `mods/<id>.json` with a
/// `listing`.
List<PublishedPage> readPublishedPages(Directory modsDir) {
  final pages = <PublishedPage>[];
  if (!modsDir.existsSync()) return pages;
  final files = modsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
  for (final file in files) {
    final page = jsonDecode(file.readAsStringSync());
    if (page is! Map || page['listing'] is! Map) continue;
    final listing = page['listing'] as Map;
    final id = listing['id'] as String?;
    if (id == null) continue;
    pages.add(PublishedPage(
      id: id,
      name: (listing['displayName'] ?? listing['name'] ?? '') as String,
      forumTopic: ModMerger.extractForumTopicId((listing['forumUrl'] ?? page['forumUrl']) as String?),
      discordThread: discordThreadIdOf((listing['discordUrl'] ?? page['discordUrl']) as String?),
    ));
  }
  return pages;
}

/// Compares [catalog] with the [published] site, by permanent id.
///
/// [notMods] is the forum topics the catalog left out on purpose
/// ([CatalogListings.notMods]). A missing page whose only post is one of them
/// is listed as removed on purpose rather than missing. A page that also had a
/// Discord thread is still missing: the thread should have kept it.
CatalogComparison compareCatalog({
  required List<PublishedPage> published,
  required ModCatalog catalog,
  Set<String> notMods = const {},
}) {
  final modsById = {for (final mod in catalog.mods) mod.id: mod};
  final collectionsById = {for (final c in catalog.collections) c.id: c};
  final publishedIds = {for (final page in published) page.id};

  final missing = <PublishedPage>[];
  final moved = <(PublishedPage, CatalogMod)>[];
  final removedOnPurpose = <PublishedPage>[];
  final becameCollections = <(PublishedPage, CatalogCollection)>[];
  final postsChanged = <(PublishedPage, CatalogMod)>[];
  final renamed = <(PublishedPage, CatalogMod)>[];

  for (final page in published) {
    final mod = modsById[page.id];
    if (mod == null) {
      final collection = collectionsById[page.id];
      final movedTo = modsById[catalog.movedIds[page.id]];
      if (collection != null) {
        becameCollections.add((page, collection));
      } else if (movedTo != null) {
        moved.add((page, movedTo));
      } else if (page.discordThread == null && notMods.contains(page.forumTopic)) {
        removedOnPurpose.add(page);
      } else {
        missing.add(page);
      }
      continue;
    }
    final forumTopics = {for (final post in mod.sourcePosts) if (post.kind == SourceKind.forum) post.id};
    final discordThreads = {for (final post in mod.sourcePosts) if (post.kind == SourceKind.discord) post.id};
    final lostForum = page.forumTopic != null && !forumTopics.contains(page.forumTopic);
    final lostDiscord = page.discordThread != null && !discordThreads.contains(page.discordThread);
    if (lostForum || lostDiscord) postsChanged.add((page, mod));
    if (page.name.trim().toLowerCase() != mod.mod.name.trim().toLowerCase()) renamed.add((page, mod));
  }

  final byThread = <String, List<CatalogMod>>{};
  for (final mod in catalog.mods) {
    for (final post in mod.sourcePosts) {
      if (post.kind == SourceKind.discord && post.foundBy == ListingOrigin.llm) {
        byThread.putIfAbsent(post.id, () => []).add(mod);
      }
    }
  }

  final joinedInto = <String, CatalogMod>{};
  for (final page in missing) {
    for (final mod in catalog.mods) {
      final holds = mod.sourcePosts.any((post) =>
          (post.kind == SourceKind.forum && post.id == page.forumTopic) ||
          (post.kind == SourceKind.discord && post.id == page.discordThread));
      if (holds) {
        joinedInto[page.id] = mod;
        break;
      }
    }
  }

  return CatalogComparison(
    missing: missing,
    joinedInto: joinedInto,
    moved: moved,
    removedOnPurpose: removedOnPurpose,
    becameCollections: becameCollections,
    postsChanged: postsChanged,
    added: [for (final mod in catalog.mods) if (!publishedIds.contains(mod.id)) mod],
    discordThreadsWithSeveral: {
      for (final entry in byThread.entries)
        if (entry.value.length >= 2) entry.key: entry.value,
    },
    renamed: renamed,
  );
}
