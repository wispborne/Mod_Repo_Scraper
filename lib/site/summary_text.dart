/// Decides whether a copied summary is worth showing.
///
/// The summary on a card is copied from whichever source the merge liked best.
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

/// [summary] tidied, or null when it is not a description at all.
String? usableSummary(String? summary) {
  final tidied =
      (summary ?? '').replaceAll(_emphasis, '').replaceAll(_spaces, ' ').trim();
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
