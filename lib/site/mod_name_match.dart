/// Telling whether two written mod names mean the same mod.
///
/// This is **not** how ids are worked out. [ModIdStore.cleanName] is the id's
/// name and can never change, because the id file is keyed on it and a mod's
/// web address is built from it — so it is deliberately cautious and leaves a
/// version like "1.0.a" in place. That caution is wrong for matching: the merge
/// calls a mod "Useful.Tithes 1.0.a" and the LLM calls the same mod
/// "Useful.Tithes", and reading those as two mods would publish a second page
/// for one that already has one, with a permanent id nobody can take back.
///
/// So matching gets its own, keener cleaner. It is only ever used to compare
/// two names, never to name anything, so it can afford to take off more.
///
/// TriOS draws the same line: `cleanModDisplayName` and `modNamesMatch` in
/// `lib/catalog/catalog_download_resolver.dart` are separate from the slug its
/// records are filed under, and this is that pair of steps — cleaned names
/// first, then letters and numbers only — with one addition TriOS does not
/// need. TriOS only strips a version off the *end* of a name; the forum writes
/// "Disco.Balls 1.1.c - More Lamp Colour Options", with the version in the
/// middle and a subtitle behind it, so the name is cut at the version instead
/// of having it trimmed off the end.
library;

/// A name's front part: what is left after the bracketed game version at the
/// front, everything from the first version onwards, and the odds and ends a
/// thread title carries. Lower case, single spaces.
///
/// "[0.98a] Disco.Balls 1.1.c - More Lamp Colour Options" comes back as
/// "disco.balls".
String matchableName(String name) {
  var result = name.trim();

  // "[0.98a]", "[0.98a][WIP]" — as many as are stacked up at the front.
  result = result.replaceFirst(_leadingBrackets, '').trim();

  // Everything from the first version onwards. A thread title reads
  // "<name> <version> - <what it does>", so the name is what comes before the
  // version, and the subtitle behind it is no part of the name.
  final version = _versionToken.firstMatch(result);
  if (version != null) result = result.substring(0, version.start).trim();

  // What a cut can leave hanging, and the "Mod" some titles end with.
  for (var pass = 0; pass < 3; pass++) {
    final before = result;
    result = result.replaceFirst(_trailingBracketed, '').trim();
    result = result.replaceFirst(_trailingMod, '').trim();
    result = result.replaceFirst(_trailingPunctuation, '').trim();
    if (result == before) break;
  }

  result = result.replaceAll(_spaces, ' ').trim().toLowerCase();

  // A name that was nothing but decoration tells us nothing, and an empty
  // string would match every other empty one. Fall back to the name as given.
  return result.isEmpty ? name.trim().toLowerCase() : result;
}

/// True when two written names mean the same mod.
///
/// Both sides are scraped from what somebody typed on a forum, so neither is
/// good enough for a plain comparison. The cleaned names are compared first,
/// then the same names with everything but letters and numbers taken out, which
/// is what lets "Useful.Tithes" and "Useful Tithes" agree.
bool modNamesMatch(String a, String b) {
  final cleanA = matchableName(a);
  final cleanB = matchableName(b);
  if (cleanA.isEmpty || cleanB.isEmpty) return false;
  if (cleanA == cleanB) return true;

  final looseA = _lettersAndNumbers(cleanA);
  final looseB = _lettersAndNumbers(cleanB);
  return looseA.isNotEmpty && looseA == looseB;
}

String _lettersAndNumbers(String value) =>
    value.toLowerCase().replaceAll(_notLetterOrNumber, '');

/// One or more bracketed groups at the front: "[0.98a]", "[0.98a][WIP]", "(WIP)".
final RegExp _leadingBrackets = RegExp(r'^(?:\s*[\[(][^\])]*[\])])+');

/// Where a version starts, wherever it sits in the name.
///
/// It counts as a version when it is a "v" and digits ("v1.2", "ver 3"), or
/// digits with a dot in them ("1.0.a", "0.98a-RC8"). A lone number is not a
/// version: plenty of mods really are called "Ship Pack 2", and cutting there
/// would leave "Ship Pack". An opening bracket may come first, which is what
/// handles "Red - the Oculian Armada (0.10.2-RC4)".
final RegExp _versionToken = RegExp(
  r'[\s\-–—]+[\[(]?'
  r'(?:(?:v|v\.|ver|ver\.|version|rev|update)\s*\d'
  r'|\d+(?:\.\d+)+[a-z]{0,2}'
  r'|\d+\.\d)',
  caseSensitive: false,
);

/// A bracketed group left on the end.
final RegExp _trailingBracketed = RegExp(r'\s*[\[(][^\])]*[\])]$');

/// A bare "Mod" or "Mods" on the end, which says nothing about which mod.
final RegExp _trailingMod = RegExp(r'\s+mods?$', caseSensitive: false);

/// A dash, comma or colon left hanging by a cut.
final RegExp _trailingPunctuation = RegExp(r'[\s\-–—,:;]+$');

final RegExp _spaces = RegExp(r'\s+');

final RegExp _notLetterOrNumber = RegExp(r'[^a-z0-9]+');
