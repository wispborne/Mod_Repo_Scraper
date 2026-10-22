import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

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
    Set<int> pinnedTopicsToKeep = const {},
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
      final mods = extractTopicsFromPage(
        doc,
        topicTitleFilter: topicTitleFilter,
        skipStickyTopics: skipStickyTopics,
        pinnedTopicsToKeep: pinnedTopicsToKeep,
        log: _log,
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

      if (!hasPageLinks(doc)) {
        _log.info('No more pages after page $pageIndex');
        break;
      }
    }

    _log.info(
        'Board scrape complete: ${allMods.length} topics across ${pageIndex + 1} pages');
    return allMods;
  }

  /// The topics listed on one board page.
  ///
  /// Pinned threads are skipped when [skipStickyTopics] is set, because most of them are not mods (the
  /// mod index itself, the beginner's guide). A pinned thread in [pinnedTopicsToKeep] is kept anyway:
  /// the caller passes the topics today's mod index lists, which is how TriOS (topic 29674), pinned to
  /// the top of the Mods board, gets scraped.
  @visibleForTesting
  static List<QbModSummary> extractTopicsFromPage(
    Document doc, {
    bool Function(String)? topicTitleFilter,
    bool skipStickyTopics = false,
    Set<int> pinnedTopicsToKeep = const {},
    Logger? log,
  }) {
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

        // The topic's row. SMF 2.1 writes it as a `div.windowbg`; SMF 2.0
        // wrote a table row.
        final row = _topicRow(span);

        if (skipStickyTopics &&
            !pinnedTopicsToKeep.contains(topicId) &&
            row != null &&
            _isPinned(row)) {
          continue;
        }

        final versionMatch = ForumConstants.gameVersionRegex.firstMatch(title);
        final gameVersion = versionMatch?.group(1);

        var author = '';
        var replies = 0;
        var views = 0;
        String? lastPostDate;
        String? lastPostBy;
        if (row != null) {
          final starter = row.querySelector('td.starter a') ??
              row.querySelector('.info p.floatleft a');
          if (starter != null) author = starter.text.trim();

          final repliesCell = row.querySelector('td.replies');
          final viewsCell = row.querySelector('td.views');
          if (repliesCell != null || viewsCell != null) {
            replies = _count(repliesCell?.text);
            views = _count(viewsCell?.text);
          } else {
            // SMF 2.1: "Replies: 402<br>Views: 194,320" in one cell.
            final stats = row.querySelector('.board_stats')?.text ?? '';
            replies = _count(_repliesRegex.firstMatch(stats)?.group(1));
            views = _count(_viewsRegex.firstMatch(stats)?.group(1));
          }

          final lastpostCell = row.querySelector('td.lastpost') ??
              row.querySelector('div.lastpost');
          final smalltext = lastpostCell?.querySelector('.smalltext');
          if (smalltext != null) {
            final parts = smalltext.text
                .split('\n')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            if (parts.isNotEmpty) lastPostDate = parts[0];
            if (parts.length >= 2) {
              lastPostBy = parts[1].replaceFirst('by ', '').trim();
            }
          } else if (lastpostCell != null) {
            // SMF 2.1: `<a>date</a><br>by <a>name</a>`.
            final links = lastpostCell.querySelectorAll('a');
            if (links.isNotEmpty) lastPostDate = links[0].text.trim();
            if (links.length >= 2) lastPostBy = links[1].text.trim();
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
        log?.warning('Failed to parse topic span: $e');
      }
    }

    return mods;
  }

  /// Whether the page has links to the board's other pages. SMF 2.1 marks them
  /// `a.nav_page` and SMF 2.0 `a.navPages`. Each topic row has its own
  /// `a.nav_page` links to the topic's pages too, so only the board's own page
  /// bar counts.
  @visibleForTesting
  static bool hasPageLinks(Document doc) =>
      doc.querySelector('.pagelinks a.nav_page') != null ||
      doc.querySelector('a.navPages') != null;

  static final RegExp _repliesRegex = RegExp(r'Replies:\s*([\d,]+)');
  static final RegExp _viewsRegex = RegExp(r'Views:\s*([\d,]+)');

  static int _count(String? text) =>
      int.tryParse((text ?? '').trim().replaceAll(',', '')) ?? 0;

  static Element? _topicRow(Element span) {
    for (Node? node = span.parent; node != null; node = node.parent) {
      if (node is! Element) continue;
      if (node.localName == 'tr') return node;
      if (node.localName == 'div' && node.classes.contains('windowbg')) {
        return node;
      }
    }
    return null;
  }

  /// SMF 2.1 puts `sticky` on the row itself; SMF 2.0 showed a pin picture.
  static bool _isPinned(Element row) =>
      row.classes.contains('sticky') ||
      row.querySelector("img[src*='show_sticky.gif']") != null;
}
