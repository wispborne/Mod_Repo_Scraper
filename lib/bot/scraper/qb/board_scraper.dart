import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:logging/logging.dart';

import 'forum_constants.dart';
import 'models/mod_summary.dart';
import 'throttled_client.dart';

class QbBoardScraper {
  static const int topicsPerPage = 20;
  final Logger _log;
  final ThrottledClient _client;

  QbBoardScraper(this._client, {Logger? logger})
      : _log = logger ?? Logger('QbBoardScraper');

  Future<List<QbModSummary>> scrapeAllPages({
    int? maxPages,
    bool Function(List<QbModSummary> pageMods)? shouldContinueAfterPage,
    bool sortByLastPostDesc = false,
    String? boardBaseUrl,
    bool Function(String title)? topicTitleFilter,
  }) async {
    final baseUrl = boardBaseUrl ?? ForumConstants.boardUrl;
    final allMods = <QbModSummary>[];
    var pageIndex = 0;
    Set<int>? previousTopicIds;

    while (true) {
      final offset = pageIndex * topicsPerPage;
      final sortSuffix = sortByLastPostDesc ? ';sort=last_post;desc' : '';
      final url = '$baseUrl$offset$sortSuffix';
      _log.info('Scraping board page ${pageIndex + 1} (offset $offset): $url');

      final response = await _client.get(Uri.parse(url));
      if (response.statusCode != 200) {
        _log.warning('Board page returned ${response.statusCode}');
        break;
      }

      final doc = html_parser.parse(response.body);
      final skipStickyTopics = !ForumConstants.isLibraryBoardBase(baseUrl);
      final mods = _extractTopicsFromPage(
        doc,
        topicTitleFilter,
        skipStickyTopics,
      );
      _log.info('Found ${mods.length} topics on page ${pageIndex + 1}');

      if (mods.isEmpty) break;

      final topicIds = mods.map((m) => m.topicId).toSet();
      if (previousTopicIds != null &&
          topicIds.length == previousTopicIds.length &&
          topicIds.containsAll(previousTopicIds)) {
        _log.info(
            'Detected repeated last page at page ${pageIndex + 1}; stopping.');
        break;
      }
      previousTopicIds = topicIds;

      allMods.addAll(mods);

      if (shouldContinueAfterPage != null &&
          !shouldContinueAfterPage(mods)) {
        _log.info(
            'Early-stop triggered after page ${pageIndex + 1}.');
        break;
      }

      pageIndex++;

      if (maxPages != null && pageIndex >= maxPages) {
        _log.info('Reached max pages limit ($maxPages)');
        break;
      }

      if (doc.querySelectorAll('a.navPages').isEmpty) {
        _log.info('No more pages after page $pageIndex');
        break;
      }
    }

    _log.info(
        'Board scrape complete: ${allMods.length} topics across ${pageIndex + 1} pages');
    return allMods;
  }

  List<QbModSummary> _extractTopicsFromPage(
    Document doc,
    bool Function(String)? topicTitleFilter,
    bool skipStickyTopics,
  ) {
    final mods = <QbModSummary>[];

    // Each topic row contains a span[id^='msg_'] with the topic link
    final topicSpans =
        doc.querySelectorAll("span[id^='msg_']");

    for (final span in topicSpans) {
      try {
        final link = span.querySelector('a');
        if (link == null) continue;

        final title = link.text.trim();
        if (topicTitleFilter != null && !topicTitleFilter(title)) continue;

        final href = link.attributes['href'];
        final topicId = ForumConstants.tryExtractTopicId(href);
        if (topicId == null) continue;

        // Sticky detection: walk up to parent td, look for show_sticky.gif
        if (skipStickyTopics) {
          final parentTd = _findAncestor(span, 'td');
          if (parentTd != null) {
            final stickyImg = parentTd.querySelector("img[src*='show_sticky.gif']");
            if (stickyImg != null) continue;
          }
        }

        final versionMatch = ForumConstants.gameVersionRegex.firstMatch(title);
        final gameVersion = versionMatch?.group(1);

        // Navigate to parent row for other cells
        final parentRow = _findAncestor(span, 'tr');

        var author = '';
        if (parentRow != null) {
          final starterCell = parentRow.querySelector('td.starter a');
          if (starterCell != null) author = starterCell.text.trim();
        }

        var replies = 0;
        var views = 0;
        if (parentRow != null) {
          final repliesCell = parentRow.querySelector('td.replies');
          if (repliesCell != null) {
            replies = int.tryParse(
                    repliesCell.text.trim().replaceAll(',', '')) ??
                0;
          }
          final viewsCell = parentRow.querySelector('td.views');
          if (viewsCell != null) {
            views =
                int.tryParse(viewsCell.text.trim().replaceAll(',', '')) ??
                    0;
          }
        }

        String? lastPostDate;
        String? lastPostBy;
        if (parentRow != null) {
          final lastpostCell = parentRow.querySelector('td.lastpost');
          if (lastpostCell != null) {
            final smalltext = lastpostCell.querySelector('.smalltext');
            if (smalltext != null) {
              final lpText = smalltext.text;
              final parts = lpText
                  .split('\n')
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList();
              if (parts.isNotEmpty) lastPostDate = parts[0];
              if (parts.length >= 2) {
                lastPostBy = parts[1].replaceFirst('by ', '').trim();
              }
            }
          }
        }

        mods.add(QbModSummary(
          topicId: topicId,
          title: title,
          gameVersion: gameVersion,
          author: author,
          replies: replies,
          views: views,
          lastPostDate: lastPostDate,
          lastPostBy: lastPostBy,
          topicUrl: ForumConstants.topicUrl(topicId),
          scrapedAt: DateTime.now().toUtc(),
        ));
      } catch (e) {
        _log.warning('Failed to parse topic span: $e');
      }
    }

    return mods;
  }

  static Element? _findAncestor(Element element, String tagName) {
    Node? current = element.parent;
    while (current != null) {
      if (current is Element && current.localName == tagName) return current;
      current = current.parent;
    }
    return null;
  }
}
