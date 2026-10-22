import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/forum_scraper.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/board_scraper.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/mod_index_scraper.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/throttled_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/topic_scraper.dart';
import 'package:test/test.dart';

/// The forum moved from SMF 2.0 to SMF 2.1.8 in October 2026. These pages are
/// cut down from the real ones, keeping the markup the scrapers read.

/// One topic on a board page, the way SMF 2.1 writes it.
String _boardRow(int topicId, String title, {bool pinned = false}) => '''
  <div class="windowbg${pinned ? ' sticky' : ''}">
    <div class="board_icon"><img src="https://fractalsoftworks.com/forum/Themes/default/images/post/xx.png" alt=""></div>
    <div class="info info_block">
      <div>
        <div class="icons floatright">${pinned ? '<span class="main_icons sticky"></span>' : ''}</div>
        <div class="message_index_title">
          <span class="preview bold_text" title="">
            <span id="msg_${topicId}1"><a href="https://fractalsoftworks.com/forum/index.php?topic=$topicId.0">$title</a></span>
          </span>
        </div>
        <p class="floatleft">
          Started by <a href="https://fractalsoftworks.com/forum/index.php?action=profile;u=7678" title="View the profile of Wispborne" class="preview">Wispborne</a>
        </p>
        <span id="pages${topicId}1" class="topic_pages"><span class="pages">Pages</span><a class="nav_page" href="https://fractalsoftworks.com/forum/index.php?topic=$topicId.0">1</a> <a class="nav_page" href="https://fractalsoftworks.com/forum/index.php?topic=$topicId.15">2</a></span>
      </div>
    </div>
    <div class="board_stats centertext">
      <p>Replies: 402<br>Views: 194,320</p>
    </div>
    <div class="lastpost">
      <p><a href="https://fractalsoftworks.com/forum/index.php?topic=$topicId.390#msg532323">October 13, 2026, 09:36:24 AM</a><br>by <a href="https://fractalsoftworks.com/forum/index.php?action=profile;u=11222">DemonicSquid</a></p>
    </div>
  </div>''';

String _boardPage(List<String> rows, {bool morePages = true}) => '''
<html><body>
  <div class="pagesection">
    <div class="pagelinks floatleft">
      <a href="#bot" class="button">Go Down</a>
      <span class="pages">Pages</span><span class="current_page">1</span>
      ${morePages ? '<a class="nav_page" href="https://fractalsoftworks.com/forum/index.php?board=8.20">2</a>' : ''}
    </div>
  </div>
  <div id="messageindex">
    <div id="topic_container">
${rows.join('\n')}
    </div>
  </div>
</body></html>''';

/// The start of the mod index post, the way SMF 2.1 writes it: `<b>` and `<i>`
/// where SMF 2.0 wrote `<strong>` and `<em>`.
const String _indexPost = '''
<html><body><div id="forumposts"><div class="windowbg"><div class="post"><div class="inner">
<table class="bbc_table"><tr><br /><td><b>Standalone Utilities:</b><br />These are clients and user-made programs.<br /><ul class="bbc_list"><br />&nbsp; <li>[<b>-</b>] <b><a href="https://fractalsoftworks.com/forum/index.php?topic=29674.0" class="bbc_link" target="_blank" rel="noopener">TriOS: Launcher/Mod Manager/Toolkit</a></b> by <i><b>Wispborne</b></i></li></ul><br /><b>Feature overhauls:</b><br />These mods drastically change how the game looks and plays.<br /><ul class="bbc_list"><br />&nbsp; <li>[<b><span style="color: blue;" class="bbc_color">0.98a</span></b>] <b><a href="https://fractalsoftworks.com/forum/index.php?topic=26307.0" class="bbc_link" target="_blank" rel="noopener">Ashes of The Domain</a></b> by <i><b>Kaysaar</b></i></li></ul></td></tr></table>
</div></div></div></div></body></html>''';

/// One post on a topic page, the way SMF 2.1 writes it.
String _topicPost(String author, String body, {String? lastEdit}) => '''
  <div class="windowbg" id="msg523707">
    <div class="post_wrapper">
      <div class="poster">
        <h4><a href="https://fractalsoftworks.com/forum/index.php?action=profile;u=2776" title="View the profile of $author">$author</a></h4>
        <ul class="user_info">
          <li class="avatar"><a href="#"><img class="avatar" src="https://fractalsoftworks.com/forum/custom_avatar/avatar_2776_1783242438.png" alt=""></a></li>
          <li class="icons"><img src="https://fractalsoftworks.com/forum/Themes/default/images/membericons/icon.png" alt="*"></li>
          <li class="postgroup">Lieutenant</li>
          <li class="postcount">Posts: 91</li>
          <li class="poster_ip">Logged</li>
        </ul>
      </div>
      <div class="postarea">
        <div class="keyinfo">
          <div class="postinfo">
            <a href="https://fractalsoftworks.com/forum/index.php?msg=523707" rel="nofollow" class="smalltext">June 26, 2026, 06:35:43 PM</a>
            <span class="spacer"></span>
            <span class="smalltext modified floatright${lastEdit == null ? '' : ' mvisible'}" id="modified_523707">${lastEdit == null ? '' : '<span class="lastedit">Last Edit</span>: $lastEdit'}
            </span>
          </div>
        </div>
        <div class="post">
          <div class="inner" data-msgid="523707" id="msg_523707">$body</div>
        </div>
      </div>
    </div>
  </div>''';

