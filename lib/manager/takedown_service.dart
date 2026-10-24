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

  File get _restoredFile => File(p.join(dataPath, TakedownList.restoredFileName));

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
    final list = TakedownList.read(dataPath);
    final day = takedownDay(_now());
    final modId = request.takedownModId?.trim();
    final names = [for (final name in request.takedownAuthors) if (name.trim().isNotEmpty) name.trim()];

    final TakedownList updated;
    if (modId != null && modId.isNotEmpty) {
      if (list.modEntry(modId) != null) {
        throw StateError('"$modId" is already taken down. Nothing was changed.');
      }
      final catalog = ModCatalog.read(File(p.join(outputPath, ModCatalog.fileName)));
      if (catalog == null) {
        throw StateError('There is no ${ModCatalog.fileName} to read "$modId" from. Rebuild the outputs first. '
            'Nothing was changed.');
      }
      final found = takedownPostsFor(catalog, modId);
      if (found == null) {
        throw StateError('No mod or Collection in ${ModCatalog.fileName} has the id "$modId". Nothing was changed.');
      }
      final entry = ModTakedown(id: modId, name: found.name, posts: found.posts, on: day);
      updated = list.copyWith(mods: [...list.mods, entry]);
      reporter.log('Taking down "${entry.name}" ($modId), blocking '
          '${entry.posts.isEmpty ? 'only its Collection page' : entry.posts.join(', ')}.');
    } else if (names.isNotEmpty) {
      for (final name in names) {
        final existing = list.authorEntryFor(name);
        if (existing != null) {
          throw StateError('"$name" is already taken down, as ${existing.names.join(', ')}. Nothing was changed.');
        }
      }
      updated = list.copyWith(authors: [...list.authors, AuthorTakedown(names: names, on: day)]);
      reporter.log('Taking down every mod credited to ${names.join(', ')}.');
    } else {
      throw StateError('A takedown needs a mod id or at least one author name. Nothing was changed.');
    }

    updated.write(dataPath);
    // Taken down again after a restore: the restore no longer explains
    // anything, so it is forgotten.
    final restored = TakedownList.readFile(_restoredFile);
    final stillRestored = restored.copyWith(
      mods: [for (final m in restored.mods) if (updated.modEntry(m.id) == null) m],
      authors: [for (final a in restored.authors) if (!a.names.any((n) => updated.authorEntryFor(n) != null)) a],
    );
    if (stillRestored != restored) stillRestored.writeFile(_restoredFile);
    reporter.log('Saved ${TakedownList.fileName}.');
  }

  void _restore(JobRequest request, RunReporter reporter) {
    final key = request.takedownEntry?.trim() ?? '';
    final list = TakedownList.read(dataPath);
    final entry = key.isEmpty ? null : list.entryFor(key);
    if (entry == null) {
      throw StateError('There is no takedown entry "$key" to restore. Nothing was changed.');
    }

    // Recorded first, so a publish never sees the entry gone without knowing
    // a restore took it.
    final restored = TakedownList.readFile(_restoredFile);
    final record = switch (entry) {
      final ModTakedown mod => restored.copyWith(mods: [...restored.mods, mod]),
      final AuthorTakedown author => restored.copyWith(authors: [...restored.authors, author]),
      _ => restored,
    };
    record.writeFile(_restoredFile);

    list.without(key).write(dataPath);
    reporter.log('Restored "$key". Saved ${TakedownList.fileName}.');
  }
}
