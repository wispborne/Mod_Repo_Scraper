import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/download_resolver.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/openai_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/picture_caption_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/picture_captioner.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/post_extractor.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/throttled_client.dart';
import 'package:mod_repo_scraper/catalog/source_post.dart';
import 'package:test/test.dart';

const _banner = 'https://i.imgur.com/banner.png';
const _shot = 'https://i.imgur.com/shot.png';
const _dead = 'https://i.imgur.com/gone.png';
const _patreon = 'https://c5.patreon.com/external/logo/become_a_patron_button.png';

/// Answers picture requests and extraction requests, and remembers both.
class _FakeModel implements LlmClient {
  final List<LlmRequest> pictureCalls = [];
  final List<LlmRequest> readCalls = [];

  /// Addresses the "server" cannot fetch. A call holding any of them fails.
  final Set<String> dead;

  /// When set, every picture call fails with this.
  final LlmException? pictureFailure;

  _FakeModel({this.dead = const {}, this.pictureFailure});

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    if (request.imageUrls.isEmpty) {
      readCalls.add(request);
      return const LlmResponse(content: '{"isMod":true,"mods":[]}', model: 'm');
    }
    pictureCalls.add(request);
    if (pictureFailure != null) throw pictureFailure!;
    if (request.imageUrls.any(dead.contains)) {
      throw LlmException('Error response (status 400): {"error": {"message": '
          '"the image URL could not be read: HTTP Error 404: Not Found"}}');
    }
    return LlmResponse(
      model: 'm',
      endpoint: 'http://local/v1',
      content: jsonEncode({
        'pictures': [
          for (final (i, url) in request.imageUrls.indexed)
            {
              'number': i + 1,
              'kind': url == _banner ? 'banner' : 'screenshot',
              'caption': 'Picture ${url.split('/').last}',
            },
        ],
      }),
    );
  }
}

SourcePost _post(List<String> pictures) => SourcePost.fromForumDetail(QbModDetail(
      topicId: 18011,
      title: 'Industrial.Evolution',
      author: 'SirHartley',
      contentHtml: '<p>Industrial Evolution adds industries.</p>',
      images: [for (final url in pictures) ImageRef(originalUrl: url)],
    ));

