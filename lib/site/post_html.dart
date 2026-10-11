import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'forum_formatting.dart';

// Rebuild forum HTML from allowed tags and attributes. Formatting uses site
// classes and checked colours; YouTube embeds become thumbnail links.
// Scripts, event handlers and arbitrary styles never reach the page.

/// How much of a post is published. Set above the longest post on the forum
/// (about 116,000 characters of HTML), so in practice a post is published
/// whole: it has the Description tab to itself, and 12,000 used to cut one
/// post in five. It stays as a limit against a runaway post. Anything cut ends
/// with a "…" paragraph, which the mod page turns into a link to the thread.
///
/// Picture tags are not counted. A tag is about 150 characters, so a short post
/// with forty screenshots would otherwise be cut short with little to read.
const int maxDescriptionLength = 150000;

/// Tags kept as they are.
const Set<String> _keptTags = {
  'p', 'br', 'hr', 'ul', 'ol', 'li', 'blockquote', 'pre', 'code',
  'strong', 'b', 'em', 'i', 'u', 's', 'strike', 'del', 'sub', 'sup',
  'h3', 'h4', 'h5', 'h6', 'a', 'img',
  'table', 'thead', 'tbody', 'tr', 'td', 'th',
};

/// Tags that go, and take what is inside them with them.
const Set<String> _droppedTags = {
  'script', 'style', 'noscript', 'iframe', 'frame', 'frameset', 'object',
  'embed', 'applet', 'svg', 'math', 'picture', 'video', 'audio',
  'source', 'canvas', 'form', 'input', 'select', 'textarea', 'button',
  'link', 'meta', 'base', 'head', 'title',
};

/// Tags that stand for themselves — nothing goes inside them.
const Set<String> _emptyTags = {'br', 'hr'};

/// Tags written as another tag: a heading bigger than the page's own headings
/// is brought down to size, and the forum's typewriter text is code.
const Map<String, String> _tagSwaps = {'h1': 'h3', 'h2': 'h3', 'tt': 'code'};

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
  final out = _Writer();

  for (final node in fragment.nodes) {
    if (out.full) break;
    _write(node, out, inLink: false);
  }
  // The cap is checked inside [_write] as well as here, because plenty of
  // posts are one enormous node — the whole thing as text with line breaks —
  // and a check between top-level nodes alone would never fire for those.
  if (out.full) out.write('<p>…</p>');

  final result = _tidy(out.toString());
  return _hasWords(result) ? result : null;
}

/// The post's plain words, for anywhere that cannot show HTML. Blocks are
/// separated by a blank line, the way the post read.
String? postHtmlAsText(String? postHtml) => plainWordsOf(cleanPostHtml(postHtml));

/// The plain words of something [cleanPostHtml] has already been through, so a
/// caller that wants both shapes only pays to read the post once.
String? plainWordsOf(String? cleanedHtml) {
  if (cleanedHtml == null || cleanedHtml.isEmpty) return null;

  final blocks = <String>[];
  for (final node in html_parser.parseFragment(cleanedHtml).nodes) {
    final text = _plainWords(node).replaceAll(RegExp(r'[ \t]+'), ' ').trim();
    if (text.isNotEmpty) blocks.add(text);
  }
  final joined = blocks.join('\n\n').trim();
  return joined.isEmpty ? null : joined;
}

/// A tag with nothing inside it. Nearly always a link whose only content was a
/// picture — a download banner, say — which was dropped on the way through.
///
/// A table cell is never one of these: taking an empty cell out would move
/// every cell after it into the wrong column.
final RegExp _emptyTag = RegExp(
    r'<(a|strong|b|em|i|u|s|p|h3|h4|h5|h6|li|blockquote|code|pre|div|span'
    r'|ul|ol|tr|tbody|thead|table|cite)'
    r'(?:\s[^>]*)?></\1>');

/// Three or more line breaks in a row. Forum posts are full of them, and they
/// leave the page looking broken once the pictures between them are gone.
final RegExp _tooManyBreaks = RegExp(r'(?:<br>\s*){3,}');

/// Line breaks at the very start or the very end, which only add a gap.
final RegExp _breaksAtTheStart = RegExp(r'^(?:\s*<br>)+');
final RegExp _breaksAtTheEnd = RegExp(r'(?:<br>\s*)+$');

/// Line breaks just inside the start or the end of a block.
final RegExp _breaksBeforeClose =
    RegExp(r'(?:<br>\s*)+(</(?:details|div|td|th|li|blockquote)>)');
