/// Decides whether a copied summary is worth showing.
///
/// A verified author excerpt supplies the summary on a card when available.
/// Otherwise it is copied from whichever source the merge liked best.
/// A lot of those are not descriptions: a bare download link, the mod's own
/// name in bold, or the line of requirements from the top of a Discord post.
/// Showing one of those on a card is worse than showing the AI's sentence,
/// which is at least a sentence and is labelled as AI. So a summary that is
/// only one of those is dropped, and the AI summary takes its place.

/// Markdown emphasis marks: stars, underscores and backticks.
final RegExp _emphasis = RegExp(r'[*_`~]');

/// A web address.
final RegExp _address = RegExp(r'<?https?://\S+>?');

/// A line that opens by saying what the mod needs, up to the end of that
/// sentence.
final RegExp _requirementsOpening = RegExp(
  r'^(?:it\s+)?(?:also\s+)?requires?\b[^.!?]*[.!?]?',
  caseSensitive: false,
);

/// Words that introduce a link and say nothing themselves.
final RegExp _linkIntroduction = RegExp(
  r'^(?:download|dl|link|mirror|get it|grab it|current version|latest version'
  r'|latest release|version|update)\b[\s:—–-]*',
  caseSensitive: false,
);

final RegExp _spaces = RegExp(r'\s+');

/// Anything that is not a letter or a number.
final RegExp _notWordy = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// The opening sentences of a verified author excerpt, for a listing.
/// Keep the author's words rather than asking the model to shorten them.
///
/// Whole sentences from the excerpt's opening lines are kept until the next one
/// would pass [_longestExcerptSummary]; the first sentence is always kept. One
/// sentence alone is often the least useful one ("A fork of Starficz's Refit
/// Filters."), and a card cuts a long summary at three lines anyway. The limit
/// is there for `mods.json`, which every mod's summary rides in.
String? summaryOfExcerpt(String? excerpt) {
  if (excerpt == null) return null;
  final firstLine = _openingLines(excerpt);

  var kept = '';
  var from = 0;
  for (final end in _sentenceEnd.allMatches(firstLine)) {
    final upTo = end.start + 1;
    if (kept.isNotEmpty && upTo > _longestExcerptSummary) break;
    kept = firstLine.substring(0, upTo);
    from = upTo;
  }
  // Words after the last full stop, when the line has no sentence end at all
  // or the rest still fits.
  if (from < firstLine.length &&
      (kept.isEmpty || firstLine.length <= _longestExcerptSummary)) {
    kept = firstLine;
  }
  final copied = kept.trim();
  return copied.isEmpty ? null : copied;
}

/// The excerpt's first line, with the lines after it that carry on from it,
/// as one line.
///
/// Forum authors often press Enter in the middle of a sentence ("…feel more
/// part of" / "the world + other optional add-ons."), so a line that starts
/// with a small letter belongs to the one before. A line that follows a
/// finished sentence is more of the same paragraph. Anything else, such as a
/// heading or a list of names after an unfinished line, ends it, and so does a
/// blank line.
String _openingLines(String excerpt) {
  final lines = excerpt.trim().split('\n');
  final joined = StringBuffer();
  for (final raw in lines) {
    final line = raw.replaceFirst(RegExp(r'^\s*[-•]\s+'), '').trim();
    if (line.isEmpty) break;
    if (joined.isNotEmpty) {
      final soFar = joined.toString();
      final carriesOn = _endsASentence.hasMatch(soFar) ||
          RegExp(r'^\p{Ll}', unicode: true).hasMatch(line);
      if (!carriesOn) break;
      joined.write(' ');
    }
    joined.write(line);
  }
  return joined.toString().replaceAll(_spaces, ' ').trim();
}

/// A line whose last word finishes a sentence.
final RegExp _endsASentence = RegExp(r'[.!?。！？]$');

/// How long an excerpt summary may grow before it stops adding sentences.
const int _longestExcerptSummary = 300;

