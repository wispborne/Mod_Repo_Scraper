import 'dart:convert';
import 'dart:io';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:path/path.dart' as p;

import '../bot/scraper/mod_repo_utils.dart';
import '../site/mod_name_match.dart';
import 'mod_catalog.dart';
import 'source_post.dart';

part 'takedowns.mapper.dart';

/// One mod taken down at somebody's request: its permanent id, the name it was
/// published under, the source posts it blocks and the day it was added.
///
/// [posts] are post keys. A whole post (`discord:1507163509224509510`) blocks
/// every listing on that post. A named one (`forum:34161#Useful.Tithes`)
/// blocks only the listings on that post whose LLM name matches the name by
/// [modNamesMatch]. An entry for a Collection's page has no posts.
///
/// There is no field for a reason, on purpose: the list is published.
@MappableClass()
class ModTakedown with ModTakedownMappable {
  final String id;
  final String name;
  final List<String> posts;
  final String on;

  const ModTakedown({required this.id, this.name = '', this.posts = const [], required this.on});
}

/// One person taken down: every mod that credits them, now and later.
@MappableClass()
class AuthorTakedown with AuthorTakedownMappable {
  final List<String> names;
  final String on;

  const AuthorTakedown({required this.names, required this.on});
}

/// `takedowns.json`: the mods and authors left out of everything we publish.
///
/// Kept in `qb_data` and copied to the published repo on every publish, so it
/// is public. A missing file is an empty list. A file that is there but cannot
/// be read throws, and the job must stop before it writes anything: building
/// without the list would put every taken-down mod back.
@MappableClass()
class TakedownList with TakedownListMappable {
  static const String fileName = 'takedowns.json';

  /// What the last catalog build left out for each entry. Not published.
  static const String matchesFileName = 'takedown-matches.json';

  /// The entries a restore job removed, so a publish can tell a restore from a
  /// lost list. Not published.
  static const String restoredFileName = 'takedowns-restored.json';

  final List<ModTakedown> mods;
  final List<AuthorTakedown> authors;

  const TakedownList({this.mods = const [], this.authors = const []});

  bool get isEmpty => mods.isEmpty && authors.isEmpty;

  /// Every entry's key: a mod entry's id, or `author:` and an author entry's
  /// first name. A mod id never holds a colon, so the two cannot clash.
  List<String> get entryKeys => [
        for (final mod in mods) mod.id,
        for (final author in authors) authorKey(author),
      ];

  static String authorKey(AuthorTakedown entry) => 'author:${entry.names.isEmpty ? '' : entry.names.first}';

  /// The ids named by mod entries.
  Set<String> get modIds => {for (final mod in mods) mod.id};

  ModTakedown? modEntry(String id) {
    for (final mod in mods) {
      if (mod.id == id) return mod;
    }
    return null;
  }

  /// The author entry naming the same person as [name] by the merge's rules.
  AuthorTakedown? authorEntryFor(String name) {
    for (final entry in authors) {
      if (entry.names.any((n) => ModRepoUtils.samePerson(n, name))) return entry;
    }
    return null;
  }

  /// The entry with [key] (see [entryKeys]), or null.
  Object? entryFor(String key) {
    if (key.startsWith('author:')) {
      final name = key.substring('author:'.length);
      for (final entry in authors) {
        if (authorKey(entry) == key) return entry;
      }
      return authorEntryFor(name);
    }
    return modEntry(key);
  }

  /// The same list without the entry with [key].
  TakedownList without(String key) {
    final entry = entryFor(key);
    return TakedownList(
      mods: [for (final mod in mods) if (!identical(mod, entry)) mod],
      authors: [for (final author in authors) if (!identical(author, entry)) author],
    );
  }

  static File fileIn(String dataPath) => File(p.join(dataPath, fileName));

  /// Reads the list in [dataPath]. A missing file is an empty list.
  static TakedownList read(String dataPath) => readFile(fileIn(dataPath));

