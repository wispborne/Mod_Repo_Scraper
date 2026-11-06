import '../manager/job.dart';
import 'mod_views.dart';
import 'post_views.dart';
import 'search_match.dart';

/// The runs a search can find, newest first. Empty when the manager is off.
typedef RunRecords = List<RunRecord> Function();

/// Search results for the new viewer's search box, via `GET /api/search`.
/// Read-only.
///
/// Mods and source posts are found by the same fields as the Mods and Source
/// posts lists (`search_match.dart`), so each group's total is the number of
/// rows the full list shows for the same text. Runs come from the run
/// history, through [runs], and are found by id. A run's id contains its job
/// kind (`20261105T230000Z-fetchAndUpdate`), so a kind name finds it too.
class SearchViews {
  final ModViews mods;
  final PostViews posts;

  /// Null when the manager is off.
  final RunRecords? runs;

  SearchViews({required this.mods, required this.posts, this.runs});

  static const int defaultLimit = 5;
  static const int maxLimit = 50;

  /// Up to [limit] matches of each kind, best first, with a total for each kind. A forum or Discord address is searched as the post's id. Text
  /// shorter than two characters finds nothing.
  Map<String, dynamic> search(String q, {int limit = defaultLimit}) {
    final text = searchText(q);
    final query = searchQuery(text);
    final empty = <String, dynamic>{'total': 0, 'items': <Object>[]};
    if (query.length < 2) {
      return {'q': text, 'mods': empty, 'topics': empty, 'discord': empty, 'runs': empty};
    }

    Map<String, dynamic> group(List<Searchable>? rows) {
      if (rows == null) return empty;
      final found = searchRows(query, rows, limit);
      return {'total': found.total, 'items': found.items};
    }

    return {
      'q': text,
      'mods': group(mods.searchable()),
      'topics': group(posts.searchable('topic')),
      'discord': group(posts.searchable('discord')),
      'runs': _runs(query, limit),
    };
  }

  Map<String, dynamic> _runs(String query, int limit) {
    final hits = <(RunRecord, int)>[];
    for (final run in runs?.call() ?? const <RunRecord>[]) {
      final id = run.id.toLowerCase();
      if (!id.contains(query)) continue;
      hits.add((run, id == query ? 0 : (id.startsWith(query) ? 1 : 2)));
    }
    // Ids start with the time, so a later id is a newer run.
    hits.sort((a, b) {
      final byRank = a.$2.compareTo(b.$2);
      return byRank != 0 ? byRank : b.$1.id.compareTo(a.$1.id);
    });
    return {
      'total': hits.length,
      'items': [
        for (final (run, _) in hits.take(limit))
          {
            'id': run.id,
            'kind': run.request.kind.name,
            'state': run.state.name,
            'startedAt': run.startedAt?.toUtc().toIso8601String(),
          },
      ],
    };
  }

  static final RegExp _forumAddress = RegExp(r'fractalsoftworks\.com/forum/index\.php\?topic=(\d+)', caseSensitive: false);
  static final RegExp _discordAddress = RegExp(r'discord(?:app)?\.com/channels/\d+/(\d+)', caseSensitive: false);

  /// The text to search for: the post's id when [q] is a forum topic or
  /// Discord thread address, otherwise [q] trimmed.
  static String searchText(String q) {
    final text = q.trim();
    final forum = _forumAddress.firstMatch(text);
    if (forum != null) return forum.group(1)!;
    final discord = _discordAddress.firstMatch(text);
    if (discord != null) return discord.group(1)!;
    return text;
  }

  /// The requested `limit`, between 1 and [maxLimit].
  static int limitOf(String? asked) {
    final v = int.tryParse(asked?.trim() ?? '');
    if (v == null || v < 1) return defaultLimit;
    return v > maxLimit ? maxLimit : v;
  }
}
