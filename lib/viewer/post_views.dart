import '../bot/scraper/qb/models/forum_date.dart';
import '../catalog/left_out_posts.dart';
import '../catalog/mod_catalog.dart';
import '../catalog/source_post.dart';
import '../site/mod_name_match.dart';
import 'data_access.dart';
import 'search_match.dart';

/// The viewer's Source posts list and what became of each post, for
/// `GET /api/posts` and `GET /api/posts/outcome`. Reads saved files only.
///
/// What became of a post comes from the last built `mod-catalog.json` (each
/// mod's `sourcePosts` and the `collections`), `takedown-matches.json` (posts
/// with every mod taken down) and `catalog-left-out.json` (the forum topics the
/// build left out, with why, and the mods that only point to a topic of their
/// own). The answers are worked out once per build and kept until one of those
/// files changes.
class PostViews {
  final DataAccess data;

  PostViews(this.data);

  // Cache outcomes by the identity of their source objects. DataAccess
  // returns the same object until a file changes on disk.
  Object? _heldCatalog;
  Object? _heldMatches;
  Object? _heldLeftOut;
  _Outcomes? _held;

  _Outcomes get _outcomes {
    final catalog = data.modRepo;
    final matches = data.takedownMatches;
    final leftOut = data.leftOutPosts;
    final held = _held;
    if (held != null &&
        identical(catalog, _heldCatalog) &&
        identical(matches, _heldMatches) &&
        identical(leftOut, _heldLeftOut)) {
      return held;
    }
    _heldCatalog = catalog;
    _heldMatches = matches;
    _heldLeftOut = leftOut;
    return _held = _Outcomes(catalog, matches, leftOut);
  }

  /// What the last build made of one post. [kind] is `topic` (or `forum`) or
  /// `discord`; null when it is neither.
  Map<String, dynamic>? outcome(String kind, String id) {
    final sourceKind = _sourceKind(kind);
    if (sourceKind == null) return null;
    final scrapedAt = sourceKind == SourceKind.forum
        ? data.index?.where((e) => '${e.topicId}' == id).firstOrNull?.scrapedAt
        : null;
    return _outcomes.of(sourceKind, id, scrapedAt: scrapedAt);
  }

  static SourceKind? _sourceKind(String kind) => switch (kind) {
        'topic' || 'forum' => SourceKind.forum,
        'discord' => SourceKind.discord,
        _ => null,
      };

  /// Every saved forum topic and Discord thread, as list rows, narrowed and
  /// sorted as asked, with the data quality counts over every post. Null when
  /// neither the mods index nor `discord-posts.json` is there.
  ({List<Map<String, dynamic>> rows, Map<String, int> counts})? list({
    String q = '',
    String kind = 'all',
    Set<String> filters = const {},
    String sort = 'lastPost',
    bool descending = true,
  }) {
    final all = _allRows();
    if (all == null) return null;

    final counts = {
      'noDownload': all.where((r) => r.noDownload).length,
      'noLlmAnswer': all.where((r) => r.noLlmAnswer).length,
      'placeholder': all.where((r) => r.isPlaceholder).length,
    };

    final query = searchQuery(q);
    final rows = all.where((row) {
      if (kind == 'topic' && row.kind != 'topic') return false;
      if (kind == 'discord' && row.kind != 'discord') return false;
      if (!matchesSearch(query, row.searchFields)) return false;
      return filters.every(row.passes);
    }).toList();

    int compare(_Row a, _Row b) => switch (sort) {
          'title' => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          'mods' => a.modCount.compareTo(b.modCount),
          _ => _compareDates(a.lastPost, b.lastPost),
        };

    rows.sort((a, b) {
      final by = descending ? compare(b, a) : compare(a, b);
      if (by != 0) return by;
      // The same order every time for rows the sort cannot tell apart.
      final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      return byTitle != 0 ? byTitle : a.id.compareTo(b.id);
    });

    return (rows: [for (final row in rows) row.toMap()], counts: counts);
  }

  /// Every saved forum topic ([kind] `topic`) or Discord thread (`discord`),
  /// for `GET /api/search`, using the same search fields as the list.
  /// Null when both the mods index and `discord-posts.json` are missing.
  List<Searchable>? searchable(String kind) {
    final all = _allRows();
    if (all == null) return null;
    return [
      for (final row in all)
        if (row.kind == kind)
          Searchable(
            fields: row.searchFields,
            sortName: row.title,
            id: row.id,
            item: {'id': row.id, 'title': row.title, 'author': row.author},
          ),
    ];
  }

