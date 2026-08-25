import 'dart:convert';

/// Comparing two saved things that hold a list of records — two merges' mods,
/// two bundles' topics — and saying what is new, what is gone, and what changed.
///
/// The two callers differ in only three ways: how a record is keyed, which of
/// its fields are worth looking at, and what to call it on screen. Everything
/// else — lining the two sides up, spotting a changed field, sorting, counting
/// the ones that stayed the same — is the same job, so it lives here once.

/// How two records are told apart as the same thing. Returning the same key for
/// two records in one snapshot is allowed; they are then compared as a set.
typedef KeyOf = String Function(Map<dynamic, dynamic> record);

/// What to show for a record in a list of differences.
typedef LabelOf = String Function(Map<dynamic, dynamic> record);

/// Says what changed inside a field item by item, for a field holding a list or
/// a map. Returning an empty list means nothing that counts moved — only the
/// order of the entries, say — and the field is then not reported as changed.
typedef ItemsOf = List<Map<String, dynamic>> Function(
    Object? before, Object? after);

/// One field worth comparing, and what to call it in plain English.
class ComparedField {
  final String name;

  /// What the page calls it. Null uses [name].
  final String? label;

  /// Says what changed in words, for a field where showing both values would
  /// be no use — a fingerprint of a post, say. Null shows the two values.
  final String Function(Object? before, Object? after)? describe;

  /// Picks a list or a map apart entry by entry, so a field where one link of
  /// twelve moved says that rather than printing all twelve twice. Null shows
  /// the two values whole.
  final ItemsOf? itemsOf;

  const ComparedField(this.name, {this.label, this.describe, this.itemsOf});
}

/// Compares two lists of records.
///
/// Every difference comes back as a row that can be searched by label or
/// author. Records that did not change are counted and not listed — there are
/// usually a thousand of them, and a list nobody can read is worse than a
/// number.
Map<String, dynamic> compareRows({
  required List<dynamic> older,
  required List<dynamic> newer,
  required KeyOf keyOf,
  required List<ComparedField> fields,
  required LabelOf labelOf,
  required LabelOf authorOf,
  /// What the record itself is called in a row. Each caller keeps the name its
  /// own pages already use.
  String recordKey = 'record',
  /// What to say when several records share one key and the set of them
  /// changed. There is no sensible field-by-field answer in that case.
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

    // More than one record under one key. Compare them as a set, and say so.
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
    final byKind =
        _kindOrder(a['kind'] as String).compareTo(_kindOrder(b['kind'] as String));
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
      // Nothing that counts moved — the entries were only written in a
      // different order. Saying "this changed" and then showing nothing is
      // worse than not mentioning it.
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

/// The added, removed and changed entries of a map — a mod's links, say. A
/// changed entry carries the old and new value; an entry that stayed the same
/// is left out, which is the whole point.
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

/// The added and removed entries of a plain list — a mod's authors, its
/// categories, the sources it was found in. Order is not a change: the same
/// names written in a different order is not something to report.
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

/// Two values count as the same when they write out the same. Good enough for
/// telling "this changed" from "this did not", which is all that is asked here.
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
