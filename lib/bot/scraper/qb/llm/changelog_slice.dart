/// Cutting one version's changelog notes out of a post, from the version and
/// the first and last few words the model points at.
///
/// Copying a long changelog word for word was a third of everything the model
/// wrote, and its copies were not always word for word. So the model now only
/// says where an entry is, and the notes are taken from the post itself. What
/// is stored is the author's own text or nothing.
library;

import 'anchor_key.dart';

/// Why an entry could not be cut.
enum ChangelogCutFailure {
  /// The first or last words are too short to point at one place.
  pointerTooShort,

  /// The version does not appear in any of the posts.
  versionNotFound,

  /// The version is there, but the first words never follow it.
  firstWordsNotFound,

  /// The first words are there, but the last words never follow them.
  lastWordsNotFound,
}

/// One entry's notes, or why there are none. Exactly one of the two is set.
class ChangelogCut {
  final String? notes;
  final ChangelogCutFailure? failure;

  const ChangelogCut.found(String this.notes) : failure = null;

  const ChangelogCut.failed(ChangelogCutFailure this.failure) : notes = null;
}

/// The notes for [version] in [postTexts], from [startsWith] through the end
/// of the line holding [endsWith].
///
/// [postTexts] is each of the author's posts as plain text, in order. The
/// first and last words must be found in one post, in that order, and are
/// first looked for after the version in that same post. The version must stand on its own: "1.2.1" is not found
/// inside "1.2.1a" or "11.2.1", but a "v", "v." or "version" before it is
/// fine. A version at the start of a line, where a heading sits, is tried
/// before one anywhere else, and the first place where all three are found
/// wins. That matters when a version is first named inside another version's
/// notes ("a save made on 1.2.1"), or when the same line appears under several
/// versions.
///
/// Some authors write the notes first and the version after them, on the
/// download link ("Yet another update… / My Mod 1.1.2 [download]", topic
/// 30736), and a Discord thread often names the version in one message and
/// gives the notes in another. So when the first words follow no place the
/// version appears, they are looked for anywhere: first in the posts that
/// hold the version, then in the rest. The version must still be in one of
/// the posts or in the thread's [title], where many authors only write it
/// ("Star Wars Mod 2.05").
///
/// The words are matched on letters and numbers only, so punctuation and
/// spacing in the model's copy do not matter. Our `[link: <url>]` notes, the
/// forum's spoiler end marks (`[close]`) and `&nbsp;` left in the text are
/// taken out of the post first. The cut keeps the post's line breaks, and the
/// version heading is not part of it.
ChangelogCut cutChangelogEntry(
  List<String> postTexts,
  String version,
  String startsWith,
  String endsWith, {
  String title = '',
}) {
  final start = anchorKey(_plain(startsWith));
  final end = anchorKey(_plain(endsWith));
  if (start.length < shortestAnchor || end.length < shortestAnchor) {
    return const ChangelogCut.failed(ChangelogCutFailure.pointerTooShort);
  }

  final texts = [for (final t in postTexts) _plain(t)];
  final keyed = [for (final t in texts) anchorKeyWithPlaces(t)];

  // Every place the version appears, headings first, each in post order.
  final atLineStart = <({int post, int from, int to})>[];
  final elsewhere = <({int post, int from, int to})>[];
  final pattern = _versionPattern(version);
  for (var p = 0; p < texts.length; p++) {
    for (final m in pattern.allMatches(texts[p])) {
      final place = (post: p, from: m.start, to: m.end);
      (_startsLine(texts[p], m.start) ? atLineStart : elsewhere).add(place);
    }
  }
  if (atLineStart.isEmpty &&
      elsewhere.isEmpty &&
      !pattern.hasMatch(_plain(title))) {
    return const ChangelogCut.failed(ChangelogCutFailure.versionNotFound);
  }

  var failure = ChangelogCutFailure.firstWordsNotFound;

  // The notes cut from post [post], with the first words looked for from
  // [after] in the text on. Null when the words are not there.
  String? cutFrom(int post, int after) {
    final text = texts[post];
    final (:key, :at) = keyed[post];

    // The first letter or number at or after [after].
    var k = 0;
    while (k < at.length && at[k] < after) {
      k++;
    }

    final startAt = key.indexOf(start, k);
    if (startAt < 0) return null;
    final endAt = key.indexOf(end, startAt);
    if (endAt < 0) {
      failure = ChangelogCutFailure.lastWordsNotFound;
      return null;
    }

    final from = _backToStart(text, at[startAt]);
    final to = _onToLineEnd(text, at[endAt + end.length - 1]);
    final notes = _tidy(text.substring(from, to));
    return notes.isEmpty ? null : notes;
  }

  for (final place in [...atLineStart, ...elsewhere]) {
    final notes = cutFrom(place.post, place.to);
    if (notes != null) return ChangelogCut.found(notes);
  }
  // The posts holding the version first, then the rest: a Discord thread
  // often names the version in one message and gives the notes in another.
  final withTheVersion = {
    for (final place in [...atLineStart, ...elsewhere]) place.post
  };
  for (final post in [
    for (var p = 0; p < texts.length; p++)
      if (withTheVersion.contains(p)) p,
    for (var p = 0; p < texts.length; p++)
      if (!withTheVersion.contains(p)) p,
  ]) {
    final notes = cutFrom(post, 0);
    if (notes != null) return ChangelogCut.found(notes);
  }
  return ChangelogCut.failed(failure);
}

