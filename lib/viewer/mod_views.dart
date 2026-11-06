import 'dart:convert';

import '../catalog/fact_choice.dart';
import '../catalog/listing.dart';
import '../catalog/mod_catalog.dart';
import '../catalog/source_post.dart';
import '../site/requirement_names.dart';
import '../site/sitemap.dart';
import 'bundle_views.dart';
import 'compare_rows.dart';
import 'data_access.dart';
import 'search_match.dart';

/// The viewer's Mods list, one mod's page and one mod's history, for
/// `GET /api/mods`, `GET /api/mods/<id>` and `GET /api/mods/<id>/history`.
/// Reads saved files only.
///
/// A mod is what the last built `mod-catalog.json` says it is. Beside it go
/// what the website published for it (`outputs/site/mods.json` and
/// `outputs/site/mods/<id>.json`), where each published fact came from
/// (`fact-sources.json`, used only when it was saved for this catalog), how
/// each of its posts joined it (the merge debug data of this build), and the
/// takedowns (`takedowns.json`, `takedown-matches.json`).
class ModViews {
  final DataAccess data;

  ModViews(this.data);

  // The catalog is parsed once per file version. DataAccess returns the same
  // map until the file changes on disk.
  Object? _heldCatalogMap;
  _Catalog? _heldCatalog;

  _Catalog? get _catalog {
    final map = data.modRepo;
    if (map == null) return null;
    if (identical(map, _heldCatalogMap) && _heldCatalog != null) return _heldCatalog;
    _heldCatalogMap = map;
    _joins = null;
    return _heldCatalog = _Catalog(map);
  }

  // --- The list ---

  /// Every catalog mod and taken-down mod, filtered and sorted as requested.
  /// Counts include every row. Null when no catalog has been built.
  ({List<Map<String, dynamic>> rows, Map<String, int> counts})? list({
    String q = '',
    Set<String> filters = const {},
    String sort = 'name',
    bool descending = false,
  }) {
    final all = _allRows();
    if (all == null) return null;

    final counts = {
      'total': all.length,
      'noDownload': all.where((r) => r.passes('noDownload')).length,
      'takenDown': all.where((r) => r.takenDown).length,
      'conflicts': all.where((r) => r.conflicts > 0).length,
      'aiStated': all.where((r) => r.usesAi != null).length,
    };

    final query = searchQuery(q);
    final rows = all.where((row) {
      if (!matchesSearch(query, row.searchFields)) return false;
      return filters.every(row.passes);
    }).toList();

    int compare(_ListRow a, _ListRow b) => switch (sort) {
          'id' => a.id.compareTo(b.id),
          'authors' => a.authors.join(', ').toLowerCase().compareTo(b.authors.join(', ').toLowerCase()),
          'gameVersion' => (a.gameVersion ?? '').compareTo(b.gameVersion ?? ''),
          'conflicts' => a.conflicts.compareTo(b.conflicts),
          _ => a.shownName.toLowerCase().compareTo(b.shownName.toLowerCase()),
        };
    rows.sort((a, b) {
      final by = descending ? compare(b, a) : compare(a, b);
      if (by != 0) return by;
      final byName = a.shownName.toLowerCase().compareTo(b.shownName.toLowerCase());
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });
    return (rows: [for (final row in rows) row.toMap()], counts: counts);
  }

  /// All list rows for `GET /api/search`, using the same search fields
  /// as the list. Null when no catalog has been built.
  List<Searchable>? searchable() {
    final all = _allRows();
    if (all == null) return null;
    return [
      for (final row in all)
        Searchable(
          fields: row.searchFields,
          sortName: row.shownName,
          id: row.id,
          item: {
            'id': row.id,
            'name': row.shownName,
            'authors': row.authors,
            if (row.takenDown) 'takenDown': true,
          },
        ),
    ];
  }