  static TakedownList readFile(File file) {
    if (!file.existsSync()) return const TakedownList();
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) throw const FormatException('not a JSON object');
      return TakedownListMapper.fromMap(decoded);
    } catch (e) {
      throw StateError('Cannot read the takedown list at ${file.path}: $e\n'
          'Building without it would put every taken-down mod back, so the job '
          'has stopped before writing anything. Fix the file, or put the '
          'published copy back.');
    }
  }

  /// Writes the list to a replacement file first and then moves it over the
  /// old one, so a stopped process never leaves half a list.
  void write(String dataPath) => writeFile(fileIn(dataPath));

  void writeFile(File file) {
    file.parent.createSync(recursive: true);
    final temp = File('${file.path}.tmp');
    temp.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(toMap())}\n');
    temp.renameSync(file.path);
  }

  /// Whether a listing from [ref], called [name] by its source, is blocked by
  /// a mod entry. A whole-post key blocks every listing on its post. A named
  /// key blocks a listing on its post whose LLM name (or, failing that, its
  /// own name) matches the key's name.
  bool blocks(SourcePostRef ref, {String? name}) => blockingEntry(ref, name: name) != null;

  ModTakedown? blockingEntry(SourcePostRef ref, {String? name}) {
    if (ref.id.isEmpty) return null;
    final post = ref.post.key;
    final shown = ref.llmModName ?? name;
    for (final entry in mods) {
      for (final key in entry.posts) {
        final (keyPost, keyName) = splitPostKey(key);
        if (keyPost != post) continue;
        if (keyName == null) return entry;
        if (shown != null && modNamesMatch(keyName, shown)) return entry;
      }
    }
    return null;
  }

  /// The author entry one of [credits] matches, with the credit that matched,
  /// or null.
  ({AuthorTakedown entry, String credit})? authorMatch(Iterable<String> credits) {
    for (final credit in credits) {
      final entry = authorEntryFor(credit);
      if (entry != null) return (entry: entry, credit: credit);
    }
    return null;
  }
}

/// `forum:34161#Useful.Tithes` as its post, `forum:34161`, and its name.
(String, String?) splitPostKey(String key) {
  final at = key.indexOf('#');
  return at < 0 ? (key, null) : (key.substring(0, at), key.substring(at + 1));
}

/// The post keys a mod entry for [id] records, from the current [catalog]: the
/// whole post where no other catalog mod comes from that post, and this mod's
/// own listing on it (`forum:34161#Useful.Tithes`) where others do. A
/// Collection's id gives no posts. Null when [id] is neither a mod nor a
/// Collection in [catalog].
({String name, List<String> posts, bool isCollection})? takedownPostsFor(ModCatalog catalog, String id) {
  for (final collection in catalog.collections) {
    if (collection.id == id) return (name: collection.name, posts: const [], isCollection: true);
  }
  CatalogMod? mod;
  for (final candidate in catalog.mods) {
    if (candidate.id == id) mod = candidate;
  }
  if (mod == null) return null;

  final posts = <String>[];
  for (final post in mod.sourcePosts) {
    if (post.id.isEmpty) continue;
    final postKey = post.ref.post.key;
    final shared = catalog.mods.any((other) =>
        other.id != mod!.id && other.sourcePosts.any((theirs) => theirs.id.isNotEmpty && theirs.ref.post.key == postKey));
    final key = shared ? '$postKey#${post.llmModName ?? mod.mod.name}' : postKey;
    if (!posts.contains(key)) posts.add(key);
  }
  return (name: mod.mod.name, posts: posts, isCollection: false);
}

