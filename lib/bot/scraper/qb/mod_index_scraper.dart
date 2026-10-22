import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import 'forum_constants.dart';
import 'legacy_category_map.dart';
import 'models/mod_summary.dart';
import 'throttled_client.dart';

class ModIndexCategoriesResult {
  Map<int, String> mainTopicCategoryMap = {};
  Map<int, String> archivedTopicCategoryMap = {};

  /// Every index line that links to each topic, in index order. A topic today's
  /// index lists only has today's lines; the older posts only fill in topics
  /// today's index leaves out. Otherwise an old "[0.97a]" would sit beside
  /// today's "[-]" (TriOS, topic 29674).
  Map<int, List<QbIndexLine>> topicIndexLines = {};

  /// Whether the index was read at all. A failed fetch gives an empty result,
  /// and that must not be read as "the index lists nothing".
  bool get isEmpty => mainTopicCategoryMap.isEmpty && archivedTopicCategoryMap.isEmpty;
  Set<String> mainCategories = {};
  Set<String> mainCategoriesLower = {};
  List<String> unknownLegacyCategories = [];
}

class QbModIndexScraper {
  final Logger _log;
  final ThrottledClient _client;

  static final RegExp _spaceRegex = RegExp(r'\s+');

  // SMF 2.1 writes bold as `<b>` and italics as `<i>`; SMF 2.0 wrote
  // `<strong>` and `<em>`. Both are read.
  static const String _headingSelector =
      'table.bbc_table > tbody > tr > td > strong, table.bbc_table > tbody > tr > td > b';
  static const String _authorSelector = 'em strong, i b';

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

      for (final (topicId, line) in extractIndexLinesFromPost(allPosts[0])) {
        _addLine(result.topicIndexLines, topicId, line);
      }

      // Older posts only add lines for topics today's index leaves out. They
      // sit oldest first below today's, so they are read newest first: a topic
      // that only an old post lists then leads with its most recent line.
      for (var i = allPosts.length - 1; i >= 1; i--) {
        try {
          for (final (topicId, line) in extractIndexLinesFromPost(allPosts[i])) {
            if (mainMap.containsKey(topicId)) continue;
            final current = currentCategoryName(line.category, result.mainCategories);
            _addLine(
              result.topicIndexLines,
              topicId,
              QbIndexLine(
                name: line.name,
                author: line.author,
                gameVersion: line.gameVersion,
                category: current ?? ForumConstants.uncategorizedCategory,
              ),
            );
          }
        } catch (e) {
          _log.warning('Failed to read index lines from post $i: $e');
        }
      }

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

  /// Adds [line] to [topicId]'s lines unless a line with the same name and
  /// heading is already there. The same name under two headings is kept twice.
  static void _addLine(Map<int, List<QbIndexLine>> lines, int topicId, QbIndexLine line) {
    final list = lines.putIfAbsent(topicId, () => []);
    final repeated = list.any((l) =>
        l.name.toLowerCase() == line.name.toLowerCase() &&
        l.category.toLowerCase() == line.category.toLowerCase());
    if (!repeated) list.add(line);
  }

  /// Every mod line in one index post, in the order the post lists them, paired
  /// with the topic it links to. Headings are found the same way as
  /// [extractTopicCategoriesFromPost]. A line is written by the forum as
  /// `[<strong>0.98a</strong>] <strong><a>Name</a></strong> by <em><strong>Author</strong></em>`.
  /// The category is the heading as written, tidied; mapping old names to
  /// today's is left to the caller.
  @visibleForTesting
  static List<(int, QbIndexLine)> extractIndexLinesFromPost(Element postRoot) {
    final lines = <(int, QbIndexLine)>[];
    for (final categoryNode in postRoot.querySelectorAll(_headingSelector)) {
      final category = _normalizeCategory(categoryNode.text.trim().replaceAll(RegExp(r':+$'), '').trim());
      if (category.isEmpty) continue;

      final list = _listAfter(categoryNode);
      if (list == null) continue;

      for (final item in list.querySelectorAll('li')) {
        final link = item.querySelector("a[href*='topic='], a[href*='topic,'], a[href*='topic/']");
        final topicId = ForumConstants.tryExtractTopicId(link?.attributes['href']);
        if (link == null || topicId == null) continue;
        final name = _tidy(link.text);
        if (name.isEmpty) continue;

        lines.add((
          topicId,
          QbIndexLine(
            name: name,
            author: _tidy(item.querySelector(_authorSelector)?.text ?? ''),
            gameVersion: _gameVersionOf(item, link),
            category: category,
          ),
        ));
      }
    }
    return lines;
  }

  /// The bracketed game version at the front of a line: the first bold text
  /// that comes before the link. TriOS's line writes "[-]" with no colour span,
  /// so the bold text is read rather than a span inside it.
  static String? _gameVersionOf(Element item, Element link) {
    for (final node in item.children) {
      if (node == link || node.contains(link)) break;
      if (node.localName == 'strong' || node.localName == 'b') {
        final text = _tidy(node.text);
        return text.isEmpty ? null : text;
      }
    }
    return null;
  }

  static String _tidy(String text) => text.trim().replaceAll(_spaceRegex, ' ');

  static Element? _listAfter(Element heading) {
    for (Element? node = heading.nextElementSibling; node != null; node = node.nextElementSibling) {
      if (node.localName == 'ul' && node.classes.contains('bbc_list')) return node;
    }
    return null;
  }

  @visibleForTesting
  static Map<int, String> extractTopicCategoriesFromPost(Element postRoot) {
    final parsed = <int, String>{};

    // Find table.bbc_table > tbody > tr > td > strong (category headers)
    final categoryNodes = postRoot.querySelectorAll(_headingSelector);

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

      // Only each line's own link, the one [extractIndexLinesFromPost] names
      // the mod from. Other links on a line are notes: an old line for New
      // Galactic Order links a "partial fix" post in topic 11402, a help
      // thread, and counting it made that thread a mod.
      for (final item in sibling.querySelectorAll('li')) {
        final link = item.querySelector("a[href*='topic='], a[href*='topic,'], a[href*='topic/']");
        final topicId = ForumConstants.tryExtractTopicId(link?.attributes['href']);
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
