/// Matching the few words the model copies to point at a stretch of a post.
///
/// The model points at a description, an AI-use statement or a changelog entry
/// by copying its first and last few words, and the code finds them in the post.
/// Those copies differ from the post in punctuation, spacing, capitals and HTML
/// entities, and none of those differences mean the model pointed somewhere
/// else. So both sides are compared on their letters and numbers only.
library;

/// How short an anchor may be before it is thrown out. A very short one matches
/// almost anywhere, and a wrong cut is worse than none.
const int shortestAnchor = 8;

/// A piece of writing with everything but its letters and numbers taken out,
/// lower case.
///
/// Letters in any alphabet count, so a post in Russian or Chinese anchors the
/// same way an English one does.
String anchorKey(String text) =>
    text.toLowerCase().replaceAll(_notLetterOrNumber, '');

/// True when the post holds both anchors, the start at or before the end.
///
/// [postText] is one post's plain words. Anchors that straddle two posts are
/// not a match: the stretch has to sit in one of them.
bool anchorsFoundIn(String postText, String startsWith, String endsWith) {
  final start = anchorKey(startsWith);
  final end = anchorKey(endsWith);
  if (start.length < shortestAnchor || end.length < shortestAnchor) {
    return false;
  }

  final haystack = anchorKey(postText);
  final startAt = haystack.indexOf(start);
  if (startAt < 0) return false;
  return haystack.indexOf(end, startAt) >= 0;
}

/// [text]'s [anchorKey], with the place in [text] each of its characters came
/// from.
///
/// `at[i]` is where `key[i]` sits in [text], so a match found in the key can
/// be turned back into a cut in the original.
({String key, List<int> at}) anchorKeyWithPlaces(String text) {
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
  return (key: key.toString(), at: at);
}

final RegExp _notLetterOrNumber = RegExp(r'[^\p{L}\p{N}]+', unicode: true);