/// What a takedown would leave out, worked out from the current catalog with
/// the same rules the catalog step uses. For the viewer's confirm box; it
/// changes nothing.
///
/// For a mod: its posts and whether each is blocked whole or by name, the
/// Collections that would lose it, the old ids that lead to it, and which of
/// its posts `ModRepo.json` cannot block. For people: every mod that credits
/// one of them, with the credit that matched.
Map<String, dynamic> previewTakedown(
  ModCatalog catalog, {
  String? modId,
  List<String> authors = const [],
  TakedownList current = const TakedownList(),
}) {
  if (modId != null && modId.isNotEmpty) {
    final found = takedownPostsFor(catalog, modId);
    if (found == null) {
      return {'error': 'No mod or Collection in ${ModCatalog.fileName} has the id "$modId".'};
    }
    return {
      'kind': 'mod',
      'id': modId,
      'name': found.name,
      'isCollection': found.isCollection,
      'alreadyTakenDown': current.modEntry(modId) != null,
      'posts': [
        for (final key in found.posts) {'key': key, 'whole': splitPostKey(key).$2 == null},
      ],
      'collections': [
        for (final c in catalog.collections)
          if (c.modIds.contains(modId)) {'id': c.id, 'name': c.name, 'modsLeft': c.modIds.length - 1},
      ],
      'oldIds': [
        for (final MapEntry(:key, :value) in catalog.movedIds.entries)
          if (value == modId) key,
      ]..sort(),
      'notInModRepo': [for (final key in found.posts) if (splitPostKey(key).$2 != null) key],
    };
  }

  final names = [for (final name in authors) if (name.trim().isNotEmpty) name.trim()];
  if (names.isEmpty) return {'error': 'Give a mod id or at least one author name.'};
  final entry = TakedownList(authors: [AuthorTakedown(names: names, on: '')]);
  final mods = <Map<String, dynamic>>[];
  final ids = <String>{};
  for (final mod in catalog.mods) {
    final match = entry.authorMatch(mod.mod.getAuthors());
    if (match == null) continue;
    ids.add(mod.id);
    mods.add({'id': mod.id, 'name': mod.mod.name, 'credit': match.credit});
  }
  return {
    'kind': 'author',
    'names': names,
    'alreadyTakenDown': [for (final name in names) if (current.authorEntryFor(name) != null) name],
    'mods': mods,
    'collections': [
      for (final c in catalog.collections)
        if (c.modIds.any(ids.contains))
          {'id': c.id, 'name': c.name, 'modsLeft': c.modIds.where((id) => !ids.contains(id)).length},
    ],
  };
}

/// The catalog's mods from one source post, by its key (`forum:34161`), for
/// the thread page's "Take down" button.
List<Map<String, dynamic>> catalogModsOnPost(ModCatalog catalog, String postKey) => [
      for (final mod in catalog.mods)
        if (mod.sourcePosts.any((post) => post.id.isNotEmpty && post.ref.post.key == postKey))
          {'id': mod.id, 'name': mod.mod.name},
    ];

/// Today as `YYYY-MM-DD`, in UTC, for an entry's day.
String takedownDay([DateTime? now]) {
  final day = (now ?? DateTime.now()).toUtc();
  return '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}

/// What one build left out for one entry.
class TakedownMatch {
  /// See [TakedownList.entryKeys].
  final String entry;

  /// The mods left out, by id, each with its name and — for an author entry —
  /// the credit that matched.
  final List<({String id, String name, String? credit})> mods;

  /// The Collection pages left out, by id.
  final List<({String id, String name})> collections;

  /// Post keys whose listings this entry blocked before the merge.
  final List<String> blockedPosts;

  TakedownMatch(this.entry) : mods = [], collections = [], blockedPosts = [];

  bool get removedNothing => mods.isEmpty && collections.isEmpty;

  Map<String, dynamic> toMap() => {
        'entry': entry,
        'mods': [
          for (final mod in mods) {'id': mod.id, 'name': mod.name, if (mod.credit != null) 'credit': mod.credit},
        ],
        'collections': [for (final c in collections) {'id': c.id, 'name': c.name}],
        'blockedPosts': blockedPosts,
      };
}

/// What the takedowns did to one catalog build. Not part of `mod-catalog.json`.
class TakedownReport {
  final List<TakedownMatch> matches;

  /// The keys of posts (`forum:123`, `discord:456`) whose listings were all
  /// removed, so the bundle leaves them out too.
  final Set<String> removedPosts;

  const TakedownReport({this.matches = const [], this.removedPosts = const {}});

  /// The forum topic ids in [removedPosts].
  Set<int> get removedTopicIds => {
        for (final key in removedPosts)
          if (key.startsWith('forum:'))
            if (int.tryParse(key.substring('forum:'.length)) case final id?) id,
      };

  /// The Discord thread ids in [removedPosts].
  Set<String> get removedThreadIds => {
        for (final key in removedPosts)
          if (key.startsWith('discord:')) key.substring('discord:'.length),
      };

  Map<String, dynamic> toMap(DateTime builtAt) => {
        'builtAt': builtAt.toUtc().toIso8601String(),
        'matches': [for (final match in matches) match.toMap()],
        'removedPosts': [...removedPosts]..sort(),
      };

  /// Writes [TakedownList.matchesFileName] in [dataPath] for the viewer.
  void write(String dataPath, DateTime builtAt) {
    final file = File(p.join(dataPath, TakedownList.matchesFileName));
    file.parent.createSync(recursive: true);
    final temp = File('${file.path}.tmp');
    temp.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(toMap(builtAt)));
    temp.renameSync(file.path);
  }
}