  /// Every catalog mod and taken-down mod, unfiltered. Null when no catalog
  /// has been built.
  List<_ListRow>? _allRows() {
    final catalog = _catalog;
    if (catalog == null) return null;
    final site = data.siteMods ?? const {};
    final conflicts = data.siteConflictCounts ?? const {};

    final all = <_ListRow>[];
    for (final mod in catalog.catalog.mods) {
      final record = site[mod.id];
      final names = [
        for (final name in (record?['nicknames'] as List?) ?? const []) '$name',
        for (final post in mod.sourcePosts)
          if (post.llmModName != null) post.llmModName!,
      ];
      all.add(_ListRow(
        id: mod.id,
        name: mod.mod.name,
        displayName: record?['displayName'] as String?,
        authors: mod.mod.getAuthors(),
        sources: [
          for (final source in (record?['sources'] as List?) ?? _kindsOf(mod.sourcePosts)) '$source',
        ],
        gameVersion: (record?['gameVersion'] ?? mod.mod.gameVersionReq) as String?,
        modVersion: (record?['modVersion'] ?? mod.mod.modVersion) as String?,
        hasDownload: record?['bestDownload'] != null,
        takenDown: false,
        conflicts: conflicts[mod.id] ?? 0,
        usesAi: record?['usesAi'] as bool?,
        otherNames: names,
      ));
    }
    final listed = {for (final row in all) row.id};
    for (final gone in _takenDownMods().values) {
      if (!listed.add(gone.id)) continue;
      all.add(_ListRow(
        id: gone.id,
        name: gone.name,
        displayName: null,
        authors: const [],
        sources: _kindsOf(gone.posts.map(_refOfKey).whereType<SourcePostRef>().toList()),
        gameVersion: null,
        modVersion: null,
        hasDownload: false,
        takenDown: true,
        conflicts: 0,
        usesAi: null,
        otherNames: const [],
      ));
    }

    return all;
  }

  static List<String> _kindsOf(List<Object> posts) => [
        for (final kind in SourceKind.values)
          if (posts.any((p) => (p is CatalogSourcePost ? p.kind : (p as SourcePostRef).kind) == kind)) kind.name,
      ];

  // --- One mod ---

  /// What the viewer knows about [id]: a mod, a Collection, an old id that
  /// leads to another mod, a taken-down mod, or nothing. Null when no catalog
  /// has been built.
  Map<String, dynamic>? mod(String id) {
    final catalog = _catalog;
    if (catalog == null) return null;
    final oldIds = [
      for (final MapEntry(:key, :value) in catalog.catalog.movedIds.entries)
        if (value == id) key,
    ]..sort();

    final mod = catalog.byId[id];
    if (mod != null) return _modAnswer(catalog, mod, oldIds);

    final collection = catalog.collectionById[id];
    if (collection != null) {
      return {
        'id': id,
        'kind': 'collection',
        'collection': {
          'id': collection.id,
          'name': collection.name,
          'sourcePost': _postRow(collection.post.kind, collection.post.id),
          'mods': [
            for (final modId in collection.modIds)
              {
                'id': modId,
                'name': catalog.byId[modId]?.mod.name ?? modId,
                if (data.siteMods?[modId]?['displayName'] case final String shown) 'displayName': shown,
              },
          ],
        },
        'catalog': catalog.rawCollections[id],
        'site': data.siteModFile(id),
        'oldIds': oldIds,
      };
    }

    final movedTo = catalog.catalog.movedIds[id];
    if (movedTo != null) {
      final target = catalog.byId[movedTo];
      return {
        'id': id,
        'kind': 'moved',
        'movedTo': movedTo,
        if (target != null) 'movedToName': target.mod.name,
      };
    }

    final gone = _takenDownMods()[id];
    if (gone != null) {
      return {
        'id': id,
        'kind': 'takenDown',
        'name': gone.name,
        'sourcePosts': [
          for (final key in gone.posts)
            if (_refOfKey(key) case final ref?) {..._postRow(ref.kind, ref.id), if (ref.llmModName != null) 'llmName': ref.llmModName},
        ],
        'takedown': {
          'status': 'takenDown',
          // Which kind of takedown entry left it out, and for an author entry
          // the person it names.
          'entryKind': gone.author == null ? 'mod' : 'author',
          if (gone.author != null) 'author': gone.author,
          if (gone.entry != null) 'entry': gone.entry,
          if (gone.match != null) 'match': gone.match,
        },
        'oldIds': oldIds,
      };
    }

    return {'id': id, 'kind': 'unknown'};
  }

