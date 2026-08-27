import 'compare_rows.dart';

/// Works out what changed between two saved bundles.
///
/// A bundle keeps its three parts apart — the index list, the details map and
/// the assumed downloads map, all keyed by topic id — so the first job is
/// putting one topic's pieces back together. After that it is the same
/// comparing the merge side does.

/// The fields worth waking somebody up over.
///
/// Left out on purpose: `scrapedAt`, `replies`, `views` and anything else that
/// moves whether or not the mod did. A list full of "scraped at a different
/// time" is a list nobody reads.
final List<ComparedField> bundleFields = [
  const ComparedField('title'),
  const ComparedField('author'),
  const ComparedField('category'),
  const ComparedField('lastPostDate', label: 'last post'),
  const ComparedField('isWip', label: 'work in progress'),
  const ComparedField('inModIndex', label: 'in the mod index'),
  const ComparedField('sourceBoard', label: 'board'),
  const ComparedField('thumbnailPath', label: 'thumbnail'),
  ComparedField('contentFingerprint',
      label: 'post text', describe: _describePostChange),
  const ComparedField('imageCount', label: 'images'),
  // The three below hold lists. They are picked apart entry by entry, so a
  // topic with twelve downloads where one moved says which one, rather than
  // printing all twelve twice.
  ComparedField('links', itemsOf: _linkItems),
  ComparedField('downloads', itemsOf: _downloadItems),
  ComparedField('llm', label: 'LLM facts', itemsOf: _llmItems),
  ComparedField('extraPosts',
      label: 'the author\'s other posts', itemsOf: _extraPostItems),
];

/// The post text is not kept in a snapshot, only a fingerprint of it, so there
/// is no before and after to show — just the fact that it moved.
String _describePostChange(Object? before, Object? after) {
  if (before == null) return 'The post text was read for the first time.';
  if (after == null) return 'The post text is no longer saved.';
  return 'The post text changed. The words themselves are not kept in a '
      'snapshot, so open the topic to see what it says now.';
}

/// What moved among the author's own later posts.
///
/// They carry no name to be told apart by, so they are lined up by where they
/// sit in the thread: the author's second post is compared against the author's
/// second post. Their text is not kept — a snapshot holds a fingerprint of it,
/// the same as the first post — so a changed post is said in words.
List<Map<String, dynamic>> _extraPostItems(Object? before, Object? after) {
  final was = _asList(before);
  final now = _asList(after);
  final items = <Map<String, dynamic>>[];

  final count = was.length > now.length ? was.length : now.length;
  for (var i = 0; i < count; i++) {
    // The first post is post one, so the first of these is post two.
    final label = 'the author\'s post ${i + 2}';
    final a = i < was.length ? was[i] : null;
    final b = i < now.length ? now[i] : null;

    if (a == null) {
      items.add({'change': 'added', 'label': label});
      continue;
    }
    if (b == null) {
      items.add({'change': 'removed', 'label': label});
      continue;
    }
    if (a is! Map || b is! Map) continue;

    final parts = <Map<String, dynamic>>[
      // The fingerprints are two pieces of gibberish; that they differ is the
      // whole of what can be said, so it is said rather than shown.
      if (sameness(a['contentFingerprint']) != sameness(b['contentFingerprint']))
        {
          'name': 'post text',
          'note': _describePostChange(
              a['contentFingerprint'], b['contentFingerprint']),
        },
      ..._partsThatMoved(a, b, const {
        'postDate': 'posted',
        'lastEditDate': 'last edited',
      }, skip: const {'contentFingerprint'}),
    ];
    if (parts.isEmpty) continue;
    items.add({'change': 'changed', 'label': label, 'parts': parts});
  }
  return items;
}

/// One topic, with its index row, its detail and its downloads put back
/// together.
List<Map<String, dynamic>> topicsOf(Map<String, dynamic> snapshot) {
  final details = (snapshot['details'] as Map?) ?? const {};
  final downloads = (snapshot['assumedDownloads'] as Map?) ?? const {};

  final topics = <Map<String, dynamic>>[];
  for (final row in (snapshot['index'] as List?) ?? const []) {
    if (row is! Map) continue;
    topics.add(_topicRow(row, details, downloads));
  }
  return topics;
}

