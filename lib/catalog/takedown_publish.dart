import 'dart:io';

import 'package:path/path.dart' as p;

import '../bot/scraper/mod_repo_utils.dart';
import 'takedowns.dart';

/// Checks the takedown list against the published copy, then copies it into
/// the clone of the published repo at [cloneDir].
///
/// Losing `qb_data` and publishing again with no list would put every
/// taken-down mod back. So the list in the freshly fetched clone is read before
/// anything is changed, and the publish fails when one of its entries is
/// missing from the local list — unless a restore job removed it, which
/// `takedowns-restored.json` records. A missing local file counts as an empty
/// list: a new or replaced `qb_data` is exactly the case this is for.
///
/// When the check passes, the local list is written to the clone's root (an
/// empty one when there is no local file). Recorded restores whose entries
/// the fetched list already left out are cleared then, since a publish has
/// already sent them. One still in the fetched list stays recorded, so a push
/// that fails keeps it for the next try.
///
/// Throws a [StateError] naming the missing entries when the check fails. The
/// caller must then commit and push nothing.
///
/// Both ways of publishing call this: `PublishService` for a publish from the
/// viewer, and `mod_repo_scraper --publish-takedowns` for the cron script.
void publishTakedowns({
  required String dataPath,
  required String cloneDir,
  void Function(String message)? log,
}) {
  final publishedFile = File(p.join(cloneDir, TakedownList.fileName));
  final TakedownList published;
  try {
    published = TakedownList.readFile(publishedFile);
  } on StateError catch (e) {
    throw StateError('The published takedown list cannot be read, so it cannot be checked. Nothing was '
        'published. ${e.message}');
  }
  final local = TakedownList.read(dataPath);
  final restoredFile = File(p.join(dataPath, TakedownList.restoredFileName));
  final restored = TakedownList.readFile(restoredFile);

  final missing = <String>[
    for (final entry in published.mods)
      if (local.modEntry(entry.id) == null && restored.modEntry(entry.id) == null) entry.id,
    for (final entry in published.authors)
      if (!_hasPerson(local, entry) && !_hasPerson(restored, entry)) TakedownList.authorKey(entry),
  ];
  if (missing.isNotEmpty) {
    throw StateError('The published takedown list has ${missing.length} entr${missing.length == 1 ? 'y' : 'ies'} '
        'the local list in $dataPath does not: ${missing.join(', ')}. No restore removed '
        '${missing.length == 1 ? 'it' : 'them'}, so publishing would put those mods back. Nothing was published. '
        'Put the takedown list back from the published copy, or restore each entry from the viewer.');
  }

  // Restores the published list no longer has are done with.
  final stillPending = TakedownList(
    mods: [for (final entry in restored.mods) if (published.modEntry(entry.id) != null) entry],
    authors: [for (final entry in restored.authors) if (_hasPerson(published, entry)) entry],
  );
  if (stillPending != restored) {
    if (stillPending.isEmpty) {
      if (restoredFile.existsSync()) restoredFile.deleteSync();
    } else {
      stillPending.writeFile(restoredFile);
    }
  }

  local.writeFile(publishedFile);
  log?.call('Copied the takedown list into the clone (${local.mods.length} mod and ${local.authors.length} author '
      'entries).');
}

bool _hasPerson(TakedownList list, AuthorTakedown entry) => list.authors.any(
    (other) => other.names.any((name) => entry.names.any((mine) => ModRepoUtils.samePerson(name, mine))));