void main() {
  late Directory dir;
  late PictureCaptionStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('captions');
    store = PictureCaptionStore(dir.path, flushEveryN: 1000);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  group('the caption store', () {
    test('a Discord picture is filed without its signature', () {
      expect(
        PictureCaptionStore.keyFor(
            'https://cdn.discordapp.com/attachments/1/2/icon.png?ex=6ad88799&is=6ad73619&hm=abc&'),
        'https://cdn.discordapp.com/attachments/1/2/icon.png',
      );
      expect(PictureCaptionStore.keyFor(' $_shot '), _shot);
      expect(PictureCaptionStore.keyFor('https://i.imgur.com/a.png?1'), 'https://i.imgur.com/a.png?1',
          reason: 'only a Discord address loses its query');
    });

    test('saved captions come back after a reload', () async {
      await store.putCaption(_shot, const PictureCaption(kind: PictureKind.screenshot, caption: 'A fleet.'));
      await store.putUnreadable(_dead, 'not found');
      await store.flush();

      final again = PictureCaptionStore(dir.path)..load();
      await again.load();
      expect(again.captionFor(_shot)?.promptText, 'screenshot: A fleet.');
      expect(again.captionFor(_dead), isNull);
      expect(again.isDone(_dead), isTrue);
    });

    test('a picture that could not be read is tried again after a month', () async {
      final then = DateTime.utc(2026, 9, 1);
      await store.putUnreadable(_dead, 'not found', now: then);
      expect(store.isDone(_dead, now: then.add(const Duration(days: 29))), isTrue);
      expect(store.isDone(_dead, now: then.add(const Duration(days: 31))), isFalse);
    });

    test('an expired Discord link is known to be expired', () {
      final now = DateTime.utc(2026, 10, 21, 12);
      const expired = 'https://cdn.discordapp.com/attachments/1/2/a.png?ex=6ad88799&is=1&hm=2';
      expect(PictureCaptionStore.discordLinkExpired(expired, now: now), isTrue);
      expect(PictureCaptionStore.discordLinkExpired(expired, now: DateTime.utc(2026, 10, 21, 9)), isFalse);
      expect(PictureCaptionStore.discordLinkExpired('https://cdn.discordapp.com/attachments/1/2/a.png', now: now),
          isTrue, reason: 'Discord has not answered unsigned addresses since 2024');
      expect(PictureCaptionStore.discordLinkExpired(_shot, now: now), isFalse);
    });
  });

  group('the captioner', () {
    test('all of a post\'s pictures go in one call, and each answer is saved', () async {
      final model = _FakeModel();
      final captioner = PictureCaptioner(client: model, store: store);
      final post = _post([_banner, _patreon, _shot]);

      final pictures = captioner.picturesToLookAt(post);
      expect(pictures, [_banner, _shot], reason: 'a Patreon button is never looked at, nor shown to the model');

      expect(await captioner.lookAt(pictures, where: 'topic 18011'), 1);
      expect(model.pictureCalls.single.imageUrls, [_banner, _shot]);
      expect(store.captionFor(_banner)?.kind, PictureKind.banner);
      expect(store.captionFor(_shot)?.caption, 'Picture shot.png');
      expect(captioner.picturesToLookAt(post), isEmpty, reason: 'each picture is looked at once');
    });

    test('a dead picture spoils the call, so each is asked about alone', () async {
      final model = _FakeModel(dead: {_dead});
      final captioner = PictureCaptioner(client: model, store: store);

      final calls = await captioner.lookAt([_banner, _dead, _shot], where: 'topic 18011');

      expect(calls, 4);
      expect(store.captionFor(_banner), isNotNull);
      expect(store.captionFor(_shot), isNotNull);
      expect(store.captionFor(_dead), isNull);
      expect(store.isDone(_dead), isTrue, reason: 'it is not tried again next run');
      expect(captioner.hasStopped, isFalse, reason: 'a dead picture is not the model failing');
    });

    test('a server that refuses pictures marks nothing dead and is stopped after five tries', () async {
      final model = _FakeModel(
          pictureFailure: LlmException('Error response (status 400): image input is not supported'));
      final captioner = PictureCaptioner(client: model, store: store);

      for (var i = 0; i < 6; i++) {
        await captioner.lookAt(['https://i.imgur.com/$i.png'], where: 'topic $i');
      }

      expect(model.pictureCalls, hasLength(5));
      expect(captioner.hasStopped, isTrue);
      expect(store.length, 0, reason: 'no picture is blamed for the server');
    });

    test('a host that is busy today is asked again next run, not marked dead', () async {
      final model = _FakeModel(
          pictureFailure: LlmException('Error response (status 400): {"error": {"message": '
              '"the image URL could not be read: HTTP Error 503: Service Unavailable"}}'));
      final captioner = PictureCaptioner(client: model, store: store);
      await captioner.lookAt([_shot], where: 'topic 32915');
      expect(store.isDone(_shot), isFalse);
      expect(captioner.hasStopped, isFalse);
    });

    test('a bad request that is not about a picture blames no picture', () async {
      final model = _FakeModel(
          pictureFailure: LlmException('Error response (status 400): model "x" not found'));
      final captioner = PictureCaptioner(client: model, store: store);
      await captioner.lookAt([_banner, _shot], where: 'topic 1');
      expect(model.pictureCalls, hasLength(1), reason: 'not split up either');
      expect(store.length, 0);
    });

    test('an address that is not a web address is never sent', () {
      final captioner = PictureCaptioner(client: _FakeModel(), store: store);
      // Topic 29956: a Markdown link inside a picture tag.
      final post = _post(['http://[imgur](https://imgur.com/ioWzjGb)', 'ftp://x.com/a.png', 'https:///a.png', _shot]);
      expect(captioner.picturesToLookAt(post), [_shot]);
    });

    test('a server that calls an address invalid has each picture asked about alone', () async {
      final model = _FakeModel(
          pictureFailure: LlmException('Error response (status 400): {"error": {"type": '
              '"invalid_request_error", "message": "Invalid IPv6 URL"}}'));
      final captioner = PictureCaptioner(client: model, store: store);
      await captioner.lookAt([_banner, _shot], where: 'topic 29956');
      expect(model.pictureCalls, hasLength(3));
      expect(store.isDone(_banner), isTrue);
      expect(captioner.hasStopped, isFalse);
    });

    test('a Discord picture whose link has run out is left for the next Discord scrape', () {
      final captioner = PictureCaptioner(client: _FakeModel(), store: store);
      final post = _post(['https://cdn.discordapp.com/attachments/1/2/a.png?ex=6ad88799&is=1&hm=2']);
      expect(captioner.picturesToLookAt(post, now: DateTime.utc(2026, 10, 22)), isEmpty);
      expect(captioner.picturesToLookAt(post, now: DateTime.utc(2026, 10, 21)), hasLength(1));
    });

    test('a skipped expired picture is written to the log', () {
      final logger = Logger.detached('test')..level = Level.ALL;
      final lines = <String>[];
      logger.onRecord.listen((record) => lines.add(record.message));
      final captioner = PictureCaptioner(client: _FakeModel(), store: store, logger: logger);
      final post = _post(['https://cdn.discordapp.com/attachments/1/2/a.png?ex=6ad88799&is=1&hm=2']);

      captioner.picturesToLookAt(post, now: DateTime.utc(2026, 10, 21));
      expect(lines, isEmpty, reason: 'the address still works');

      captioner.picturesToLookAt(post, now: DateTime.utc(2026, 10, 22));
      expect(lines, [contains('Skipped 1 picture')]);
    });

    test('an answer is read by picture number, and a picture it leaves out is not saved', () {
      final found = PictureCaptioner.parseAnswer(
          '```json\n{"pictures":[{"number":2,"kind":"LOGO","fit":"Good","caption":"  The   mod name. "},'
          '{"number":9,"kind":"logo","caption":"x"}]}\n```',
          2);
      expect(found!.keys, [2]);
      expect(found[2]!.kind, PictureKind.logo);
      expect(found[2]!.caption, 'The mod name.');
      expect(found[2]!.fit, CardFit.good);
      expect(PictureCaptioner.parseAnswer('no json here', 1), isNull);
    });
  });

  group('the extractor', () {
    PostExtractor extractor(_FakeModel model, {bool captioning = true}) => PostExtractor(
          client: model,
          store: LlmExtractionStore(dir.path, flushEveryN: 1000),
          resolver: QbDownloadResolver(
            client: MockClient((_) async => http.Response('', 200)),
            dataPath: dir.path,
          ),
          dataPath: dir.path,
          pictureCaptions: store,
          captioner: captioning ? PictureCaptioner(client: model, store: store) : null,
        );

    test('the pictures are looked at first, and what was seen goes into the prompt', () async {
      final model = _FakeModel();
      final llm = extractor(model);

      expect(await llm.extractFor(_post([_banner, _patreon]), const []), isTrue);

      expect(model.pictureCalls, hasLength(1));
      final prompt = model.readCalls.single.userPrompt;
      expect(prompt, contains('- $_banner  (seen: banner: Picture banner.png)'));
      expect(llm.liveCallCount, 2, reason: 'the picture call counts against llm_max_topics');
    });

    test('saved captions are used with captioning off, and nothing is looked at', () async {
      await store.putCaption(_banner, const PictureCaption(kind: PictureKind.logo, caption: 'The mod name.'));
      final model = _FakeModel();

      await extractor(model, captioning: false).extractFor(_post([_banner, _shot]), const []);

      expect(model.pictureCalls, isEmpty);
      final prompt = model.readCalls.single.userPrompt;
      expect(prompt, contains('- $_banner  (seen: logo: The mod name.)'));
      expect(prompt, contains('- $_shot\n'), reason: 'a picture nobody looked at is listed as it always was');
    });

    test('a post whose pictures are all described costs no picture call', () async {
      final model = _FakeModel();
      final llm = extractor(model);
      await llm.extractFor(_post([_banner]), const []);
      await llm.extractFor(_post([_banner]), const []);
      expect(model.pictureCalls, hasLength(1));
      expect(model.readCalls, hasLength(1), reason: 'the second read is a saved answer');
    });
  });

  test('a request with pictures sends them as parts after the words', () async {
    Map<String, dynamic>? body;
    final client = OpenAiCompatibleClient(
      client: ThrottledClient(
        client: MockClient((req) async {
          body = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': '{"pictures":[]}'},
                    'finish_reason': 'stop',
                  }
                ],
              }),
              200);
        }),
        delayMs: 0,
      ),
      baseUrl: 'http://localhost/v1/chat/completions',
      model: 'test',
      structuredOutput: true,
    );

    await client.complete(LlmRequest(
      systemPrompt: 'sys',
      userPrompt: 'There is 1 picture.',
      imageUrls: const [_shot],
      jsonSchema: PictureCaptioner.responseSchema,
      schemaName: 'picture_captions',
    ));

    final user = (body!['messages'] as List)[1] as Map<String, dynamic>;
    expect(user['content'], [
      {'type': 'text', 'text': 'There is 1 picture.'},
      {
        'type': 'image_url',
        'image_url': {'url': _shot},
      },
    ]);
    expect((body!['response_format'] as Map)['json_schema']['name'], 'picture_captions');
  });
}
