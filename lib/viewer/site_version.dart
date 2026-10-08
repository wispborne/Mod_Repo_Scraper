import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Reads the build number, commit and commit date for the viewer footer.
///
/// Releases have `site/version.json` but no git checkout. In a development
/// checkout, git supplies the values if that file is unavailable or invalid.
/// If both fail, the footer omits the version.
class SiteVersion {
  final String rootDir;

  const SiteVersion(this.rootDir);

  /// Shared with the public website; both report the repository's build.
  static const versionFile = ['site', 'version.json'];

  /// Returns null if neither the release file nor git provides a version.
  Map<String, Object?>? read() => _fromFile() ?? _fromGit();

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
      final result = Process.runSync('git', args,
          workingDirectory: rootDir, runInShell: true);
      if (result.exitCode != 0) return null;

      final answer = (result.stdout as String).trim();
      return answer.isEmpty ? null : answer;
    } on ProcessException {
      // Git is optional in released copies.
      return null;
    }
  }
}
