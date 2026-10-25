import 'compare_rows.dart';

/// Fields included in bundle diffs and topic history. Scrape timestamps and
/// activity counts are excluded because they change independently of mod data.
final List<ComparedField> bundleFields = [
  const ComparedField('title'),
  const ComparedField('author'),
  const ComparedField('category'),
  const ComparedField('lastPostDate', label: 'last post'),
  const ComparedField('isWip', label: 'work in progress'),
  const ComparedField('inModIndex', label: 'in the mod index'),
  const ComparedField('indexLines',
      label: 'mod index lines', itemsOf: _indexLineItems),
  const ComparedField('sourceBoard', label: 'board'),
  const ComparedField('thumbnailPath', label: 'thumbnail'),
  const ComparedField('contentFingerprint',
      label: 'post text', describe: _describePostChange),
  const ComparedField('imageCount', label: 'images'),
  const ComparedField('links', itemsOf: _linkItems),
  const ComparedField('downloads', itemsOf: _downloadItems),
  const ComparedField('llm', label: 'LLM facts', itemsOf: _llmItems),
  const ComparedField('extraPosts',
      label: 'the author\'s other posts', itemsOf: _extraPostItems),
];

/// One mod index line as a reader would name it: "Name by Author [0.98a] in Faction Mods".
List<Map<String, dynamic>> _indexLineItems(Object? before, Object? after) {
  List<String> named(Object? value) => [
        for (final line in value is List ? value : const [])
          if (line is Map)
            [
              line['name'],
              if ('${line['author'] ?? ''}'.isNotEmpty) 'by ${line['author']}',
              if (line['gameVersion'] != null) '[${line['gameVersion']}]',
              'in ${line['category']}',
            ].join(' '),
      ];
  return listItems(named(before), named(after));
}

/// Snapshots retain a fingerprint, so text changes have no before/after values.
String _describePostChange(Object? before, Object? after) {
  if (before == null) return 'The post text was read for the first time.';
  if (after == null) return 'The post text is no longer saved.';
  return 'The post text changed. Snapshots do not keep the text; '
      'open the topic to read the current post.';
}

/// Compares the author's follow-up posts by position. Text changes are
/// described from fingerprints, as for the first post.
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
      // Display a text-change note rather than the fingerprint values.
      if (sameness(a['contentFingerprint']) !=
          sameness(b['contentFingerprint']))
        {
          'name': 'post text',
          'note': _describePostChange(
              a['contentFingerprint'], b['contentFingerprint']),
        },
      ..._partsThatMoved(a, b, const {
        'postDate': 'posted',
        'lastEditDate': 'last edited',
      }, skip: const {
        'contentFingerprint'
      }),
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
  // Bundle downloads are a plain list; the resolver cache wraps its list in
  // `candidates`. This reads the bundle shape.
  final download = downloads[id];

  return {
    'topicId': row['topicId'],
    'title': row['title'],
    'author': row['author'],
    'category': row['category'],
    'lastPostDate': row['lastPostDate'],
    'isWip': row['isWip'],
    'inModIndex': row['inModIndex'],
    'indexLines': row['indexLines'],
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

/// Walks snapshots oldest to newest, reporting only changes to this topic.
///
/// The oldest retained snapshot is the baseline. A topic already present in it
/// is not reported as added because no earlier snapshot is available.
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
    'entries': entries.reversed.toList(),
    // Distinguish never-published topics from published but unchanged topics.
    'everInBundle': everInBundle,
    'snapshotsRead': read,
    'snapshotsTotal': snapshots.length,
    'oldestSavedAt': oldestSavedAt?.toUtc().toIso8601String(),
    'oldestRunId': oldestRunId,
  };
}

/// Uses the bundle diff's fields and labels so topic history stays consistent.
List<Map<String, dynamic>> topicChanges(
  Map<dynamic, dynamic> before,
  Map<dynamic, dynamic> after,
) =>
    changedFields(before, after, bundleFields);

List<dynamic> _asList(Object? value) => value is List ? value : const [];

/// Matches entries by key and reports additions, removals and changed parts.
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

/// Compares all keys from either entry. [named] supplies display labels, not a
/// filter; [skip] excludes keys used for matching or handled separately.
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
    ...{...was.keys, ...now.keys}
        .map((k) => '$k')
        .where((k) => !named.containsKey(k)),
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
List<Map<String, dynamic>> _linkItems(Object? before, Object? after) => _lineUp(
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

/// Compares LLM mods by name, with separate changes for extras and downloads.
List<Map<String, dynamic>> _llmItems(Object? was, Object? now) {
  List<dynamic> modsOf(Object? value) =>
      value is Map ? _asList(value['mods']) : const [];

  return _lineUp(
    modsOf(was),
    modsOf(now),
    keyOf: (m) => '${m['name'] ?? ''}'.toLowerCase(),
    labelOf: (m) => '${m['name'] ?? '(no name)'}',
    partsOf: (a, b) => [
      // Name is the matching key; extras and downloads are compared separately.
      ..._partsThatMoved(a, b, const {
        'role': 'role',
        'nicknames': 'other names',
        'requires': 'requires',
        'image': 'image',
        'descriptionAnchors': 'where it is described',
      }, skip: const {
        'name',
        'extras',
        'downloads'
      }),
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

/// Display labels for LLM extras, including flattened nested fields.
const Map<String, String> _extraNames = {
  'version': 'version',
  'license': 'license',
  'sourceCode': 'source code',
  'saveCompatibility': 'adding to a save',
  'updateNotes': 'update notes',
  'removalCompatibility': 'removing from a save',
  'canAdd': 'can add to a save',
  'canRemove': 'can remove from a save',
  'needs': 'what it needs',
  'optionalNeeds': 'optional mods',
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
