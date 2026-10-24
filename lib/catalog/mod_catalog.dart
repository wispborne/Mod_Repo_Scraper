import 'dart:convert';
import 'dart:io';

import '../bot/scraper/debug/merge_debug_collector.dart';
import '../bot/scraper/mod_merger.dart';
import '../bot/scraper/scraped_mod.dart';
import '../site/mod_id_store.dart';
import '../site/mod_name_match.dart';
import 'catalog_inputs.dart';
import 'listing.dart';
import 'source_post.dart';
import 'takedowns.dart';

/// One mod in the catalog: its permanent id, the merged mod, and every source
/// post it was built from.
class CatalogMod {
  final String id;
  final ScrapedMod mod;
  final List<CatalogSourcePost> sourcePosts;

  const CatalogMod({required this.id, required this.mod, this.sourcePosts = const []});

  /// The forum topic this mod's forum post is, if it has one.
  CatalogSourcePost? get forumPost => _first(SourceKind.forum);

  /// The Discord thread this mod's Discord post is, if it has one.
  CatalogSourcePost? get discordPost => _first(SourceKind.discord);

  CatalogSourcePost? _first(SourceKind kind) {
    for (final post in sourcePosts) {
      if (post.kind == kind) return post;
    }
    return null;
  }

  /// Written as the merged mod's own fields with `id` and `sourcePosts` beside
  /// them, so the record reads like a `ModRepo.json` record with two more
  /// fields.
  Map<String, dynamic> toMap() => {
        'id': id,
        ...mod.toMap(),
        'sourcePosts': [for (final post in sourcePosts) post.toMap()],
      };

  factory CatalogMod.fromMap(Map<String, dynamic> map) {
    final rest = Map<String, dynamic>.from(map)
      ..remove('id')
      ..remove('sourcePosts');
    return CatalogMod(
      id: map['id'] as String,
      mod: ScrapedModMapper.fromMap(rest),
      sourcePosts: [
        for (final post in (map['sourcePosts'] as List?) ?? const [])
          CatalogSourcePostMapper.fromMap(Map<String, dynamic>.from(post as Map)),
      ],
    );
  }
}

/// A source post that holds two or more mods and already had a permanent id
/// from before it was known to be one. Its page stays at [id] and lists the
/// mods in [modIds]. A Collection that never had an id is not here.
class CatalogCollection {
  final String id;
  final String name;
  final SourcePostRef post;
  final List<String> modIds;

  const CatalogCollection({required this.id, required this.name, required this.post, this.modIds = const []});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'sourcePost': post.toMap(),
        'modIds': modIds,
      };

  factory CatalogCollection.fromMap(Map<String, dynamic> map) => CatalogCollection(
        id: map['id'] as String,
        name: map['name'] as String? ?? '',
        post: SourcePostRefMapper.fromMap(Map<String, dynamic>.from(map['sourcePost'] as Map)),
        modIds: [for (final id in (map['modIds'] as List?) ?? const []) id as String],
      );
}

/// `mod-catalog.json`: every mod with its permanent id and source posts, and the
/// Collections that keep an old address.
///
/// It holds none of the facts the details file holds. A reader finds a mod's
/// facts in `mod-catalog-details.json` through its source posts — the forum
/// topic id or Discord thread id, and the LLM's name for the mod — without
/// matching names.
class ModCatalog {
  static const String fileName = 'mod-catalog.json';

  final DateTime generatedAt;
  final List<CatalogMod> mods;
  final List<CatalogCollection> collections;

  /// Old ids that no mod has any more, each with the id of the mod it was
  /// joined into. The site keeps such an address leading to that mod's page.
  final Map<String, String> movedIds;

  /// What the takedowns left out of this build. Never written to the file.
  final TakedownReport takedownReport;

  const ModCatalog({
    required this.generatedAt,
    this.mods = const [],
    this.collections = const [],
    this.movedIds = const {},
    this.takedownReport = const TakedownReport(),
  });

