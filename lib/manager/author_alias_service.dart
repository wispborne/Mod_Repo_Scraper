import '../bot/scraper/author_aliases.dart';
import '../bot/scraper/mod_repo_utils.dart';
import 'cancel_token.dart';
import 'job.dart';
import 'run_reporter.dart';
import 'scraper_service.dart';

/// The first step of a `setAuthorAliases` job: saving `author-aliases.json`.
/// `JobRouter` runs the rebuild after it.
///
/// A list it cannot save is refused with a reason, and the file is left as it
/// was.
class AuthorAliasService implements JobRunner {
  /// Holds `author-aliases.json`.
  final String dataPath;

  const AuthorAliasService({required this.dataPath});

  @override
  Future<JobOutcome> runJob(
    JobRequest request, {
    RunReporter reporter = const SilentRunReporter(),
    CancelToken? cancel,
    String? runId,
  }) async {
    if (request.kind != JobKind.setAuthorAliases) {
      throw ArgumentError('The author alias service cannot run ${request.kind.name}.');
    }
    reporter.phase('Author aliases');
    final checked = checkAliasRows(request.authorAliasPeople, request.authorAliasNotSame);
    final before = AuthorAliasFile.read(dataPath).rowsToUse();

    final updated = AuthorAliasFile(people: checked.people, notSame: checked.notSame, saved: true);
    updated.write(dataPath);
    ModRepoUtils.useAuthorAliases(updated.rowsToUse());

    for (final line in describeAliasChanges(before, checked.people)) {
      reporter.log(line);
    }
    reporter.log('Saved ${checked.people.length} people and ${checked.notSame.length} '
        '"different people" pairs to ${AuthorAliasFile.fileName}.');
    return const JobOutcome(itemsDone: 1, itemsTotal: 1);
  }
}

/// One line per person whose names changed between [before] and [after], for
/// the run's log.
List<String> describeAliasChanges(List<List<String>> before, List<List<String>> after) {
  String key(List<String> row) => row.map((n) => n.toLowerCase()).join('\n');
  final beforeKeys = {for (final row in before) key(row)};
  final afterKeys = {for (final row in after) key(row)};
  return [
    for (final row in before)
      if (!afterKeys.contains(key(row))) 'Was: ${row.join(', ')}',
    for (final row in after)
      if (!beforeKeys.contains(key(row))) 'Now: ${row.join(', ')}',
  ];
}
