import 'dart:math';

/// Which of two versions is newer, by TriOS's rules.
///
/// A copy of `Version.compareVersions` in TriOS (`lib/models/version.dart`),
/// so the site's builder, the site's pages (`site/version.js`) and the launcher
/// all put versions in the same order. Keep the three in step: a fix in TriOS
/// belongs in both copies here. The logging and the small caches TriOS keeps
/// are left out; the comparison itself is unchanged.
///
/// Negative when [a] is older than [b], positive when it is newer, zero when
/// they are the same. Numbers are read as numbers, so 1.10 is newer than 1.9; a
/// number beats a letter in the same place; "dev", "prerelease", "preview",
/// "pre", "alpha", "beta" and "rc" are older than no marker at all.
int compareVersions(String a, String b) {
  if (a == b) return 0;

  final byParts = compareVersionParts(a, b);
  if (byParts != 0) return byParts;

  // Every part matched. TriOS still puts the two in a fixed order, so a sort
  // always comes out the same: the one written with more parts, then the
  // spellings as text.
  final lengthCompared = _tokenize(a).length.compareTo(_tokenize(b).length);
  if (lengthCompared != 0) return lengthCompared > 0 ? 1 : -1;

  final rawCompared = a.compareTo(b);
  if (rawCompared != 0) return rawCompared > 0 ? 1 : -1;
  return 0;
}

/// [compareVersions] without its last tiebreak: zero whenever every part
/// matches, so "1.0" and "1" are the same version here. Use it to ask whether
/// two versions are the same; use [compareVersions] to sort.
int compareVersionParts(String a, String b) {
  if (a == b) return 0;

  final (aParts, bParts) = _lineUp(
    a.replaceAll(_separators, '.'),
    b.replaceAll(_separators, '.'),
  );

  for (var i = 0; i < max(aParts.length, bParts.length); i++) {
    final aPart = i < aParts.length ? aParts[i] : '';
    final bPart = i < bParts.length ? bParts[i] : '';

    final aIsNumber = int.tryParse(aPart) != null;
    final bIsNumber = int.tryParse(bPart) != null;

    if (aIsNumber && bIsNumber) {
      final aNum = int.parse(aPart);
      final bNum = int.parse(bPart);
      if (aNum != bNum) return aNum > bNum ? 1 : -1;
    } else if (aIsNumber && !bIsNumber) {
      return 1;
    } else if (!aIsNumber && bIsNumber) {
      return -1;
    } else {
      final ai = _suffixRank[aPart.toLowerCase()];
      final bi = _suffixRank[bPart.toLowerCase()];
      if (ai != null && bi != null) {
        if (ai != bi) return ai > bi ? 1 : -1;
      } else if (ai != null) {
        return -1;
      } else if (bi != null) {
        return 1;
      }

      if (aPart != bPart) return aPart.compareTo(bPart) > 0 ? 1 : -1;
    }
  }
  return 0;
}

final RegExp _grouping = RegExp(r'(\d+|[a-zA-Z]+|[-\.]+)');
final RegExp _separators = RegExp(r'[\s\-–_]+');
final RegExp _letter = RegExp(r'[a-zA-Z]');

/// Words that mean "not finished yet", earliest first.
const List<String> _suffixOrder = [
  'dev',
  'prerelease',
  'preview',
  'pre',
  'alpha',
  'beta',
  'rc',
];

final Map<String, int> _suffixRank = {
  for (var i = 0; i < _suffixOrder.length; i++) _suffixOrder[i]: i,
};

List<String> _tokenize(String s) =>
    _grouping.allMatches(s).map((m) => m.group(0)!).toList();

/// Lines the two versions' parts up so they can be compared one by one,
/// filling a gap on one side the way TriOS does.
(List<String>, List<String>) _lineUp(String a, String b) {
  final aParts = _tokenize(a);
  final bParts = _tokenize(b);
  final aResult = <String>[];
  final bResult = <String>[];

  for (var i = 0; i < max(aParts.length, bParts.length); i++) {
    var aPart = i < aParts.length ? aParts[i] : '';
    var bPart = i < bParts.length ? bParts[i] : '';

    final aIsNumber = int.tryParse(aPart) != null;
    final bIsNumber = int.tryParse(bPart) != null;
    final aIsLetter = aPart.contains(_letter);
    final bIsLetter = bPart.contains(_letter);

    // A letter against a number: "1.9.g" against "1.9.0" reads the letter as
    // coming after a zero.
    if (aIsLetter && bIsNumber) {
      aResult.add('0');
    } else if (bIsLetter && aIsNumber) {
      bResult.add('0');
    } else if (aPart.isEmpty && bIsNumber) {
      aPart = '0';
    } else if (bPart.isEmpty && aIsNumber) {
      bPart = '0';
    } else if (aPart.isEmpty && bPart == '.') {
      aPart = '.';
    } else if (bPart.isEmpty && aPart == '.') {
      bPart = '.';
    } else if (aPart.isEmpty && bIsLetter) {
      // A letter against nothing is left as it is.
    } else if (bPart.isEmpty && aIsLetter) {
      // A letter against nothing is left as it is.
    } else if (aPart.isEmpty && bPart.isNotEmpty) {
      aPart = bPart;
    } else if (bPart.isEmpty && aPart.isNotEmpty) {
      bPart = aPart;
    }

    aResult.add(aPart);
    bResult.add(bPart);
  }

  return (aResult, bResult);
}
