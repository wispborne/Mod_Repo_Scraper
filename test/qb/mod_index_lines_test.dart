import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/mod_index_scraper.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/scraper_engine.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/throttled_client.dart';
import 'package:test/test.dart';

/// One line as the forum writes it: [version] **name** by *author*.
String _line(String version, String name, int topicId, String author) =>
    '<li>[<strong><span class="bbc_color">$version</span></strong>] '
    '<strong><a class="bbc_link" href="https://fractalsoftworks.com/forum/index.php?PHPSESSID=abc&amp;topic=$topicId.0">$name</a></strong> '
    'by <em><strong>$author </strong></em></li>';

/// TriOS's line, which writes "[-]" with no colour span.
String _dashLine(String name, int topicId, String author) =>
    '<li>[<strong>-</strong>] '
    '<strong><a class="bbc_link" href="https://fractalsoftworks.com/forum/index.php?topic=$topicId.0">$name</a></strong> '
    'by <em><strong>$author</strong></em></li>';

String _section(String heading, List<String> lines) =>
    '<strong>$heading:</strong><br><ul class="bbc_list">${lines.join()}</ul>';

String _post(List<String> sections) =>
    '<div class="post"><div class="inner"><table class="bbc_table"><tbody><tr><td>'
    '${sections.join('<br>')}'
    '</td></tr></tbody></table></div></div>';

/// Enough filler lines that the scraper does not go back for the ";all" page.
List<String> _filler() => [for (var i = 0; i < 25; i++) _line('0.98a', 'Filler $i', 90000 + i, 'Someone')];

Future<ModIndexCategoriesResult> _scrape(List<String> posts) async {
  final page = '<html><body><div id="forumposts">${posts.join()}</div></body></html>';
  final client = ThrottledClient(client: MockClient((_) async => http.Response(page, 200)), delayMs: 0);
  return QbModIndexScraper(client).scrape();
}

void main() {
  test('a topic linked from three lines keeps all three, in index order', () async {
    final result = await _scrape([
      _post([
        _section('Faction Mods', [
          _line('0.98a', 'Midline Expansion', 21968, 'Yunru'),
          _line('0.98a', 'Pirate Collection', 21968, 'Yunru'),
        ]),
        _section('Miscellaneous Mods', [_line('0.98a', 'Yunru Mods', 21968, 'Yunru'), ..._filler()]),
      ]),
    ]);

    final lines = result.topicIndexLines[21968]!;
    expect(lines.map((l) => l.name), ['Midline Expansion', 'Pirate Collection', 'Yunru Mods']);
    expect(lines.map((l) => l.category), ['Faction Mods', 'Faction Mods', 'Miscellaneous Mods']);
    // The topic takes the first line's heading.
    expect(result.mainTopicCategoryMap[21968], 'Faction Mods');
  });

  test('a topic with one line keeps its name, author, game version and heading', () async {
    final result = await _scrape([
      _post([
        _section('Utility Mods', [_line('0.98a', 'Better Combat', 29877, 'willthefunperson'), ..._filler()]),
      ]),
    ]);

    final lines = result.topicIndexLines[29877]!;
    expect(lines, hasLength(1));
    expect(lines.single.name, 'Better Combat');
    expect(lines.single.author, 'willthefunperson');
    expect(lines.single.gameVersion, '0.98a');
    expect(lines.single.category, 'Utility Mods');
  });

  test('a repeated line under one heading is kept once, but the same name under two headings is kept twice',
      () async {
    final result = await _scrape([
      _post([
        _section('Faction Mods', [
          _line('0.98a', 'Exalted', 500, 'Someone'),
          _line('0.98a', 'Exalted', 500, 'Someone'),
        ]),
        _section('Ship Mods', [_line('0.98a', 'Exalted', 500, 'Someone'), ..._filler()]),
      ]),
    ]);

    final lines = result.topicIndexLines[500]!;
    expect(lines.map((l) => '${l.name} / ${l.category}'), ['Exalted / Faction Mods', 'Exalted / Ship Mods']);
  });

  test("today's index wins over an older post, so TriOS keeps its \"[-]\"", () async {
    final result = await _scrape([
      _post([
        _section('Standalone Utilities', [_dashLine('TriOS: Launcher/Mod Manager/Toolkit', 29674, 'Wispborne'), ..._filler()]),
      ]),
      _post([
        _section('Utility mods', [
          _line('0.97a', 'TriOS: Launcher/Mod Manager/Toolkit', 29674, 'Wispborne'),
          _line('0.97a', 'Only In The Old Post', 600, 'Old Author'),
        ]),
      ]),
    ]);

    final trios = result.topicIndexLines[29674]!;
    expect(trios, hasLength(1));
    expect(trios.single.gameVersion, '-');

    // The older post still adds the topics today's index leaves out.
    final old = result.topicIndexLines[600]!;
    expect(old.single.name, 'Only In The Old Post');
    expect(old.single.gameVersion, '0.97a');
  });

  test('topics the index lists that no board gave and the store lacks are fetched', () async {
    final result = await _scrape([
      _post([
        _section('Faction Mods', [
          _line('0.98a', 'On A Board', 1, 'A'),
          _line('0.98a', 'Already Stored', 2, 'B'),
          _line('0.98a', 'Only In The Index', 3, 'C'),
          ..._filler(),
        ]),
      ]),
      _post([
        _section('Factions', [_line('0.95a', 'Only In An Old Post', 4, 'D')]),
      ]),
    ]);

    final toFetch = QbScraperEngine.indexTopicsToFetch(result, scraping: {1}, stored: {2});
    expect(toFetch, containsAll([3, 4]));
    expect(toFetch, isNot(contains(1)));
    expect(toFetch, isNot(contains(2)));
  });

  test('lines round-trip through the summary model', () {
    final summary = QbModSummary(
      topicId: 1,
      indexLines: const [QbIndexLine(name: 'A', author: 'B', gameVersion: '0.98a', category: 'Faction Mods')],
    );
    final back = QbModSummaryMapper.fromMap(summary.toMap());
    expect(back.indexLines!.single.name, 'A');
    // A topic outside the index writes no field at all.
    expect(QbModSummary(topicId: 2).toMap().containsKey('indexLines'), isFalse);
  });
}
