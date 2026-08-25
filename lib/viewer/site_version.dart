import 'dart:io';

/// Which version of the code the viewer is running, taken from the newest git
/// tag in the checkout it was started from.
///
/// The release workflow tags every build `v<number of commits>`, so the tag is
/// the only place the number lives — there is nothing to keep in step and
/// nothing to write down. Where the checkout is not a git repository, or git
/// is not installed, or nothing has been tagged yet, this says so quietly and
/// the site shows no version line at all. Nothing here is ever worth an error
/// on screen.
class SiteVersion {
  /// The folder to ask git about — the checkout the server was started in.
  final String rootDir;

  const SiteVersion(this.rootDir);

  /// The newest tag, how many commits have landed since, and the full answer
  /// git gave. Null when there is no tag to report.
  Map<String, Object?>? read() {
    final described = _describe();
    return described == null ? null : parseDescribed(described);
  }

  /// Reads git's answer apart. "3.4.2-3-g4150078" is the tag, the number of
  /// commits since it, and the commit itself.
  ///
  /// A tag can have dashes of its own ("1.0-beta-2-gabc1234"), so the last two
  /// pieces are taken off the end rather than the tag being read from the
  /// front. Anything that does not have that shape is passed on whole as the
  /// tag, since showing git's own words beats showing nothing.
  static Map<String, Object?> parseDescribed(String described) {
    final pieces = described.split('-');
    final commitsSince = pieces.length < 3 ? null : int.tryParse(pieces[pieces.length - 2]);

    return {
      'tag': commitsSince == null ? described : pieces.sublist(0, pieces.length - 2).join('-'),
      'commitsSince': commitsSince ?? 0,
      'described': described,
    };
  }

  String? _describe() {
    try {
      final result = Process.runSync(
        'git',
        // --long always spells out the commit count, even sitting exactly on a
        // tag, so there is only ever one shape to read.
        ['describe', '--tags', '--long'],
        workingDirectory: rootDir,
        runInShell: true,
      );
      if (result.exitCode != 0) return null;

      final described = (result.stdout as String).trim();
      return described.isEmpty ? null : described;
    } on ProcessException {
      // No git on this machine. Not a problem worth reporting.
      return null;
    }
  }
}
