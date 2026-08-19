import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Turns a forum post into a small, safe piece of HTML the mod's page can show.
///
/// The description used to be one line of plain text picked from whichever
/// source the merge liked best, which for the bigger mods was the Discord
/// announcement rather than the author's own post. The post itself is already
/// in the bundle, so it is what the page shows now — but a forum post is
/// whatever HTML the forum produced, so it is rebuilt here from a short list of
/// tags rather than published as it arrived.
///
/// What survives: paragraphs, line breaks, lists, headings, quotes, code,
/// emphasis and links. What does not: anything that can run (scripts, event
/// handlers), anything that can style the page, and anything that loads from
/// another host (pictures, frames, embeds). Pictures are not lost — they are
/// published separately as the gallery.

/// How much of a post is published. A few threads run to tens of thousands of
/// words of changelog; what is published stops at about this many characters
/// and ends with a "…" paragraph so the reader can see it was cut short. The
/// mod page's link to the thread is where the rest is.
const int maxDescriptionLength = 12000;

/// Tags kept as they are.
const Set<String> _keptTags = {
  'p', 'br', 'hr', 'ul', 'ol', 'li', 'blockquote', 'pre', 'code',
  'strong', 'b', 'em', 'i', 'u', 's', 'strike', 'del', 'sub', 'sup',
  'h3', 'h4', 'h5', 'h6', 'a',
};

/// Tags that go, and take what is inside them with them.
const Set<String> _droppedTags = {
  'script', 'style', 'noscript', 'iframe', 'frame', 'frameset', 'object',
  'embed', 'applet', 'svg', 'math', 'img', 'picture', 'video', 'audio',
  'source', 'canvas', 'form', 'input', 'select', 'textarea', 'button',
  'link', 'meta', 'base', 'head', 'title',
};

/// Tags that stand for themselves — nothing goes inside them.
const Set<String> _emptyTags = {'br', 'hr'};

/// A heading bigger than the page's own headings is brought down to size.
const Map<String, String> _headingSwaps = {'h1': 'h3', 'h2': 'h3'};

/// A web address written out in the middle of a sentence.
final RegExp _bareAddress = RegExp(r'https?://[^\s<>"\x27]+');

/// Punctuation a sentence puts after an address, which is not part of it.
final RegExp _addressTail = RegExp(r'[.,;:!?)\]}\x27"]+$');

/// [postHtml] rebuilt from the tags above, or null when nothing readable is
/// left.
String? cleanPostHtml(String? postHtml) {
  final source = postHtml?.trim();
  if (source == null || source.isEmpty) return null;

  final fragment = html_parser.parseFragment(source);
  final out = StringBuffer();

  for (final node in fragment.nodes) {
    if (out.length >= maxDescriptionLength) break;
    _write(node, out, inLink: false);
  }
  // The cap is checked inside [_write] as well as here, because plenty of
  // posts are one enormous node — the whole thing as text with line breaks —
  // and a check between top-level nodes alone would never fire for those.
  if (out.length >= maxDescriptionLength) out.write('<p>…</p>');

  final result = _tidy(out.toString());
  return _hasWords(result) ? result : null;
}

/// The post's plain words, for anywhere that cannot show HTML. Blocks are
/// separated by a blank line, the way the post read.
String? postHtmlAsText(String? postHtml) => plainWordsOf(cleanPostHtml(postHtml));

/// The plain words of something [cleanPostHtml] has already been through, so a
/// caller that wants both shapes only pays to read the post once.
String? plainWordsOf(String? cleanedHtml) {
  final cleaned = cleanedHtml;
  if (cleaned == null || cleaned.isEmpty) return null;

  final blocks = <String>[];
  for (final node in html_parser.parseFragment(cleaned).nodes) {
    final text = _plainWords(node).replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    if (text.isNotEmpty) blocks.add(text);
  }
  final joined = blocks.join('\n\n').trim();
  return joined.isEmpty ? null : joined;
}

/// A tag with nothing inside it. Nearly always a link whose only content was a
/// picture — a download banner, say — which was dropped on the way through.
final RegExp _emptyTag =
    RegExp(r'<(a|strong|b|em|i|u|s|p|h3|h4|h5|h6|li|blockquote|code|pre)'
        r'(?:\s[^>]*)?></\1>');

/// Three or more line breaks in a row. Forum posts are full of them, and they
/// leave the page looking broken once the pictures between them are gone.
final RegExp _tooManyBreaks = RegExp(r'(?:<br>\s*){3,}');

/// Line breaks at the very start or the very end, which only add a gap.
final RegExp _breaksAtTheStart = RegExp(r'^(?:\s*<br>)+');
final RegExp _breaksAtTheEnd = RegExp(r'(?:<br>\s*)+$');

