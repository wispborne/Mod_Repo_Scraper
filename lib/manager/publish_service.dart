import 'dart:io';

import 'package:path/path.dart' as p;

import 'cancel_token.dart';
import 'job.dart';
import 'run_reporter.dart';
import 'scraper_service.dart';
import 'scraper_settings.dart';

/// Publishing the current output files to GitHub as something you can call,
/// rather than a shell script you run.
///
/// The same split as the other pipelines: it is built once with its environment
/// (which repo, which clone folder, where the outputs are) and never reads the
/// config file. A request carries nothing about where to publish, so no caller
/// over the web API can point it at a different repo. Auth is the host user's own
/// git and SSH key — there is no token here.
///
/// It automates the tail of the twice-a-day cron script: make sure a clone is
/// present and current, copy the two output files in, commit only if something
/// changed, and push. History is kept plainly — it never force-pushes.
class PublishService implements JobRunner {
  final PublishEnvironment environment;

  /// The message every publish commit carries. Distinct from the cron script's
  /// wording, so a browser publish is easy to tell from an automatic one in the
  /// repo's log.
  final String commitMessage;

  /// The git program to run. Only tests change it.
  final String gitExecutable;

  const PublishService({
    required this.environment,
    this.commitMessage =
        'Published ModRepo.json & forum-data-bundle.json from the viewer.',
    this.gitExecutable = 'git',
  });

  /// The output files a publish copies across, in the order they are listed.
  static const List<String> outputFiles = [
    'ModRepo.json',
    'forum-data-bundle.json',
  ];

  @override
  Future<JobOutcome> runJob(
    JobRequest request, {
    RunReporter reporter = const SilentRunReporter(),
    CancelToken? cancel,
    String? runId,
  }) {
    if (request.kind != JobKind.publishOutputs) {
      throw ArgumentError(
          'The publish service cannot run ${request.kind.name}; it only '
          'publishes outputs.');
    }
    return _publish(reporter, cancel);
  }

  // ---------------------------------------------------------------------------

  Future<JobOutcome> _publish(RunReporter reporter, CancelToken? cancel) async {
    reporter.phase('Prepare clone');
    await _prepareClone(reporter);
    final branch = await _defaultBranch();
    reporter.log('Publishing to ${environment.repoUrl} (branch $branch).');

    reporter.phase('Copy outputs');
    _copyOutputs(reporter);
    await _git(['add', '-A'], reporter);

    if (!await _hasStagedChanges()) {
      reporter.log('Nothing changed, so nothing to publish.');
      return const JobOutcome();
    }

    // A publish stopped before the push pushes nothing and leaves the target
    // repo exactly as it was. Any local commit is discarded by the next run's
    // reset, so there is nothing to undo.
    if (cancel?.isCancelled ?? false) return _cancelled(reporter);

    reporter.phase('Commit and push');
    await _git([
      '-c', 'user.name=Mod Repo Scraper',
      '-c', 'user.email=scraper@localhost',
      '-c', 'commit.gpgsign=false',
      'commit', '-m', commitMessage,
    ], reporter);

    if (cancel?.isCancelled ?? false) return _cancelled(reporter);

    await _git(['push', 'origin', 'HEAD:$branch'], reporter);
    reporter.log('Published ${outputFiles.length} files to '
        '${environment.repoUrl}.');
    return JobOutcome(itemsDone: outputFiles.length, itemsTotal: outputFiles.length);
  }

  JobOutcome _cancelled(RunReporter reporter) {
    reporter.log('Publish cancelled before pushing. The target repo was left '
        'as it was.');
    return const JobOutcome(cancelled: true);
  }

  /// Makes sure the clone folder holds a current copy of the target repo. A
  /// missing (or broken) folder is cloned fresh; an existing one is fetched and
  /// hard-reset to the remote, so a divergent or dirty local copy never blocks a
  /// publish.
  Future<void> _prepareClone(RunReporter reporter) async {
    final dir = environment.cloneDir;
    final gitDir = Directory(p.join(dir, '.git'));

    if (!gitDir.existsSync()) {
      final existing = Directory(dir);
      if (existing.existsSync()) existing.deleteSync(recursive: true);
      final parent = existing.parent;
      if (!parent.existsSync()) parent.createSync(recursive: true);
      reporter.log('Cloning ${environment.repoUrl} into $dir...');
      await _git(['clone', environment.repoUrl, dir], reporter,
          workingDir: '.');
      return;
    }

    reporter.log('Refreshing the clone in $dir...');
    await _git(['fetch', 'origin', '--prune'], reporter);
    final branch = await _defaultBranch();
    await _git(['checkout', '-B', branch, 'origin/$branch'], reporter);
    await _git(['reset', '--hard', 'origin/$branch'], reporter);
    await _git(['clean', '-fd'], reporter);
  }

  /// The remote's default branch, read from `origin/HEAD` rather than assumed to
  /// be `main` or `master`. Falls back to whatever branch is checked out if the
  /// remote head is not set.
  Future<String> _defaultBranch() async {
    final head = await _run(['rev-parse', '--abbrev-ref', 'origin/HEAD']);
    if (head.exitCode == 0) {
      final name = (head.stdout as String).trim();
      if (name.startsWith('origin/')) return name.substring('origin/'.length);
      if (name.isNotEmpty) return name;
    }
    final current = await _run(['rev-parse', '--abbrev-ref', 'HEAD']);
    final name = (current.stdout as String).trim();
    return name.isEmpty ? 'main' : name;
  }

  void _copyOutputs(RunReporter reporter) {
    for (final name in outputFiles) {
      final source = File(p.join(environment.outputPath, name));
      if (!source.existsSync()) {
        throw StateError('Cannot publish: ${source.path} is not there. Run a '
            'scrape or merge first.');
      }
      source.copySync(p.join(environment.cloneDir, name));
      reporter.log('Copied $name into the clone.');
    }
  }

  /// True when `git add` staged something. `git diff --cached --quiet` exits 0
  /// when nothing is staged and 1 when something is; any other exit is an error.
  Future<bool> _hasStagedChanges() async {
    final result = await _run(['diff', '--cached', '--quiet']);
    if (result.exitCode == 0) return false;
    if (result.exitCode == 1) return true;
    throw StateError('git diff failed (exit ${result.exitCode}): '
        '${(result.stderr as String).trim()}');
  }

  /// Runs a git command that must succeed, logging it. Throws with the command's
  /// own error text when git returns non-zero, so the run is recorded as failed
  /// with a reason a person can read.
  Future<void> _git(List<String> args, RunReporter reporter,
      {String? workingDir}) async {
    reporter.log('git ${args.join(' ')}');
    final result = await _run(args, workingDir: workingDir);
    final err = (result.stderr as String).trim();
    if (result.exitCode != 0) {
      throw StateError('git ${args.join(' ')} failed (exit '
          '${result.exitCode}): ${err.isEmpty ? '(no output)' : err}');
    }
    if (err.isNotEmpty) reporter.log(err);
  }

  /// Runs a git command in the clone folder (unless [workingDir] says otherwise)
  /// and hands back the raw result, exit code and all.
  Future<ProcessResult> _run(List<String> args, {String? workingDir}) {
    return Process.run(
      gitExecutable,
      args,
      workingDirectory: workingDir ?? environment.cloneDir,
    );
  }
}