  Map<String, dynamic> _modAnswer(_Catalog catalog, CatalogMod mod, List<String> oldIds) {
    final site = data.siteModFile(mod.id);
    final joins = _joinsFor(catalog);
    final joinedBy = joins?.forMod(mod);

    final sourcePosts = [
      for (final post in mod.sourcePosts)
        {
          ..._postRow(post.kind, post.id),
          if (post.llmModName != null) 'llmName': post.llmModName,
          'foundBy': post.foundBy.name,
          if (joinedBy?[post.ref.key] case final how?) 'joinedBy': how,
        },
    ];

    // Where each fact came from, only from the file saved for this catalog.
    final file = data.factSources;
    final String factsStatus;
    final facts = <String, dynamic>{};
    if (file == null) {
      factsStatus = 'missing';
    } else if (!file.builtAt.isAtSameMomentAs(catalog.catalog.generatedAt)) {
      factsStatus = 'otherBuild';
    } else {
      factsStatus = 'current';
      final listing = site?['listing'];
      for (final MapEntry(key: field, value: origin) in (file.mods[mod.id] ?? const <String, FactOrigin>{}).entries) {
        final value = site == null
            ? null
            : site.containsKey(field)
                ? site[field]
                : (listing is Map ? listing[field] : null);
        facts[field] = {
          'value': value,
          'source': origin.toJson(),
          if (origin.fromJson() case final from?) 'from': from,
        };
      }
    }

    final takedowns = _takedownsOverlapping(mod);
    return {
      'id': mod.id,
      'kind': 'mod',
      'builtAt': catalog.catalog.generatedAt.toUtc().toIso8601String(),
      'catalog': catalog.rawMods[mod.id],
      'site': site,
      'starmodderUrl': '${siteAddress}mods/${mod.id}/',
      'publishedFileUrl': '${siteAddress}mods/${mod.id}.json',
      'sourcePosts': sourcePosts,
      'facts': facts,
      'factsStatus': factsStatus,
      'oldIds': oldIds,
      if (takedowns.isNotEmpty)
        'takedown': {
          'status': 'returnedUnderNewId',
          'entries': takedowns,
        },
      'unmatchedNeeds': _unmatchedNeeds(site),
    };
  }

  /// One post's kind, id, title, and the kind the Source posts pages use
  /// (`topic` or `discord`; none for a Nexus page).
  Map<String, dynamic> _postRow(SourceKind kind, String id) => {
        'kind': kind.name,
        'id': id,
        'title': _titleOf(kind, id),
        if (kind == SourceKind.forum) 'postKind': 'topic',
        if (kind == SourceKind.discord) 'postKind': 'discord',
      };

  Object? _titleIndexFor;
  Map<String, String> _titles = const {};

  String _titleOf(SourceKind kind, String id) {
    switch (kind) {
      case SourceKind.forum:
        final index = data.index;
        if (!identical(index, _titleIndexFor)) {
          _titleIndexFor = index;
          _titles = {for (final topic in index ?? const []) '${topic.topicId}': topic.title};
        }
        return _titles[id] ?? '';
      case SourceKind.discord:
        final thread = data.discordPosts?.threads[id];
        if (thread != null && thread.name.isNotEmpty) return thread.name;
        for (final answer in (data.bundle?['discordThreads'] as List?) ?? const []) {
          if (answer is Map && answer['threadId'] == id) return '${answer['name'] ?? ''}';
        }
        return '';
      case SourceKind.nexus:
        return '';
    }
  }

  /// Requirement names the website build could not match to a mod, as written
  /// in the post (`name`), each with the key `requirement-names.json` files it
  /// under (`key`), which is how the page finds a pending match for it.
  /// Required names come first, then optional names.
  static List<Map<String, String>> _unmatchedNeeds(Map<String, dynamic>? site) {
    final seen = <String>{};
    final listing = site?['listing'];
    final names = <Map<String, String>>[];
    for (final list in [listing is Map ? listing['needs'] : null, site?['optionalNeeds']]) {
      for (final need in list is List ? list : const []) {
        if (need is! Map || need['id'] != null || need['via'] != null) continue;
        final name = '${need['name'] ?? ''}'.trim();
        if (name.isNotEmpty && seen.add(name.toLowerCase())) {
          names.add({'name': name, 'key': requirementKey(name)});
        }
      }
    }
    return names;
  }

  // --- Takedowns ---

