import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/download_resolver.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/post_extractor.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:test/test.dart';

/// The whole prompt a forum topic is sent, and the fingerprint its answer is
/// filed under, written down before the extractor learned to read Discord.
///
/// Every forum answer in the store is filed under that fingerprint. If reading
/// Discord changed one character of the forum prompt, every forum topic would
/// be paid for again. Regenerate the file only when the forum prompt is meant
/// to change (and `ExtractionPrompt.promptVersion` goes up with it):
/// `UPDATE_GOLDEN=1 dart test test/catalog/forum_prompt_unchanged_test.dart`.
const _golden = 'test/catalog/golden/forum_prompt.txt';

class _RecordingLlmClient implements LlmClient {
  final List<String> prompts = [];

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    prompts.add(request.userPrompt);
    return LlmResponse(content: '{"isMod":true,"mods":[]}', totalTokens: 1);
  }
}

QbModDetail _detail() => QbModDetail(
      topicId: 35651,
      title: "[0.98a] Computica's Faction Forks 1.2 (2026-01-01)",
      gameVersion: '0.98a',
      author: 'Computica',
      contentHtml: "<p>Computica's Faction Forks.</p>"
          '<p>Requires <a href="https://fractalsoftworks.com/forum/index.php?topic=5444.0">LazyLib</a>.</p>'
          '<img src="https://img.shields.io/badge/kwin-release-blue" alt="badge">'
          '<img src="https://i.imgur.com/shot.png" alt="A screenshot">',
      images: [
        ImageRef(originalUrl: 'https://img.shields.io/badge/kwin-release-blue', alt: 'badge'),
        ImageRef(originalUrl: 'https://i.imgur.com/shot.png', alt: 'A screenshot'),
      ],
      links: [
        LinkRef(url: 'https://fractalsoftworks.com/forum/index.php?topic=5444.0', text: 'LazyLib'),
      ],
      extraPosts: [
        QbForumPost(
          contentHtml: "<p>Kwin's Sector Industry Compilation</p>"
              '<a href="https://github.com/x/kwin/releases/download/1.2/kwin.zip">Download</a>',
          links: [
            LinkRef(
              url: 'https://github.com/x/kwin/releases/download/1.2/kwin.zip',
              text: 'Download',
              isExternal: true,
              isDownloadable: true,
            ),
          ],
        ),
      ],
    );

void main() {
  test("a forum topic's prompt and fingerprint are exactly what they were", () async {
    final dir = Directory.systemTemp.createTempSync('forum_prompt');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = LlmExtractionStore(dir.path, flushEveryN: 1000);
    final client = _RecordingLlmClient();
    final extractor = PostExtractor(
      client: client,
      store: store,
      resolver: QbDownloadResolver(
        client: MockClient((_) async => http.Response('', 200)),
        dataPath: dir.path,
      ),
      dataPath: dir.path,
    );

    await extractor.extractForTopic(_detail(), [
      DownloadCandidate(
        sourceUrl: 'https://github.com/x/kwin/releases/download/1.2/kwin.zip',
        resolvedUrl: 'https://github.com/x/kwin/releases/download/1.2/kwin.zip',
      ),
    ]);

    final actual = '${client.prompts.single}\n--- fingerprint ---\n${store.get(35651)!.fingerprint}\n';
    final file = File(_golden);
    if (Platform.environment['UPDATE_GOLDEN'] == '1') {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(actual);
    }
    expect(actual, file.readAsStringSync());
  });
}
