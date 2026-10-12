import 'version_compare.dart';

/// Reading and comparing the version strings mod authors actually write.
///
/// The same version turns up spelled several ways — "0.95", "v.0.95",
/// "Version 0.95" — and the extractor is not always right about it. So before
/// two versions are compared they are cleaned to one spelling, and anything that
/// does not read as a single version is thrown out rather than guessed at.
class VersionText {
  VersionText._();

  /// A word in front of the number that only ever means "version". Longest
  /// first, so "version" is not read as a "v" followed by "ersion".
  static final RegExp _leadingMarker = RegExp(
    r'^(?:version|update|ver\.?|rev\.?|v\.?)\s*',
    caseSensitive: false,
  );

  /// Spaces, dashes and underscores, all of which authors use where a dot
  /// belongs.
  static final RegExp _separators = RegExp(r'[\s\-_]+');

  /// What a cleaned version has to look like: a number, then any number of
  /// dot-separated parts of letters and numbers.
  static final RegExp _shape = RegExp(r'^\d+(?:\.[0-9a-z]+)*$');

  /// A dotted number, e.g. "1.2" or "0.9.5". Two of these in one string means
  /// the text holds more than one version.
  static final RegExp _dottedNumber = RegExp(r'\d+(?:\.\d+)+');

  /// One spelling of a version, or null when the text does not read as a single
  /// version.
  ///
  /// Lower-cased, with any leading "v", "ver", "version", "update" or "rev"
  /// taken off, and spaces, dashes and underscores turned into dots. Text that
  /// does not start with a number, or that holds two versions at once, comes
  /// back null — it is unreadable, and an unreadable reading is ignored rather
  /// than acted on.
  static String? clean(String? raw) {
    var text = raw?.trim().toLowerCase();
    if (text == null || text.isEmpty) return null;

    // "v.60, .54a" and "0.95 and 1.0" are two versions in one field. Neither is
    // an answer to "what version is this mod on?".
    if (_dottedNumber.allMatches(text).length > 1) return null;

    text = text.replaceFirst(_leadingMarker, '').trim();
    text = text
        .replaceAll(_separators, '.')
        .replaceAll(RegExp(r'\.+'), '.')
        .replaceAll(RegExp(r'^\.+|\.+$'), '');

    if (text.isEmpty || !_shape.hasMatch(text)) return null;
    return text;
  }

  /// Compares two cleaned versions. Negative when [a] is older, positive when it
  /// is newer, zero when they are the same version.
  ///
  /// TriOS's rules, through [compareVersionParts], so the site and the launcher
  /// agree about which version is newer: numbers are read as numbers, so 1.10
  /// is newer than 1.9; a letter on the end counts as newer, so 3.5.2g is newer
  /// than 3.5.2; an "rc", "alpha", "beta", "pre" or "dev" counts as older, so
  /// 1.0-rc1 is older than 1.0. Two versions whose parts all match are the
  /// same, so "1.0" and "1" compare as equal.
  static int compare(String a, String b) => compareVersionParts(a, b);

  /// True when [a] is a later version than [b].
  static bool isNewer(String a, String b) => compare(a, b) > 0;

  /// True when [candidate] is really the game's version rather than the mod's.
  ///
  /// The extractor mixes the two up often enough to matter: a thread titled
  /// "[0.98a] Some Mod" reporting its mod version as "0.98a" has told us
  /// nothing. Both the thread's own game version and the version in square
  /// brackets at the front of the title are checked.
  static bool isGameVersion(
    String? candidate, {
    String? threadGameVersion,
    String? threadTitle,
  }) {
    final cleaned = clean(candidate);
    if (cleaned == null) return false;

    final game = clean(threadGameVersion);
    if (game != null && compare(cleaned, game) == 0) return true;

    final bracketed = clean(gameVersionFromTitle(threadTitle));
    return bracketed != null && compare(cleaned, bracketed) == 0;
  }

  /// The version in square brackets at the front of a thread title, e.g.
  /// "[0.98a]". That is the game's version, never the mod's.
  static final RegExp _leadingBracket = RegExp(r'^\s*[\[(]\s*([^\]\)]+?)\s*[\]\)]');

  static String? gameVersionFromTitle(String? title) {
    if (title == null || title.trim().isEmpty) return null;
    return _leadingBracket.firstMatch(title)?.group(1);
  }

  /// A version written anywhere in a title, with a "v" in front of it or a dot
  /// in it — "Nexerelin v0.12.2", "BattleFarer Forever [v 0.3]". A lone number
  /// is not taken for one, because "Ship Pack 2" is a name.
  static final RegExp _versionInTitle = RegExp(
    r'(?:v|ver|version)\s*\.?\s*\d+(?:\.\d+)*[a-z]{0,2}|\d+(?:\.\d+)+[a-z]{0,2}',
    caseSensitive: false,
  );

  /// The mod version the thread title itself names, or null when it names none.
  ///
  /// The bracketed game version at the front is taken off first, so it is never
  /// read as the mod's. Where a title names several, the last one is used —
  /// authors put the current version at the end.
  ///
  /// Titles are the author's own words and are far steadier than the extractor,
  /// which is why a title can overrule it. But only some threads carry one, so
  /// it is only ever a veto, never a source.
  static String? versionFromTitle(String? title) {
    if (title == null || title.trim().isEmpty) return null;

    final rest = title.replaceFirst(_leadingBracket, '');
    final found = _versionInTitle.allMatches(rest).toList();
    if (found.isEmpty) return null;
    return clean(found.last.group(0));
  }
}