  /// Every mod a takedown keeps off the site, by id: the mod entries of
  /// `takedowns.json` and the mods `takedown-matches.json` says the last build
  /// left out (which include the ones an author entry removed).
  Map<String, _TakenDown> _takenDownMods() {
    final out = <String, _TakenDown>{};
    final list = data.takedownList;
    final matches = data.takedownMatches;
    final entries = <String, Map<String, dynamic>>{};
    for (final entry in (list?['mods'] as List?) ?? const []) {
      if (entry is Map<String, dynamic> && entry['id'] is String) entries[entry['id'] as String] = entry;
    }
    final authorEntries = [
      for (final entry in (list?['authors'] as List?) ?? const [])
        if (entry is Map<String, dynamic>) entry,
    ];

    Map<String, dynamic>? entryFor(String key) {
      if (entries[key] case final entry?) return entry;
      if (!key.startsWith('author:')) return null;
      final name = key.substring('author:'.length).toLowerCase();
      return authorEntries
          .where((e) => ((e['names'] as List?) ?? const []).any((n) => '$n'.toLowerCase() == name))
          .firstOrNull;
    }

    for (final match in (matches?['matches'] as List?) ?? const []) {
      if (match is! Map<String, dynamic>) continue;
      final key = '${match['entry'] ?? ''}';
      final entry = entryFor(key);
      final byAuthor = entries[key] == null && key.startsWith('author:');
      final authorNames = (entry?['names'] as List?) ?? const [];
      final author = !byAuthor
          ? null
          : authorNames.isNotEmpty
              ? '${authorNames.first}'
              : key.substring('author:'.length);
      for (final mod in (match['mods'] as List?) ?? const []) {
        if (mod is! Map || mod['id'] is! String) continue;
        final id = mod['id'] as String;
        out[id] = _TakenDown(
          id: id,
          name: '${mod['name'] ?? id}',
          posts: [
            for (final post in (entries[id]?['posts'] as List?) ?? (match['blockedPosts'] as List?) ?? const []) '$post',
          ],
          entry: entry,
          match: match,
          author: author,
        );
      }
    }
    for (final MapEntry(key: id, value: entry) in entries.entries) {
      out.putIfAbsent(
          id,
          () => _TakenDown(
                id: id,
                name: '${entry['name'] ?? id}',
                posts: [for (final post in (entry['posts'] as List?) ?? const []) '$post'],
                entry: entry,
                match: null,
              ));
    }
    return out;
  }

  /// Takedown mod entries whose posts are posts of [mod]: the mod came back
  /// under a new id.
  List<Map<String, dynamic>> _takedownsOverlapping(CatalogMod mod) {
    final keys = {for (final post in mod.sourcePosts) ...[post.ref.key, post.ref.post.key]};
    return [
      for (final entry in (data.takedownList?['mods'] as List?) ?? const [])
        if (entry is Map<String, dynamic> && ((entry['posts'] as List?) ?? const []).any((p) => keys.contains('$p')))
          entry,
    ];
  }

  // --- How each post joined its mod ---

  _Joins? _joins;
  String _joinsStamp = '';

  /// How each post joined its mod, from the merge debug data that goes with
  /// [catalog]: `merge-debug.json` first, then the merge snapshot of the run
  /// that built the catalog. Null when there is neither.
  _Joins? _joinsFor(_Catalog catalog) {
    final debug = data.mergeDebug;
    final snapshots = data.mergeRuns();
    final stamp = [
      identityHashCode(catalog),
      identityHashCode(debug),
      for (final s in snapshots) s.id,
    ].join('|');
    if (_joins != null && stamp == _joinsStamp) return _joins;
    _joinsStamp = stamp;

    final candidates = <Map<String, dynamic>? Function()>[
      if (debug != null) () => debug,
    ];
    // The run started before the catalog was built and saved its snapshot after.
    // Old snapshots use the file time when no save time was recorded. Copying
    // the data folder can give those files a later time. Check newest first
    // to avoid choosing an older build's snapshot.
    final built = catalog.catalog.generatedAt;
    for (final s in snapshots) {
      final started = s.startedAt ?? s.savedAt;
      if (started.isAfter(built) || s.writtenAt.isBefore(built)) continue;
      candidates.add(() => data.mergeSnapshots.readRaw(s.id));
      break;
    }
    return _joins = _Joins(candidates);
  }

