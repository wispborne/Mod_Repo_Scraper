import 'post_html.dart';

/// A Discord post's markdown turned into the same small set of tags a forum
/// post is published with, or null when nothing readable is left.
///
/// Discord writes `**bold**`, `# headings`, `- lists`, `> quotes`, code fences
/// and `[words](links)`. Shown as plain text, a post reads as a page of
/// asterisks. The HTML built here is then passed through [cleanPostHtml], so a
/// Discord post can never carry a tag or an address a forum post could not.
///
/// What has no place on a web page is dropped: mentions of a person, a role or
/// a channel are only numbers outside Discord. A custom emoji keeps its name
/// (`:name:`), and a timestamp becomes its day. An inline spoiler (`||…||`) is
/// shown as plain words, since the site has no way to hide part of a line.
String? discordMarkdownAsHtml(String? markdown) {
  final source = markdown?.replaceAll('\r\n', '\n').trim();
  if (source == null || source.isEmpty) return null;
  return cleanPostHtml(_Blocks(source.split('\n')).write());
}

/// Reads the post a line at a time and writes each block: code, headings,
/// quotes, lists and paragraphs.
class _Blocks {
  final List<String> lines;
  final StringBuffer out = StringBuffer();
  final List<String> paragraph = [];
  int at = 0;

  _Blocks(this.lines);

  static final RegExp _heading = RegExp(r'^(#{1,3})\s+(.+)$');
  static final RegExp _subtext = RegExp(r'^-#\s+(.+)$');
  static final RegExp _listItem = RegExp(r'^(\s*)([-*•]|\d+[.)])\s+(.*)$');
  static final RegExp _quote = RegExp(r'^>\s?(.*)$');
  static final RegExp _quoteToTheEnd = RegExp(r'^>>>\s?(.*)$');

  String write() {
    while (at < lines.length) {
      final line = lines[at];
      final trimmed = line.trim();

      if (trimmed.startsWith('```')) {
        _flushParagraph();
        _code();
        continue;
      }
      if (trimmed.isEmpty) {
        _flushParagraph();
        at++;
        continue;
      }
      final heading = _heading.firstMatch(trimmed);
      if (heading != null) {
        _flushParagraph();
        // Discord's biggest heading is still a heading inside a post, so the
        // three sizes start below the page's own.
        final tag = 'h${heading.group(1)!.length + 2}';
        out.write('<$tag>${_inline(heading.group(2)!)}</$tag>');
        at++;
        continue;
      }
      final subtext = _subtext.firstMatch(trimmed);
      if (subtext != null) {
        _flushParagraph();
        out.write('<p>${_inline(subtext.group(1)!)}</p>');
        at++;
        continue;
      }
      final toTheEnd = _quoteToTheEnd.firstMatch(line);
      if (toTheEnd != null) {
        _flushParagraph();
        final rest = [toTheEnd.group(1)!, ...lines.sublist(at + 1)];
        at = lines.length;
        out.write('<blockquote>${_Blocks(rest).write()}</blockquote>');
        continue;
      }
      if (_quote.hasMatch(line)) {
        _flushParagraph();
        final quoted = <String>[];
        while (at < lines.length) {
          final match = _quote.firstMatch(lines[at]);
          if (match == null) break;
          quoted.add(match.group(1)!);
          at++;
        }
        out.write('<blockquote>${_Blocks(quoted).write()}</blockquote>');
        continue;
      }
      if (_listItem.hasMatch(line)) {
        _flushParagraph();
        _list();
        continue;
      }

      paragraph.add(trimmed);
      at++;
    }
    _flushParagraph();
    return out.toString();
  }

  void _flushParagraph() {
    if (paragraph.isEmpty) return;
    out.write('<p>${paragraph.map(_inline).join('<br>')}</p>');
    paragraph.clear();
  }

  /// A fenced code block. A fence can open and shut on one line ("```Lore```"),
  /// and a single word straight after the opening fence names the language and
  /// is not part of the code.
  void _code() {
    final first = lines[at].trim().substring(3);
    at++;

    final shut = first.indexOf('```');
    if (shut >= 0) {
      out.write('<pre><code>${_escape(first.substring(0, shut))}</code></pre>');
      _afterFence(first.substring(shut + 3).trim());
      return;
    }

    final held = <String>[];
    if (first.trim().isNotEmpty && !RegExp(r'^\w+$').hasMatch(first.trim())) {
      held.add(first);
    }
    while (at < lines.length) {
      final line = lines[at];
      at++;
      final end = line.indexOf('```');
      if (end >= 0) {
        if (line.substring(0, end).trim().isNotEmpty) held.add(line.substring(0, end));
        final after = line.substring(end + 3).trim();
        if (held.any((l) => l.trim().isNotEmpty)) {
          out.write('<pre><code>${_escape(held.join('\n'))}</code></pre>');
        }
        _afterFence(after);
        return;
      }
      held.add(line);
    }
    if (held.every((l) => l.trim().isEmpty)) return;
    out.write('<pre><code>${_escape(held.join('\n'))}</code></pre>');
  }

