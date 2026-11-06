import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../bot/scraper/author_aliases.dart';
import '../catalog/mod_catalog.dart';
import '../catalog/takedowns.dart';
import '../site/requirement_names.dart';
import 'author_alias_views.dart';
import 'data_access.dart';

/// The counts behind the new viewer's Needs attention panel, read from saved
/// files. Each count is left out when a file it needs is missing or cannot be
/// read, so one bad file never hides the others. Writes nothing.
///
/// - `unmatchedDependencyNames`: spellings in the last website build's
///   `requirement-names-report.json` that matched no mod.
/// - `authorPairsToDecide`: the pairs the Author aliases page suggests. Pairs
///   marked "different people" are not suggested, so they are not counted.
/// - `takedownsExcludedNothing`: takedown entries that left out nothing from
///   the last build, other than those counted in `takedownsReturned`.
/// - `takedownsReturned`: mod entries that left out nothing although one of
///   their posts is still in the catalog. The mod most likely came back under
///   a new id.
/// - `postsWithoutLlmAnswer`: saved forum topics (not placeholders) and saved
///   Discord threads with no LLM answer.
/// - `modsWithoutDownload`: the website's mods with no download.
Map<String, int> attentionCounts(DataAccess data) {
  final counts = <String, int>{};
  void add(String key, int? Function() count) {
    try {
      final value = count();
      if (value != null) counts[key] = value;
    } catch (_) {
      // Omit the count if its file cannot be read.
    }
  }

  add('unmatchedDependencyNames', () => _unmatchedDependencyNames(data));
  add('authorPairsToDecide', () => _authorPairsToDecide(data));
  try {
    final takedowns = _takedownWarnings(data);
    if (takedowns != null) {
      counts['takedownsExcludedNothing'] = takedowns.excludedNothing;
      if (takedowns.returned != null) {
        counts['takedownsReturned'] = takedowns.returned!;
      }
    }
  } catch (_) {
    // Omit takedown counts if their files cannot be read.
  }
  add('postsWithoutLlmAnswer', () => _postsWithoutLlmAnswer(data));
  add('modsWithoutDownload', () => data.modsWithoutDownload);
  return counts;
}

int? _unmatchedDependencyNames(DataAccess data) {
  final file = File(p.join(data.dataDir, RequirementNameStore.reportFileName));
  if (!file.existsSync()) return null;
  final report = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final names = report['names'] as List<dynamic>? ?? const [];
  return names.where((name) => name is Map && name['by'] == RequirementDecidedBy.unmatched.name).length;
}

/// Needs the catalog, because a suggestion is two names on one catalog mod.
int? _authorPairsToDecide(DataAccess data) {
  if (data.modRepo == null) return null;
  // Use the same file and rules as the Author aliases page. Installing applies
  // the saved rows in memory without writing files.
  final file = AuthorAliasFile.install(data.dataDir);
  final suggestions = authorAliasReportFromData(data, file)['suggestions'] as List?;
  return suggestions?.length ?? 0;
}

/// Null when the last build's matches are missing. [returned] is null when
/// the catalog is missing, and then every entry that left out nothing counts
/// in [excludedNothing].
({int excludedNothing, int? returned})? _takedownWarnings(DataAccess data) {
  final matchesFile = File(p.join(data.dataDir, TakedownList.matchesFileName));
  if (!matchesFile.existsSync()) return null;
  final list = TakedownList.read(data.dataDir);
  final matches = <String, Map<String, dynamic>>{
    for (final match in (jsonDecode(matchesFile.readAsStringSync()) as Map<String, dynamic>)['matches']
            as List<dynamic>? ??
        const [])
      if (match is Map<String, dynamic>) '${match['entry']}': match,
  };

  // The same test as the old Takedowns page: an entry the last build knew
  // about that left out no mod and no Collection page.
  bool leftOutNothing(String key) {
    final match = matches[key];
    if (match == null) return false;
    final mods = match['mods'] as List<dynamic>? ?? const [];
    final collections = match['collections'] as List<dynamic>? ?? const [];
    return mods.isEmpty && collections.isEmpty;
  }

  final repo = data.modRepo;
  final postsInCatalog = repo == null
      ? null
      : {
          for (final mod in ModCatalog.fromMap(repo).mods)
            for (final post in mod.sourcePosts)
              if (post.id.isNotEmpty) post.ref.post.key,
        };

  var excludedNothing = 0;
  var returned = 0;
  for (final entry in list.mods) {
    if (!leftOutNothing(entry.id)) continue;
    final postStillThere = postsInCatalog != null &&
        entry.posts.any((key) => postsInCatalog.contains(splitPostKey(key).$1));
    if (postStillThere) {
      returned++;
    } else {
      excludedNothing++;
    }
  }
  for (final entry in list.authors) {
    if (leftOutNothing(TakedownList.authorKey(entry))) excludedNothing++;
  }
  return (excludedNothing: excludedNothing, returned: postsInCatalog == null ? null : returned);
}

/// Needs the mods index and the LLM answers file. A Discord thread counts
/// only when `discord-posts.json` is there.
int? _postsWithoutLlmAnswer(DataAccess data) {
  final index = data.index;
  final answers = data.llmCache;
  if (index == null || answers == null) return null;
  final placeholders = data.placeholderDetailIds();
  var count = 0;
  for (final topic in index) {
    final id = topic.topicId;
    if (answers.containsKey(id) || placeholders.contains(id)) continue;
    // A topic with no saved post is never sent to the LLM.
    if (!File(p.join(data.dataDir, 'mods', '$id', 'detail.json')).existsSync()) continue;
    count++;
  }
  final threads = data.discordPosts?.threads;
  if (threads != null) {
    final discordAnswers = data.discordLlmCache ?? const {};
    count += threads.keys.where((id) => !discordAnswers.containsKey(id)).length;
  }
  return count;
}