final RegExp _breaksAfterOpen = RegExp(
    r'(</summary>|<div class="[a-z-]+">|<td>|<th>|<li>|<blockquote>)(?:\s*<br>)+');

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
  // A fold, a centred block or a table cell that starts or ends on a line
  // break only gains a gap from it.
  tidied = tidied.replaceAllMapped(_breaksBeforeClose, (m) => m[1]!);
  tidied = tidied.replaceAllMapped(_breaksAfterOpen, (m) => m[1]!);
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

/// What [cleanPostHtml] has written so far, and how much of it counts toward
/// [maxDescriptionLength] — everything but picture tags.
class _Writer {
  final StringBuffer _out = StringBuffer();
  int _counted = 0;

  bool get full => _counted >= maxDescriptionLength;
  int get room => maxDescriptionLength - _counted;

  void write(String html) {
    _out.write(html);
    _counted += html.length;
  }

  /// Written, but not counted toward the cap.
  void writeUncounted(String html) => _out.write(html);

  @override
  String toString() => _out.toString();
}

void _write(dom.Node node, _Writer out, {required bool inLink}) {
  // Stop taking anything more in once the cap is reached. Closing tags are
  // still written by whoever opened them, so what comes out is never left with
  // a tag hanging open.
  if (out.full) return;

  if (node is dom.Text) {
    final text = _cutToFit(node.text, out.room);
    out.write(inLink ? _escape(text) : _linkify(text));
    return;
  }
  if (node is! dom.Element) return;

  final tag = node.localName?.toLowerCase() ?? '';

  // An embedded video becomes a link to it, before frames are dropped.
  if (tag == 'iframe') {
    if (!inLink) _writeVideo(node, out);
    return;
  }
  if (_droppedTags.contains(tag)) return;

  // The forum's own markup for a spoiler, a quote, a code block, centring, a
  // size or a colour, written back out in the site's own tags.
  if (_writeForumFormatting(node, tag, out, inLink: inLink)) return;

  final kept = _tagSwaps[tag] ?? tag;

  if (!_keptTags.contains(kept)) {
    // A tag we have no opinion about: keep what it held, drop the tag itself.
    _writeChildren(node, out, inLink: inLink);
    return;
  }

  if (_emptyTags.contains(kept)) {
    out.write('<$kept>');
    return;
  }

  if (kept == 'img') {
    final picture = _pictureTag(node);
    if (picture != null) out.writeUncounted(picture);
    return;
  }

  if (kept == 'a') {
    final href = _webAddress(node.attributes['href']);
    if (href == null) {
      _writeChildren(node, out, inLink: inLink);
      return;
    }
    out.write('<a href="${_escapeAttribute(href)}" rel="nofollow noopener" '
        'target="_blank">');
    _writeChildren(node, out, inLink: true);
    out.write('</a>');
    return;
  }

  // A table sits in a box of its own that scrolls sideways, so a wide one never
  // widens the page.
  if (kept == 'table') {
    out.write('<div class="table-scroll"><table>');
    _writeChildren(node, out, inLink: inLink);
    out.write('</table></div>');
    return;
  }

  // The forum numbers a list with a style rather than with `<ol>`.
  final written = kept == 'ul' &&
          styleValue(node.attributes['style'], 'list-style-type') == 'decimal'
      ? 'ol'
      : kept;

  out.write('<$written>');
  if (written == 'blockquote') _writeQuoteHeader(node, out);
  _writeChildren(node, out, inLink: inLink);
  out.write('</$written>');
}

void _writeChildren(dom.Element node, _Writer out, {required bool inLink}) {
  for (final child in node.nodes) {
    _write(child, out, inLink: inLink);
  }
}

/// The class names the forum puts on one tag.
Set<String> _classesOf(dom.Element node) =>
    (node.attributes['class'] ?? '').split(RegExp(r'\s+')).toSet();

/// Writes [node] when it is one of the forum's own formatting tags, and says
/// whether it did. Everything here is read from the forum's classes and styles
/// and written as one of the site's own fixed classes; nothing of the forum's
/// is passed through.
bool _writeForumFormatting(
  dom.Element node,
  String tag,
  _Writer out, {
  required bool inLink,
}) {
  final classes = _classesOf(node);

  if (tag == 'div') {
    if (classes.contains('sp-wrap')) return _writeSpoiler(node, out, inLink: inLink);
    // The spoiler's "[close]" line, and the lines the forum puts above and
    // below a quote or a code block, are the forum's furniture. A quote's
    // header is read again by the quote itself.
    if (classes.contains('sp-foot') ||
        classes.contains('quoteheader') ||
        classes.contains('quotefooter') ||
        classes.contains('codeheader')) {
      return true;
    }

    final align = (node.attributes['align'] ??
            styleValue(node.attributes['style'], 'text-align') ??
            '')
        .trim()
        .toLowerCase();
    if (align == 'center' || align == 'right') {
      out.write('<div class="align-$align">');
      _writeChildren(node, out, inLink: inLink);
      out.write('</div>');
      return true;
    }
    return false;
  }

  if (tag == 'span') {
    final style = node.attributes['style'];
    final opened = <String>[];
    if (classes.contains('bbc_u')) opened.add('<u>');
    final step = sizeStepOf(styleValue(style, 'font-size'));
    if (step != null) opened.add('<span class="${step.className}">');
    final colour = hexColourOf(styleValue(style, 'color'));
    if (colour != null) {
      opened.add('<span class="author-colour" style="--c:$colour">');
    }
    if (opened.isEmpty) return false;

    opened.forEach(out.write);
    _writeChildren(node, out, inLink: inLink);
    for (final open in opened.reversed) {
      out.write(open == '<u>' ? '</u>' : '</span>');
    }
    return true;
  }
  return false;
}

