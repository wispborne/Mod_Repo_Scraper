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
        'Published the outputs and the website from the viewer.',
    this.gitExecutable = 'git',
  });

  /// The output files a publish copies across, in the order they are listed.
  /// These two must always be there — a publish with nothing to publish is an
  /// error, not a quiet no-op.
  static const List<String> outputFiles = [
    'ModRepo.json',
    'forum-data-bundle.json',
  ];

  /// The public website's data files, copied from `<outputs>/site/` when a run
  /// has built them. Per-mod files come across as well, from `site/mods/`.
  static const List<String> websiteFiles = [
    'mods.json',
    'updates.json',
    'updates.xml',
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
    _copyWebsiteData(reporter);
    _copyWebsiteFiles(reporter);
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
    reporter.log('Published to ${environment.repoUrl}.');
    return JobOutcome(
        itemsDone: outputFiles.length, itemsTotal: outputFiles.length);
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

  /// Copies the public website's data files in: the mod list, the release feed
  /// and one file per mod. A mod that this run no longer produces has its file
  /// removed, so a mod that has gone does not linger on the site.
  ///
  /// These are built at the end of a run. When they are not there — a fresh
  /// setup, or a run that only merged — the publish carries on with the outputs
  /// it does have and says so.
  void _copyWebsiteData(RunReporter reporter) {
    final from = Directory(p.join(environment.outputPath, 'site'));
    if (!from.existsSync()) {
      reporter.log('The website files were not there (${from.path}), so only '
          'the outputs above were published.');
      return;
    }

    var copied = 0;
    for (final name in websiteFiles) {
      final source = File(p.join(from.path, name));
      if (!source.existsSync()) continue;
      source.copySync(p.join(environment.cloneDir, name));
      copied++;
    }

    final modsFrom = Directory(p.join(from.path, 'mods'));
    final modsTo = Directory(p.join(environment.cloneDir, 'mods'));
    final published = <String>{};
    final pagesPublished = <String>{};
    if (modsFrom.existsSync()) {
      if (!modsTo.existsSync()) modsTo.createSync(recursive: true);
      for (final fileOrFolder in modsFrom.listSync()) {
        final name = p.basename(fileOrFolder.path);
        if (fileOrFolder is File) {
          if (!name.endsWith('.json')) continue;
          fileOrFolder.copySync(p.join(modsTo.path, name));
          published.add(name);
          copied++;
        } else if (fileOrFolder is Directory) {
          // One mod's own little page, so a link shared in Discord shows that
          // mod rather than the site's front page.
          final page = File(p.join(fileOrFolder.path, 'index.html'));
          if (!page.existsSync()) continue;
          final into = Directory(p.join(modsTo.path, name));
          if (!into.existsSync()) into.createSync(recursive: true);
          page.copySync(p.join(into.path, 'index.html'));
          pagesPublished.add(name);
          copied++;
        }
      }
    }

    final dropped = _dropMissingModFiles(modsTo, published)
        + _dropMissingModPages(modsTo, pagesPublished);
    reporter.log('Copied $copied website files into the clone'
        '${dropped == 0 ? '' : ', and removed $dropped for mods that are gone'}.');
  }

  /// Deletes any per-mod page in the clone that this run did not produce.
  ///
  /// The same rules as [_dropMissingModFiles], and for the same reason: these
  /// two are the only places here that delete anything, and both work from
  /// names read off a disk. Only a folder sitting directly in the clone's
  /// `mods/` folder goes, and only when this run published some pages of its
  /// own — an empty set means the pages were not built this time, not that
  /// every mod has gone.
  int _dropMissingModPages(Directory modsInClone, Set<String> published) {
    if (!modsInClone.existsSync() || published.isEmpty) return 0;

    var dropped = 0;
    for (final folder in modsInClone.listSync().whereType<Directory>()) {
      final name = p.basename(folder.path);
      if (published.contains(name)) continue;
      if (!p.equals(p.dirname(folder.path), modsInClone.path)) continue;
      folder.deleteSync(recursive: true);
      dropped++;
    }
    return dropped;
  }

  /// Deletes any per-mod file in the clone that this run did not produce.
  ///
  /// Only `.json` files sitting directly in the clone's `mods/` folder are ever
  /// touched, in the same way the snapshot stores guard their own folders — the
  /// names come off disk, and this and [_dropMissingModPages] are the only
  /// places here that delete anything.
  int _dropMissingModFiles(Directory modsInClone, Set<String> published) {
    if (!modsInClone.existsSync() || published.isEmpty) return 0;

    var dropped = 0;
    for (final file in modsInClone.listSync().whereType<File>()) {
      final name = p.basename(file.path);
      if (!name.endsWith('.json') || published.contains(name)) continue;
      if (!p.equals(p.dirname(file.path), modsInClone.path)) continue;
      file.deleteSync();
      dropped++;
    }
    return dropped;
  }

  /// Copies the website's own files — its HTML, stylesheet and scripts — into
  /// the clone, so the pushed repo can be handed to any static host as it is.
  void _copyWebsiteFiles(RunReporter reporter) {
    final from = Directory(environment.sitePath);
    if (!from.existsSync()) {
      reporter.log('The website itself was not at ${from.path}, so only the '
          'data was published.');
      return;
    }

    final copied = _copyFolder(from, Directory(environment.cloneDir));
    reporter.log('Copied $copied of the website\'s own files into the clone.');
  }

  /// Copies a folder's contents into another, making folders as it goes. Skips
  /// anything starting with a dot, so a stray `.git` or editor folder never
  /// lands in the published repo.
  int _copyFolder(Directory from, Directory to) {
    if (!to.existsSync()) to.createSync(recursive: true);
    var copied = 0;
    for (final entry in from.listSync()) {
      final name = p.basename(entry.path);
      if (name.startsWith('.')) continue;
      if (entry is File) {
        entry.copySync(p.join(to.path, name));
        copied++;
      } else if (entry is Directory) {
        copied += _copyFolder(entry, Directory(p.join(to.path, name)));
      }
    }
    return copied;
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
