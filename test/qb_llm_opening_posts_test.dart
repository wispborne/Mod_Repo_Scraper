import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/download_resolver.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/post_extractor.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:test/test.dart';

/// An [LlmClient] that answers with the same canned reply every time and keeps
/// every prompt it was sent, so a test can read what the model was shown.
class _RecordingLlmClient implements LlmClient {
  final String answer;
  final List<String> prompts = [];

  _RecordingLlmClient(this.answer);

  int get callCount => prompts.length;

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    prompts.add(request.userPrompt);
    return LlmResponse(content: answer, totalTokens: 42);
  }
}

/// A thread whose downloads and write-ups sit in the author's second post —
/// the shape topic 35651 has.
QbModDetail _twoPostDetail({
  String firstPost = '<p>Computica\'s Faction Forks. What this is.</p>',
  String secondPost = '<p>Kwin\'s Sector Industry Compilation</p>'
      '<p>Adds four lore-rich corporations with unique ships and weapons.</p>'
      '<a href="https://github.com/x/kwin.zip">Download</a>',
}) =>
    QbModDetail(
      topicId: 35651,
      title: 'Computica\'s Faction Forks',
      contentHtml: firstPost,
      extraPosts: [QbForumPost(contentHtml: secondPost)],
    );

String _oneMod({
  String name = 'Kwin\'s Sector Industry Compilation',
  String url = 'https://github.com/x/kwin.zip',
  String? startsWith,
  String? endsWith,
}) {
  final anchors = startsWith == null || endsWith == null
      ? 'null'
      : '{"startsWith":"$startsWith","endsWith":"$endsWith"}';
  return '{"isMod":true,"mods":[{"name":"$name","role":"main",'
      '"downloads":[{"url":"$url","label":"Download","kind":"direct"}],'
      '"descriptionAnchors":$anchors}]}';
}