/// Tidies what is left once the tags that were not kept have gone.
String _tidy(String html) {
  var tidied = html;
  // Taking one empty tag out can leave the tag around it empty too, so this
  // goes round until nothing more comes out.
  for (var pass = 0; pass < 5; pass++) {
    final before = tidied;
    tidied = tidied.replaceAll(_emptyTag, '');
    if (tidied == before) break;
  }
  tidied = tidied.replaceAll(_tooManyBreaks, '<br><br>');
  tidied = tidied.replaceFirst(_breaksAtTheStart, '');
  tidied = tidied.replaceFirst(_breaksAtTheEnd, '');
  return tidied.trim();
}

/// Plain words turned into the same small set of tags, so a description that
/// came from Discord or from the AI is shown the same way as a forum post: a
/// paragraph per blank line, and every web address in it a link.
String? plainTextAsHtml(String? text) {
  final source = text?.trim();
  if (source == null || source.isEmpty) return null;

  final out = StringBuffer();
  for (final block in source.split(RegExp(r'\n\s*\n'))) {
    final lines = block
        .split('\n')
        .map((line) => _linkify(line.trim()))
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) continue;
    out.write('<p>${lines.join('<br>')}</p>');
  }

  final result = out.toString();
  return _hasWords(result) ? result : null;
}

// -----------------------------------------------------------------------------

void _write(dom.Node node, StringBuffer out, {required bool inLink}) {
  // Stop taking anything more in once the cap is reached. Closing tags are
  // still written by whoever opened them, so what comes out is never left with
  // a tag hanging open.
  if (out.length >= maxDescriptionLength) return;

  if (node is dom.Text) {
    final text = _cutToFit(node.text, maxDescriptionLength - out.length);
    out.write(inLink ? _escape(text) : _linkify(text));
    return;
  }
  if (node is! dom.Element) return;

  final tag = node.localName?.toLowerCase() ?? '';
  if (_droppedTags.contains(tag)) return;

  final kept = _headingSwaps[tag] ?? tag;

  if (!_keptTags.contains(kept)) {
    // A tag we have no opinion about: keep what it held, drop the tag itself.
    for (final child in node.nodes) {
      _write(child, out, inLink: inLink);
    }
    return;
  }

  if (_emptyTags.contains(kept)) {
    out.write('<$kept>');
    return;
  }

  if (kept == 'a') {
    final href = _webAddress(node.attributes['href']);
    if (href == null) {
      for (final child in node.nodes) {
        _write(child, out, inLink: inLink);
      }
      return;
    }
    out.write('<a href="${_escapeAttribute(href)}" rel="nofollow noopener" '
        'target="_blank">');
    for (final child in node.nodes) {
      _write(child, out, inLink: true);
    }
    out.write('</a>');
    return;
  }

  out.write('<$kept>');
  for (final child in node.nodes) {
    _write(child, out, inLink: inLink);
  }
  out.write('</$kept>');
}

/// [text] cut to [room] characters, at the last space before the cut so a word
/// is never sliced in half. A post that is one huge block of text needs this —
/// the check between nodes never fires for it.
String _cutToFit(String text, int room) {
  if (text.length <= room) return text;
  if (room <= 0) return '';
  final lastSpace = text.lastIndexOf(' ', room);
  return text.substring(0, lastSpace > room ~/ 2 ? lastSpace : room);
}

String _plainWords(dom.Node node) {
  if (node is dom.Text) return node.text;
  if (node is! dom.Element) return '';
  if (node.localName == 'br') return '\n';
  return node.nodes.map(_plainWords).join();
}

/// The address as a link, or null when it is not one this site should follow —
/// a `javascript:` address, or a path back into the forum's own pages.
String? _webAddress(String? href) {
  final url = href?.trim();
  if (url == null || url.isEmpty) return null;
  final lower = url.toLowerCase();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) return null;
  return url;
}

/// Text with any bare web address in it turned into a link.
String _linkify(String text) {
  final out = StringBuffer();
  var at = 0;
  for (final match in _bareAddress.allMatches(text)) {
    out.write(_escape(text.substring(at, match.start)));

    var url = match[0]!;
    // A full stop or bracket after an address belongs to the sentence.
    final tail = _addressTail.firstMatch(url);
    var after = '';
    if (tail != null) {
      after = url.substring(tail.start);
      url = url.substring(0, tail.start);
    }
    if (url.isEmpty) {
      out.write(_escape(match[0]!));
    } else {
      out.write('<a href="${_escapeAttribute(url)}" rel="nofollow noopener" '
          'target="_blank">${_escape(url)}</a>${_escape(after)}');
    }
    at = match.end;
  }
  out.write(_escape(text.substring(at)));
  return out.toString();
}

/// True when there is something to read once the tags are taken away.
bool _hasWords(String html) =>
    html.replaceAll(RegExp(r'<[^>]*>'), '').trim().isNotEmpty;

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _escapeAttribute(String value) =>
    _escape(value).replaceAll('"', '&quot;');
