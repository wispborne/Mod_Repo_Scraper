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

  static String processHtml(String html) {
    var processed = _addTargetBlankToExternalLinks(html);
    processed = _stripSmfArtifacts(processed);
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
