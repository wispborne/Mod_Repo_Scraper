import 'forum_constants.dart';

class HtmlProcessor {
  HtmlProcessor._();

  static final RegExp _externalLinkRegex = RegExp(
    r'<a\s+([^>]*?)href="(https?://(?!' +
        RegExp.escape(ForumConstants.forumHost) +
        r')[^"]+)"([^>]*?)>',
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _smfEditGuillemetsAmp = RegExp(
    r'<span class="smalltext">\s*&laquo;.*?&raquo;\s*</span>',
    dotAll: true,
    caseSensitive: false,
  );

  static final RegExp _smfEditGuillemetsUnicode = RegExp(
    r'<span class="smalltext">\s*\u00ab.*?\u00bb\s*</span>',
    dotAll: true,
    caseSensitive: false,
  );

  static final RegExp _smfSmileyImg = RegExp(
    r'<img\s+[^>]*?src="[^"]*?/Smileys/[^"]*"[^>]*?>',
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _altAttr =
      RegExp(r'alt="([^"]*?)"', caseSensitive: false);

  // The forum glues a per-request `PHPSESSID=<hex>` onto some in-post links, so
  // the same unchanged post comes back with a different token every fetch. These
  // three patterns strip it out of post HTML. Unlike [ForumConstants.stripPhpSessId]
  // (which runs on a decoded URL), these run on the stored HTML, where the query
  // separator is the entity `&amp;`, so the token's value ends just before it.
  // The value stops at any query/HTML boundary: `&`, `#`, a quote, whitespace, or
  // an angle bracket.
  static const String _sessValue = r'''[^&#"'\s<>]*''';

  // `?PHPSESSID=xxx&amp;rest` → `?rest`: first query param, more follow. The
  // trailing separator is consumed and the leading `?` put back.
  static final RegExp _sessFirstParam =
      RegExp(r'\?PHPSESSID=' + _sessValue + r'(?:&amp;|&)', caseSensitive: false);
  // `...&amp;PHPSESSID=xxx...` → `......`: a later (or the last) query param.
  static final RegExp _sessOtherParam =
      RegExp(r'(?:&amp;|&)PHPSESSID=' + _sessValue, caseSensitive: false);
  // `?PHPSESSID=xxx` → ``: the only query param, so the `?` goes too.
  static final RegExp _sessOnlyParam =
      RegExp(r'\?PHPSESSID=' + _sessValue, caseSensitive: false);

  /// Removes the forum's `PHPSESSID=<hex>` session token from every link in a
  /// block of post HTML. Idempotent, and a no-op when there is no token. Keeping
  /// it out of the stored post matters twice over: the token is a session id we
  /// should not publish to clients, and because it changes on every fetch it
  /// makes an unchanged post look changed to the LLM freshness check, which would
  /// otherwise re-extract the same post again and again.
  static String stripSessionIds(String html) {
    if (!html.contains('PHPSESSID=')) return html;
    return html
        .replaceAll(_sessFirstParam, '?')
        .replaceAll(_sessOtherParam, '')
        .replaceAll(_sessOnlyParam, '');
  }

  static String processHtml(String html) {
    var processed = _addTargetBlankToExternalLinks(html);
    processed = _stripSmfArtifacts(processed);
    processed = stripSessionIds(processed);
    return processed;
  }

  static String decodeEntities(String text) => text
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&apos;', "'");

  static String _addTargetBlankToExternalLinks(String html) {
    return html.replaceAllMapped(_externalLinkRegex, (match) {
      final before = match.group(1)!;
      final href = match.group(2)!;
      final after = match.group(3)!;
      final full = before + after;

      if (full.toLowerCase().contains('target=')) {
        return match.group(0)!;
      }

      return '<a ${before}href="$href" target="_blank" rel="noopener"$after>';
    });
  }

  static String _stripSmfArtifacts(String html) {
    var result = html.replaceAll(_smfEditGuillemetsAmp, '');
    result = result.replaceAll(_smfEditGuillemetsUnicode, '');
    result = result.replaceAllMapped(_smfSmileyImg, (match) {
      final altMatch = _altAttr.firstMatch(match.group(0)!);
      return altMatch != null ? altMatch.group(1)! : '';
    });
    return result;
  }
}
