import 'dart:convert';

import 'compare_rows.dart';

/// Works out the two "before and after" pictures the Merge Explorer shows,
/// from merge debug data that is already saved.
///
/// Nothing here changes how merging works, or asks the merger to record
/// anything new. Both answers are read back out of what the merge already
/// wrote down.

// --- Which source supplied each field ---

/// The fields worth showing side by side. `urls` is a map and the three list
/// fields are lists, so they get picked apart entry by entry — that is where
/// the interesting answers are.
const List<String> _scalarFields = [
  'name',
  'summary',
  'description',
  'modVersion',
  'gameVersionReq',
  'dateTimeCreated',
  'dateTimeEdited',
];

const List<String> _listFields = ['authorsList', 'sources', 'categories'];

String _same(Object? value) => jsonEncode(value);

/// One row per field, saying what each member had, what came out, and which
/// member it came from.
///
/// A value that matches exactly one member came from that member. A value
/// several members agree on is marked as agreed, since there is nothing to
/// choose between them. A value matching none of them — a merged-together map,
/// say — is marked as not known, because a guess here would defeat the point of
/// the page.
Map<String, dynamic> fieldsForGroup({
  required Map<dynamic, dynamic> group,
  Map<dynamic, dynamic>? decision,
}) {
  final members = ((group['members'] as List?) ?? const []).cast<Map>();
  final merged = (decision?['finalResult'] as Map?) ??
      (members.length == 1 ? members.first : null);

  final rows = <Map<String, dynamic>>[];

  for (final field in _scalarFields) {
    final finalValue = merged?[field];
    rows.add({
      'field': field,
      'kind': 'scalar',
      'values': [
        for (var i = 0; i < members.length; i++)
          {'member': i, 'value': members[i][field]},
      ],
      'final': finalValue,
      ..._whoHad(members, field, finalValue),
    });
  }

  for (final field in _listFields) {
    final finalList = (merged?[field] as List?) ?? const [];
    rows.add({
      'field': field,
      'kind': 'list',
      'values': [
        for (var i = 0; i < members.length; i++)
          {'member': i, 'value': members[i][field] ?? const []},
      ],
      'final': finalList,
      'entries': [
        for (final value in finalList)
          {
            'value': value,
            ..._whoHadInList(members, field, value),
          },
      ],
    });
  }

  final finalUrls = (merged?['urls'] as Map?) ?? const {};
  rows.add({
    'field': 'urls',
    'kind': 'map',
    'values': [
      for (var i = 0; i < members.length; i++)
        {'member': i, 'value': members[i]['urls'] ?? const {}},
    ],
    'final': finalUrls,
    'entries': [
      for (final entry in finalUrls.entries)
        {
          'key': entry.key,
          'value': entry.value,
          ..._whoHadInMap(members, entry.key, entry.value),
        },
    ],
  });

  return {
    'groupIndex': group['groupIndex'],
    'memberCount': members.length,
    'members': [
      for (var i = 0; i < members.length; i++)
        {
          'member': i,
          'name': members[i]['name'],
          'authorsList': members[i]['authorsList'] ?? const [],
          'sources': members[i]['sources'] ?? const [],
        },
    ],
    'merged': merged,
    'wasMerged': members.length > 1,
    'rows': rows,
  };
}

/// `from` is the members holding this value; `verdict` is what that means.
Map<String, dynamic> _whoHad(
    List<Map> members, String field, Object? finalValue) {
  if (finalValue == null) {
    return {'from': const <int>[], 'verdict': 'empty'};
  }
  final wanted = _same(finalValue);
  final from = <int>[
    for (var i = 0; i < members.length; i++)
      if (_same(members[i][field]) == wanted) i,
  ];
  return {'from': from, 'verdict': _verdict(from)};
}

Map<String, dynamic> _whoHadInList(
    List<Map> members, String field, Object? value) {
  final wanted = _same(value);
  final from = <int>[
    for (var i = 0; i < members.length; i++)
      if (((members[i][field] as List?) ?? const [])
          .any((v) => _same(v) == wanted))
        i,
  ];
  return {'from': from, 'verdict': _verdict(from)};
}

Map<String, dynamic> _whoHadInMap(
    List<Map> members, Object? key, Object? value) {
  final wanted = _same(value);
  final from = <int>[
    for (var i = 0; i < members.length; i++)
      if (_same(((members[i]['urls'] as Map?) ?? const {})[key]) == wanted) i,
  ];
  return {'from': from, 'verdict': _verdict(from)};
}

String _verdict(List<int> from) => switch (from.length) {
      0 => 'unknown',
      1 => 'one',
      _ => 'agreed',
    };

// --- What changed between two merges ---

/// The fields a comparison looks at. Anything not here is not worth waking
/// somebody up over.
const List<ComparedField> _comparedFields = [
  ComparedField('name'),
  // The four fields below hold a list or a map. They are picked apart entry by
  // entry, because a mod with four links where one moved used to print all
  // four twice and leave the reader to spot which.
  ComparedField('authorsList', itemsOf: listItems),
  ComparedField('summary'),
  ComparedField('description'),
  ComparedField('modVersion'),
  ComparedField('gameVersionReq'),
  ComparedField('urls', itemsOf: mapItems),
  ComparedField('sources', itemsOf: listItems),
  ComparedField('categories', itemsOf: listItems),
];

final RegExp _forumTopic = RegExp(r'topic=(\d+)');

/// How two merges' mods are lined up: by forum topic when there is one, and
/// otherwise by name and authors with everything but letters stripped out —
/// the same flattening the merger itself matches on, so a version suffix in the
/// name does not read as a different mod.
String modKey(Map<dynamic, dynamic> mod) {
  final forumUrl = ((mod['urls'] as Map?) ?? const {})['Forum'] as String?;
  final topic = forumUrl == null ? null : _forumTopic.firstMatch(forumUrl);
  if (topic != null) return 'topic:${topic.group(1)}';

  final name = _flatten(mod['name'] as String? ?? '');
  final authors = (((mod['authorsList'] as List?) ?? const [])
          .map((a) => _flatten('$a'))
          .toList()
        ..sort())
      .join(',');
  return 'name:$name|$authors';
}

String _flatten(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

String _label(Map<dynamic, dynamic> mod) => (mod['name'] as String?) ?? '';

String _authorLabel(Map<dynamic, dynamic> mod) =>
    ((mod['authorsList'] as List?) ?? const []).join(', ');

/// Compares the mods two merges ended up with.
///
/// The comparing itself is shared with the bundle side; all this adds is how a
/// mod is keyed, which fields matter, and what to call it on screen.
Map<String, dynamic> compareMerges({
  required List<dynamic> olderOutput,
  required List<dynamic> newerOutput,
}) =>
    compareRows(
      older: olderOutput,
      newer: newerOutput,
      keyOf: modKey,
      fields: _comparedFields,
      labelOf: _label,
      authorOf: _authorLabel,
      recordKey: 'mod',
      setChangedNote:
          'More than one mod shares this name and author, and the set of '
          'them changed.',
    );