/// [text] with our link notes, the forum's spoiler end marks and `&nbsp;`
/// taken out. The space before a note or mark goes with it, so no double
/// space is left behind.
String _plain(String text) =>
    text.replaceAll(_markers, '').replaceAll(_nbsp, ' ');

/// Finds [version] standing on its own, with an optional "v", "v." or
/// "version" before it. The model's spelling is tried, and so is the version
/// without a leading "v".
RegExp _versionPattern(String version) {
  final spelled = version.trim();
  final plain = spelled.replaceFirst(_leadingV, '');
  final spellings = {spelled, plain}.where((s) => s.isNotEmpty).toList()
    // Longest first, so "v1.2" wins over "1.2" at the same place.
    ..sort((a, b) => b.length.compareTo(a.length));
  // A dash, underscore or space between parts may be any of the three or
  // none: the model writes "0.3.8-RC1" for the post's "0.3.8 RC1" (topic
  // 18227). Dots must match as written.
  final alternatives = spellings
      .map((s) => s.split(_partBreak).map(RegExp.escape).join('[-_ ]?'))
      .join('|');
  return RegExp(
    // Not straight after a letter or number, or after one and a dot
    // ("0.1.2.1" does not hold "1.2.1").
    r'(?<![\p{L}\p{N}])(?<![\p{L}\p{N}][.\-_])'
    r'(?:version\s*|v\.?\s*)?'
    '(?:$alternatives)'
    // Not straight before a letter or number, or before a dot and one
    // ("1.2.1a" and "1.2.1.5" do not hold "1.2.1").
    r'(?![\p{L}\p{N}])(?![.\-_+][\p{L}\p{N}])',
    caseSensitive: false,
    unicode: true,
  );
}

/// True when only marks and spaces sit between the start of the line and
/// [index], the way a heading starts: "1.2.1", "## v1.2.1", "- 1.2.1:".
bool _startsLine(String text, int index) {
  final lineStart = _lineStartOf(text, index);
  return !_letterOrNumber.hasMatch(text.substring(lineStart, index));
}

/// Where the cut starts: the start of the word the first words begin in, and
/// the start of the line when only a list mark sits before that word, so the
/// first line keeps its "- " like the rest. Never back past a version
/// heading, which holds a number.
int _backToStart(String text, int index) {
  var from = index;
  while (from > 0 && _letterOrNumber.hasMatch(text[from - 1])) {
    from--;
  }
  final lineStart = _lineStartOf(text, from);
  final before = text.substring(lineStart, from);
  if (before.trim().isNotEmpty && !_letterOrNumber.hasMatch(before)) {
    return lineStart;
  }
  return from;
}

/// The start of the line holding [index].
int _lineStartOf(String text, int index) =>
    index == 0 ? 0 : text.lastIndexOf('\n', index - 1) + 1;

/// The end of the line holding [index].
int _onToLineEnd(String text, int index) {
  final lineEnd = text.indexOf('\n', index);
  return lineEnd < 0 ? text.length : lineEnd;
}

/// Line ends trimmed, runs of blank lines made one, the whole trimmed.
String _tidy(String notes) => notes
    .split('\n')
    .map((line) => line.trimRight())
    .join('\n')
    .replaceAll(_blankLines, '\n\n')
    .trim();

final RegExp _markers = RegExp(r' ?(?:\[link: [^\]]*\]|\[close\])');
final RegExp _nbsp = RegExp(r'&nbsp;|&#0*160;|&#x0*a0;| ',
    caseSensitive: false);
final RegExp _leadingV = RegExp(r'^[vV]\.?\s*(?=\d)');
final RegExp _partBreak = RegExp(r'[-_ ]+');
final RegExp _letterOrNumber = RegExp(r'[\p{L}\p{N}]', unicode: true);
final RegExp _blankLines = RegExp(r'\n{3,}');