/// A spoiler as a fold, shut until the reader opens it, labelled with the
/// spoiler's own title. False when it is not shaped like one, so its words are
/// still kept the ordinary way.
bool _writeSpoiler(dom.Element wrap, _Writer out, {required bool inLink}) {
  dom.Element? head;
  dom.Element? body;
  for (final child in wrap.children) {
    final classes = _classesOf(child);
    if (classes.contains('sp-head')) head ??= child;
    if (classes.contains('sp-body')) body ??= child;
  }
  if (body == null) return false;

  final title = _oneLine(head?.text ?? '');
  out.write('<details class="spoiler"><summary>'
      '${_escape(title.isEmpty ? 'Spoiler' : title)}</summary>');
  _writeChildren(body, out, inLink: inLink);
  out.write('</details>');
  return true;
}

/// The name a quote's header gives, as a `<cite>` at the top of the quote. A
/// header that only says "Quote" says nothing, and is left out.
void _writeQuoteHeader(dom.Element blockquote, _Writer out) {
  final header = blockquote.previousElementSibling;
  if (header == null || !_classesOf(header).contains('quoteheader')) return;
  final words = _oneLine(header.text);
  if (words.isEmpty || words.toLowerCase() == 'quote') return;
  out.write('<cite>${_escape(words)}</cite>');
}

/// An embedded YouTube video as a link to it, holding its thumbnail; a Vimeo
/// video as a plain link. Anything else embedded is left out.
void _writeVideo(dom.Element frame, _Writer out) {
  final src = frame.attributes['src'];
  final youTube = youTubeIdOf(src);
  if (youTube != null) {
    out.write('<a class="video-link" '
        'href="https://www.youtube.com/watch?v=$youTube" '
        'rel="nofollow noopener" target="_blank">');
    out.writeUncounted('<img src="https://i.ytimg.com/vi/$youTube/hqdefault.jpg" '
        'alt="Video on YouTube" loading="lazy" decoding="async" '
        'referrerpolicy="no-referrer">');
    out.write('</a>');
    return;
  }
  final vimeo = vimeoIdOf(src);
  if (vimeo != null) {
    out.write('<p><a href="https://vimeo.com/$vimeo" rel="nofollow noopener" '
        'target="_blank">Video on Vimeo</a></p>');
  }
}

/// Words with their runs of spaces, line breaks and non-breaking spaces made
/// into single spaces.
String _oneLine(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// A width or height the post gave a picture, when it is a plain whole number.
final RegExp _wholeNumber = RegExp(r'^\d{1,5}$');

/// The picture rebuilt from its address, alt text and size, or null when its
/// address is not a web address. Nothing else on the forum's tag is kept: no
/// class, no style, no event handler.
String? _pictureTag(dom.Element img) {
  final src = _webAddress(img.attributes['src']);
  if (src == null) return null;

  final tag = StringBuffer('<img src="${_escapeAttribute(src)}"');
  tag.write(' alt="${_escapeAttribute(img.attributes['alt']?.trim() ?? '')}"');
  for (final side in const ['width', 'height']) {
    final value = img.attributes[side]?.trim();
    if (value != null && _wholeNumber.hasMatch(value) && int.parse(value) > 0) {
      tag.write(' $side="$value"');
    }
  }
  tag.write(' loading="lazy" decoding="async" referrerpolicy="no-referrer">');
  return tag.toString();
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
  final tag = node.localName;
  if (tag == 'br') return '\n';
  final words = node.nodes.map(_plainWords).join();
  // Table cells, a fold's title and a quote's name each end where the next
  // thing starts, so they are kept apart.
  if (tag == 'td' || tag == 'th') return '$words ';
  if (tag == 'summary' || tag == 'cite' || tag == 'tr') return '$words\n';
  return words;
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
    out.write('<a href="${_escapeAttribute(url)}" rel="nofollow noopener" '
        'target="_blank">${_escape(url)}</a>${_escape(after)}');
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