  Map<String, dynamic> toMap() => {
        'items': [for (final mod in mods) mod.toMap()],
        'collections': [for (final c in collections) c.toMap()],
        if (movedIds.isNotEmpty) 'movedIds': Map.fromEntries(movedIds.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
        'totalCount': mods.length,
        'lastUpdated': generatedAt.toUtc().toIso8601String(),
      };

  factory ModCatalog.fromMap(Map<String, dynamic> map) => ModCatalog(
        generatedAt: DateTime.tryParse(map['lastUpdated'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        mods: [
          for (final item in (map['items'] as List?) ?? const [])
            CatalogMod.fromMap(Map<String, dynamic>.from(item as Map)),
        ],
        collections: [
          for (final item in (map['collections'] as List?) ?? const [])
            CatalogCollection.fromMap(Map<String, dynamic>.from(item as Map)),
        ],
        movedIds: {
          for (final MapEntry(:key, :value) in ((map['movedIds'] as Map?) ?? const {}).entries)
            if (key is String && value is String) key: value,
        },
      );

  /// The Discord threads of every mod built from one of [topicIds], each once,
  /// in catalog order.
  List<String> discordThreadIdsFor(Iterable<int> topicIds) {
    final topics = {for (final id in topicIds) '$id'};
    final threadIds = <String>{};
    for (final mod in mods) {
      final posts = mod.sourcePosts;
      if (!posts.any((post) => post.kind == SourceKind.forum && topics.contains(post.id))) continue;
      for (final post in posts) {
        if (post.kind == SourceKind.discord) threadIds.add(post.id);
      }
    }
    return threadIds.toList();
  }

  /// Reads [file], or null when there is none.
  static ModCatalog? read(File file) {
    if (!file.existsSync()) return null;
    return ModCatalog.fromMap(jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
  }

  Future<void> write(File file) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(const JsonEncoder.withIndent('  ').convert(toMap()));
    await temp.rename(file.path);
  }

  /// Merges [inputs] and gives every mod its permanent id.
  ///
  /// The ids of Collections are held back first, so no mod can be handed an
  /// address that is about to become a Collection's page. Then each merged mod
  /// is looked up by its source posts, and by its name only when none of them
  /// has an id. [ids] is changed but not saved; the caller saves it once the
  /// catalog is written.
  ///
  /// [takedowns] are applied in two places. A mod entry's posts are blocked
  /// before the merge, so a taken-down listing can never be joined to another
  /// mod of the same name and take that mod down too. Author entries are
  /// checked after the merge, once a mod's credits hold every source's
  /// spelling. A mod given a mod entry's id is left out as well, which catches
  /// a mod the LLM renamed too far for its key to match.
  static Future<ModCatalog> build({
    required CatalogListings inputs,
    required ModIdStore ids,
    ModMerger? merger,
    MergeDebugCollector? debugCollector,
    bool keepAllGameVersionsFromSameSource = false,
    TakedownList takedowns = const TakedownList(),
    void Function(String message)? log,
    DateTime? generatedAt,
  }) async {
    final matches = {for (final key in takedowns.entryKeys) key: TakedownMatch(key)};
    final listings = <Listing>[];
    final blocked = <Listing>[];
    for (final listing in inputs.listings) {
      final entry = takedowns.blockingEntry(listing.ref, name: listing.mod.name);
      if (entry == null) {
        listings.add(listing);
        continue;
      }
      blocked.add(listing);
      final noted = matches[entry.id]!.blockedPosts;
      if (!noted.contains(listing.ref.key)) noted.add(listing.ref.key);
    }

    ids.beginRun(refsThisRun: [
      for (final listing in listings) listing.ref,
      for (final collection in inputs.collections) collection.ref,
    ], blockedRefs: [
      for (final listing in blocked) listing.ref,
    ]);
    final reserved = <(String, Listing)>[];
    for (final collection in inputs.collections) {
      final id = ids.reserveCollection(
        collection.mod.name,
        mark: markFor(collection.mod),
        ref: collection.ref,
      );
      if (id != null) reserved.add((id, collection));
    }

    final merged = await (merger ?? ModMerger()).mergeListings(
      listings,
      keepAllGameVersionsFromSameSource: keepAllGameVersionsFromSameSource,
      debugCollector: debugCollector,
      existingIdOf: (post) => post.id.isEmpty ? null : ids.idLinkedTo(post.ref),
    );

    // Who gets an old id when two mods' posts both lead to it. First a mod that
    // still goes by the id's name: the old site sometimes joined a Discord
    // announcement to whatever forum topic its message linked, and topic 29589
    // turned out to be NebuLib while the page, "nitelib-update-i", was the
    // Discord thread's NiteLib. Then a mod with a forum topic, so a topic has
    // the next claim on its own old id (see ModIdStore.idForPosts). Then the
    // rest. The mods keep their order in the file.
    final postsOf = [
      for (final entry in merged) [for (final post in entry.sourcePosts) if (post.id.isNotEmpty) post],
    ];
    int claimOrder(int i) {
      final names = [merged[i].mod.name, for (final post in postsOf[i]) if (post.llmModName case final name?) name];
      final idNames = ids.namesLinkedTo([for (final post in postsOf[i]) post.ref]);
      if (idNames.any((idName) => names.any((name) => modNamesMatch(idName, name)))) return 0;
      if (postsOf[i].any((post) => post.kind == SourceKind.forum)) return 1;
      return 2;
    }

    final order = [for (var i = 0; i < merged.length; i++) (i, claimOrder(i))];
    final idOf = List<String?>.filled(merged.length, null);
    for (final i in [
      for (final tier in [0, 1, 2])
        for (final (i, t) in order)
          if (t == tier) i,
    ]) {
      idOf[i] = ids.idForPosts(
        merged[i].mod.name,
        mark: markFor(merged[i].mod),
        refs: [for (final post in postsOf[i]) post.ref],
        onClash: log,
        onRenamed: log,
      );
    }
    final everyMod = [
      for (var i = 0; i < merged.length; i++)
        CatalogMod(id: idOf[i]!, mod: merged[i].mod, sourcePosts: postsOf[i]),
    ];

    // A mod given a mod entry's id, and a mod crediting a person an author
    // entry names, are left out. Their ids stay in the id file, linked to
    // their posts, so restoring the entry brings each back at its address.
    final mods = <CatalogMod>[];
    final dropped = <CatalogMod>[];
    for (final mod in everyMod) {
      final byId = takedowns.modEntry(mod.id);
      if (byId != null) {
        matches[byId.id]!.mods.add((id: mod.id, name: mod.mod.name, credit: null));
        dropped.add(mod);
        continue;
      }
      final byAuthor = takedowns.authorMatch(mod.mod.getAuthors());
      if (byAuthor != null) {
        matches[TakedownList.authorKey(byAuthor.entry)]!
            .mods
            .add((id: mod.id, name: mod.mod.name, credit: byAuthor.credit));
        dropped.add(mod);
        continue;
      }
      mods.add(mod);
    }
    final droppedIds = {for (final mod in dropped) mod.id};
    // A mod whose listings were blocked before the merge never got an id this
    // build, but it is the entry's mod all the same.
    for (final entry in takedowns.mods) {
      final match = matches[entry.id]!;
      if (match.blockedPosts.isNotEmpty && !match.mods.any((mod) => mod.id == entry.id)) {
        match.mods.add((id: entry.id, name: entry.name, credit: null));
      }
    }

    // The topics a Collection's mods link to, where they have a thread of
    // their own (see SourcePostListings.combine).
    Set<String> pointedFrom(SourcePostRef collection) {
      final prefix = '${collection.post.key}#';
      return {
        for (final MapEntry(:key, :value) in inputs.pointers.entries)
          if (key.startsWith(prefix)) value,
      };
    }

    final blockedPosts = {for (final listing in blocked) listing.ref.post.key};
    final collections = <CatalogCollection>[];
    for (final (id, collection) in reserved) {
      final modIds = [
        for (final mod in everyMod)
          if (mod.sourcePosts.any((post) =>
              (post.kind == collection.ref.kind && post.id == collection.ref.id) ||
              pointedFrom(collection.ref).contains(post.ref.post.key)))
            mod.id,
      ];
      final kept = [for (final modId in modIds) if (!droppedIds.contains(modId)) modId];
      final page = CatalogCollection(id: id, name: collection.mod.name, post: collection.ref.post, modIds: kept);
      if (takedowns.modEntry(id) case final entry?) {
        matches[entry.id]!.collections.add((id: id, name: page.name));
        continue;
      }
      // Every mod it held was taken down, so the page has nothing left to list.
      if (kept.isEmpty && (modIds.isNotEmpty || blockedPosts.contains(collection.ref.post.key))) continue;
      collections.add(page);
    }

    final movedIds = ids.movedIds([
      for (final mod in mods)
        (
          id: mod.id,
          names: [mod.mod.name],
          authors: mod.mod.getAuthors(),
          refs: [for (final post in mod.sourcePosts) post.ref],
        ),
    ], pointers: inputs.pointers, takenDown: {...takedowns.modIds, ...droppedIds}, log: log);

    // The posts with nothing left on them, which the details file leaves out
    // too. A post that still gives a published mod stays in it whole.
    final keptPosts = {
      for (final mod in mods)
        for (final post in mod.sourcePosts) post.ref.post.key,
    };
    final removedPosts = {
      ...blockedPosts,
      for (final mod in dropped)
        for (final post in mod.sourcePosts) post.ref.post.key,
    }.difference(keptPosts);

    final report = TakedownReport(matches: matches.values.toList(), removedPosts: removedPosts);
    if (log != null) _logTakedowns(report, log);

    return ModCatalog(
      generatedAt: (generatedAt ?? DateTime.now()).toUtc(),
      mods: mods,
      collections: collections,
      movedIds: movedIds,
      takedownReport: report,
    );
  }

  static void _logTakedowns(TakedownReport report, void Function(String message) log) {
    for (final match in report.matches) {
      final left = [
        for (final mod in match.mods)
          '"${mod.name}" (${mod.id}${mod.credit == null ? '' : ', credited to ${mod.credit}'})',
        for (final c in match.collections) 'the Collection page "${c.name}" (${c.id})',
      ];
      if (left.isEmpty) {
        log('WARNING: the takedown entry "${match.entry}" left out nothing this build. The author may have a '
            'new name, the mod may be back under a new id, or its post may be gone.');
      } else {
        log('Takedown "${match.entry}" left out ${left.length}: ${left.join(', ')}.');
      }
    }
    if (report.removedPosts.isNotEmpty) {
      log('${report.removedPosts.length} source post(s) had every mod taken down, so the details file leaves '
          'them out too.');
    }
  }

  /// What tells one mod apart from another of the same name: its forum topic
  /// where it has one, and failing that the person credited. The same mark the
  /// site used when it handed out ids, so existing entries are found again.
  static String markFor(ScrapedMod mod) {
    final topicId = ModMerger.extractForumTopicId(mod.getUrls()[ModUrlType.Forum]);
    if (topicId != null && topicId.isNotEmpty) return 'topic:$topicId';
    final authors = mod.getAuthors();
    if (authors.isNotEmpty) return 'author:${authors.first.toLowerCase()}';
    return '';
  }
}
