import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:synchronized/synchronized.dart';

import '../../../../catalog/source_post.dart';
import '../../../../site/gallery_filter.dart';
import 'llm_client.dart';
import 'picture_caption_store.dart';

/// Shows the model the pictures in a post and saves what it sees, so the
/// extraction prompt can say what each picture is next to its address.
///
/// The extraction step only ever saw picture addresses, and on about a third
/// of the threads with pictures it picked none for the mod (Industrial
/// Evolution's among them). With a description beside each address it can
/// tell the mod's banner from a Patreon button.
///
/// One call per post, with all of its pictures at once: on the server this
/// was written against, a call costs about 13 seconds whatever is in it, and
/// four pictures in one call cost 16. Only the first [maxPicturesPerPost] are
/// looked at; the mod's own picture is nearly always near the top.
///
/// The pictures are sent by address and the model's server fetches them, so
/// nothing is downloaded here. A server that cannot fetch one picture fails
/// the whole call without saying which, so a failed call is tried again one
/// picture at a time, and the ones it still cannot read are remembered.
///
/// A failure here never stops the extraction: the post is read without
/// descriptions, and the pictures are tried again next run. After
/// [maxConsecutiveFailures] failed calls in a row the captioner stops for the
/// run, which is what a model that cannot read pictures at all looks like.
class PictureCaptioner {
  static const int maxPicturesPerPost = 10;
  static const int maxCaptionLength = 200;

  final LlmClient _client;
  final PictureCaptionStore store;
  final int maxConsecutiveFailures;
  final Logger _log;

  final Lock _lock = Lock();
  int _consecutiveFailures = 0;
  bool _stopped = false;
  int _calls = 0;

  PictureCaptioner({
    required LlmClient client,
    required this.store,
    this.maxConsecutiveFailures = 5,
    Logger? logger,
  })  : _client = client,
        _log = logger ?? Logger('PictureCaptioner');

  /// How many calls this run has made, failed ones included.
  int get callCount => _calls;

  bool get hasStopped => _stopped;

  /// The pictures of [source] the extraction prompt shows, in post order:
  /// every picture that is not a badge, a button or an avatar by its address.
  /// The same filter the extractor uses, so the two always agree.
  static List<String> picturesOf(SourcePost source) => [
        for (final image in source.allImages)
          if (!isBadgeOrDonationImage(image.originalUrl)) image.originalUrl.trim(),
      ];

  /// The pictures of [source] that still need looking at: among the first
  /// [maxPicturesPerPost], the ones with no saved description, leaving out
  /// Discord addresses whose signature has already run out (those would come
  /// back "not found" and be wrongly remembered as dead).
  List<String> picturesToLookAt(SourcePost source, {DateTime? now}) {
    if (_stopped) return const [];
    final seen = <String>{};
    final expired = <String>[];
    final pictures = <String>[];
    for (final url in picturesOf(source).take(maxPicturesPerPost)) {
      if (!seen.add(PictureCaptionStore.keyFor(url)) || store.isDone(url, now: now)) continue;
      if (PictureCaptionStore.discordLinkExpired(url, now: now)) {
        expired.add(url);
      } else {
        pictures.add(url);
      }
    }
    if (expired.isNotEmpty) {
      _log.info('Skipped ${expired.length} '
          '${expired.length == 1 ? 'picture' : 'pictures'} in ${source.label}: '
          'the Discord address has expired. Fetch Discord again to get working '
          'addresses.');
    }
    return pictures;
  }

  /// Looks at [pictures] (from [picturesToLookAt]) and saves what the model
  /// says about each. Returns how many calls were made.
  ///
  /// [title] is the post's title, so the model knows which mod "this mod" is
  /// when it judges how well each picture would do on the mod's card.
  Future<int> lookAt(List<String> pictures, {required String where, String? title}) async {
    if (pictures.isEmpty || _stopped) return 0;
    var calls = 0;

    final first = await _ask(pictures, where, title);
    calls++;
    if (first.answered) return calls;
    if (!first.pictureUnreadable) return calls;

    // One picture the server could not fetch spoils the whole call, and the
    // error does not say which. Each is asked about alone; a dead one fails
    // in under a second.
    if (pictures.length == 1) {
      await store.putUnreadable(pictures.single, first.error!);
      return calls;
    }
    for (final url in pictures) {
      if (_stopped) break;
      final alone = await _ask([url], where, title);
      calls++;
      if (alone.pictureUnreadable) await store.putUnreadable(url, alone.error!);
    }
    return calls;
  }

