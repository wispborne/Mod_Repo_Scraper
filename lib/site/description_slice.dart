/// Cutting one mod's own description out of a post that describes several.
///
/// Some forum threads hold several mods, and the author writes a paragraph
/// about each one. Those paragraphs are the mods' descriptions, but nothing in
/// the post says where one stops and the next begins, so the model is asked to
/// point: it copies the first few words and the last few words of the stretch
/// of text about one mod, and the words in between are cut out of the post
/// here. The model never writes the description — it only says where it is.
///
/// Both ends have to be found, in order, or nothing is cut. That is the whole
/// safety of it: a description that reaches a mod's page is the author's own
/// words or it does not appear at all.
library;

import 'post_html.dart';

/// How short an anchor may be before it is thrown out. A very short one matches
/// almost anywhere, and a wrong cut is worse than no description.
const int _shortestAnchor = 8;

/// A piece of writing with everything but its letters and numbers taken out,
/// lower case.
///
/// Punctuation, spacing, capitals and HTML entities all differ between what the
/// model copies and what the post holds, and none of those differences mean the
/// model pointed somewhere else. Letters and numbers are what is left when they
/// are all gone. Letters in any alphabet count, so a description in Russian or
/// Chinese anchors the same way an English one does.
String anchorKey(String text) =>
    text.toLowerCase().replaceAll(_notLetterOrNumber, '');

/// True when the post holds both anchors, the start at or before the end.
///
/// [postText] is one post's plain words. Anchors that straddle two posts are
/// not a match: the description has to sit in one of them.
bool anchorsFoundIn(String postText, String startsWith, String endsWith) {
  final start = anchorKey(startsWith);
  final end = anchorKey(endsWith);
  if (start.length < _shortestAnchor || end.length < _shortestAnchor) {
    return false;
  }

  final haystack = anchorKey(postText);
  final startAt = haystack.indexOf(start);
  if (startAt < 0) return false;
  return haystack.indexOf(end, startAt) >= 0;
}

/// The stretch of [cleanedHtml] between the two anchors, rebuilt as its own
/// small piece of HTML — or null when either anchor cannot be found.
///
/// [cleanedHtml] is a post that has already been through [cleanPostHtml]. The
/// cut is made at the breaks a reader sees as separate lines, never inside a
/// sentence, so what comes back is whole paragraphs. It goes through
/// [cleanPostHtml] once more on the way out, which closes anything a cut left
/// open.
String? sliceDescriptionHtml(
  String? cleanedHtml,
  String startsWith,
  String endsWith,
) {
  final source = cleanedHtml?.trim();
  if (source == null || source.isEmpty) return null;

  final start = anchorKey(startsWith);
  final end = anchorKey(endsWith);
  if (start.length < _shortestAnchor || end.length < _shortestAnchor) {
    return null;
  }

  final pieces = _splitIntoLines(source);
  if (pieces.isEmpty) return null;

  // Each piece's letters and numbers, and where that piece starts once they are
  // all run together. Matching against the run-together form is what lets an
  // anchor that crosses a line break still be found.
  final keys = [for (final piece in pieces) anchorKey(plainWordsOf(piece) ?? '')];
  final startOfPiece = <int>[];
  var running = 0;
  for (final key in keys) {
    startOfPiece.add(running);
    running += key.length;
  }
  final haystack = keys.join();

  final startAt = haystack.indexOf(start);
  if (startAt < 0) return null;
  final endAt = haystack.indexOf(end, startAt);
  if (endAt < 0) return null;

  final firstPiece = _pieceHolding(startOfPiece, startAt);
  final lastPiece = _pieceHolding(startOfPiece, endAt + end.length - 1);

  return cleanPostHtml(pieces.sublist(firstPiece, lastPiece + 1).join());
}

/// Which piece a position in the run-together text falls in.
int _pieceHolding(List<int> startOfPiece, int position) {
  for (var i = startOfPiece.length - 1; i >= 0; i--) {
    if (position >= startOfPiece[i]) return i;
  }
  return 0;
}

/// The post cut at the places a reader sees as the end of a line: the end of a
/// paragraph, list item, heading, quote or code block, and every line break.
/// The break itself stays with the piece before it.
List<String> _splitIntoLines(String html) {
  final pieces = <String>[];
  var start = 0;
  for (final match in _lineBreak.allMatches(html)) {
    final piece = html.substring(start, match.end);
    if (piece.trim().isNotEmpty) pieces.add(piece);
    start = match.end;
  }
  if (start < html.length) {
    final rest = html.substring(start);
    if (rest.trim().isNotEmpty) pieces.add(rest);
  }
  return pieces;
}

final RegExp _lineBreak = RegExp(
  r'</p>|</li>|</h[3-6]>|</blockquote>|</pre>|<br\s*/?>',
  caseSensitive: false,
);

final RegExp _notLetterOrNumber = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