void main() {
  late Directory tempDir;
  late LlmExtractionStore store;
  late QbDownloadResolver resolver;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('llm_opening_posts');
    store = LlmExtractionStore(tempDir.path, flushEveryN: 1000);
    resolver = QbDownloadResolver(
      client: MockClient((req) async => http.Response('', 200)),
      dataPath: tempDir.path,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  PostExtractor makeExtractor(_RecordingLlmClient client, {int? maxInputChars}) =>
      PostExtractor(
        client: client,
        store: store,
        resolver: resolver,
        dataPath: tempDir.path,
        maxInputChars: maxInputChars,
      );

  List<LlmMod> modsOf(int id) => store.get(id)?.mods ?? const [];

  group('reading the author\'s opening run', () {
    test('the whole run goes to the model in one call', () async {
      final client = _RecordingLlmClient(_oneMod());
      await makeExtractor(client).extractForTopic(
        QbModDetail(
          topicId: 35651,
          contentHtml: '<p>First post.</p>',
          extraPosts: [
            QbForumPost(contentHtml: '<p>Second post.</p>'),
            QbForumPost(contentHtml: '<p>Third post.</p>'),
          ],
        ),
        [],
      );

      expect(client.callCount, 1, reason: 'one thread is one call');
      final prompt = client.prompts.single;
      expect(prompt, contains('First post.'));
      expect(prompt, contains('Second post.'));
      expect(prompt, contains('Third post.'));
      expect(prompt, contains('FOLLOW-UP POST 1 BY THE SAME AUTHOR'));
      expect(prompt, contains('FOLLOW-UP POST 2 BY THE SAME AUTHOR'));
    });

    test('a download only the second post has is kept', () async {
      final client = _RecordingLlmClient(_oneMod());
      await makeExtractor(client).extractForTopic(_twoPostDetail(), []);

      expect(modsOf(35651).single.downloads.map((d) => d.url),
          ['https://github.com/x/kwin.zip']);
    });

    test('a download in none of the posts is dropped', () async {
      final client = _RecordingLlmClient(
          _oneMod(url: 'https://invented.example/nothere.zip'));
      await makeExtractor(client).extractForTopic(_twoPostDetail(), []);

      expect(modsOf(35651), isEmpty,
          reason: 'nothing was grounded, so nothing is kept');
    });

    test('a thread with no follow-up posts reads as it always did', () async {
      final client = _RecordingLlmClient(_oneMod());
      await makeExtractor(client).extractForTopic(
        QbModDetail(
          topicId: 35651,
          contentHtml: '<a href="https://github.com/x/kwin.zip">Download</a>',
        ),
        [],
      );

      expect(client.prompts.single, isNot(contains('FOLLOW-UP POST')));
      expect(modsOf(35651).single.downloads, hasLength(1));
    });

    test('a changed second post is read again', () async {
      final first = _RecordingLlmClient(_oneMod());
      await makeExtractor(first).extractForTopic(_twoPostDetail(), []);
      expect(first.callCount, 1);

      // The same thread, same first post, one word different in the second.
      final again = _RecordingLlmClient(_oneMod());
      await makeExtractor(again).extractForTopic(
        _twoPostDetail(
          secondPost: '<p>Kwin\'s Sector Industry Compilation</p>'
              '<p>Adds five lore-rich corporations with unique ships.</p>'
              '<a href="https://github.com/x/kwin.zip">Download</a>',
        ),
        [],
      );
      expect(again.callCount, 1, reason: 'the changed post is paid for again');
    });

    test('an unchanged thread is not read again', () async {
      final first = _RecordingLlmClient(_oneMod());
      await makeExtractor(first).extractForTopic(_twoPostDetail(), []);

      final again = _RecordingLlmClient(_oneMod());
      await makeExtractor(again).extractForTopic(_twoPostDetail(), []);
      expect(again.callCount, 0, reason: 'the saved answer still fits');
    });
  });

  group('where a mod is described', () {
    test('anchors found in one post are kept', () async {
      final client = _RecordingLlmClient(_oneMod(
        startsWith: 'Adds four lore-rich corporations',
        endsWith: 'unique ships and weapons',
      ));
      await makeExtractor(client).extractForTopic(_twoPostDetail(), []);

      final anchors = modsOf(35651).single.descriptionAnchors;
      expect(anchors, isNotNull);
      expect(anchors!.startsWith, 'Adds four lore-rich corporations');
      expect(anchors.endsWith, 'unique ships and weapons');
    });

    test('anchors nobody wrote are dropped', () async {
      final client = _RecordingLlmClient(_oneMod(
        startsWith: 'A faction of space wizards',
        endsWith: 'who ride enormous cats',
      ));
      await makeExtractor(client).extractForTopic(_twoPostDetail(), []);

      expect(modsOf(35651).single.descriptionAnchors, isNull);
    });

    test('anchors that straddle two posts are dropped', () async {
      final client = _RecordingLlmClient(_oneMod(
        startsWith: 'Computica\'s Faction Forks. What this is',
        endsWith: 'unique ships and weapons',
      ));
      await makeExtractor(client).extractForTopic(_twoPostDetail(), []);

      expect(modsOf(35651).single.descriptionAnchors, isNull,
          reason: 'a description cut from two posts was never one description');
    });

    test('a very short anchor is dropped', () async {
      final client = _RecordingLlmClient(_oneMod(
        startsWith: 'Adds',
        endsWith: 'ships',
      ));
      await makeExtractor(client).extractForTopic(_twoPostDetail(), []);

      expect(modsOf(35651).single.descriptionAnchors, isNull);
    });
  });

  group('the input budget', () {
    test('the first post gives up the room, the follow-ups keep their words',
        () async {
      final longFirstPost = '<p>${'blah ' * 400}</p>';
      const secondPost = '<p>The downloads live here, every word of them.</p>'
          '<a href="https://github.com/x/kwin.zip">Download</a>';

      final client = _RecordingLlmClient(_oneMod());
      await makeExtractor(client, maxInputChars: 300).extractForTopic(
        _twoPostDetail(firstPost: longFirstPost, secondPost: secondPost),
        [],
      );

      final prompt = client.prompts.single;
      expect(prompt, contains('The downloads live here, every word of them.'),
          reason: 'the follow-up post is sent whole');
      expect('blah '.allMatches(prompt).length, lessThan(400),
          reason: 'the first post is the one that was cut');
    });

    test('a thread inside the budget is untouched', () async {
      final client = _RecordingLlmClient(_oneMod());
      await makeExtractor(client, maxInputChars: 100000)
          .extractForTopic(_twoPostDetail(), []);

      final prompt = client.prompts.single;
      expect(prompt, contains('Computica\'s Faction Forks. What this is.'));
      expect(prompt, contains('Adds four lore-rich corporations'));
    });
  });
}