/// The end of a sentence: a stop followed by a space or the end, or a stop in
/// Chinese or Japanese, which needs no space after it.
final RegExp _sentenceEnd = RegExp(r'[.!?](?=\s|$)|[。！？]');

/// A Discord heading line ("## Hullmods - Renewed"). A heading is a title, and
/// at the top of a post it is nearly always the mod's own name.
final RegExp _headingLine = RegExp(r'^#{1,6}\s');

/// The marks Discord puts at the start of a line: small text, a quote, a list
/// item.
final RegExp _lineMarks = RegExp(r'^(?:-#\s+|>+\s*|[-*•]\s+)');

/// At most four words and a colon, the way "Forum post:" introduces a link.
final RegExp _labelOnly = RegExp(r'^[^\s:]+(?:\s+[^\s:]+){0,3}\s*:$');

/// True when [line] is only a link, or a short label and a link — "Forum
/// post: https://…".
bool _onlyALabelledLink(String line) {
  if (!_address.hasMatch(line)) return false;
  final rest = line.replaceAll(_address, ' ').replaceAll(_spaces, ' ').trim();
  return rest.isEmpty || _labelOnly.hasMatch(rest);
}

/// The first usable paragraph near the top of a Discord post, cut to whole
/// sentences the way [summaryOfExcerpt] cuts an excerpt. Null when none of
/// the first few paragraphs says anything about the mod.
///
/// The Discord reader keeps only a post's first two lines as its summary, and
/// those are often the mod's name as a heading and a link. Hullmods - Renewed
/// opens that way and writes its real opening ("Ever scrolled past 200+
/// hullmods…") a few lines further down. Only the first few paragraphs are
/// read, so a line from a changelog far down the post never stands in.
String? summaryOfDiscordPost(String? post) {
  if (post == null) return null;
  final paragraphs = post
      .replaceAll('\r\n', '\n')
      .split(RegExp(r'\n\s*\n'))
      .where((block) => block.trim().isNotEmpty)
      .take(_paragraphsToRead);
  for (final paragraph in paragraphs) {
    final usable = usableSummary(paragraph);
    if (usable != null) return summaryOfExcerpt(usable);
  }
  return null;
}

/// How many of a Discord post's paragraphs [summaryOfDiscordPost] reads.
const int _paragraphsToRead = 4;

/// [summary] tidied, or null when it is not a description at all.
///
/// Read a line at a time first: a heading and a line that only points at a
/// link are dropped, and the marks Discord starts a line with come off. The
/// top of Hullmods - Renewed's post is its name as a heading and then "Forum
/// post:" and the thread's address, which together read as a summary.
String? usableSummary(String? summary) {
  final lines = (summary ?? '')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !_headingLine.hasMatch(line))
      // Emphasis comes off first, so a bold label ("**Download:**") still
      // ends in its colon.
      .map((line) => line.replaceFirst(_lineMarks, '').replaceAll(_emphasis, '').trim())
      .where((line) => line.isNotEmpty && !_onlyALabelledLink(line));
  final tidied =
      lines.join(' ').replaceAll(_emphasis, '').replaceAll(_spaces, ' ').trim();
  if (tidied.isEmpty) return null;

  // A summary that is only a list of requirements says nothing about the mod.
  // One that opens with the requirements and then describes the mod is kept —
  // "Requires LazyLib. Adds a new faction…" is a description.
  final afterRequirements = tidied.replaceFirst(_requirementsOpening, '').trim();
  if (afterRequirements.isEmpty) return null;

  // What is left once the links, and the words that only introduce a link, are
  // taken away. Nothing left means the summary was the link.
  final withoutLinks = tidied
      .replaceFirst(_linkIntroduction, '')
      .replaceAll(_address, ' ')
      .replaceAll(_notWordy, ' ')
      .trim();
  if (withoutLinks.isEmpty) return null;

  // One word is a name, not a description.
  if (!withoutLinks.contains(' ')) return null;

  return tidied;
}