  /// Every saved forum topic and Discord thread as list rows, unfiltered.
  /// Null when neither the mods index nor `discord-posts.json` is there.
  List<_Row>? _allRows() {
    final index = data.index;
    final threads = data.discordPosts?.threads;
    if (index == null && threads == null) return null;
    final outcomes = _outcomes;

    final all = <_Row>[];

    // Forum topics, joined the way GET /api/topics joins them.
    final llm = data.llmCache ?? const {};
    final assumed = data.assumedDownloads ?? const {};
    final placeholders = index == null ? const <int>{} : data.placeholderDetailIds();
    final saved = index == null ? const <int>{} : data.savedDetailIds();
    for (final topic in index ?? const []) {
      final id = topic.topicId;
      final answer = llm[id];
      final placeholder = placeholders.contains(id);
      all.add(_Row(
        kind: 'topic',
        id: '$id',
        title: topic.title,
        author: topic.author,
        lastPost: _forumLastPost(topic.lastPostDate, topic.scrapedAt),
        ruleUrls: [for (final c in assumed[id] ?? const []) c.sourceUrl],
        llmUrls: [
          for (final mod in answer?.mods ?? const [])
            for (final download in mod.downloads) download.url,
        ],
        hasLlmAnswer: answer != null,
        isPlaceholder: placeholder,
        // A placeholder, or a topic with no saved post, is never sent to the
        // LLM, so it is not counted as missing an answer (as on Control).
        couldHaveAnswer: !placeholder && saved.contains(id),
        outcome: outcomes.of(SourceKind.forum, '$id', scrapedAt: topic.scrapedAt),
      ));
    }

    // Discord threads: the saved opening runs, plus any thread with an LLM
    // answer whose run is no longer saved.
    final discordLlm = data.discordLlmCache ?? const {};
    final discordRules = data.discordAssumedDownloads ?? const {};
    final threadIds = {...?threads?.keys, ...discordLlm.keys};
    for (final id in threadIds) {
      final thread = threads?[id];
      final answer = discordLlm[id];
      final outcome = outcomes.of(SourceKind.discord, id);
      DateTime? last;
      for (final message in thread?.messages ?? const []) {
        final at = message.timestamp?.toUtc();
        if (at != null && (last == null || at.isAfter(last))) last = at;
      }
      final modNames = [for (final mod in outcome['mods'] as List) (mod as Map)['name'] as String];
      all.add(_Row(
        kind: 'discord',
        id: id,
        title: thread?.name ?? (modNames.isEmpty ? '' : modNames.first),
        author: thread?.author ?? data.discordAuthors?[id]?.firstOrNull ?? '',
        lastPost: last,
        ruleUrls: [for (final c in discordRules[id] ?? const []) c.sourceUrl],
        llmUrls: [
          for (final mod in answer?.mods ?? const [])
            for (final download in mod.downloads) download.url,
        ],
        hasLlmAnswer: answer != null,
        isPlaceholder: false,
        couldHaveAnswer: thread != null,
        outcome: outcome,
      ));
    }

    return all;
  }

  static int _compareDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return a.compareTo(b);
  }

  static final RegExp _relativeDay = RegExp(r'^(Today|Yesterday) at (\d{1,2}):(\d{2}):(\d{2})\s*([AP]M)?');

  /// The forum's last post date. The forum writes a recent one as "Today at
  /// 08:39:11 PM", which is read against the day the topic was scraped.
  static DateTime? _forumLastPost(String? text, DateTime scrapedAt) {
    final parsed = parseForumDate(text);
    if (parsed != null) return parsed;
    final m = _relativeDay.firstMatch(text?.trim() ?? '');
    if (m == null) return null;
    var hour = int.parse(m.group(2)!);
    if (m.group(5) == 'PM' && hour != 12) hour += 12;
    if (m.group(5) == 'AM' && hour == 12) hour = 0;
    final at = scrapedAt.toUtc();
    var day = DateTime(at.year, at.month, at.day, hour, int.parse(m.group(3)!), int.parse(m.group(4)!));
    if (m.group(1) == 'Yesterday') return day.subtract(const Duration(days: 1));
    // The forum writes its own clock, which is behind UTC: a "today" time
    // later than the scrape's UTC clock was on the forum's day before.
    if (day.isAfter(DateTime(at.year, at.month, at.day, at.hour, at.minute, at.second))) {
      day = day.subtract(const Duration(days: 1));
    }
    return day;
  }
}

