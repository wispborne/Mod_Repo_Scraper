import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Which build of the code is running: a number that goes up by one with every
/// commit, the commit itself, and the day it was made.
///
/// There are two ways to find that out and they are tried in that order.
///
/// The release workflow writes the three values into `site/version.json` when
/// it builds, and that folder ships beside the server, so on a machine running
/// a release the file is simply there. This is the one that matters: a released
/// copy is unpacked from a tarball, not cloned, so there is no git checkout to
/// ask and asking one was why this line used to be blank in production.
///
/// Failing that — working in the repo, where the file is only ever made by a
/// build — git is asked the same three questions directly, so a version shows
/// while developing too.
///
/// Where neither works, this says so quietly and the page shows no version line
/// at all. Nothing here is ever worth an error on screen.
class SiteVersion {
  /// The folder to look in — the one the server was started from.
  final String rootDir;

  const SiteVersion(this.rootDir);

  /// Where a build leaves its version. It is written for the public website,
  /// which reads it from its own folder, but it names the build of the whole
  /// repository, so this reads the same file rather than keeping a second copy
  /// of the same three values somewhere else.
  static const versionFile = ['site', 'version.json'];

  /// The build number, the commit and the day it was made. Null when there is
  /// nothing to report.
  Map<String, Object?>? read() => _fromFile() ?? _fromGit();

  /// Reads what the build wrote. Anything unexpected in the file — missing,
  /// half-written, not the shape it should be — is treated as no answer, and
  /// git is asked instead.
  Map<String, Object?>? _fromFile() {
    final file = File(p.join(rootDir, versionFile[0], versionFile[1]));
    if (!file.existsSync()) return null;

    try {
      final read = jsonDecode(file.readAsStringSync());
      if (read is! Map) return null;
      final build = read['build'];
      final commit = read['commit'];
      if (build is! int || commit is! String || commit.isEmpty) return null;
      return {'build': build, 'commit': commit, 'date': read['date']};
    } on FormatException {
      return null;
    } on IOException {
      return null;
    }
  }

  /// Asks git the same three questions the build asks it, so the version line
  /// is not blank while working in the repo.
  Map<String, Object?>? _fromGit() {
    final build = int.tryParse(_git(['rev-list', '--count', 'HEAD']) ?? '');
    final commit = _git(['rev-parse', '--short', 'HEAD']);
    if (build == null || commit == null) return null;
    return {
      'build': build,
      'commit': commit,
      'date': _git(['log', '-1', '--format=%cs'])
    };
  }

  String? _git(List<String> args) {
    try {
      final result = Process.runSync('git', args, workingDirectory: rootDir, runInShell: true);
      if (result.exitCode != 0) return null;

      final answer = (result.stdout as String).trim();
      return answer.isEmpty ? null : answer;
    } on ProcessException {
      // No git on this machine. Not a problem worth reporting.
      return null;
    }
  }
}
