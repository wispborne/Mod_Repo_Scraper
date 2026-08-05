import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import 'forum_constants.dart';
import 'legacy_category_map.dart';
import 'throttled_client.dart';

class ModIndexCategoriesResult {
  Map<int, String> mainTopicCategoryMap = {};
  Map<int, String> archivedTopicCategoryMap = {};
  Set<String> mainCategories = {};
  Set<String> mainCategoriesLower = {};
  List<String> unknownLegacyCategories = [];
}

class QbModIndexScraper {
  final Logger _log;
  final ThrottledClient _client;

  static final RegExp _spaceRegex = RegExp(r'\s+');

  QbModIndexScraper(this._client, {Logger? logger}) : _log = logger ?? Logger('QbModIndexScraper');

  Future<ModIndexCategoriesResult> scrape() async {
    final result = ModIndexCategoriesResult();
    const url = ForumConstants.modIndexUrl;

    try {
      var response = await _client.get(Uri.parse(url));
      if (response.statusCode != 200) {
        _log.warning('Mod index returned ${response.statusCode}');
        return result;
      }

      var doc = html_parser.parse(response.body);
      var topicLinks = _countTopicLinks(doc);
      _log.info('Mod index initial topic-link count: $topicLinks');

      if (topicLinks < 20) {
        final allUrl = '$url;all';
        response = await _client.get(Uri.parse(allUrl));
        if (response.statusCode == 200) {
          doc = html_parser.parse(response.body);
          topicLinks = _countTopicLinks(doc);
          _log.info("Mod index ';all' topic-link count: $topicLinks");
        }
      }

      final allPosts = doc.querySelectorAll('#forumposts .post .inner');
      if (allPosts.isEmpty) {
        _log.warning('Mod index: no post bodies found');
        return result;
      }

      final mainMap = extractTopicCategoriesFromPost(allPosts[0]);
      result.mainTopicCategoryMap = mainMap;
      result.mainCategories = mainMap.values.toSet();
      result.mainCategoriesLower = result.mainCategories.map((v) => v.toLowerCase()).toSet();

      for (var i = 1; i < allPosts.length; i++) {
        Map<int, String> archivedMap;
        try {
          archivedMap = extractTopicCategoriesFromPost(allPosts[i]);
        } catch (e) {
          _log.warning('Failed to extract categories from post $i: $e');
          continue;
        }
        for (final entry in archivedMap.entries) {
          if (mainMap.containsKey(entry.key)) continue;

          final normalized = _normalizeCategory(entry.value);
          final current = currentCategoryName(normalized, result.mainCategories);
          if (current == null) {
            result.unknownLegacyCategories.add(normalized);
          }

          result.archivedTopicCategoryMap[entry.key] = current ?? ForumConstants.uncategorizedCategory;
        }
      }

      _log.info('Parsed ${result.mainTopicCategoryMap.length} main-post topic categories');
      _log.info('Parsed ${result.archivedTopicCategoryMap.length} archived-only topic categories');

      final distinctCategories = result.mainCategories.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      _log.info('Mod index distinct categories: ${distinctCategories.join(', ')}');

      final sampleEntries = result.mainTopicCategoryMap.entries.take(10).map((e) => '${e.key}:${e.value}').join('; ');
      _log.info('Mod index sample topic-category mappings: $sampleEntries');

      if (result.unknownLegacyCategories.isNotEmpty) {
        final deduped = result.unknownLegacyCategories.map((s) => s.toLowerCase()).toSet().toList()..sort();
        _log.warning(
            'Unmapped legacy categories (update lib/bot/scraper/qb/legacy_category_map.dart): ${deduped.join(', ')}');
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
    final cleaned = _spaceRegex.hasMatch(raw.trim()) ? raw.trim().replaceAll(_spaceRegex, ' ') : raw.trim();
    if (cleaned.isEmpty) return ForumConstants.uncategorizedCategory;
    if (ForumConstants.isLibraryCategoryName(cleaned)) {
      return ForumConstants.libraryCategory;
    }
    return cleaned;
  }

  @visibleForTesting
  static Map<int, String> extractTopicCategoriesFromPost(Element postRoot) {
    final parsed = <int, String>{};

    // Find table.bbc_table > tbody > tr > td > strong (category headers)
    final categoryNodes = postRoot.querySelectorAll('table.bbc_table > tbody > tr > td > strong');

    for (final categoryNode in categoryNodes) {
      final categoryRaw = categoryNode.text.trim();
      final category = _normalizeCategory(categoryRaw.replaceAll(RegExp(r':+$'), '').trim());
      if (category.isEmpty) continue;

      // Walk following siblings for the first ul.bbc_list.
      Element? sibling;
      for (Element? node = categoryNode.nextElementSibling; node != null; node = node.nextElementSibling) {
        if (node.localName == 'ul' && node.classes.contains('bbc_list')) {
          sibling = node;
          break;
        }
      }

      if (sibling == null) continue;

      final topicLinks = sibling.querySelectorAll("a[href*='topic='], a[href*='topic,'], a[href*='topic/']");
      for (final link in topicLinks) {
        final href = link.attributes['href'];
        final topicId = ForumConstants.tryExtractTopicId(href);
        if (topicId == null) continue;
        parsed.putIfAbsent(topicId, () => category);
      }
    }

    return parsed;
  }

  int _countTopicLinks(Document doc) {
    final eqLinks = doc.querySelectorAll("a[href*='topic=']");
    final commaLinks = doc.querySelectorAll("a[href*='topic,']");
    return eqLinks.length + commaLinks.length;
  }
}
