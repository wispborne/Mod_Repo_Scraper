import 'dart:io';

import 'package:path/path.dart' as p;

import '../catalog/mod_catalog.dart';
import '../catalog/takedowns.dart';
import 'cancel_token.dart';
import 'job.dart';
import 'run_reporter.dart';
import 'scraper_service.dart';

/// The first step of a `takeDown` or `restoreTakedown` job: adding the entry
/// to `takedowns.json`, or taking it out. `JobRouter` runs the rebuild and the
/// publish after it.
///
/// It runs under the data lock like every job, so the list never changes
/// while a catalog is being built. A request it cannot carry out is refused
/// with a reason, and the list is left as it was.
class TakedownService implements JobRunner {
  /// Holds `takedowns.json` and `takedowns-restored.json`.
  final String dataPath;

  /// Holds `mod-catalog.json`, which a mod entry's posts are read from.
  final String outputPath;

  final DateTime Function() _now;

  TakedownService({required this.dataPath, required this.outputPath, DateTime Function()? now})
      : _now = now ?? DateTime.now;

  @override
  Future<JobOutcome> runJob(
    JobRequest request, {
    RunReporter reporter = const SilentRunReporter(),
    CancelToken? cancel,
    String? runId,
  }) async {
    reporter.phase('Takedown list');
    switch (request.kind) {
      case JobKind.takeDown:
        _takeDown(request, reporter);
      case JobKind.restoreTakedown:
        _restore(request, reporter);
      default:
        throw ArgumentError('The takedown service cannot run ${request.kind.name}.');
    }
    return const JobOutcome(itemsDone: 1, itemsTotal: 1);
  }

  void _takeDown(JobRequest request, RunReporter reporter) {
    final edits = TakedownEdits.read(dataPath, outputPath: outputPath, day: takedownDay(_now()));
    final modId = request.takedownModId?.trim();
    _refuseWithNothingChanged(() {
      if (modId != null && modId.isNotEmpty) {
        edits.takeDownMod(modId, log: reporter.log);
      } else {
        edits.takeDownAuthor(request.takedownAuthors, log: reporter.log);
      }
    });
    edits.write(dataPath);
    reporter.log('Saved ${TakedownList.fileName}.');
  }

  void _restore(JobRequest request, RunReporter reporter) {
    final key = request.takedownEntry?.trim() ?? '';
    final edits = TakedownEdits.read(dataPath, outputPath: outputPath, day: takedownDay(_now()));
    _refuseWithNothingChanged(() => edits.restore(key));
    edits.write(dataPath);
    reporter.log('Restored "$key". Saved ${TakedownList.fileName}.');
  }

  /// Runs [change], adding "Nothing was changed." to the reason it is refused.
  static void _refuseWithNothingChanged(void Function() change) {
    try {
      change();
    } on TakedownRefused catch (e) {
      throw StateError('${e.reason} Nothing was changed.');
    }
  }
}

/// Why a takedown change was refused, in a plain sentence.
class TakedownRefused implements Exception {
  final String reason;
  const TakedownRefused(this.reason);

  @override
  String toString() => reason;
}

/// Changes to `takedowns.json` and `takedowns-restored.json`, made in memory
/// and written only when asked. `takeDown`, `restoreTakedown` and
/// `saveCorrections` all change the list through this class, so they refuse
/// the same changes with the same messages.
///
/// A refused change throws [TakedownRefused] and leaves both lists as they
/// were.
class TakedownEdits {
  /// The lists as they were read.
  final TakedownList listBefore;
  final TakedownList restoredBefore;

  /// The lists with every change so far.
  TakedownList list;
  TakedownList restored;

  /// Holds `mod-catalog.json`, which a mod entry's posts are read from.
  final String outputPath;

  /// The day a new entry is marked with.
  final String day;

  ModCatalog? _catalog;
  bool _catalogRead = false;

  TakedownEdits({
    required this.listBefore,
    required this.restoredBefore,
    required this.outputPath,
    required this.day,
  })  : list = listBefore,
        restored = restoredBefore;

