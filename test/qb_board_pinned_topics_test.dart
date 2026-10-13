import 'package:html/parser.dart' as html_parser;
import 'package:mod_repo_scraper/bot/scraper/qb/board_scraper.dart';
import 'package:test/test.dart';

/// One row of a board page as the forum writes it. A pinned thread carries the sticky icon in its cell.
String _row(int topicId, String title, {bool pinned = false}) => '''
  <tr>
    <td class="subject">
      <div>
        ${pinned ? '<img src="https://fractalsoftworks.com/forum/Themes/default/images/icons/show_sticky.gif" alt="">' : ''}
        <span id="msg_$topicId"><a href="https://fractalsoftworks.com/forum/index.php?topic=$topicId.0">$title</a></span>
      </div>
    </td>
    <td class="starter"><a href="#">Someone</a></td>
  </tr>''';

void main() {
  group('pinned threads on a board page', () {
    final doc = html_parser.parse('''
      <table>
        ${_row(177, 'Mod Index (Categorized)', pinned: true)}
        ${_row(25974, 'Adding mods to your game: first steps', pinned: true)}
        ${_row(29674, 'TriOS: Starsector Launcher/Mod Manager/Toolkit', pinned: true)}
        ${_row(17103, '[0.98a] Better Colonies 1.91')}
      </table>
    ''');

    test('a pinned thread the mod index lists is kept; the other pinned threads are not', () {
      final topics = QbBoardScraper.extractTopicsFromPage(
        doc,
        skipStickyTopics: true,
        pinnedTopicsToKeep: {29674, 17103},
      );

      expect(topics.map((t) => t.topicId), [29674, 17103]);
    });

    test('with nothing to keep, every pinned thread is skipped as before', () {
      final topics = QbBoardScraper.extractTopicsFromPage(doc, skipStickyTopics: true);

      expect(topics.map((t) => t.topicId), [17103]);
    });
  });
}