/// One topic's row from a saved bundle, or null when that bundle does not hold
/// the topic at all.
Map<String, dynamic>? topicRecordOf(
    Map<String, dynamic> snapshot, int topicId) {
  for (final row in (snapshot['index'] as List?) ?? const []) {
    if (row is! Map) continue;
    if ('${row['topicId']}' != '$topicId') continue;
    return _topicRow(
      row,
      (snapshot['details'] as Map?) ?? const {},
      (snapshot['assumedDownloads'] as Map?) ?? const {},
    );
  }
  return null;
}

/// The three parts of a bundle joined into the one row everything here
/// compares.
Map<String, dynamic> _topicRow(
  Map<dynamic, dynamic> row,
  Map<dynamic, dynamic> details,
  Map<dynamic, dynamic> downloads,
) {
  final id = '${row['topicId']}';
  final detail = details[id];
  // A bundle keeps one topic's rule-based downloads as a plain list. The
  // resolver's own cache file on disk wraps the same list in a `candidates`
  // field, and reading for that shape here is why the downloads column was
  // empty for every topic on real data — the two files look alike and are not.
  final download = downloads[id];

  return {
    'topicId': row['topicId'],
    'title': row['title'],
    'author': row['author'],
    'category': row['category'],
    'lastPostDate': row['lastPostDate'],
    'isWip': row['isWip'],
    'inModIndex': row['inModIndex'],
    'sourceBoard': row['sourceBoard'],
    'thumbnailPath': row['thumbnailPath'],
    'llm': row['llm'],
    'contentFingerprint': detail is Map ? detail['contentFingerprint'] : null,
    'imageCount':
        detail is Map ? ((detail['images'] as List?) ?? const []).length : null,
    'links': detail is Map ? detail['links'] : null,
    'downloads': download is List ? download : null,
    'extraPosts': detail is Map ? detail['extraPosts'] : null,
  };
}

/// Compares the topics two saved bundles ended up with.
Map<String, dynamic> compareBundles({
  required Map<String, dynamic> older,
  required Map<String, dynamic> newer,
}) =>
    compareRows(
      older: topicsOf(older),
      newer: topicsOf(newer),
      keyOf: (topic) => 'topic:${topic['topicId']}',
      fields: bundleFields,
      labelOf: (topic) => (topic['title'] as String?) ?? '',
      authorOf: (topic) => (topic['author'] as String?) ?? '',
      recordKey: 'topic',
    );

// ---------------------------------------------------------------------------
// One topic's history across every saved bundle.

/// One saved bundle as the history walk sees it: its name, when it was saved,
/// and a way to read it that is only called when it is wanted.
class HistorySnapshot {
  final String runId;
  final DateTime savedAt;

  /// Reads the whole snapshot back. Null when the file has gone or cannot be
  /// read — the walk skips it and compares its neighbours across the gap.
  final Map<String, dynamic>? Function() read;

  const HistorySnapshot(this.runId, this.savedAt, this.read);
}

/// Walks the saved bundles oldest to newest and reports every run that changed
/// this topic. Runs that left it alone report nothing, which is what makes the
/// answer readable: on real data most topics change in one run out of twenty.
///
/// The oldest snapshot still kept is where history *starts*, not something that
/// happened in it — a topic already in it was not added then, we simply have
/// nothing older to compare it against.
Map<String, dynamic> topicHistory({
  required int topicId,
  required List<HistorySnapshot> snapshots,
}) {
  final entries = <Map<String, dynamic>>[];
  Map<String, dynamic>? previous;
  var started = false;
  var read = 0;
  var everInBundle = false;
  DateTime? oldestSavedAt;
  String? oldestRunId;
  String? title;
  String? author;

  for (final snapshot in snapshots) {
    final bundle = snapshot.read();
    if (bundle == null) continue;
    read++;
    oldestSavedAt ??= snapshot.savedAt;
    oldestRunId ??= snapshot.runId;

    final now = topicRecordOf(bundle, topicId);
    if (now != null) {
      everInBundle = true;
      title = (now['title'] as String?) ?? title;
      author = (now['author'] as String?) ?? author;
    }

    if (!started) {
      started = true;
      previous = now;
      continue;
    }

    Map<String, dynamic> entry(String kind) => {
          'kind': kind,
          'runId': snapshot.runId,
          'savedAt': snapshot.savedAt.toUtc().toIso8601String(),
        };

    if (previous == null && now != null) {
      entries.add(entry('first'));
    } else if (previous != null && now == null) {
      entries.add(entry('gone'));
    } else if (previous != null && now != null) {
      final changes = topicChanges(previous, now);
      if (changes.isNotEmpty) {
        entries.add({...entry('changed'), 'changes': changes});
      }
    }
    previous = now;
  }

  return {
    'topicId': topicId,
    'title': title,
    'author': author,
    // Newest first, the way a log reads.
    'entries': entries.reversed.toList(),
    // A topic in none of them has no history at all, which is a different thing
    // from one that has sat unchanged through every run.
    'everInBundle': everInBundle,
    'snapshotsRead': read,
    'snapshotsTotal': snapshots.length,
    'oldestSavedAt': oldestSavedAt?.toUtc().toIso8601String(),
    'oldestRunId': oldestRunId,
  };
}

