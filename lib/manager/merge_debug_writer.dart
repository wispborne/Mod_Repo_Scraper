import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../bot/scraper/debug/merge_debug_data.dart';
import 'merge_snapshot_store.dart';

/// Saves the data behind the Merge view and Catalog diff: `merge-debug.json`,
/// plus one snapshot per run so an older merge can still be looked at after the
/// next one lands.
///
/// Both pipelines build the catalog, so both use this. The files go to the same
/// places whichever one wrote them.
class MergeDebugWriter {
  /// The folder `merge-debug.json` is written to.
  final String workingPath;

  final MergeSnapshotStore snapshots;

  const MergeDebugWriter({required this.workingPath, required this.snapshots});

  Future<void> save(
    MergeDebugData data,
    String? runId,
    void Function(String message) log,
  ) async {
    MergeDebugDataMapper.ensureInitialized();
    final file = File(p.join(workingPath, 'merge-debug.json'));
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data.toMap()));
    log('Merge debug data written to ${file.path}.');

    if (runId == null) return;
    try {
      final saved = await snapshots.save(runId, data);
      log('Saved this merge as ${p.basename(saved.path)}, so it can be '
          'compared with the next one.');
    } catch (e) {
      // A snapshot is a nice-to-have. Losing it must not fail a good merge.
      log('Could not save the merge snapshot: $e');
    }
  }
}
