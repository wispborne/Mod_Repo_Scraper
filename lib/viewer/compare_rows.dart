import 'dart:convert';

/// Identifies a record across snapshots. Records sharing a key within one
/// snapshot are compared as a set.
typedef KeyOf = String Function(Map<dynamic, dynamic> record);

/// What to show for a record in a list of differences.
typedef LabelOf = String Function(Map<dynamic, dynamic> record);

/// Compares entries within a list or map. An empty result suppresses the field
/// change, including differences caused only by entry order.
typedef ItemsOf = List<Map<String, dynamic>> Function(
    Object? before, Object? after);

/// A compared field and its display options.
class ComparedField {
  final String name;

  /// What the page calls it. Null uses [name].
  final String? label;

  /// Describes changes whose values are not useful to display, such as post
  /// fingerprints. Null displays the before and after values.
  final String Function(Object? before, Object? after)? describe;

  /// Compares list or map entries. Null displays the complete values.
  final ItemsOf? itemsOf;

  const ComparedField(this.name, {this.label, this.describe, this.itemsOf});
}

/// Returns searchable rows for added, removed and changed records, plus counts.
/// Unchanged records are counted but omitted from the rows.
Map<String, dynamic> compareRows({
  required List<dynamic> older,
  required List<dynamic> newer,
  required KeyOf keyOf,
  required List<ComparedField> fields,
  required LabelOf labelOf,
  required LabelOf authorOf,

  /// The response key for the record's data.
  String recordKey = 'record',

  /// Explains a changed set of records sharing a key; individual records cannot
  /// be matched for a field-by-field comparison.
  String setChangedNote =
      'More than one record shares this key, and the set of them changed.',
}) {
  final before = _byKey(older, keyOf);
  final after = _byKey(newer, keyOf);

  final rows = <Map<String, dynamic>>[];
  var same = 0;

  Map<String, dynamic> row(
          String kind, Map<dynamic, dynamic> record, String key) =>
      {
        'kind': kind,
        'key': key,
        'name': labelOf(record),
        'authors': authorOf(record),
        recordKey: record,
      };

  for (final key in {...before.keys, ...after.keys}) {
    final was = before[key] ?? const [];
    final now = after[key] ?? const [];

    if (was.isEmpty) {
      for (final record in now) {
        rows.add(row('added', record, key));
      }
      continue;
    }
    if (now.isEmpty) {
      for (final record in was) {
        rows.add(row('gone', record, key));
      }
      continue;
    }

    if (was.length == 1 && now.length == 1) {
      final changes = changedFields(was.first, now.first, fields);
      if (changes.isEmpty) {
        same++;
      } else {
        rows.add({
          ...row('changed', now.first, key),
          'changes': changes,
        });
      }
      continue;
    }

    // Duplicate keys cannot be matched individually; ignore their order.
    final wasJson = (was.map(sameness).toList()..sort()).join('|');
    final nowJson = (now.map(sameness).toList()..sort()).join('|');
    if (wasJson == nowJson) {
      same += now.length;
    } else {
      rows.add({
        ...row('changed', now.first, key),
        'changes': const [],
        'note': setChangedNote,
        'beforeCount': was.length,
        'afterCount': now.length,
      });
    }
  }

  rows.sort((a, b) {
    final byKind = _kindOrder(a['kind'] as String)
        .compareTo(_kindOrder(b['kind'] as String));
    if (byKind != 0) return byKind;
    return (a['name'] as String)
        .toLowerCase()
        .compareTo((b['name'] as String).toLowerCase());
  });

  return {
    'rows': rows,
    'sameCount': same,
    'addedCount': rows.where((r) => r['kind'] == 'added').length,
    'goneCount': rows.where((r) => r['kind'] == 'gone').length,
    'changedCount': rows.where((r) => r['kind'] == 'changed').length,
  };
}

/// Which of [fields] differ between two records.
List<Map<String, dynamic>> changedFields(
  Map<dynamic, dynamic> before,
  Map<dynamic, dynamic> after,
  List<ComparedField> fields,
) {
  final changes = <Map<String, dynamic>>[];
  for (final field in fields) {
    final was = before[field.name];
    final now = after[field.name];
    if (sameness(was) == sameness(now)) continue;

    if (field.itemsOf != null) {
      final items = field.itemsOf!(was, now);
      // Entry order alone is not a reported change.
      if (items.isEmpty) continue;
      changes.add({'field': field.label ?? field.name, 'items': items});
      continue;
    }

    changes.add({
      'field': field.label ?? field.name,
      if (field.describe != null) 'note': field.describe!(was, now),
      if (field.describe == null) 'before': was,
      if (field.describe == null) 'after': now,
    });
  }
  return changes;
}

// --- Picking a list or a map apart, entry by entry ---

/// Returns added, removed and changed map entries, omitting unchanged entries.
List<Map<String, dynamic>> mapItems(Object? before, Object? after) {
  final was = before is Map ? before : const {};
  final now = after is Map ? after : const {};
  final items = <Map<String, dynamic>>[];

  for (final key in now.keys) {
    if (!was.containsKey(key)) {
      items.add({'change': 'added', 'label': '$key', 'after': now[key]});
    }
  }
  for (final key in was.keys) {
    if (!now.containsKey(key)) {
      items.add({'change': 'removed', 'label': '$key', 'before': was[key]});
    }
  }
  for (final key in now.keys) {
    if (!was.containsKey(key)) continue;
    if (sameness(was[key]) == sameness(now[key])) continue;
    items.add({
      'change': 'changed',
      'label': '$key',
      'before': was[key],
      'after': now[key],
    });
  }
  return items;
}

/// Returns added and removed list entries, ignoring order.
List<Map<String, dynamic>> listItems(Object? before, Object? after) {
  Set<String> setOf(Object? value) => {
        for (final entry in value is List ? value : const []) sameness(entry),
      };
  String labelOf(Object? entry) => entry is String ? entry : sameness(entry);

  final was = setOf(before);
  final now = setOf(after);
  final items = <Map<String, dynamic>>[];

  for (final entry in after is List ? after : const []) {
    if (was.contains(sameness(entry))) continue;
    items.add({'change': 'added', 'label': labelOf(entry)});
  }
  for (final entry in before is List ? before : const []) {
    if (now.contains(sameness(entry))) continue;
    items.add({'change': 'removed', 'label': labelOf(entry)});
  }
  return items;
}

/// Equality for stored JSON values; map key and list entry order are preserved.
String sameness(Object? value) => jsonEncode(value);

int _kindOrder(String kind) => switch (kind) {
      'added' => 0,
      'gone' => 1,
      _ => 2,
    };

Map<String, List<Map<dynamic, dynamic>>> _byKey(
    List<dynamic> records, KeyOf keyOf) {
  final out = <String, List<Map<dynamic, dynamic>>>{};
  for (final record in records) {
    if (record is! Map) continue;
    out.putIfAbsent(keyOf(record), () => []).add(record);
  }
  return out;
}