  // --- History ---

  final Map<String, Map<String, dynamic>> _historyCache = {};
  String _historyStamp = '';

  /// The saved runs in which [id] changed, newest first, or null when no
  /// catalog has been built. Cached per mod until the saved snapshots or the
  /// catalog change. Handles other requests between snapshots so a slow first
  /// history request does not block the rest of the viewer.
  Future<Map<String, dynamic>?> history(String id) async {
    final catalog = _catalog;
    if (catalog == null) return null;
    final bundles = data.bundleRuns();
    final merges = data.mergeRuns();
    final stamp = [
      catalog.catalog.generatedAt.toIso8601String(),
      for (final s in bundles) s.id,
      '|',
      for (final s in merges) s.id,
    ].join(',');
    if (stamp != _historyStamp) {
      _historyCache.clear();
      _historyStamp = stamp;
    }
    final held = _historyCache[id];
    if (held != null) return held;

    final answer = mod(id) ?? const {'kind': 'unknown'};
    final kind = answer['kind'] as String;
    final keys = <String>{
      if (catalog.byId[id] case final mod?)
        for (final post in mod.sourcePosts) post.ref.key,
      if (catalog.collectionById[id] case final collection?) collection.post.key,
      if (kind == 'takenDown')
        for (final post in (answer['sourcePosts'] as List)) _keyOfRow(post as Map),
      ..._idPosts(id),
    };
    final refs = [
      for (final key in keys)
        if (_refOfKey(key) case final ref?) ref,
    ];

    final entries = <Map<String, dynamic>>[];
    final bundleWalk = await _walk(
      source: 'bundle',
      snapshots: [for (final s in bundles.reversed) (s.id, s.savedAt, () => data.bundleRunUncached(s.id))],
      recordOf: (snapshot) => _bundleRecord(snapshot, refs),
      entries: entries,
    );
    final mergeWalk = await _walk(
      source: 'merge',
      snapshots: [for (final s in merges.reversed) (s.id, s.savedAt, () => data.mergeSnapshots.readRaw(s.id))],
      recordOf: (snapshot) => _mergeRecord(snapshot, keys),
      entries: entries,
    );
    entries.sort((a, b) {
      final byTime = (b['at'] as String).compareTo(a['at'] as String);
      return byTime != 0 ? byTime : (b['runId'] as String).compareTo(a['runId'] as String);
    });

    final worked = {
      'id': id,
      'kind': kind,
      'posts': [for (final ref in refs) FactOrigin.refToJson(ref)],
      'entries': entries,
      'bundleSnapshots': bundleWalk,
      'mergeSnapshots': mergeWalk,
    };
    _historyCache[id] = worked;
    return worked;
  }

  static String _keyOfRow(Map post) =>
      post['llmName'] == null ? '${post['kind']}:${post['id']}' : '${post['kind']}:${post['id']}#${post['llmName']}';

  /// The posts `mod-ids.json` links to [id].
  List<String> _idPosts(String id) {
    final ids = data.modIds?['ids'];
    if (ids is! Map) return const [];
    for (final entry in ids.values) {
      if (entry is Map && entry['id'] == id) {
        return [for (final post in (entry['posts'] as List?) ?? const []) '$post'];
      }
    }
    return const [];
  }

  /// Walks [snapshots] oldest to newest and adds an entry for each one in
  /// which the record changed. Returns how many were read.
  static Future<Map<String, dynamic>> _walk({
    required String source,
    required List<(String, DateTime, Map<String, dynamic>? Function())> snapshots,
    required _Record? Function(Map<String, dynamic> snapshot) recordOf,
    required List<Map<String, dynamic>> entries,
  }) async {
    var read = 0;
    var started = false;
    _Record? previous;
    DateTime? oldest;
    for (final (runId, savedAt, load) in snapshots) {
      // Let the server answer other requests between snapshots.
      await Future<void>.delayed(Duration.zero);
      final snapshot = load();
      if (snapshot == null) continue;
      read++;
      oldest ??= savedAt;
      final now = recordOf(snapshot);
      if (!started) {
        started = true;
        previous = now;
        continue;
      }
      final diff = _diff(previous, now);
      if (diff != null) {
        entries.add({
          'runId': runId,
          'at': savedAt.toUtc().toIso8601String(),
          'source': source,
          'kind': diff.kind,
          'fields': {for (final change in diff.changes) change['field']}.toList(),
          'diff': diff.changes,
        });
      }
      previous = now;
    }
    return {
      'read': read,
      'total': snapshots.length,
      if (oldest != null) 'oldestSavedAt': oldest.toUtc().toIso8601String(),
    };
  }