String _topicPage(List<String> posts) => '''
<html><body>
  <div id="display_head" class="information">
    <h2 class="display_title"><span id="top_subject">Computica's Faction Forks</span></h2>
  </div>
  <div id="forumposts"><form>
${posts.join('\n')}
  </form></div>
</body></html>''';

void main() {
  group('a board page', () {
    final doc = html_parser.parse(_boardPage([
      _boardRow(177, 'Mod Index (Categorized)', pinned: true),
      _boardRow(29674, 'TriOS: Starsector Launcher/Mod Manager/Toolkit', pinned: true),
      _boardRow(18751, '[0.98a] Arma Armatura v3.3.7'),
    ]));

    test('reads each topic\'s starter, replies, views and last post', () {
      final topics = QbBoardScraper.extractTopicsFromPage(doc);

      final arma = topics.singleWhere((t) => t.topicId == 18751);
      expect(arma.title, '[0.98a] Arma Armatura v3.3.7');
      expect(arma.gameVersion, '0.98a');
      expect(arma.author, 'Wispborne');
      expect(arma.replies, 402);
      expect(arma.views, 194320);
      expect(arma.lastPostDate, 'October 13, 2026, 09:36:24 AM');
      expect(arma.lastPostBy, 'DemonicSquid');
    });

    test('skips pinned threads unless the mod index lists them', () {
      final topics = QbBoardScraper.extractTopicsFromPage(
        doc,
        skipStickyTopics: true,
        pinnedTopicsToKeep: {29674},
      );

      expect(topics.map((t) => t.topicId), [29674, 18751]);
    });

    test('a topic\'s own page links do not count as more board pages', () {
      final lastPage = html_parser.parse(
          _boardPage([_boardRow(18751, 'Arma Armatura')], morePages: false));
      final firstPage = html_parser.parse(
          _boardPage([_boardRow(18751, 'Arma Armatura')]));

      expect(QbBoardScraper.hasPageLinks(firstPage), isTrue);
      expect(QbBoardScraper.hasPageLinks(lastPage), isFalse);
    });
  });

  group('the mod index', () {
    final doc = html_parser.parse(_indexPost);
    final post = doc.querySelector('#forumposts .post .inner')!;

    test('reads each line\'s heading, name, author and game version', () {
      final lines = QbModIndexScraper.extractIndexLinesFromPost(post);

      expect(lines.map((l) => l.$1), [29674, 26307]);
      final aotd = lines[1].$2;
      expect(aotd.name, 'Ashes of The Domain');
      expect(aotd.author, 'Kaysaar');
      expect(aotd.gameVersion, '0.98a');
      expect(aotd.category, 'Feature overhauls');
      expect(lines[0].$2.gameVersion, '-');
      expect(lines[0].$2.category, 'Standalone Utilities');
    });

    test('gives each topic its heading', () {
      expect(QbModIndexScraper.extractTopicCategoriesFromPost(post), {
        29674: 'Standalone Utilities',
        26307: 'Feature overhauls',
      });
    });

    test('the ModRepo forum scraper reads the same lines', () {
      final mods = ForumScraper.parseModIndex(doc);

      expect(mods.map((m) => m.name), ['TriOS: Launcher/Mod Manager/Toolkit', 'Ashes of The Domain']);
      expect(mods[1].authorsList, ['Kaysaar']);
      expect(mods[1].gameVersionReq, '0.98a');
      expect(mods[1].categories, ['Feature overhauls']);
    });
  });

  group('a topic page', () {
    Future<dynamic> scrape(String html) => QbTopicScraper(
          ThrottledClient(
              client: MockClient((req) async => http.Response(html, 200)),
              delayMs: 0),
          externalClient: MockClient((req) async => http.Response('', 200,
              headers: {'content-type': 'text/html'})),
          probeTimeout: const Duration(milliseconds: 100),
        ).scrapeTopic(35651);

    test('reads the author, their rank, the post date and the last edit', () async {
      final detail = await scrape(_topicPage([
        _topicPost('Computica', 'The forks.',
            lastEdit: 'July 16, 2026, 08:21:44 AM by Computica'),
      ]));

      expect(detail.title, "Computica's Faction Forks");
      expect(detail.author, 'Computica');
      expect(detail.authorTitle, 'Lieutenant');
      expect(detail.authorPostCount, 91);
      expect(detail.authorAvatarPath,
          'https://fractalsoftworks.com/forum/custom_avatar/avatar_2776_1783242438.png');
      expect(detail.postDate, 'June 26, 2026, 06:35:43 PM');
      expect(detail.lastEditDate, 'July 16, 2026, 08:21:44 AM by Computica');
      expect(detail.contentHtml.trim(), 'The forks.');
    });

    test('a post never edited has no last edit', () async {
      final detail = await scrape(_topicPage([_topicPost('Computica', 'The forks.')]));

      expect(detail.lastEditDate, isNull);
    });

    test('keeps the author\'s own follow-up posts', () async {
      final detail = await scrape(_topicPage([
        _topicPost('Computica', 'The forks.'),
        _topicPost('Computica', 'The downloads.'),
        _topicPost('Someone', 'Thanks!'),
      ]));

      expect(detail.extraPosts.map((p) => p.contentHtml.trim()), ['The downloads.']);
    });
  });
}
