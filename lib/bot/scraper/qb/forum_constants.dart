import 'models/mod_detail.dart';

class ForumConstants {
  ForumConstants._();

  static const String forumHost = 'fractalsoftworks.com';
  static const String uncategorizedCategory = 'uncategorized';
  static const String boardUrl =
      'https://$forumHost/forum/index.php?board=8.';
  static const String lesserBoardUrl =
      'https://$forumHost/forum/index.php?board=3.';
  static const int lesserBoardMaxPages = 20;
  static const String libraryBoardUrl =
      'https://$forumHost/forum/index.php?board=9.';
  static const String libraryCategory = 'Libraries';
  static const String modIndexUrl =
      'https://$forumHost/forum/index.php?topic=177.0';

  static String topicUrl(int topicId) =>
      'https://$forumHost/forum/index.php?topic=$topicId.0';

  static bool isLibraryBoardBase(String? boardBaseUrl) =>
      boardBaseUrl != null &&
      boardBaseUrl.isNotEmpty &&
      boardBaseUrl.toLowerCase().startsWith(libraryBoardUrl.toLowerCase());

  static final RegExp _libraryTitlePrefix = RegExp(r'^\[\s*\d');

  static bool isLibraryThreadTitle(String? title) =>
      title != null && _libraryTitlePrefix.hasMatch(title.trimLeft());

  static bool isLibraryCategoryName(String? category) {
    if (category == null || category.trim().isEmpty) return false;
    final c = category.trim().toLowerCase();
    return c == 'library' || c == 'libraries';
  }

  static bool isStandaloneUtilityCategoryName(String? category) {
    if (category == null || category.trim().isEmpty) return false;
    final c = category.trim();
    if (c.toLowerCase().contains('standalone utilit')) return true;
    return c.toLowerCase() == 'utility mods';
  }

  static bool isForumHosted(String url) {
    if (url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;
    final host = uri.host.toLowerCase();
    return host == forumHost || host.endsWith('.$forumHost');
  }

  static final RegExp topicIdRegex =
      RegExp(r'(?:topic[=,/])(\d+)', caseSensitive: false);

  static final RegExp gameVersionRegex =
      RegExp(r'\[(\d+\.\d+[\w.\-]*)(?:[^\]]*)\]');

  static int? tryExtractTopicId(String? href) {
    if (href == null || href.trim().isEmpty) return null;
    final match = topicIdRegex.firstMatch(href);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Strips SMF's `PHPSESSID=<hex>` query parameter from a URL while preserving
  /// the rest of the query string verbatim (including SMF's semicolon-separated
  /// dlattach params, which Dart's `Uri.replace` would percent-encode).
  static String stripPhpSessId(String url) {
    if (url.isEmpty || !url.contains('PHPSESSID=')) return url;
    return url
        .replaceFirst(RegExp(r'\?PHPSESSID=[^&#]*&'), '?')
        .replaceFirst(RegExp(r'&PHPSESSID=[^&#]*'), '')
        .replaceFirst(RegExp(r'\?PHPSESSID=[^&#]*'), '');
  }

  static bool isWipTitle(String? title) =>
      title != null &&
      title.isNotEmpty &&
      title.toLowerCase().contains('wip');

  static bool isLesserBoardTopicTitle(String? title) {
    if (title == null || title.trim().isEmpty) return false;
    if (title.toLowerCase().contains('moved')) return false;
    return gameVersionRegex.hasMatch(title);
  }

  static String guessCategoryFromTitle(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('faction')) return 'Faction Mods';
    if (lower.contains('portrait')) return 'Portrait Packs';
    if (lower.contains('flag')) return 'Flag Packs';
    return uncategorizedCategory;
  }

  static bool hasFileHostingLinks(List<LinkRef> links) {
    for (final l in links) {
      if (l.url.trim().isEmpty) continue;
      final uri = Uri.tryParse(l.url.trim());
      if (uri == null) continue;
      if (uri.scheme != 'http' && uri.scheme != 'https') continue;
      if (isForumHosted(l.url)) continue;
      final host = uri.host.toLowerCase();
      if (host.contains('nexusmods.com')) continue;
      if (_isYoutubeHost(host)) continue;
      return true;
    }
    return false;
  }

  static bool _isYoutubeHost(String host) {
    if (host.isEmpty) return false;
    return host == 'youtu.be' ||
        host.endsWith('.youtube.com') ||
        host == 'youtube.com';
  }
}
