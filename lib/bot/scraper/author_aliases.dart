import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'mod_repo_utils.dart';

/// `author-aliases.json`: the author aliases as edited in the viewer.
///
/// The rows built into the code ([ModRepoUtils.builtInAuthorAliases]) are the
/// starting list. Once the viewer saves this file, [people] is the whole list,
/// built-in rows included, so a built-in row can be changed or removed.
/// [builtInSeen] records which built-in rows the file was saved against, so a
/// row added to the code later still reaches a copy saved before it.
///
/// [notSame] holds pairs of names marked as different people. They only keep
/// the viewer's suggestions from offering the pair again; the merge never
/// reads them.
///
/// A missing file means the built-in rows. A file that is there but cannot be
/// read throws, and the job must stop before it writes anything: building
/// without it would credit people under names they asked to be folded away.
class AuthorAliasFile {
  static const String fileName = 'author-aliases.json';

  final List<List<String>> people;
  final List<List<String>> notSame;
  final List<String> builtInSeen;

  /// False when there was no file, so [people] is empty and means nothing.
  final bool saved;

  const AuthorAliasFile({
    this.people = const [],
    this.notSame = const [],
    this.builtInSeen = const [],
    this.saved = false,
  });

  static File fileIn(String dataPath) => File(p.join(dataPath, fileName));

  static AuthorAliasFile read(String dataPath) {
    final file = fileIn(dataPath);
    if (!file.existsSync()) return const AuthorAliasFile();
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, dynamic>) throw const FormatException('not a JSON object');
      return AuthorAliasFile(
        people: _rows(decoded['people']),
        notSame: _rows(decoded['notSame']),
        builtInSeen: [for (final key in decoded['builtInSeen'] as List? ?? const []) '$key'],
        saved: true,
      );
    } catch (e) {
      throw StateError('Cannot read the author aliases at ${file.path}: $e\n'
          'Building without them would credit people under the wrong names, so '
          'the job has stopped before writing anything. Fix the file, or delete '
          'it to go back to the built-in aliases.');
    }
  }

  static List<List<String>> _rows(Object? value) {
    if (value == null) return const [];
    if (value is! List) throw const FormatException('a list of rows was expected');
    return [
      for (final row in value)
        if (row is List) [for (final name in row) '$name'] else throw const FormatException('a row is not a list'),
    ];
  }

  /// The rows the merge uses: the built-in rows when nothing is saved, else
  /// [people] plus any built-in row added since. Rows that share a name are
  /// joined, so a built-in row that grew a name cannot leave one person in
  /// two rows.
  List<List<String>> rowsToUse([List<List<String>> builtIn = ModRepoUtils.builtInAuthorAliases]) {
    if (!saved) return builtIn;
    final seen = builtInSeen.toSet();
    return joinRowsSharingAName([
      ...people,
      for (final row in builtIn)
        if (!seen.contains(rowKey(row))) row,
    ]);
  }

  /// One built-in row, as [builtInSeen] records it.
  static String rowKey(List<String> row) => row.map((name) => name.toLowerCase()).join('\n');

  /// Writes the file through a replacement file, so a stopped process never
  /// leaves half of it.
  void write(String dataPath, {List<List<String>> builtIn = ModRepoUtils.builtInAuthorAliases}) {
    final file = fileIn(dataPath);
    file.parent.createSync(recursive: true);
    final temp = File('${file.path}.tmp');
    temp.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({
          'people': people,
          'notSame': notSame,
          'builtInSeen': [for (final row in builtIn) rowKey(row)],
        })}\n');
    temp.renameSync(file.path);
  }

  /// Reads the file in [dataPath] and makes its rows the ones every merge and
  /// takedown uses from now on. Throws like [read].
  static AuthorAliasFile install(String dataPath) {
    final file = read(dataPath);
    ModRepoUtils.useAuthorAliases(file.rowsToUse());
    return file;
  }
}

/// The alias list [people] and [notSame] tidied for saving: names trimmed,
/// blanks and repeats within a row dropped. Throws a [StateError] in plain
/// words when the list cannot be saved as it stands.
({List<List<String>> people, List<List<String>> notSame}) checkAliasRows(
  List<List<String>> people,
  List<List<String>> notSame,
) {
  List<String> tidy(List<String> row) {
    final seen = <String>{};
    return [
      for (final name in row.map((n) => n.trim()))
        if (name.isNotEmpty && seen.add(name.toLowerCase())) name,
    ];
  }

  final rows = [for (final row in people) tidy(row)]..removeWhere((row) => row.isEmpty);
  final rowOf = <String, int>{};
  for (var i = 0; i < rows.length; i++) {
    if (rows[i].length < 2) {
      throw StateError('"${rows[i].single}" has no other name. A person needs at least two names to be an alias. '
          'Nothing was saved.');
    }
    for (final name in rows[i]) {
      final other = rowOf[name.toLowerCase()];
      if (other != null) {
        throw StateError('"$name" is listed for two people ("${rows[other].first}" and "${rows[i].first}"). '
            'Nothing was saved.');
      }
      rowOf[name.toLowerCase()] = i;
    }
  }

  final pairs = [for (final pair in notSame) tidy(pair)];
  for (final pair in pairs) {
    if (pair.length != 2) {
      throw StateError('A "different people" entry needs exactly two names, not ${pair.length}. Nothing was saved.');
    }
    final left = rowOf[pair[0].toLowerCase()];
    if (left != null && left == rowOf[pair[1].toLowerCase()]) {
      throw StateError('"${pair[0]}" and "${pair[1]}" are marked as different people and listed as one person. '
          'Nothing was saved.');
    }
  }
  return (people: rows, notSame: pairs);
}

/// [rows] with every two rows that share a name (ignoring capitals) made one,
/// in the order the names first appear.
List<List<String>> joinRowsSharingAName(List<List<String>> rows) {
  final joined = <List<String>>[];
  for (final row in rows) {
    final lower = {for (final name in row) name.toLowerCase()};
    final overlapping = [
      for (final existing in joined)
        if (existing.any((name) => lower.contains(name.toLowerCase()))) existing,
    ];
    final into = overlapping.isEmpty ? <String>[] : overlapping.first;
    if (overlapping.isEmpty) joined.add(into);
    for (final other in overlapping.skip(1)) {
      into.addAll(other);
      joined.remove(other);
    }
    into.addAll(row);
    final seen = <String>{};
    into.retainWhere((name) => seen.add(name.toLowerCase()));
  }
  return joined;
}