  Future<_Asked> _ask(List<String> pictures, String where, String? title) async {
    await _lock.synchronized(() => _calls++);
    final named = title == null || title.trim().isEmpty ? '' : 'The post is titled: ${title.trim()}\n';
    final request = LlmRequest(
      systemPrompt: systemPrompt,
      userPrompt: named +
          (pictures.length == 1
              ? 'There is 1 picture.'
              : 'There are ${pictures.length} pictures, numbered 1 to '
                  '${pictures.length} in the order they are shown.'),
      imageUrls: pictures,
      temperature: 0,
      // Room for the JSON around each answer too: at 120 + 80 a picture, a
      // one-picture answer was cut off.
      maxTokens: 200 + 120 * pictures.length,
      jsonSchema: responseSchema,
      schemaName: 'picture_captions',
    );

    final LlmResponse response;
    try {
      response = await _client.complete(request);
    } on LlmException catch (e) {
      if (_isUnreadablePicture(e)) {
        // Not the model failing: the server works, a picture does not.
        await _recordSuccess();
        // A host that is busy or slow today is asked again next run, not
        // remembered as dead for a month. Topic 32915's forum attachment
        // answered "503 Service Unavailable" once and worked the run after.
        if (_isTemporary(e)) {
          _log.info('A picture host of $where did not answer this time: ${e.message}');
          return const _Asked.failed();
        }
        return _Asked.unreadable(e.message);
      }
      _log.warning('Could not look at the pictures of $where: $e');
      await _recordFailure();
      return const _Asked.failed();
    }

    final captions = parseAnswer(response.content, pictures.length);
    if (captions == null) {
      _log.warning('Could not read the picture descriptions for $where: '
          '${_preview(response.content)}');
      await _recordFailure();
      return const _Asked.failed();
    }
    await _recordSuccess();
    for (final (index, url) in pictures.indexed) {
      final caption = captions[index + 1];
      if (caption == null) continue;
      await store.putCaption(url, caption,
          model: response.model, endpoint: response.endpoint);
    }
    _log.fine('Looked at ${pictures.length} pictures of $where '
        '(${response.usageSummary})');
    return const _Asked.answered();
  }

  /// True when the server answered "bad request" because it could not fetch or
  /// open a picture. Anything else, including a server that refuses pictures
  /// altogether, is a failure of the call.
  ///
  /// The words must be about a picture or an address as well, so "model not
  /// found" never marks every picture in the post dead.
  static bool _isUnreadablePicture(LlmException e) =>
      e.message.contains('(status 400)') &&
      _aboutAPicture.hasMatch(e.message) &&
      _unreadableWords.hasMatch(e.message);

  static bool _isTemporary(LlmException e) => _temporaryWords.hasMatch(e.message);

  static final RegExp _temporaryWords = RegExp(
    r'\b(?:5\d\d|429)\b|timed? ?out|temporar|try again|unavailable',
    caseSensitive: false,
  );

  static final RegExp _aboutAPicture = RegExp(r'image|picture|url', caseSensitive: false);

  static final RegExp _unreadableWords = RegExp(
    r'could not be read|cannot identify|could not (?:fetch|load|download|open)'
    r'|failed to (?:fetch|load|download|open)|unable to (?:fetch|load|download|open)'
    r'|not found|forbidden|\b40[34]\b',
    caseSensitive: false,
  );

  Future<void> _recordSuccess() => _lock.synchronized(() => _consecutiveFailures = 0);

  Future<void> _recordFailure() => _lock.synchronized(() {
        _consecutiveFailures++;
        if (!_stopped && _consecutiveFailures >= maxConsecutiveFailures) {
          _stopped = true;
          _log.warning('Stopped looking at pictures: $_consecutiveFailures '
              'calls in a row failed. Posts are read without picture '
              'descriptions for the rest of the run. If the model cannot read '
              'pictures, turn llm_caption_pictures off.');
        }
      });