/// One row of the list, before it is written out.
class _Row {
  final String kind;
  final String id;
  final String title;
  final String author;
  final DateTime? lastPost;
  final List<String> ruleUrls;
  final List<String> llmUrls;
  final bool hasLlmAnswer;
  final bool isPlaceholder;
  final bool couldHaveAnswer;
  final Map<String, dynamic> outcome;

  _Row({
    required this.kind,
    required this.id,
    required this.title,
    required this.author,
    required this.lastPost,
    required this.ruleUrls,
    required this.llmUrls,
    required this.hasLlmAnswer,
    required this.isPlaceholder,
    required this.couldHaveAnswer,
    required this.outcome,
  });

  /// Downloads found by the rules or the LLM, each address once.
  late final int downloads = {for (final url in [...ruleUrls, ...llmUrls]) _normUrl(url)}.length;

  bool get noDownload => downloads == 0;

  bool get noLlmAnswer => !hasLlmAnswer && couldHaveAnswer;

  int get modCount => (outcome['mods'] as List).length;

  /// Search fields shared by the list and `GET /api/search`.
  /// The id is last so an equally ranked match on another field supplies the note.
  late final List<SearchField> searchFields = [
    SearchField(SearchFieldKind.name, title),
    SearchField(SearchFieldKind.other, author, detail: 'author: $author'),
    for (final mod in outcome['mods'] as List)
      SearchField(SearchFieldKind.alias, '${(mod as Map)['name']}', detail: 'mod: ${mod['name']}'),
    SearchField.id(id),
  ];

  bool passes(String filter) => switch (filter) {
        'noDownload' => noDownload,
        'noLlmAnswer' => noLlmAnswer,
        'placeholder' => isPlaceholder,
        'leftOut' => outcome['outcome'] == 'leftOut',
        'takenDown' => outcome['outcome'] == 'takenDown',
        'collection' => outcome['outcome'] == 'collection',
        // Unknown filters leave all rows included.
        _ => true,
      };

  Map<String, dynamic> toMap() => {
        'kind': kind,
        'id': id,
        'title': title,
        'author': author,
        'lastPostDate': lastPost?.toIso8601String(),
        'downloads': downloads,
        'downloadCounts': {'rules': ruleUrls.length, 'llm': llmUrls.length},
        'hasLlmAnswer': hasLlmAnswer,
        'isPlaceholder': isPlaceholder,
        'outcome': outcome['outcome'],
        'line': outcome['line'],
        'modCount': modCount,
      };

  /// Matches rule and LLM addresses ignoring case, scheme and trailing slashes.
  static String _normUrl(String u) =>
      u.trim().toLowerCase().replaceFirst(RegExp(r'^https?://'), '').replaceFirst(RegExp(r'/+$'), '');
}

/// The last build's answers about every post, indexed by post key
/// (`forum:34161`, `discord:<thread id>`).
class _Outcomes {
  bool hasCatalog = false;
  DateTime? builtAt;
  final Map<String, List<CatalogMod>> modsByPost = {};
  final Map<String, CatalogCollection> collectionByPost = {};
  final Map<String, String> modNames = {};
  final Set<String> removedPosts = {};
  final Map<String, List<({String llmName, String target})>> pointersByPost = {};

  /// Null when no reasons were saved or they belong to another build.
  LeftOutPosts? leftOut;

  _Outcomes(Map<String, dynamic>? catalogMap, Map<String, dynamic>? matches, LeftOutPosts? leftOutFile) {
    if (catalogMap == null) return;
    final catalog = ModCatalog.fromMap(catalogMap);
    hasCatalog = true;
    builtAt = catalog.generatedAt;
    for (final mod in catalog.mods) {
      modNames[mod.id] = mod.mod.name;
      final keys = <String>{};
      for (final post in mod.sourcePosts) {
        if (post.id.isEmpty) continue;
        if (keys.add(post.ref.post.key)) modsByPost.putIfAbsent(post.ref.post.key, () => []).add(mod);
      }
    }
    for (final collection in catalog.collections) {
      collectionByPost[collection.post.post.key] = collection;
    }
    for (final key in (matches?['removedPosts'] as List?) ?? const []) {
      removedPosts.add('$key');
    }
    // A file saved by another build would describe other posts.
    if (leftOutFile != null && leftOutFile.builtAt.isAtSameMomentAs(catalog.generatedAt)) {
      leftOut = leftOutFile;
      for (final MapEntry(:key, :value) in leftOutFile.pointers.entries) {
        final hash = key.indexOf('#');
        if (hash < 0) continue;
        pointersByPost
            .putIfAbsent(key.substring(0, hash), () => [])
            .add((llmName: key.substring(hash + 1), target: value));
      }
    }
  }

