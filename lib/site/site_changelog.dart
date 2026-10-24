import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The website's changelog, read from git: one entry for each commit that
/// changed the website.
///
/// The release workflow writes it to `site/changelog.json`, beside
/// `version.json`, and a publish copies it out with the rest of `site/`. A
/// released copy has no git checkout, so the file is read first and git is only
/// asked when it is not there.
class SiteChangelog {
  final String rootDir;

  const SiteChangelog(this.rootDir);

  static const changelogFile = ['site', 'changelog.json'];

  /// The folders whose changes a reader of the site can see: the pages
  /// themselves, and the code that builds the data they show.
  static const sitePaths = ['site', 'lib/site'];

  /// The commit message lines that are about who wrote the commit, not about
  /// what changed.
  static final _trailer = RegExp(r'^(Co-Authored-By|Signed-off-by):',
      caseSensitive: false);

  /// Returns null if neither the release file nor git gives a changelog.
  List<Map<String, Object?>>? read() => _fromFile() ?? fromGit();

  List<Map<String, Object?>>? _fromFile() {
    final file = File(p.join(rootDir, changelogFile[0], changelogFile[1]));
    if (!file.existsSync()) return null;
    try {
      final read = jsonDecode(file.readAsStringSync());
      if (read is! List) return null;
      return [
        for (final entry in read)
          if (entry is Map) Map<String, Object?>.from(entry)
      ];
    } on FormatException {
      return null;
    } on IOException {
      return null;
    }
  }

  /// Newest first. Each entry has the build number the release of that commit
  /// was given, the short commit, its day, a title and the rest of the message.
  List<Map<String, Object?>>? fromGit() {
    // The build number of a commit is how many commits there are up to and
    // including it, the same count the release workflow names releases by.
    final all = _git(['log', '--reverse', '--format=%H']);
    if (all == null) return null;
    final buildOf = <String, int>{};
    var count = 0;
    for (final sha in const LineSplitter().convert(all)) {
      if (sha.isEmpty) continue;
      buildOf[sha] = ++count;
    }

    final log = _git([
      'log',
      '--format=%H%x1f%h%x1f%cs%x1f%s%x1f%b%x1e',
      '--',
      ...sitePaths,
    ]);
    if (log == null) return null;

    final entries = <Map<String, Object?>>[];
    for (final record in log.split('\x1e')) {
      final fields = record.trim().split('\x1f');
      if (fields.length < 5) continue;
      final build = buildOf[fields[0]];
      if (build == null) continue;
      final body = const LineSplitter()
          .convert(fields[4])
          .where((line) => !_trailer.hasMatch(line.trim()))
          .join('\n')
          .trim();
      entries.add({
        'build': build,
        'commit': fields[1],
        'date': fields[2],
        'title': fields[3].trim(),
        if (body.isNotEmpty) 'body': body,
      });
    }
    return entries;
  }

  /// Writes the changelog from git to `site/changelog.json`. Returns how many
  /// entries it holds, or null when git could not be read.
  int? writeFromGit() {
    final entries = fromGit();
    if (entries == null) return null;
    final file = File(p.join(rootDir, changelogFile[0], changelogFile[1]));
    file.writeAsStringSync(jsonEncode(entries));
    return entries.length;
  }

  String? _git(List<String> args) {
    try {
      final result = Process.runSync('git', args,
          workingDirectory: rootDir, runInShell: true);
      if (result.exitCode != 0) return null;
      final answer = result.stdout as String;
      return answer.trim().isEmpty ? null : answer;
    } on ProcessException {
      return null;
    }
  }
}