  /// What changed between two readings of the mod, or null when nothing did.
  static ({String kind, List<Map<String, dynamic>> changes})? _diff(_Record? before, _Record? after) {
    if (before == null && after == null) return null;
    if (before == null) return (kind: 'first', changes: const <Map<String, dynamic>>[]);
    if (after == null) return (kind: 'gone', changes: const <Map<String, dynamic>>[]);
    final changes = <Map<String, dynamic>>[];
    for (final key in {...before.parts.keys, ...after.parts.keys}) {
      final was = before.parts[key];
      final now = after.parts[key];
      final post = after.posts[key] ?? before.posts[key];
      if (was == null || now == null) {
        changes.add({
          if (post != null) 'post': post,
          'field': 'source post',
          'note': was == null ? 'This post was in this snapshot for the first time.' : 'This post is no longer in this snapshot.',
        });
        continue;
      }
      for (final change in changedFields(was.record, now.record, was.fields)) {
        changes.add({if (post != null) 'post': post, ...change});
      }
    }
    return changes.isEmpty ? null : (kind: 'changed', changes: changes);
  }

  /// The mod as one saved bundle has it: each of its posts' records, narrowed
  /// to the LLM's answer for this mod where the post names one.
  static _Record? _bundleRecord(Map<String, dynamic> snapshot, List<SourcePostRef> refs) {
    final parts = <String, _Part>{};
    final posts = <String, Map<String, String>>{};
    for (final ref in refs) {
      Map<String, dynamic>? record;
      List<ComparedField> fields;
      switch (ref.kind) {
        case SourceKind.forum:
          final topicId = int.tryParse(ref.id);
          record = topicId == null ? null : topicRecordOf(snapshot, topicId);
          if (record != null) record = {...record, 'llm': _narrowed(record['llm'], ref.llmModName)};
          fields = bundleFields;
        case SourceKind.discord:
          final thread = ((snapshot['discordThreads'] as List?) ?? const [])
              .whereType<Map>()
              .where((t) => '${t['threadId']}' == ref.id)
              .firstOrNull;
          record = thread == null
              ? null
              : {
                  'name': thread['name'],
                  'url': thread['url'],
                  'llm': _narrowed({'mods': thread['mods']}, ref.llmModName),
                };
          fields = discordThreadFields;
        case SourceKind.nexus:
          continue;
      }
      if (record == null) continue;
      parts[ref.key] = _Part(record, fields);
      posts[ref.key] = FactOrigin.refToJson(ref);
    }
    return parts.isEmpty ? null : _Record(parts, posts);
  }

  /// The LLM's answer with only the mod named [name] kept, when there is a
  /// name; the whole answer otherwise.
  static Object? _narrowed(Object? llm, String? name) {
    if (llm is! Map || name == null) return llm;
    final wanted = name.trim().toLowerCase();
    return {
      ...llm,
      'mods': [
        for (final mod in (llm['mods'] as List?) ?? const [])
          if (mod is Map && '${mod['name'] ?? ''}'.trim().toLowerCase() == wanted) mod,
      ],
    };
  }

  static final List<ComparedField> _mergeFields = [
    const ComparedField('name'),
    const ComparedField('authorsList', label: 'authors', itemsOf: listItems),
    const ComparedField('categories', itemsOf: listItems),
    const ComparedField('gameVersionReq', label: 'game version'),
    const ComparedField('modVersion', label: 'mod version'),
    ComparedField('summary', describe: (a, b) => 'The merged summary changed.'),
    ComparedField('description', describe: (a, b) => 'The merged description changed.'),
    const ComparedField('urls', label: 'links', itemsOf: mapItems),
    const ComparedField('sources', itemsOf: listItems),
    const ComparedField('sourcePosts', label: 'source posts', itemsOf: listItems),
  ];

