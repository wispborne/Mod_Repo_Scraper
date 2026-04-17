import 'package:html/parser.dart' as html_parser;
import 'package:logging/logging.dart';

import 'forum_constants.dart';
import 'legacy_category_map.dart';
import 'throttled_client.dart';

class ModIndexCategoriesResult {
  Map<int, String> mainTopicCategoryMap = {};
  Map<int, String> archivedTopicCategoryMap = {};
  Set<String> mainCategories = {};
  List<String> unknownLegacyCategories = [];
}

class QbModIndexScraper {
  final Logger _log;
  final ThrottledClient _client;

  static final RegExp _spaceRegex = RegExp(r'\s+');

  QbModIndexScraper(this._client, {Logger? logger})
      : _log = logger ?? Logger('QbModIndexScraper');

  Future<ModIndexCategoriesResult> scrape() async {
    final result = ModIndexCategoriesResult();
    const url = 'https://fractalsoftworks.com/forum/index.php?topic=177.0';

    try {
      var response = await _client.get(Uri.parse(url));
      if (response.statusCode != 200) {
        _log.warning('Mod index returned ${response.statusCode}');
        return result;
      }

      var topicLinks = _countTopicLinks(response.body);
      _log.info('Mod index initial topic-link count: $topicLinks');

      if (topicLinks < 20) {
        final allUrl = '$url;all';
        response = await _client.get(Uri.parse(allUrl));
        if (response.statusCode == 200) {
          topicLinks = _countTopicLinks(response.body);
          _log.info("Mod index ';all' topic-link count: $topicLinks");
        }
      }

      final doc = html_parser.parse(response.body);
      final allPosts = doc.querySelectorAll('#forumposts .post .inner');
      if (allPosts.isEmpty) {
        _log.warning('Mod index: no post bodies found');
        return result;
      }

      final mainMap = _extractTopicCategoriesFromPost(allPosts[0]);
      result.mainTopicCategoryMap = mainMap;
      result.mainCategories =
          mainMap.values.map((v) => v.toLowerCase()).toSet();

      for (var i = 1; i < allPosts.length; i++) {
        Map<int, String> archivedMap;
        try {
          archivedMap = _extractTopicCategoriesFromPost(allPosts[i]);
        } catch (e) {
          _log.warning('Failed to extract categories from post $i: $e');
          continue;
        }
        for (final entry in archivedMap.entries) {
          if (mainMap.containsKey(entry.key)) continue;

          var normalized = _normalizeCategory(entry.value);
          if (!result.mainCategories.contains(normalized.toLowerCase())) {
            // Try legacy map (case-insensitive lookup)
            final legacyMapped = _lookupLegacy(normalized);
            if (legacyMapped != null &&
                result.mainCategories.contains(legacyMapped.toLowerCase())) {
              normalized = legacyMapped;
            } else {
              result.unknownLegacyCategories.add(normalized);
              normalized = ForumConstants.uncategorizedCategory;
            }
          }

          result.archivedTopicCategoryMap[entry.key] = normalized;
        }
      }

      _log.info(
          'Parsed ${result.mainTopicCategoryMap.length} main-post topic categories');
      _log.info(
          'Parsed ${result.archivedTopicCategoryMap.length} archived-only topic categories');
      if (result.unknownLegacyCategories.isNotEmpty) {
        _log.warning(
            'Unmapped legacy categories: ${result.unknownLegacyCategories.toSet().join(', ')}');
      }

      return result;
    } catch (e) {
      _log.warning('Failed to scrape mod index categories: $e');
      return result;
    }
  }

  static String _normalizeCategory(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return ForumConstants.uncategorizedCategory;
    }
    final cleaned = _spaceRegex.hasMatch(raw.trim())
        ? raw.trim().replaceAll(_spaceRegex, ' ')
        : raw.trim();
    if (cleaned.isEmpty) return ForumConstants.uncategorizedCategory;
    if (ForumConstants.isLibraryCategoryName(cleaned)) {
      return ForumConstants.libraryCategory;
    }
    return cleaned;
  }

  static String? _lookupLegacy(String category) {
    for (final entry in legacyCategoryMap.entries) {
      if (entry.key.toLowerCase() == category.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  Map<int, String> _extractTopicCategoriesFromPost(dynamic postRoot) {
    final parsed = <int, String>{};

    // Find table.bbc_table > tbody > tr > td > strong (category headers)
    final categoryNodes = postRoot.querySelectorAll(
        'table.bbc_table tbody tr td strong');

    for (final categoryNode in categoryNodes) {
      final categoryRaw = categoryNode.text.trim();
      final category =
          _normalizeCategory(categoryRaw.replaceAll(RegExp(r':$'), '').trim());
      if (category.isEmpty) continue;

      // Find the next sibling ul.bbc_list
      var sibling = categoryNode.nextElementSibling;
      // Walk up to the td if needed, then look for next ul
      if (sibling == null) {
        final parentTd = categoryNode.parent;
        if (parentTd != null) {
          // Look through children of td for a ul.bbc_list after this strong
          var foundStrong = false;
          for (final child in parentTd.children) {
            if (child == categoryNode) {
              foundStrong = true;
              continue;
            }
            if (foundStrong &&
                child.localName == 'ul' &&
                (child.classes.contains('bbc_list'))) {
              sibling = child;
              break;
            }
          }
        }
      }

      if (sibling == null) continue;
      if (sibling.localName != 'ul') continue;

      final topicLinks = sibling.querySelectorAll('a');
      for (final link in topicLinks) {
        final href = link.attributes['href'];
        final topicId = ForumConstants.tryExtractTopicId(href);
        if (topicId == null) continue;
        parsed.putIfAbsent(topicId, () => category);
      }
    }

    return parsed;
  }

  int _countTopicLinks(String html) {
    final doc = html_parser.parse(html);
    final eqLinks = doc.querySelectorAll("a[href*='topic=']");
    final commaLinks = doc.querySelectorAll("a[href*='topic,']");
    return eqLinks.length + commaLinks.length;
  }
}
