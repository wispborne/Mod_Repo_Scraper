import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/throttled_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/topic_scraper.dart';

/// One post on the page: who wrote it and what it holds.
typedef _Post = ({String author, String body});

/// A topic page with several posts, the way SMF writes one: the background
/// class alternates from post to post, and every post carries a poster block.
String _topicHtml(List<_Post> posts) {
  final blocks = <String>[];
  for (var i = 0; i < posts.length; i++) {
    final post = posts[i];
    final background = i.isEven ? 'windowbg' : 'windowbg2';
    blocks.add('''
    <div class="clearfix $background largepadding">
      <div class="poster">
        <h4><a href="#">${post.author}</a></h4>
        <ul><li>Lieutenant</li><li>Posts: 42</li></ul>
      </div>
      <div class="post">
        <div class="inner">${post.body}</div>
      </div>
    </div>''');
  }
  return '''
<html>
<head><title>Test Topic</title></head>
<body>
  <div id="top_subject">Topic: Test Mod  (Read 1 times)</div>
  <div id="forumposts">
${blocks.join('\n')}
  </div>
</body>
</html>
''';
}

Future<QbModDetail?> _scrape(List<_Post> posts) async {
  final forum = MockClient((req) async => http.Response(_topicHtml(posts), 200));
  final external = MockClient((req) async => http.Response('<html></html>', 200,
      headers: {'content-type': 'text/html; charset=utf-8'}));
  final scraper = QbTopicScraper(
    ThrottledClient(client: forum, delayMs: 0),
    externalClient: external,
    probeTimeout: const Duration(milliseconds: 100),
  );
  return scraper.scrapeTopic(35651);
}

void main() {
  group('the author\'s opening run of posts', () {
    test('a Downloads post by the same author is kept', () async {
      final detail = await _scrape([
        (author: 'Computica', body: '<p>What this is. No links here.</p>'),
        (
          author: 'Computica',
          body: '<p>Kwin</p><a href="https://example.com/kwin.zip">Get it</a>'
              '<a href="https://example.com/farsight.zip">And this</a>',
        ),
      ]);

      expect(detail, isNotNull);
      expect(detail!.links, isEmpty, reason: 'the first post has no links');
      expect(detail.extraPosts, hasLength(1));
      expect(detail.extraPosts.single.links.map((l) => l.url), [
        'https://example.com/kwin.zip',
        'https://example.com/farsight.zip',
      ]);
      expect(detail.allLinks.map((l) => l.url), [
        'https://example.com/kwin.zip',
        'https://example.com/farsight.zip',
      ]);
      expect(detail.extraPosts.single.links.every((l) => l.isDownloadable),
          isTrue);
    });

    test('a reply by somebody else ends the run', () async {
      final detail = await _scrape([
        (author: 'Computica', body: '<p>What this is.</p>'),
        (author: 'lchronosl', body: '<p>Nice work!</p>'),
        (
          author: 'Computica',
          body: '<a href="https://example.com/late.zip">Fixed build</a>',
        ),
      ]);

      expect(detail!.extraPosts, isEmpty);
      expect(detail.allLinks, isEmpty,
          reason: 'the author\'s answer after a reply is not read');
    });

    test('the run stops at ten follow-up posts', () async {
      final detail = await _scrape([
        for (var i = 0; i < 15; i++)
          (author: 'Computica', body: '<p>Post $i</p>'),
      ]);

      expect(detail!.extraPosts, hasLength(10));
    });

    test('a thread with one post has no follow-ups', () async {
      final detail = await _scrape([
        (
          author: 'Computica',
          body: '<a href="https://example.com/only.zip">Download</a>',
        ),
      ]);

      expect(detail!.extraPosts, isEmpty);
      expect(detail.allLinks, hasLength(1));
    });

    test('the first post keeps its own fields', () async {
      final detail = await _scrape([
        (
          author: 'Computica',
          body: '<p>The write-up.</p>'
              '<a href="https://example.com/first.zip">One</a>',
        ),
        (
          author: 'Computica',
          body: '<a href="https://example.com/second.zip">Two</a>',
        ),
      ]);

      expect(detail!.contentHtml, contains('The write-up.'));
      expect(detail.contentHtml, isNot(contains('second.zip')),
          reason: 'contentHtml is the first post alone');
      expect(detail.links.map((l) => l.url), ['https://example.com/first.zip']);
      expect(detail.allLinks.map((l) => l.url), [
        'https://example.com/first.zip',
        'https://example.com/second.zip',
      ]);
    });

    test('a link in both posts is listed once', () async {
      final detail = await _scrape([
        (
          author: 'Computica',
          body: '<a href="https://example.com/same.zip">One</a>',
        ),
        (
          author: 'Computica',
          body: '<a href="https://example.com/same.zip">Again</a>'
              '<a href="https://example.com/other.zip">Other</a>',
        ),
      ]);

      expect(detail!.allLinks.map((l) => l.url), [
        'https://example.com/same.zip',
        'https://example.com/other.zip',
      ]);
    });
  });

  group('reading a detail back', () {
    test('a file written before extra posts existed reads as none', () {
      final detail = QbModDetailMapper.fromMap({
        'topicId': 35651,
        'title': 'Test Mod',
        'author': 'Computica',
        'contentHtml': '<p>Hello</p>',
        'images': <dynamic>[],
        'links': <dynamic>[],
        'scrapedAt': '2026-08-25T00:00:00.000Z',
      });

      expect(detail.extraPosts, isEmpty);
      expect(detail.contentHtml, '<p>Hello</p>');
      expect(detail.openingPosts, hasLength(1));
    });

    test('extra posts survive a round trip through JSON', () {
      final detail = QbModDetail(
        topicId: 35651,
        contentHtml: '<p>First</p>',
        extraPosts: [
          QbForumPost(
            contentHtml: '<p>Downloads</p>',
            links: [LinkRef(url: 'https://example.com/a.zip', isExternal: true)],
            postDate: 'June 26, 2026, 06:50:19 PM',
          ),
        ],
      );

      final read = QbModDetailMapper.fromMap(detail.toMap());
      expect(read.extraPosts, hasLength(1));
      expect(read.extraPosts.single.contentHtml, '<p>Downloads</p>');
      expect(read.extraPosts.single.postDate, 'June 26, 2026, 06:50:19 PM');
      expect(read.openingPosts, hasLength(2));
    });
  });
}
