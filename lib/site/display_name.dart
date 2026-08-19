import 'mod_id_store.dart';

/// The name a reader sees, built from the mod's name as the thread wrote it.
///
/// A thread title is not a name. It carries the game version in brackets at the
/// front, the mod version, sometimes a date, sometimes a "WIP" tag, and often a
/// leading dash to push it up the board's own list. All of that is taken off
/// here. Browse sorts by name, so leaving it in would put every dash and
/// bracket on page one.
///
/// The raw title is still published on the mod's own page, so nothing is lost.

/// Leading punctuation: dashes, dots, colons, commas, stars and spaces.
final RegExp _leadingJunk = RegExp(r'^[\s\-–—:,.*_|~]+');

/// A bracketed part at the front, e.g. "[0.98a]" or "(WIP)".
final RegExp _leadingBracket = RegExp(r'^\s*[\[(][^\]\)]*[\]\)]');

/// An "updated" tail, in the spellings threads use: "(Updated 2026-01-05)",
/// "- Updated: 5 January 2026", ", updated!".
final RegExp _updatedTail = RegExp(
  r'[\s,\-–—\(\[]+updated\b[^\]\)]*[\)\]]?\s*$',
  caseSensitive: false,
);

/// A "work in progress" tag on the end, bracketed or not.
final RegExp _wipTail = RegExp(
  r'[\s,\-–—]*[\[(]?\s*(?:wip|work in progress)\s*[\)\]]?\s*$',
  caseSensitive: false,
);

/// A lone "v" or "ver" left dangling once the number after it came off, as in
/// "Mimikko Assistant v (0.96/0.97)".
final RegExp _danglingVersionWord = RegExp(
  r'[\s,\-–—]*\b(?:v|ver|version|rev)\.?\s*$',
  caseSensitive: false,
);

/// Punctuation left dangling once something was taken off the end.
final RegExp _trailingJunk = RegExp(r'[\s\-–—:,;.*_|~]+$');

final RegExp _spaces = RegExp(r'\s+');

/// [modName] with everything that is not the name taken off. When that would
/// leave nothing, the name is handed back exactly as it was written — an empty
/// card title helps nobody.
String displayName(String modName) {
  var name = modName;

  // A dash can sit either side of the bracketed version, so keep taking both
  // off until neither comes off.
  for (var pass = 0; pass < 6; pass++) {
    final before = name;
    name = name.replaceFirst(_leadingJunk, '');
    name = name.replaceFirst(_leadingBracket, '');
    if (name == before) break;
  }

  // The version, date and bracket stripping the id already does, with the
  // author's own capitals left alone.
  name = ModIdStore.stripReleaseParts(name);

  for (var pass = 0; pass < 4; pass++) {
    final before = name;
    name = name.replaceFirst(_updatedTail, '');
    name = name.replaceFirst(_wipTail, '');
    name = _withoutUnclosedBracket(name);
    name = name.replaceFirst(_danglingVersionWord, '');
    name = name.replaceFirst(_trailingJunk, '');
    if (name == before) break;
  }

  name = name.replaceAll(_spaces, ' ').trim();
  return name.isEmpty ? modName : name;
}

/// A bracket that was opened and never closed, and everything after it.
///
/// Taking a version off the end can cut a bracketed part in half — "Mimikko
/// Assistant v (0.96/0.97)" lost its closing bracket and came back as "Mimikko
/// Assistant v (0". Whatever is left inside a half-open bracket was part of
/// what was being taken off, so it goes too.
String _withoutUnclosedBracket(String name) {
  var depth = 0;
  var openedAt = -1;
  for (var i = 0; i < name.length; i++) {
    final char = name[i];
    if (char == '(' || char == '[') {
      if (depth == 0) openedAt = i;
      depth++;
    } else if (char == ')' || char == ']') {
      if (depth > 0) depth--;
      if (depth == 0) openedAt = -1;
    }
  }
  return depth > 0 && openedAt >= 0 ? name.substring(0, openedAt).trim() : name;
}
