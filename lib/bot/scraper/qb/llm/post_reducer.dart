import '../html_processor.dart';

/// A single link kept from the post: its URL, its anchor text, and whether the
/// scraper already flagged it downloadable.
typedef ReducedLink = ({String url, String text, bool isDownloadable});

/// The cleaned-up post sent to the model, plus the data used to verify its
/// answers.
class ReducedPost {
  /// Readable post text with HTML tags removed and special characters decoded.
  /// Spoiler-box contents are kept (unlike the regex link extractor, which
  /// strips them).
  final String text;

  /// Every `<a href>` in the post (including inside spoilers), url + anchor text.
  final List<ReducedLink> links;

  /// Every URL that appears in the post (anchor hrefs plus bare URLs in text),
  /// cleaned up so we can check whether a URL really appears in the post.
  final Set<String> urlSet;

  ReducedPost({
    required this.text,
    required this.links,
    required this.urlSet,
  });
}

/// Turns a post's HTML into the reduced form the LLM reads.
///
/// This reuses [HtmlProcessor] for cleanup only — [HtmlProcessor] does not hand
/// back "text plus links", so the reduction itself is done here.
class PostReducer {
  PostReducer._();

  static final RegExp _anchorRegex = RegExp(
    r'''<a\s+[^>]*?href\s*=\s*["']([^"']+)["'][^>]*?>(.*?)</a>''',
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _tagStrip = RegExp(r'<[^>]+>', dotAll: true);

  static final RegExp _imgTag =
      RegExp(r'<img\b[^>]*>', caseSensitive: false, dotAll: true);
  static final RegExp _imgAltAttr =
      RegExp(r'''alt\s*=\s*["']([^"']*)["']''', caseSensitive: false);

  static final RegExp _bareUrlRegex = RegExp(
    r'''https?://[^\s"'<>)\]]+''',
    caseSensitive: false,
  );

  static final RegExp _blockBreak = RegExp(
    r'</(?:p|div|li|tr|h[1-6]|blockquote)>|<br\s*/?>',
    caseSensitive: false,
  );

  static final RegExp _multiBlankLines = RegExp(r'\n{3,}');
  static final RegExp _trailingSpaces = RegExp(r'[ \t]+\n');

  static ReducedPost reduce(String contentHtml) {
    // Clean up forum leftovers and smileys. Safe to run more than once.
    final cleaned = HtmlProcessor.processHtml(contentHtml);

    // Collect links (including those inside spoiler boxes).
    final links = <ReducedLink>[];
    final seenLinks = <String>{};
    for (final m in _anchorRegex.allMatches(cleaned)) {
      final href = HtmlProcessor.decodeEntities(m.group(1)!.trim());
      if (href.isEmpty ||
          href.startsWith('#') ||
          href.startsWith('javascript:')) {
        continue;
      }
      final text = HtmlProcessor.decodeEntities(
              m.group(2)!.replaceAll(_tagStrip, '').trim())
          .trim();
      if (!seenLinks.add(href)) continue;
      links.add((url: href, text: text, isDownloadable: false));
    }

    // Build the reduced text: turn block-level tags into line breaks, strip the
    // rest, decode entities, tidy whitespace.
    var text = cleaned.replaceAll(_blockBreak, '\n');
    // Keep image alt text before dropping tags — license/version badges carry
    // their label there (e.g. alt="License: MIT").
    text = text.replaceAllMapped(_imgTag, (m) {
      final alt = _imgAltAttr.firstMatch(m.group(0)!);
      return alt != null && alt.group(1)!.trim().isNotEmpty
          ? ' ${alt.group(1)} '
          : ' ';
    });
    text = text.replaceAll(_tagStrip, ' ');
    text = HtmlProcessor.decodeEntities(text);
    text = text.replaceAll(_trailingSpaces, '\n');
    text = text.replaceAll(_multiBlankLines, '\n\n');
    text = text
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trimRight())
        .join('\n')
        .trim();

    // URLs in the post: link targets plus any bare URLs anywhere in the post.
    final urlSet = <String>{};
    for (final l in links) {
      urlSet.add(normalizeForMatching(l.url));
    }
    for (final m in _bareUrlRegex.allMatches(cleaned)) {
      urlSet.add(normalizeForMatching(
          HtmlProcessor.decodeEntities(m.group(0)!.trim())));
    }

    return ReducedPost(text: text, links: links, urlSet: urlSet);
  }

  /// Lowercases and strips a trailing slash so we can match links that
  /// differ only in case or a trailing slash.
  static String normalizeForMatching(String url) {
    var u = url.trim().toLowerCase();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}
