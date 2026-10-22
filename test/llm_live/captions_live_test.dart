@Tags(['llm'])
library;

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mod_repo_scraper/bot/scraper/qb/llm/openai_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/picture_caption_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/picture_captioner.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/throttled_client.dart';
import 'package:test/test.dart';

import 'live_llm.dart';

/// The real model looking at real pictures from real posts.
///
/// What these protect is the site's card picture: it is the earliest picture
/// the model rated a good fit, so a wrong kind or a wrong rating puts the
/// wrong picture on a mod's card. The pictures are fetched by the model's
/// server from where the authors put them, so a test can start failing
/// because a host took a picture down. The failure message says what the
/// model saw; check the address in a browser before changing the prompt.
const _indevoBanner = 'https://i.imgur.com/7k1QAas.png';
const _patreonButton = 'https://i.imgur.com/xQodpET.png';
const _marketScreenshot = 'https://i.imgur.com/QnmBYHx.png';

/// Four tiny fighter sprites on a see-through 80x80 picture. Photobucket hides
/// its own "Groupsy by photobucket ... Your moments. Your space." text in the
/// see-through pixels. A browser never shows it, but a model server that
/// throws the see-through layer away shows the model that text, and the model
/// then calls the picture a logo and a good card picture.
const _tinySprites = 'http://i44.photobucket.com/albums/f9/Dante80/Minecraft/bolt.png';

/// imgbox answers a picture linked from another site with a "Thumbnail
/// Temporarily Unavailable" picture.
const _imgboxNotice = 'https://images2.imgbox.com/b1/c9/58n8Rkw3_o.png';

/// TinyPic closed in 2019; its host name no longer exists.
const _tinypicGone = 'http://oi40.tinypic.com/t8nh2p.jpg';

void main() {
  late Directory dir;
  late PictureCaptionStore store;
  late ThrottledClient transport;
  late PictureCaptioner captioner;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('captions_live');
    store = PictureCaptionStore(dir.path, flushEveryN: 1000);
    final settings = LiveLlmSettings.read();
    transport = ThrottledClient(client: http.Client(), delayMs: 0);
    captioner = PictureCaptioner(
      client: OpenAiCompatibleClient(
        client: transport,
        baseUrl: settings.baseUrl,
        model: settings.model,
        apiToken: settings.apiToken,
        disableThinking: settings.disableThinking,
        structuredOutput: settings.structuredOutput,
        idleTimeout: const Duration(seconds: 300),
      ),
      store: store,
    );
  });

  tearDown(() {
    transport.close();
    dir.deleteSync(recursive: true);
  });

  /// Looks at [pictures] with the model, or skips the test when there is none.
  Future<bool> look(List<String> pictures, {String title = ''}) async {
    final off = await whyLiveLlmIsOff();
    if (off != null) {
      markTestSkipped('No live model: $off');
      return false;
    }
    await captioner.lookAt(pictures, where: 'live test', title: title);
    return true;
  }

  String said(List<String> pictures) => [
        for (final url in pictures)
          '$url → ${store.captionFor(url)?.promptText ?? (store.isUnreadable(url) ? 'unreadable' : 'nothing')}'
              ' (fit ${store.captionFor(url)?.fit.name})',
      ].join('\n');

  test("a mod's title banner is a good card picture and a Patreon button never is", () async {
    final pictures = [_indevoBanner, _patreonButton, _marketScreenshot];
    if (!await look(pictures, title: '[0.98a] Industrial.Evolution - Campaign content expansion')) return;
    final why = said(pictures);

    final banner = store.captionFor(_indevoBanner);
    expect(banner?.kind, anyOf(PictureKind.banner, PictureKind.logo), reason: why);
    expect(banner?.fit, CardFit.good, reason: why);
    expect(banner?.caption.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ''), contains('industrialevolution'),
        reason: 'the words written large on it are copied\n$why');

    expect(store.captionFor(_patreonButton)?.neverOnACard, isTrue, reason: why);

    final shot = store.captionFor(_marketScreenshot);
    expect(shot?.kind, PictureKind.screenshot, reason: why);
    expect(shot?.fit, isNot(CardFit.poor), reason: why);
  });

  test("a host's notice that the picture is gone is never a card picture", () async {
    final pictures = [_imgboxNotice];
    if (!await look(pictures, title: '[0.98a] All the Domain Drones+ (ATDD+)')) return;
    final why = said(pictures);
    expect(store.captionFor(_imgboxNotice)?.kind, PictureKind.missing, reason: why);
    expect(store.captionFor(_imgboxNotice)?.neverOnACard, isTrue, reason: why);
  });

  test('a see-through picture is judged by what a reader sees', skip:
      'Fails while the model server drops the see-through layer instead of '
      'laying the picture on a background first. Fix that on the server, then '
      'run this.', () async {
    final pictures = [_tinySprites];
    if (!await look(pictures, title: ':: The Lotus Conglomerate v1.10 :: Intrepid to the grave!!')) return;
    final why = said(pictures);
    expect(store.captionFor(_tinySprites)?.neverOnACard, isTrue, reason: why);
    expect(store.captionFor(_tinySprites)?.caption.toLowerCase(), isNot(contains('groups')), reason: why);
  });

  test('a picture the server cannot fetch is remembered, and the rest of the post is still read', () async {
    final pictures = [_indevoBanner, _tinypicGone];
    if (!await look(pictures)) return;
    final why = said(pictures);
    expect(store.isUnreadable(_tinypicGone), isTrue, reason: why);
    expect(store.captionFor(_indevoBanner), isNotNull, reason: why);
  });
}
