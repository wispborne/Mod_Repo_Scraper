import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import '../bot/scraper/author_aliases.dart';
import '../catalog/mod_catalog.dart';
import '../catalog/takedowns.dart';
import '../site/requirement_names.dart';
import 'author_alias_service.dart';
import 'cancel_token.dart';
import 'job.dart';
import 'run_reporter.dart';
import 'scraper_service.dart';
import 'takedown_service.dart';

/// The first step of a `saveCorrections` job: applying every correction to
/// `takedowns.json`, `author-aliases.json` and `requirement-names.json`.
/// `JobRouter` runs the merge, the rebuild and the publish after it.
///
/// Every correction is applied in order to copies of the files held in memory.
/// Each one is checked with the rules the single-correction jobs use. If any
/// is refused, the job fails with one message naming each refused correction,
/// and no file is written. Otherwise only the files that changed are written,
/// each through a replacement file.
class CorrectionsService implements JobRunner {
  /// Holds the three files.
  final String dataPath;

  /// Holds `mod-catalog.json`, which mod ids are checked against.
  final String outputPath;

  final DateTime Function() _now;

  CorrectionsService({required this.dataPath, required this.outputPath, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  @override
  Future<JobOutcome> runJob(
    JobRequest request, {
    RunReporter reporter = const SilentRunReporter(),
    CancelToken? cancel,
    String? runId,
  }) async {
    if (request.kind != JobKind.saveCorrections) {
      throw ArgumentError('The corrections service cannot run ${request.kind.name}.');
    }
    reporter.phase('Corrections');
    final corrections = request.corrections;
    if (corrections.isEmpty) {
      throw StateError('There are no corrections to save. Nothing was saved.');
    }

    final edits = _Edits(dataPath: dataPath, outputPath: outputPath, day: takedownDay(_now()));
    final refused = <String>[];
    for (var i = 0; i < corrections.length; i++) {
      final correction = corrections[i];
      try {
        edits.apply(correction, reporter.log);
      } on _Refused catch (e) {
        refused.add('Correction ${i + 1} (${describeCorrection(correction)}): ${e.reason}');
      }
    }
    if (refused.isNotEmpty) {
      throw StateError('Nothing was saved. ${refused.join(' ')}');
    }

    await edits.write(reporter.log);
    return JobOutcome(itemsDone: corrections.length, itemsTotal: corrections.length);
  }
}

/// What [correction] does, in a few words, for refusals and the log.
String describeCorrection(Correction correction) {
  final names = [for (final name in correction.names) if (name.trim().isNotEmpty) '"${name.trim()}"'];
  String both() => names.length == 2 ? '${names[0]} and ${names[1]}' : names.join(', ');
  final one = names.isEmpty ? '""' : names.first;
  return switch (correction.kind) {
    CorrectionKind.takeDownMod => 'take down "${correction.modId?.trim() ?? ''}"',
    CorrectionKind.takeDownAuthor => 'take down the person ${names.join(', ')}',
    CorrectionKind.restore => 'restore "${correction.entry?.trim() ?? ''}"',
    CorrectionKind.sameAuthor => '${both()} are the same person',
    CorrectionKind.differentAuthors => '${both()} are different people',
    CorrectionKind.removeAuthorName => 'take $one off its person',
    CorrectionKind.publishAuthorAs => 'publish the person as $one',
    CorrectionKind.matchRequirement => correction.forget
        ? 'forget the saved answer for "${correction.written?.trim() ?? ''}"'
        : '"${correction.written?.trim() ?? ''}" means '
            '${_modIdOf(correction) == null ? 'none of our mods' : '"${_modIdOf(correction)}"'}',
  };
}

/// Why [change] cannot be saved, or null when it can. [knownModIds] are the
/// ids of the mods in `mod-catalog.json`. Shared by `setRequirementNames` and
/// `saveCorrections`.
String? requirementChangeProblem(RequirementChange change, Set<String> knownModIds) {
  final id = change.id;
  if (change.forget || id == null || knownModIds.contains(id)) return null;
  return 'No mod in ${ModCatalog.fileName} has the id "$id". "${change.written}" cannot match it.';
}

String? _modIdOf(Correction correction) {
  final id = correction.modId?.trim();
  return id == null || id.isEmpty ? null : id;
}

/// A correction that cannot be applied, with the reason in a plain sentence.
class _Refused implements Exception {
  final String reason;
  const _Refused(this.reason);
}

/// Holds the three files with the corrections applied so far. Each file is read
/// when a correction first needs it. An existing file that cannot be read
/// stops the job before anything is written.
class _Edits {
  final String dataPath;
  final String outputPath;
  final String day;

  _Edits({required this.dataPath, required this.outputPath, required this.day});

  TakedownEdits? _takedowns;

  List<List<String>>? _peopleBefore;
  List<List<String>>? _notSameBefore;
  late List<List<String>> _people;
  late List<List<String>> _notSame;

  RequirementNameStore? _requirements;
  Map<String, String> _requirementsBefore = const {};

  Set<String>? _modIds;

  void apply(Correction correction, void Function(String line) log) {
    switch (correction.kind) {
      case CorrectionKind.takeDownMod:
      case CorrectionKind.takeDownAuthor:
      case CorrectionKind.restore:
        _applyTakedown(correction, log);
      case CorrectionKind.sameAuthor:
      case CorrectionKind.differentAuthors:
      case CorrectionKind.removeAuthorName:
      case CorrectionKind.publishAuthorAs:
        _applyAlias(correction, log);
      case CorrectionKind.matchRequirement:
        _applyRequirement(correction, log);
    }
  }

  // --- Takedowns ---

  void _applyTakedown(Correction correction, void Function(String line) log) {
    final edits = _takedowns ??= TakedownEdits.read(dataPath, outputPath: outputPath, day: day);
    try {
      switch (correction.kind) {
        case CorrectionKind.takeDownMod:
          edits.takeDownMod(correction.modId ?? '', log: log);
        case CorrectionKind.takeDownAuthor:
          edits.takeDownAuthor(correction.names, log: log);
        default:
          edits.restore(correction.entry ?? '', log: log);
      }
    } on TakedownRefused catch (e) {
      throw _Refused(e.reason);
    }
  }

  // --- Author aliases ---

  void _loadAliases() {
    if (_peopleBefore != null) return;
    final file = AuthorAliasFile.read(dataPath);
    _peopleBefore = file.rowsToUse();
    _notSameBefore = file.notSame;
    _people = [for (final row in _peopleBefore!) [...row]];
    _notSame = [for (final pair in _notSameBefore!) [...pair]];
  }

  void _applyAlias(Correction correction, void Function(String line) log) {
    _loadAliases();
    final people = [for (final row in _people) [...row]];
    final notSame = [for (final pair in _notSame) [...pair]];
    final names = [for (final name in correction.names) if (name.trim().isNotEmpty) name.trim()];
    int? rowOf(String name) {
      final lower = name.toLowerCase();
      for (var i = 0; i < people.length; i++) {
        if (people[i].any((n) => n.toLowerCase() == lower)) return i;
      }
      return null;
    }

    switch (correction.kind) {
      case CorrectionKind.sameAuthor:
      case CorrectionKind.differentAuthors:
        if (names.length != 2) throw const _Refused('This correction needs exactly two author names.');
        final [a, b] = names;
        if (a.toLowerCase() == b.toLowerCase()) {
          throw const _Refused('The two names are the same name.');
        }
        if (correction.kind == CorrectionKind.differentAuthors) {
          final pair = {a.toLowerCase(), b.toLowerCase()};
          if (notSame.any((p) => p.map((n) => n.toLowerCase()).toSet().containsAll(pair))) {
            log('"$a" and "$b" are already marked as different people.');
            return;
          }
          notSame.add([a, b]);
          log('"$a" and "$b" are different people.');
          break;
        }
        final ia = rowOf(a);
        final ib = rowOf(b);
        if (ia != null && ia == ib) {
          log('"$a" and "$b" are already one person.');
          return;
        }
        // The first name's person keeps the name it is published under. With
        // no person for the first name, the second name's person does. With
        // neither, a new person is made, published under the first name.
        final List<String> joined;
        if (ia != null && ib != null) {
          joined = [...people[ia], ...people[ib]];
          people[ia] = joined;
          people.removeAt(ib);
        } else if (ia != null) {
          joined = people[ia]..add(b);
        } else if (ib != null) {
          joined = people[ib]..add(a);
        } else {
          joined = [a, b];
          people.add(joined);
        }
        // Joining two names removes any earlier "different people" mark
        // between names in the joined group.
        final inJoined = {for (final name in joined) name.toLowerCase()};
        notSame.removeWhere((pair) => pair.every((n) => inJoined.contains(n.toLowerCase())));
        log('"$a" and "$b" are one person: ${joined.join(', ')}.');
      case CorrectionKind.removeAuthorName:
        if (names.length != 1) throw const _Refused('This correction needs exactly one author name.');
        final name = names.single;
        final row = rowOf(name);
        if (row == null) {
          log('"$name" is not listed as an alias, so there is nothing to take off.');
          return;
        }
        people[row].removeWhere((n) => n.toLowerCase() == name.toLowerCase());
        if (people[row].length < 2) {
          log('Took "$name" off its person. "${people[row].join()}" has no other name left, so it is no longer an alias.');
          people.removeAt(row);
        } else {
          log('Took "$name" off its person: ${people[row].join(', ')}.');
        }
      case CorrectionKind.publishAuthorAs:
        if (names.length != 1) throw const _Refused('This correction needs exactly one author name.');
        final name = names.single;
        final row = rowOf(name);
        if (row == null) {
          throw _Refused('"$name" is not one of a person\'s names. Join it with another name first.');
        }
        if (people[row].first == name) {
          log('"$name" is already the name its person is published under.');
          return;
        }
        people[row] = [name, ...people[row].where((n) => n.toLowerCase() != name.toLowerCase())];
        log('The person ${people[row].join(', ')} is now published as "$name".');
      default:
        throw ArgumentError('${correction.kind.name} is not an author correction.');
    }

    try {
      final checked = checkAliasRows(people, notSame);
      _people = checked.people;
      _notSame = checked.notSame;
    } on StateError catch (e) {
      throw _Refused(_withoutNothingSaved(e.message));
    }
  }

  static String _withoutNothingSaved(String message) {
    const tail = ' Nothing was saved.';
    return message.endsWith(tail) ? message.substring(0, message.length - tail.length) : message;
  }

  static const _rowsEqual = DeepCollectionEquality();

  bool get _aliasesChanged =>
      _peopleBefore != null &&
      (!_rowsEqual.equals(_people, _peopleBefore) || !_rowsEqual.equals(_notSame, _notSameBefore));

  // --- Dependency names ---

  void _applyRequirement(Correction correction, void Function(String line) log) {
    final store = _requirements ?? _loadRequirements();
    final written = correction.written?.trim() ?? '';
    if (requirementKey(written).isEmpty) {
      throw const _Refused('A dependency name correction needs the name as the post writes it.');
    }
    final change = RequirementChange(written: written, id: _modIdOf(correction), forget: correction.forget);
    final problem = requirementChangeProblem(change, _knownModIds());
    if (problem != null) throw _Refused(problem);
    if (change.forget) {
      store.forget(written);
      log('Removed the saved answer for "$written".');
    } else {
      store.putHandAnswer(written, change.id);
      log('"$written" now means ${change.id == null ? 'none of our mods' : '"${change.id}"'}.');
    }
  }

  RequirementNameStore _loadRequirements() {
    final store = RequirementNameStore(dataPath)..load();
    if (store.isUnreadable) {
      throw StateError('${RequirementNameStore.fileName} could not be read. Fix or remove it first. '
          'Nothing was saved.');
    }
    _requirementsBefore = _answersOf(store);
    return _requirements = store;
  }

  static Map<String, String> _answersOf(RequirementNameStore store) =>
      {for (final entry in store.answers.entries) entry.key: jsonEncode(entry.value.toJson())};

  bool get _requirementsChanged =>
      _requirements != null && !const MapEquality<String, String>().equals(_answersOf(_requirements!), _requirementsBefore);

  Set<String> _knownModIds() => _modIds ??= {
        for (final mod in ModCatalog.read(File(p.join(outputPath, ModCatalog.fileName)))?.mods ?? const <CatalogMod>[])
          mod.id,
      };

  // --- Writing ---

  /// Writes each file that changed, through a replacement file.
  Future<void> write(void Function(String line) log) async {
    final takedowns = _takedowns;
    if (takedowns != null && (takedowns.listChanged || takedowns.restoredChanged)) {
      takedowns.write(dataPath);
      log('Saved ${TakedownList.fileName}.');
    }
    if (_aliasesChanged) {
      AuthorAliasFile(people: _people, notSame: _notSame, saved: true).write(dataPath);
      // Reload so the active rows match the saved file.
      AuthorAliasFile.install(dataPath);
      describeAliasChanges(_peopleBefore!, _people).forEach(log);
      log('Saved ${_people.length} people and ${_notSame.length} "different people" pairs to '
          '${AuthorAliasFile.fileName}.');
    }
    if (_requirementsChanged) {
      await _requirements!.save();
      log('Saved ${RequirementNameStore.fileName}.');
    }
  }
}