  /// The mod in a saved merge with the most source posts matching [keys].
  static _Record? _mergeRecord(Map<String, dynamic> snapshot, Set<String> keys) {
    final output = (snapshot['finalOutput'] as List?) ?? const [];
    final posts = (snapshot['finalSourcePosts'] as List?) ?? const [];
    var best = -1;
    var bestShared = 0;
    for (var i = 0; i < posts.length && i < output.length; i++) {
      final shared = _keysOf(posts[i]).where(keys.contains).length;
      if (shared > bestShared) {
        best = i;
        bestShared = shared;
      }
    }
    if (best < 0 || output[best] is! Map) return null;
    final record = {
      ...(output[best] as Map).cast<String, dynamic>(),
      'sourcePosts': _keysOf(posts[best])..sort(),
    };
    return _Record({'merge': _Part(record, _mergeFields)}, const {});
  }

  static List<String> _keysOf(Object? posts) => [
        for (final post in posts is List ? posts : const [])
          if (post is Map) post['llmModName'] == null ? '${post['kind']}:${post['id']}' : '${post['kind']}:${post['id']}#${post['llmModName']}',
      ];
}

/// `forum:123`, `forum:123#Name` or `discord:456` read back as a ref.
SourcePostRef? _refOfKey(String key) {
  final colon = key.indexOf(':');
  if (colon < 0) return null;
  final kind = SourceKind.values.where((k) => k.name == key.substring(0, colon)).firstOrNull;
  if (kind == null) return null;
  final rest = key.substring(colon + 1);
  final hash = rest.indexOf('#');
  return hash < 0
      ? SourcePostRef(kind: kind, id: rest)
      : SourcePostRef(kind: kind, id: rest.substring(0, hash), llmModName: rest.substring(hash + 1));
}

/// The catalog, parsed once, with its mods and Collections by id and the raw
/// records as the file has them.
class _Catalog {
  final ModCatalog catalog;
  final Map<String, CatalogMod> byId;
  final Map<String, CatalogCollection> collectionById;
  final Map<String, dynamic> rawMods;
  final Map<String, dynamic> rawCollections;

  _Catalog._(this.catalog, this.byId, this.collectionById, this.rawMods, this.rawCollections);

  factory _Catalog(Map<String, dynamic> map) {
    final catalog = ModCatalog.fromMap(map);
    return _Catalog._(
      catalog,
      {for (final mod in catalog.mods) mod.id: mod},
      {for (final collection in catalog.collections) collection.id: collection},
      {
        for (final item in (map['items'] as List?) ?? const [])
          if (item is Map && item['id'] is String) item['id'] as String: item,
      },
      {
        for (final item in (map['collections'] as List?) ?? const [])
          if (item is Map && item['id'] is String) item['id'] as String: item,
      },
    );
  }
}

class _TakenDown {
  final String id;
  final String name;
  final List<String> posts;
  final Map<String, dynamic>? entry;
  final Map<String, dynamic>? match;

  /// The first name listed in the author takedown. Null for a mod takedown.
  final String? author;

  const _TakenDown({required this.id, required this.name, required this.posts, this.entry, this.match, this.author});
}

/// One post's record in one snapshot, and the fields compared on it.
class _Part {
  final Map<String, dynamic> record;
  final List<ComparedField> fields;

  const _Part(this.record, this.fields);
}

/// A mod as one snapshot has it: a part per post (or one for the merged mod),
/// and each post's `{kind, id, llmName}`.
class _Record {
  final Map<String, _Part> parts;
  final Map<String, Map<String, String>> posts;

  const _Record(this.parts, this.posts);
}

/// How each post joined its mod in one merge, read from that merge's debug
/// data. Each candidate is read only when needed and only once.
///
/// In each group of listings the merge formed, the first member is the one
/// the mod started from (`first`). Every other member joined through the
/// first match recorded for it: `sameId` when the two posts already shared a
/// permanent id, else `forumLink` (a link to the same forum topic), else
/// `download` (a shared download), else `name` (name and author). A mod's
/// answer is used only when that merge's output has a mod with exactly the
/// mod's posts, so data from another build is never read as this one's.
class _Joins {
  final List<Map<String, dynamic>? Function()> _candidates;
  final List<_JoinData?> _read = [];

  _Joins(this._candidates);

