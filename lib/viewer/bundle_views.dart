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

/// Fields compared for one Discord thread in a saved bundle. The mod history
/// reads it as `{name, url, llm: {mods}}`. The LLM's mods use the same
/// comparison as a forum topic's.
final List<ComparedField> discordThreadFields = [
  const ComparedField('name', label: 'thread name'),
  const ComparedField('url', label: 'thread address'),
  const ComparedField('llm', label: 'LLM facts', itemsOf: _llmItems),
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
///
/// Two entries can share a key (a thread that names one mod twice, a link
/// given twice). Those are matched by key and then by position, the first with
/// the first and so on, and each is labelled with its place ("Foo #2") so a
/// change to the second one is reported too.
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
  Map<String, List<Map<dynamic, dynamic>>> byKey(List<dynamic> list) {
    final out = <String, List<Map<dynamic, dynamic>>>{};
    for (final item in list) {
      if (item is! Map) continue;
      out.putIfAbsent(keyOf(item), () => []).add(item);
    }
    return out;
  }

  final was = byKey(before);
  final now = byKey(after);
  // Keys given to more than one entry on either side get a place in the label.
  final shared = {
    for (final group in [was, now])
      for (final entry in group.entries)
        if (entry.value.length > 1) entry.key,
  };
  String label(String key, Map<dynamic, dynamic> item, int index) =>
      shared.contains(key) ? '${labelOf(item)} #${index + 1}' : labelOf(item);

  final rows = <Map<String, dynamic>>[];
  for (final key in now.keys) {
    final had = was[key]?.length ?? 0;
    final items = now[key]!;
    for (var i = had; i < items.length; i++) {
      rows.add({'change': 'added', 'label': label(key, items[i], i)});
    }
  }
  for (final key in was.keys) {
    final has = now[key]?.length ?? 0;
    final items = was[key]!;
    for (var i = has; i < items.length; i++) {
      rows.add({'change': 'removed', 'label': label(key, items[i], i)});
    }
  }
  for (final key in now.keys) {
    final old = was[key];
    if (old == null) continue;
    final items = now[key]!;
    for (var i = 0; i < items.length && i < old.length; i++) {
      final parts = partsOf?.call(old[i], items[i]) ?? const [];
      final inner = itemsOf?.call(old[i], items[i]) ?? const [];
      if (parts.isEmpty && inner.isEmpty) continue;
      rows.add({
        'change': 'changed',
        'label': label(key, items[i], i),
        if (parts.isNotEmpty) 'parts': parts,
        if (inner.isNotEmpty) 'items': inner,
      });
    }
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
        'descriptionAnchors': 'description start and end',
        'isTool': 'tool',
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
  'conflicts': 'conflicting mods',
  'summary.sentence': 'summary — one line',
  'summary.paragraph': 'summary — paragraph',
  'changelog.link': 'changelog link',
  'changelog.entries': 'changelog entries',
  'supportLinks': 'support links',
  'aiUse.usesAi': 'AI used',
  'aiUse.uses': 'AI use',
  'aiUse.tools': 'AI tools',
  'aiUse.quote': 'AI use statement',
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
