import 'dart:convert';
import 'dart:io';

import '../bot/scraper/debug/merge_debug_collector.dart';
import '../bot/scraper/mod_merger.dart';
import '../bot/scraper/scraped_mod.dart';
import '../site/mod_id_store.dart';
import 'catalog_inputs.dart';
import 'listing.dart';
import 'source_post.dart';

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

/// `ModRepo-v2.json`: every mod with its permanent id and source posts, and the
/// Collections that keep an old address.
///
/// It holds none of the facts the bundle holds. A reader finds a mod's facts
/// in `forum-data-bundle-v2.json` through its source posts — the forum topic id
/// or Discord thread id, and the LLM's name for the mod — without matching
/// names.
class ModCatalog {
  static const String fileName = 'ModRepo-v2.json';

  final DateTime generatedAt;
  final List<CatalogMod> mods;
  final List<CatalogCollection> collections;

  const ModCatalog({required this.generatedAt, this.mods = const [], this.collections = const []});

  Map<String, dynamic> toMap() => {
        'items': [for (final mod in mods) mod.toMap()],
        'collections': [for (final c in collections) c.toMap()],
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
      );

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
  static Future<ModCatalog> build({
    required CatalogListings inputs,
    required ModIdStore ids,
    ModMerger? merger,
    MergeDebugCollector? debugCollector,
    bool keepAllGameVersionsFromSameSource = false,
    void Function(String message)? log,
    DateTime? generatedAt,
  }) async {
    ids.beginRun(refsThisRun: [
      for (final listing in inputs.listings) listing.ref,
      for (final collection in inputs.collections) collection.ref,
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
      inputs.listings,
      keepAllGameVersionsFromSameSource: keepAllGameVersionsFromSameSource,
      debugCollector: debugCollector,
      existingIdOf: (post) => post.id.isEmpty ? null : ids.idLinkedTo(post.ref),
    );

    final mods = <CatalogMod>[];
    for (final entry in merged) {
      final posts = [for (final post in entry.sourcePosts) if (post.id.isNotEmpty) post];
      final id = ids.idForPosts(
        entry.mod.name,
        mark: markFor(entry.mod),
        refs: [for (final post in posts) post.ref],
        onClash: log,
        onRenamed: log,
      );
      mods.add(CatalogMod(id: id, mod: entry.mod, sourcePosts: posts));
    }

    final collections = [
      for (final (id, collection) in reserved)
        CatalogCollection(
          id: id,
          name: collection.mod.name,
          post: collection.ref.post,
          modIds: [
            for (final mod in mods)
              if (mod.sourcePosts.any((post) => post.kind == collection.ref.kind && post.id == collection.ref.id))
                mod.id,
          ],
        ),
    ];

    return ModCatalog(
      generatedAt: (generatedAt ?? DateTime.now()).toUtc(),
      mods: mods,
      collections: collections,
    );
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