  /// The model's answer, by picture number, or null when it cannot be read at
  /// all. A picture the answer leaves out is missing from the map and is
  /// looked at again next run.
  static Map<int, PictureCaption>? parseAnswer(String content, int pictureCount) {
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(content.substring(start, end + 1));
    } catch (_) {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;
    final pictures = decoded['pictures'];
    if (pictures is! List) return null;

    final found = <int, PictureCaption>{};
    for (final (index, item) in pictures.indexed) {
      if (item is! Map<String, dynamic>) continue;
      // A one-picture answer sometimes leaves the number out.
      final number = item['number'] is num ? (item['number'] as num).toInt() : index + 1;
      if (number < 1 || number > pictureCount) continue;
      var text = (item['caption'] as String? ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
      if (text.isEmpty) continue;
      if (text.length > maxCaptionLength) {
        text = '${text.substring(0, maxCaptionLength).trimRight()}…';
      }
      final kind = PictureKind.values
              .where((k) => k.name == (item['kind'] as String?)?.trim().toLowerCase())
              .firstOrNull ??
          PictureKind.other;
      final fit = CardFit.values
              .where((f) => f.name == (item['fit'] as String?)?.trim().toLowerCase())
              .firstOrNull ??
          CardFit.okay;
      found[number] = PictureCaption(kind: kind, caption: text, fit: fit);
    }
    return found;
  }

  static String _preview(String text) =>
      text.length > 200 ? '${text.substring(0, 200)}…' : text;

  static const String systemPrompt = '''
You are shown the pictures from a post about one mod for Starsector, a space game. The post's title is given first. Every picture comes from that post, so never name another game.

Describe only what you can see in each picture. The title says which mod the post is about; it never says what a picture shows. A picture that looks blank, dark or mostly one colour is "other", rated "poor", with the caption "A mostly empty picture.".

For each picture, in the order shown, give:
- "number": its place in the order, starting at 1.
- "kind": one of
  - "screenshot": the game running, such as ships in battle, a fleet, a menu, a map or a stats screen.
  - "logo": the mod's name or emblem on its own.
  - "banner": a title picture, usually wide, often with the mod's name written on it.
  - "art": a drawing, a portrait, or ship art that is not a game screen, such as a ship sprite on a plain background.
  - "button": a link button, such as "Download", "Become a patron" or "Buy me a coffee".
  - "badge": a small label, shield or version mark.
  - "divider": a line or spacer between parts of the post.
  - "missing": the picture host's notice that the picture is gone, shown instead of the picture. A picture whose readable words say the picture was removed, is unavailable, or cannot be shown is "missing". So is a picture that is only an image host's logo or an error message.
  - "other": anything else, such as a meme or a page of text.
- "fit": how well it would work as the small picture beside the mod's name in a list of mods.
  - "good": shows this mod clearly and still reads when small: its logo, its title picture unless it is a very thin strip, a clear screenshot of what the mod adds, or its ship art or portraits.
  - "okay": about this mod, but hard to read when small: a busy collage, a very thin strip, a long table, a stats screen, or mostly words.
  - "poor": not a picture of this mod: a button, a badge, a divider, a "missing" notice, a meme or joke picture, or a picture of something else. Also "poor": a picture that is mostly empty, or whose contents are too small to make out, such as a few tiny ship sprites on a large dark background.
- "caption": one short sentence saying what the picture shows. Copy any words written large on it, such as the mod's name, but only words you can clearly read. Never guess at words or invent a logo: if you cannot read it, do not write it. For a "missing" picture, say which host's notice it is. Only call a picture "missing" when you can read the host's notice on it.

Answer with JSON only: {"pictures": [{"number": 1, "kind": "...", "fit": "...", "caption": "..."}]}''';

  static final Map<String, dynamic> responseSchema = {
    'type': 'object',
    'properties': {
      'pictures': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'number': {'type': 'integer'},
            'kind': {
              'type': 'string',
              'enum': [for (final k in PictureKind.values) k.name],
            },
            'fit': {
              'type': 'string',
              'enum': [for (final f in CardFit.values) f.name],
            },
            'caption': {'type': 'string'},
          },
          'required': ['number', 'kind', 'fit', 'caption'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['pictures'],
    'additionalProperties': false,
  };
}

class _Asked {
  final bool answered;

  /// The server's words when it could not fetch or open a picture.
  final String? error;

  const _Asked.answered()
      : answered = true,
        error = null;
  const _Asked.failed()
      : answered = false,
        error = null;
  const _Asked.unreadable(String this.error) : answered = false;

  bool get pictureUnreadable => error != null;
}