  /// Reads both lists from [dataPath]. Throws a [StateError] when either file
  /// exists but cannot be read.
  factory TakedownEdits.read(String dataPath, {required String outputPath, required String day}) =>
      TakedownEdits(
        listBefore: TakedownList.read(dataPath),
        restoredBefore: TakedownList.readFile(restoredFileIn(dataPath)),
        outputPath: outputPath,
        day: day,
      );

  static File restoredFileIn(String dataPath) => File(p.join(dataPath, TakedownList.restoredFileName));

  bool get listChanged => list != listBefore;
  bool get restoredChanged => restored != restoredBefore;

  ModCatalog? get _readCatalog {
    if (!_catalogRead) {
      _catalog = ModCatalog.read(File(p.join(outputPath, ModCatalog.fileName)));
      _catalogRead = true;
    }
    return _catalog;
  }

  /// Takes down the mod or Collection page [modId], with its posts from the
  /// current catalog.
  void takeDownMod(String modId, {void Function(String line)? log}) {
    final id = modId.trim();
    if (id.isEmpty) throw const TakedownRefused('A takedown needs a mod id or at least one author name.');
    if (list.modEntry(id) != null) throw TakedownRefused('"$id" is already taken down.');
    final catalog = _readCatalog;
    if (catalog == null) {
      throw TakedownRefused('There is no ${ModCatalog.fileName} to read "$id" from. Rebuild the outputs first.');
    }
    final found = takedownPostsFor(catalog, id);
    if (found == null) {
      throw TakedownRefused('No mod or Collection in ${ModCatalog.fileName} has the id "$id".');
    }
    final entry = ModTakedown(id: id, name: found.name, posts: found.posts, on: day);
    list = list.copyWith(mods: [...list.mods, entry]);
    _forgetRestores();
    log?.call('Taking down "${entry.name}" ($id), blocking '
        '${entry.posts.isEmpty ? 'only its Collection page' : entry.posts.join(', ')}.');
  }

  /// Takes down every mod credited to the person called [names]. Blank names
  /// are dropped.
  void takeDownAuthor(List<String> names, {void Function(String line)? log}) {
    final kept = [for (final name in names) if (name.trim().isNotEmpty) name.trim()];
    if (kept.isEmpty) throw const TakedownRefused('A takedown needs a mod id or at least one author name.');
    for (final name in kept) {
      final existing = list.authorEntryFor(name);
      if (existing != null) {
        throw TakedownRefused('"$name" is already taken down, as ${existing.names.join(', ')}.');
      }
    }
    list = list.copyWith(authors: [...list.authors, AuthorTakedown(names: kept, on: day)]);
    _forgetRestores();
    log?.call('Taking down every mod credited to ${kept.join(', ')}.');
  }

  /// Removes the entry [key] (a mod id, or `author:` and a first name) and
  /// records it as restored.
  void restore(String key, {void Function(String line)? log}) {
    final trimmed = key.trim();
    final entry = trimmed.isEmpty ? null : list.entryFor(trimmed);
    if (entry == null) throw TakedownRefused('There is no takedown entry "$trimmed" to restore.');
    restored = switch (entry) {
      final ModTakedown mod => restored.copyWith(mods: [...restored.mods, mod]),
      final AuthorTakedown author => restored.copyWith(authors: [...restored.authors, author]),
      _ => restored,
    };
    list = list.without(trimmed);
    log?.call('Restoring "$trimmed".');
  }

  /// Removes restore records for entries that have been taken down again.
  void _forgetRestores() {
    restored = restored.copyWith(
      mods: [for (final m in restored.mods) if (list.modEntry(m.id) == null) m],
      authors: [for (final a in restored.authors) if (!a.names.any((n) => list.authorEntryFor(n) != null)) a],
    );
  }

  /// Writes the lists that changed. Save the restore record first so publishing
  /// can explain why an entry was removed from the takedown list.
  void write(String dataPath) {
    if (restoredChanged) restored.writeFile(restoredFileIn(dataPath));
    if (listChanged) list.write(dataPath);
  }
}
