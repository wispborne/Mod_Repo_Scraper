import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:mod_repo_scraper/bot/scraper/qb/throttled_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/topic_scraper.dart';

/// Minimal forum HTML that exercises the first-post extraction path. The
/// <a> hrefs cover the five classification cases in the integration test.
String _buildTopicHtml({required List<String> hrefs}) {
  final anchors = hrefs
      .map((h) => '<a href="${h.replaceAll('"', '&quot;')}">link</a>')
      .join('\n');
  return '''
<html>
<head><title>Test Topic</title></head>
<body>
  <div id="top_subject">Topic: Test Mod  (Read 1 times)</div>
  <div id="forumposts">
    <div class="windowbg">
      <div class="poster">
        <h4><a href="#">Author</a></h4>
        <ul><li>Lieutenant</li><li>Posts: 42</li></ul>
      </div>
      <div class="post">
        <div class="inner">
          $anchors
        </div>
      </div>
    </div>
  </div>
</body>
</html>
''';
}

void main() {
  test(
      'TopicScraper classifies links via sync heuristic and async probe, '
      'falling back to false on timeout/non-download content-type',
      () async {
    const topicId = 12345;
    const zipUrl = 'https://cdn.example.com/mod.zip';
    const fileHostUrl = 'https://mega.nz/file/abc';
    const ambiguousAttachmentUrl = 'https://ambiguous.example.com/attach';
    const htmlUrl = 'https://ambiguous.example.com/page';
    const slowUrl = 'https://slow.example.com/path';

    final html = _buildTopicHtml(hrefs: [
      zipUrl,
      fileHostUrl,
      ambiguousAttachmentUrl,
      htmlUrl,
      slowUrl,
    ]);

    // Forum client: returns our crafted topic HTML.
    final forumInner = MockClient((req) async {
      expect(req.url.toString(), contains('topic=$topicId'));
      return http.Response(html, 200);
    });
    final throttled = ThrottledClient(client: forumInner, delayMs: 0);

    // External client: answers the async probes. Obvious links
    // (zip / mega.nz) should short-circuit and never hit this.
    final external = MockClient((req) async {
      final url = req.url.toString();
      if (url == zipUrl || url == fileHostUrl) {
        fail('Sync heuristic should have short-circuited $url');
      }
      if (url == ambiguousAttachmentUrl) {
        return http.Response('', 200, headers: {
          'content-disposition': 'attachment; filename="thing.bin"',
        });
      }
      if (url == htmlUrl) {
        return http.Response('<html></html>', 200, headers: {
          'content-type': 'text/html; charset=utf-8',
        });
      }
      if (url == slowUrl) {
        // Exceed the probeTimeout configured below.
        await Future<void>.delayed(const Duration(seconds: 2));
        return http.Response('', 200);
      }
      fail('Unexpected probe URL: $url');
    });

    final scraper = QbTopicScraper(
      throttled,
      externalClient: external,
      probeTimeout: const Duration(milliseconds: 100),
    );

    final detail = await scraper.scrapeTopic(topicId);

    expect(detail, isNotNull);
    final byUrl = {for (final l in detail!.links) l.url: l};

    expect(byUrl[zipUrl]!.isDownloadable, isTrue,
        reason: 'archive URL → sync heuristic → true');
    expect(byUrl[fileHostUrl]!.isDownloadable, isTrue,
        reason: 'known file-host → sync heuristic → true');
    expect(byUrl[ambiguousAttachmentUrl]!.isDownloadable, isTrue,
        reason: 'Content-Disposition: attachment → probe → true');
    expect(byUrl[htmlUrl]!.isDownloadable, isFalse,
        reason: 'text/html → probe → false');
    expect(byUrl[slowUrl]!.isDownloadable, isFalse,
        reason: 'probe timeout → false');
  });
}
