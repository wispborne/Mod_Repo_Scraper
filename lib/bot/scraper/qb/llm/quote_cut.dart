/// Cutting an author's statement out of a post, from the first and last few
/// words the model points at.
///
/// This is how descriptions are handled (`descriptionAnchors`): the model
/// copies only the two ends, and the words in between are taken from the post
/// itself. So a long statement costs the model a few words, and what is stored
/// is always the author's own text, never the model's copy of it.
library;

import '../../../../site/description_slice.dart';

/// The longest statement kept. Two anchors make it cheap to point at half a
/// post by mistake, and a statement that long is not one statement.
const int longestCutQuote = 1000;

/// The words of [postText] from [startsWith] to [endsWith], or null when
/// either cannot be found, the end does not come after the start, or the cut
/// is longer than [longestCutQuote].
///
/// [postText] is one post's plain text. Our `[link: <url>]` notes are taken
/// out first, so an anchor never has to copy one. The two anchors are matched
/// on letters and numbers only, the same as description anchors, so
/// punctuation and spacing in the model's copy do not matter. The cut is
/// widened to whole words at both ends and keeps the post's line breaks, so a
/// statement written as a list still reads as one. Spaces inside each line are
/// tidied.
String? cutQuote(String postText, String startsWith, String endsWith) {
  final text = postText.replaceAll(_linkNote, '');
  // Also turns away an anchor too short to point at one place.
  if (!anchorsFoundIn(text, startsWith, endsWith)) return null;
  final start = anchorKey(startsWith);
  final end = anchorKey(endsWith);

  // The letters and numbers of the text, lower case, and where each one sits
  // in the text.
  final key = StringBuffer();
  final at = <int>[];
  var i = 0;
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final kept = anchorKey(char);
    for (var k = 0; k < kept.length; k++) {
      at.add(i);
    }
    key.write(kept);
    i += char.length;
  }
  final haystack = key.toString();

  final startAt = haystack.indexOf(start);
  if (startAt < 0) return null;
  final endAt = haystack.indexOf(end, startAt);
  if (endAt < 0) return null;

  var from = at[startAt];
  var to = at[endAt + end.length - 1] + 1;
  if (to < text.length && _isLowSurrogate(text.codeUnitAt(to))) to++;

  // Out to whole words: back and on to the nearest space, which also takes in
  // an opening quote mark and a closing full stop.
  while (from > 0 && !_space.hasMatch(text[from - 1])) {
    from--;
  }
  while (to < text.length && !_space.hasMatch(text[to])) {
    to++;
  }

  final quote = text
      .substring(from, to)
      .split('\n')
      .map((line) => line.replaceAll(_spaces, ' ').trim())
      .where((line) => line.isNotEmpty)
      .join('\n');
  if (quote.isEmpty || quote.length > longestCutQuote) return null;
  return quote;
}

bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

final RegExp _linkNote = RegExp(r'\[link: [^\]]*\]');
final RegExp _space = RegExp(r'\s');
final RegExp _spaces = RegExp(r'[ \t ]+');
