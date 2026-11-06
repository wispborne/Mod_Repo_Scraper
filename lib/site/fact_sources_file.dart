import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../catalog/fact_choice.dart';

/// Each published fact's source, recorded by one website build. Saved in the
/// QB data folder for the viewer's mod page, beside `takedown-matches.json`
/// and `catalog-left-out.json`. Never published.
///
/// [builtAt] is the catalog's `lastUpdated`, so the viewer can tell a file
/// written for the catalog it is showing from one written for an older one.
///
/// On disk: `{ builtAt, mods: { <id>: { <field>: source } }, mergedFrom: {
/// <id>: { <field>: [post] } } }`. A source is `{kind, id, llmName}` for one
/// post, or the word `rules` or `merged`; [FactOrigin] says what each means.
/// `mergedFrom` names the posts behind a field put together from several
/// answers, and is left out when there are none.
class FactSourcesFile {
  static const String fileName = 'fact-sources.json';

  final DateTime builtAt;

  /// By mod id, then by published field name.
  final Map<String, Map<String, FactOrigin>> mods;

  const FactSourcesFile({required this.builtAt, this.mods = const {}});

  Map<String, dynamic> toMap() {
    final ids = mods.keys.toList()..sort();
    final mergedFrom = <String, Map<String, dynamic>>{};
    for (final id in ids) {
      final fields = mods[id]!;
      for (final field in fields.keys.toList()..sort()) {
        final from = fields[field]!.fromJson();
        if (from != null) (mergedFrom[id] ??= {})[field] = from;
      }
    }
    return {
      'builtAt': builtAt.toUtc().toIso8601String(),
      'mods': {
        for (final id in ids)
          id: {
            for (final field in mods[id]!.keys.toList()..sort()) field: mods[id]![field]!.toJson(),
          },
      },
      if (mergedFrom.isNotEmpty) 'mergedFrom': mergedFrom,
    };
  }

  /// Reads what [toMap] wrote. A source it cannot read is skipped.
  factory FactSourcesFile.fromMap(Map<String, dynamic> map) {
    final mergedFrom = (map['mergedFrom'] as Map?) ?? const {};
    return FactSourcesFile(
      builtAt: DateTime.tryParse('${map['builtAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
      mods: {
        for (final MapEntry(key: id, value: fields) in ((map['mods'] as Map?) ?? const {}).entries)
          if (fields is Map)
            '$id': {
              for (final MapEntry(key: field, value: source) in fields.entries)
                if (FactOrigin.read(source, (mergedFrom[id] as Map?)?[field]) case final origin?) '$field': origin,
            },
      },
    );
  }

  static File fileIn(String dataPath) => File(p.join(dataPath, fileName));

  /// Writes [fileName] in [dataPath], through a temporary file.
  void write(String dataPath) {
    final file = fileIn(dataPath);
    file.parent.createSync(recursive: true);
    final temp = File('${file.path}.tmp');
    temp.writeAsStringSync(jsonEncode(toMap()));
    temp.renameSync(file.path);
  }
}