/// What changed about one topic between two saved bundles.
///
/// Exactly what the bundle comparison page works out for the same topic — the
/// same fields, the same labels, the same item-by-item picking apart — so the
/// two pages can never disagree about what changed or what to call it.
List<Map<String, dynamic>> topicChanges(
  Map<dynamic, dynamic> before,
  Map<dynamic, dynamic> after,
) =>
    changedFields(before, after, bundleFields);

List<dynamic> _asList(Object? value) => value is List ? value : const [];

/// Lines two lists of maps up by a key and says what was added, removed, and —
/// for something in both — which of its parts moved.
List<Map<String, dynamic>> _lineUp(
  List<dynamic> before,
  List<dynamic> after, {
  required String Function(Map<dynamic, dynamic> item) keyOf,
  required String Function(Map<dynamic, dynamic> item) labelOf,
  List<Map<String, dynamic>> Function(
          Map<dynamic, dynamic> was, Map<dynamic, dynamic> now)?
      partsOf,
  List<Map<String, dynamic>> Function(
          Map<dynamic, dynamic> was, Map<dynamic, dynamic> now)?
      itemsOf,
}) {
  Map<String, Map<dynamic, dynamic>> byKey(List<dynamic> list) {
    final out = <String, Map<dynamic, dynamic>>{};
    for (final item in list) {
      if (item is! Map) continue;
      out.putIfAbsent(keyOf(item), () => item);
    }
    return out;
  }

  final was = byKey(before);
  final now = byKey(after);
  final rows = <Map<String, dynamic>>[];

  for (final key in now.keys) {
    if (was.containsKey(key)) continue;
    rows.add({'change': 'added', 'label': labelOf(now[key]!)});
  }
  for (final key in was.keys) {
    if (now.containsKey(key)) continue;
    rows.add({'change': 'removed', 'label': labelOf(was[key]!)});
  }
  for (final key in now.keys) {
    if (!was.containsKey(key)) continue;
    final parts = partsOf?.call(was[key]!, now[key]!) ?? const [];
    final inner = itemsOf?.call(was[key]!, now[key]!) ?? const [];
    if (parts.isEmpty && inner.isEmpty) continue;
    rows.add({
      'change': 'changed',
      'label': labelOf(now[key]!),
      if (parts.isNotEmpty) 'parts': parts,
      if (inner.isNotEmpty) 'items': inner,
    });
  }
  return rows;
}

/// Which parts of an entry differ, in plain words.
///
/// Every key both sides hold is looked at, not only the ones in [named] —
/// [named] just says what to call the ones worth naming. A key nobody named
/// still gets reported under its own name, because a field that says "this
/// changed" and then lists nothing sends somebody hunting for a change the
/// page decided not to mention. [skip] is for keys handled somewhere else: the
/// key the entries are lined up by, and anything with its own list of items.
List<Map<String, dynamic>> _partsThatMoved(
  Map<dynamic, dynamic> was,
  Map<dynamic, dynamic> now,
  Map<String, String> named, {
  Set<String> skip = const {},
}) {
  final parts = <Map<String, dynamic>>[];
  // Named first, in the order they are named, then anything left over.
  final keys = <String>[
    ...named.keys,
    ...{...was.keys, ...now.keys}.map((k) => '$k').where(
        (k) => !named.containsKey(k)),
  ];
  for (final key in keys) {
    if (skip.contains(key)) continue;
    final a = was[key];
    final b = now[key];
    if (sameness(a) == sameness(b)) continue;
    parts.add({'name': named[key] ?? key, 'before': a, 'after': b});
  }
  return parts;
}