  /// Whatever follows a closing fence on the same line. Authors often shut one
  /// block and open the next with no line between ("``````diff"), so text that
  /// starts with a fence is read again as a new line rather than as words.
  void _afterFence(String after) {
    if (after.isEmpty) return;
    if (after.startsWith('```')) {
      at--;
      lines[at] = after;
      return;
    }
    paragraph.add(after);
  }

  /// A run of list lines. Deeper indents become a list inside the item above.
  void _list() {
    // Each open list: how far it is indented and whether it is numbered.
    final open = <({int indent, bool numbered})>[];
    var itemOpen = false;

    while (at < lines.length) {
      final match = _listItem.firstMatch(lines[at]);
      if (match == null) break;
      at++;
      final indent = match.group(1)!.replaceAll('\t', '    ').length;
      final numbered = !RegExp(r'^[-*•]$').hasMatch(match.group(2)!);
      final text = _inline(match.group(3)!);

      if (open.isEmpty || indent > open.last.indent) {
        out.write(numbered ? '<ol>' : '<ul>');
        open.add((indent: indent, numbered: numbered));
      } else {
        while (open.length > 1 && indent < open.last.indent) {
          out.write('</li>${open.removeLast().numbered ? '</ol>' : '</ul>'}');
        }
        out.write('</li>');
      }
      out.write('<li>$text');
      itemOpen = true;
    }
    if (itemOpen) out.write('</li>');
    while (open.isNotEmpty) {
      final list = open.removeLast();
      out.write(list.numbered ? '</ol>' : '</ul>');
      if (open.isNotEmpty) out.write('</li>');
    }
  }
}

/// Everything inside a line that must not be read as marks: inline code,
/// `[words](address)`, `<address>`, mentions, emoji, timestamps and bare
/// addresses, in that order of preference.
final RegExp _held = RegExp(
  r'(`{1,2})([^`]+?)\1'
  r'|\[([^\]\n]+)\]\(\s*<?(https?://[^\s)>]+)>?\s*\)'
  r'|<(https?://[^\s>]+)>'
  r'|<(?:@[!&]?|#)\d+>'
  r'|<a?:(\w+):\d+>'
  r'|<t:(\d+)(?::[tTdDfFR])?>'
  r'|https?://[^\s<>"\x27]+',
);

/// One line's marks — bold, italics, underline, strikethrough, spoilers —
/// written as tags.
String _inline(String text) {
  final kept = <String>[];
  String hold(String html) {
    kept.add(html);
    return '\u0000${kept.length - 1}\u0000';
  }

  final marked = text.replaceAllMapped(_held, (m) {
    final whole = m.group(0)!;
    if (m.group(2) != null) return hold('<code>${_escape(m.group(2)!)}</code>');
    if (m.group(4) != null) {
      return hold('<a href="${_escape(m.group(4)!)}">'
          '${_marks(_escape(m.group(3)!))}</a>');
    }
    if (m.group(5) != null) return hold(_escape(m.group(5)!));
    if (m.group(6) != null) return hold(':${m.group(6)}:');
    if (m.group(7) != null) {
      final seconds = int.tryParse(m.group(7)!);
      if (seconds == null) return '';
      final day = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
      return hold(day.toIso8601String().substring(0, 10));
    }
    if (whole.startsWith('<')) return ''; // a mention
    return hold(_escape(whole));
  });

  return _marks(_escape(marked))
      .replaceAllMapped(RegExp('\u0000(\\d+)\u0000'), (m) => kept[int.parse(m.group(1)!)]);
}

String _marks(String text) => text
    .replaceAllMapped(RegExp(r'\|\|(.+?)\|\|'), (m) => m.group(1)!)
    .replaceAllMapped(RegExp(r'\*\*\*(?!\s)(.+?)(?<!\s)\*\*\*'),
        (m) => '<strong><em>${m.group(1)}</em></strong>')
    .replaceAllMapped(RegExp(r'\*\*(?!\s)(.+?)(?<!\s)\*\*'),
        (m) => '<strong>${m.group(1)}</strong>')
    .replaceAllMapped(RegExp(r'__(?!\s)(.+?)(?<!\s)__'), (m) => '<u>${m.group(1)}</u>')
    .replaceAllMapped(RegExp(r'(?<![\w*])\*(?![\s*])(.+?)(?<![\s*])\*(?![\w*])'),
        (m) => '<em>${m.group(1)}</em>')
    .replaceAllMapped(RegExp(r'(?<!\w)_(?![\s_])(.+?)(?<![\s_])_(?!\w)'),
        (m) => '<em>${m.group(1)}</em>')
    .replaceAllMapped(RegExp(r'~~(?!\s)(.+?)(?<!\s)~~'), (m) => '<s>${m.group(1)}</s>');

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Whether [a] and [b] are the same words once spacing is set aside — how the
/// builder tells that a merged description is only the Discord post again.
bool sameWords(String? a, String? b) {
  if (a == null || b == null) return false;
  String squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return squash(a) == squash(b);
}
