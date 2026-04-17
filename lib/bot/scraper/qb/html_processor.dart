import 'forum_constants.dart';

class HtmlProcessor {
  HtmlProcessor();

  String processHtml(String html, int topicId) {
    var processed = html;

    // Add target="_blank" to external links
    processed = _addTargetBlankToExternalLinks(processed);

    // Strip SMF artifacts
    processed = _stripSmfArtifacts(processed);

    return processed;
  }

  static String _addTargetBlankToExternalLinks(String html) {
    final pattern = RegExp(
      r'<a\s+([^>]*?)href="(https?://(?!' +
          RegExp.escape(ForumConstants.forumHost) +
          r')[^"]+)"([^>]*?)>',
      caseSensitive: false,
      dotAll: true,
    );

    return html.replaceAllMapped(pattern, (match) {
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
    // Remove edit timestamps
    var result = html.replaceAll(
      RegExp(
        r'<span class="smalltext">\s*&laquo;.*?&raquo;\s*</span>',
        dotAll: true,
        caseSensitive: false,
      ),
      '',
    );

    // Also handle Unicode guillemets
    result = result.replaceAll(
      RegExp(
        r'<span class="smalltext">\s*\u00ab.*?\u00bb\s*</span>',
        dotAll: true,
        caseSensitive: false,
      ),
      '',
    );

    // Replace smiley imgs with alt text
    result = result.replaceAllMapped(
      RegExp(
        r'<img\s+[^>]*?src="[^"]*?/Smileys/[^"]*"[^>]*?>',
        caseSensitive: false,
        dotAll: true,
      ),
      (match) {
        final altMatch = RegExp(r'alt="([^"]*?)"', caseSensitive: false)
            .firstMatch(match.group(0)!);
        return altMatch != null ? altMatch.group(1)! : '';
      },
    );

    return result;
  }
}