/// The rule-based downloads, lined up by the link as it appeared in the post —
/// that is what makes two of them the same download.
List<Map<String, dynamic>> _downloadItems(Object? before, Object? after) =>
    _lineUp(
      _asList(before),
      _asList(after),
      keyOf: (d) => '${d['originalUrl'] ?? d['url'] ?? ''}',
      labelOf: _downloadLabel,
      partsOf: (was, now) => _partsThatMoved(was, now, const {
        'resolvedDirectUrl': 'resolved link',
        'fileName': 'file name',
        'sourceHost': 'host',
        'confidence': 'confidence',
        'requiresManualStep': 'needs a manual step',
        'linkText': 'link text',
      }),
    );

String _downloadLabel(Map<dynamic, dynamic> d) {
  final name = '${d['fileName'] ?? ''}'.trim();
  if (name.isNotEmpty) return name;
  return '${d['originalUrl'] ?? d['url'] ?? '(no link)'}';
}

/// The links found in the post, lined up by URL.
List<Map<String, dynamic>> _linkItems(Object? before, Object? after) =>
    _lineUp(
      _asList(before),
      _asList(after),
      keyOf: (l) => '${l['url'] ?? ''}',
      labelOf: (l) {
        final text = '${l['text'] ?? ''}'.trim();
        return text.isEmpty ? '${l['url'] ?? ''}' : '$text — ${l['url'] ?? ''}';
      },
      partsOf: (was, now) => _partsThatMoved(was, now, const {
        'text': 'link text',
        'isDownloadable': 'looks downloadable',
      }),
    );

/// What the LLM found, mod by mod. Within a mod, the extras it pulled out are
/// compared one at a time and its downloads are lined up like the rules' ones,
/// so "the version went 0.7 to 0.8" reads as that and not as two blocks of
/// JSON.
List<Map<String, dynamic>> _llmItems(Object? was, Object? now) {
  List<dynamic> modsOf(Object? value) =>
      value is Map ? _asList(value['mods']) : const [];

  return _lineUp(
    modsOf(was),
    modsOf(now),
    keyOf: (m) => '${m['name'] ?? ''}'.toLowerCase(),
    labelOf: (m) => '${m['name'] ?? '(no name)'}',
    partsOf: (a, b) => [
      // `name` lines the mods up, `extras` is flattened just below, and
      // `downloads` gets its own list of items — so none of the three belongs
      // here as well.
      ..._partsThatMoved(a, b, const {
        'role': 'role',
        'requires': 'requires',
        'image': 'image',
        'descriptionAnchors': 'where it is described',
      }, skip: const {'name', 'extras', 'downloads'}),
      ..._partsThatMoved(
        _flattenExtras(a['extras']),
        _flattenExtras(b['extras']),
        _extraNames,
      ),
    ],
    itemsOf: (a, b) =>
        _downloadItems(_asList(a['downloads']), _asList(b['downloads'])),
  );
}

/// The extras the LLM pulls out, in plain words. A nested one is flattened a
/// level so "the summary sentence changed" can be said on its own.
const Map<String, String> _extraNames = {
  'version': 'version',
  'license': 'license',
  'sourceCode': 'source code',
  'saveCompatibility': 'save compatibility',
  'needs': 'what it needs',
  'summary.sentence': 'summary — one line',
  'summary.paragraph': 'summary — paragraph',
  'changelog.link': 'changelog link',
  'changelog.entries': 'changelog entries',
  'supportLinks': 'support links',
};

/// The extras map with its one level of nesting flattened to `parent.child`
/// keys, so each piece can be compared and named on its own.
Map<String, dynamic> _flattenExtras(Object? extras) {
  final out = <String, dynamic>{};
  if (extras is! Map) return out;
  for (final entry in extras.entries) {
    final key = '${entry.key}';
    final value = entry.value;
    if (value is Map) {
      for (final inner in value.entries) {
        out['$key.${inner.key}'] = inner.value;
      }
    } else {
      out[key] = value;
    }
  }
  return out;
}