  /// See `GET /api/posts/outcome`. [scrapedAt] is when a forum topic was last
  /// scraped, which tells a topic the build never saw from one it left out
  /// when the build saved no reasons.
  Map<String, dynamic> of(SourceKind kind, String id, {DateTime? scrapedAt}) {
    final apiKind = kind == SourceKind.forum ? 'topic' : 'discord';
    final key = '${kind.name}:$id';
    Map<String, dynamic> answer(String outcome, String line, {List<Map<String, String>> mods = const [], Map<String, dynamic>? extra}) => {
          'kind': apiKind,
          'id': id,
          'outcome': outcome,
          'line': line,
          'mods': mods,
          if (builtAt != null) 'builtAt': builtAt!.toUtc().toIso8601String(),
          ...?extra,
        };

    if (!hasCatalog) return answer('notInBuild', 'No catalog has been built yet.');

    final collection = collectionByPost[key];
    if (collection != null) {
      final mods = [
        for (final modId in collection.modIds) {'id': modId, 'name': modNames[modId] ?? modId},
      ];
      return answer('collection', 'A Collection page listing ${_count(mods.length, 'mod')}.',
          mods: mods, extra: {'collection': {'id': collection.id, 'name': collection.name}});
    }

    final mods = modsByPost[key] ?? const [];
    if (mods.isNotEmpty) {
      final names = [for (final mod in mods) mod.mod.name];
      return answer('mods', 'Became ${_count(mods.length, 'mod')}: ${_nameList(names)}.',
          mods: [for (final mod in mods) {'id': mod.id, 'name': mod.mod.name}]);
    }

    if (removedPosts.contains(key)) return answer('takenDown', 'Taken down.');

    final pointers = pointersByPost[key];
    if (pointers != null && pointers.isNotEmpty) {
      final targets = {for (final pointer in pointers) pointer.target};
      final first = pointers.first;
      final topicId = first.target.substring(first.target.indexOf(':') + 1);
      final target = _modOnTarget(first.target, first.llmName);
      final pointsTo = {
        'kind': 'topic',
        'id': topicId,
        if (target != null) 'modId': target.id,
        if (target != null) 'modName': target.mod.name,
      };
      final line = targets.length > 1
          ? 'Points to ${targets.length} other topics, where its mods are published.'
          : target == null
              ? 'Points to topic $topicId.'
              : 'Points to topic $topicId, where ${target.mod.name} is published.';
      return answer('pointsTo', line, extra: {'pointsTo': pointsTo});
    }

    if (kind == SourceKind.forum) {
      final saved = leftOut;
      final reason = saved?.topics[id];
      if (reason != null) {
        return answer('leftOut', 'Left out: ${_lowerFirst(reason.sentence)}', extra: {'reason': reason.sentence});
      }
      // With no reasons saved, a topic scraped before the build was seen by it.
      if (saved == null && scrapedAt != null && builtAt != null && !scrapedAt.isAfter(builtAt!)) {
        return answer('leftOut', 'Left out.');
      }
    }
    return answer('notInBuild', 'Not in the last build.');
  }

  /// The mod on [targetKey] that a pointer named [llmName] means: the only
  /// one there, or the one whose name matches.
  CatalogMod? _modOnTarget(String targetKey, String llmName) {
    final there = modsByPost[targetKey] ?? const [];
    if (there.length == 1) return there.single;
    final named = there.where((mod) =>
        modNamesMatch(mod.mod.name, llmName) ||
        mod.sourcePosts.any((post) => post.llmModName != null && modNamesMatch(post.llmModName!, llmName)));
    return named.length == 1 ? named.single : null;
  }

  static String _count(int n, String word) => n == 1 ? '1 $word' : '$n ${word}s';

  static String _lowerFirst(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

  /// "A", "A and B", "A, B and C", and past five names "A, B, C, D, E and 3 more".
  static String _nameList(List<String> names) {
    if (names.length == 1) return names.single;
    if (names.length <= 5) return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    return '${names.take(5).join(', ')} and ${names.length - 5} more';
  }
}