  _JoinData? _data(int i) {
    while (_read.length <= i) {
      final map = _candidates[_read.length]();
      _read.add(map == null ? null : _JoinData(map));
    }
    return _read[i];
  }

  /// By post key (`forum:123#Name`), or null when no candidate made this mod.
  Map<String, String>? forMod(CatalogMod mod) {
    final keys = [for (final post in mod.sourcePosts) post.ref.key]..sort();
    final signature = keys.join('\n');
    for (var i = 0; i < _candidates.length; i++) {
      final data = _data(i);
      if (data == null || !data.outputs.contains(signature)) continue;
      return {
        for (final key in keys)
          if (data.joinedBy[key] case final how?) key: how,
      };
    }
    return null;
  }
}

class _JoinData {
  /// Each merged mod's post keys, sorted and joined by new lines.
  final Set<String> outputs = {};

  /// By post key.
  final Map<String, String> joinedBy = {};

  _JoinData(Map<String, dynamic> map) {
    for (final posts in (map['finalSourcePosts'] as List?) ?? const []) {
      outputs.add((ModViews._keysOf(posts)..sort()).join('\n'));
    }
    for (final group in (map['groups'] as List?) ?? const []) {
      if (group is! Map) continue;
      final members = (group['members'] as List?) ?? const [];
      final memberPosts = (group['memberSourcePosts'] as List?) ?? const [];
      if (memberPosts.length != members.length) continue;
      final memberJson = [for (final member in members) jsonEncode(member)];
      final entries = (group['matchEntries'] as List?) ?? const [];
      for (var i = 0; i < members.length; i++) {
        String? how;
        if (i == 0) {
          how = 'first';
        } else {
          for (final entry in entries) {
            if (entry is! Map) continue;
            if (jsonEncode(entry['outerMod']) != memberJson[i] && jsonEncode(entry['innerMod']) != memberJson[i]) {
              continue;
            }
            how = _howOf((entry['reasons'] as List?) ?? const []);
            break;
          }
        }
        if (how == null) continue;
        for (final key in ModViews._keysOf(memberPosts[i])) {
          joinedBy[key] = how;
        }
      }
    }
  }

  static String _howOf(List reasons) {
    if (reasons.contains('sameId')) return 'sameId';
    if (reasons.contains('forumUrl')) return 'forumLink';
    if (reasons.contains('nameAndDownload')) return 'download';
    return 'name';
  }
}

/// One row of the Mods list, before it is written out.
class _ListRow {
  final String id;
  final String name;
  final String? displayName;
  final List<String> authors;
  final List<String> sources;
  final String? gameVersion;
  final String? modVersion;
  final bool hasDownload;
  final bool takenDown;
  final int conflicts;
  final bool? usesAi;
  final List<String> otherNames;

  _ListRow({
    required this.id,
    required this.name,
    required this.displayName,
    required this.authors,
    required this.sources,
    required this.gameVersion,
    required this.modVersion,
    required this.hasDownload,
    required this.takenDown,
    required this.conflicts,
    required this.usesAi,
    required this.otherNames,
  });

  String get shownName => displayName ?? name;

  /// Search fields shared by the list and `GET /api/search`.
  /// The id is last so an equally ranked author match supplies the note.
  late final List<SearchField> searchFields = [
    SearchField(SearchFieldKind.name, shownName),
    if (displayName != null && displayName != name)
      SearchField(SearchFieldKind.name, name, detail: 'also called $name'),
    for (final author in authors) SearchField(SearchFieldKind.other, author, detail: 'author: $author'),
    for (final other in otherNames) SearchField(SearchFieldKind.alias, other, detail: 'also called $other'),
    SearchField.id(id),
  ];

  bool passes(String filter) => switch (filter) {
        'noDownload' => !hasDownload && !takenDown,
        'takenDown' => takenDown,
        'conflicts' || 'hasConflicts' => conflicts > 0,
        'aiStated' || 'aiUse' => usesAi != null,
        // Unknown filters leave all rows included.
        _ => true,
      };

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'displayName': displayName,
        'authors': authors,
        'sources': sources,
        'gameVersion': gameVersion,
        'modVersion': modVersion,
        'hasDownload': hasDownload,
        'takenDown': takenDown,
        'conflicts': conflicts,
        'usesAi': usesAi,
      };
}
