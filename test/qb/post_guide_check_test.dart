import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/post_guide_check.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/post_guide_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:test/test.dart';

/// Answers every guide question with [answer], unless [answers] names one.
class _FakeLlm implements LlmClient {
  final String answer;
  final Map<String, String> answers;
  final List<LlmRequest> requests = [];
  bool fail = false;

  _FakeLlm({this.answer = 'yes', this.answers = const {}});

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    requests.add(request);
    if (fail) throw LlmException('server down');
    return LlmResponse(
      content: jsonEncode({
        for (final item in postGuideItems)
          if (item.askLlm) item.id: answers[item.id] ?? answer,
      }),
      model: 'scraper',
    );
  }
}

QbModDetail _post({
  int topicId = 36100,
  String title = '[0.98a] My Mod v1.0',
  String postDate = 'October 02, 2026, 10:00:00 AM',
  String html = '<p>Adds ships.</p>',
  List<LinkRef> links = const [],
  List<ImageRef> images = const [],
}) =>
    QbModDetail(
      topicId: topicId,
      title: title,
      postDate: postDate,
      contentHtml: html,
      links: links,
      images: images,
    );

void main() {
  late Directory dir;
  late PostGuideStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('post_guide_');
    store = PostGuideStore(dir.path);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  PostGuideChecker checker(_FakeLlm llm, {int budget = 100}) {
    var left = budget;
    return PostGuideChecker(
      client: llm,
      takeCall: () async => left-- > 0,
      store: store,
    );
  }

  group('which posts are checked', () {
    test('a thread started before the guide is never sent', () async {
      final llm = _FakeLlm();
      final spent = await checker(llm)
          .check(_post(postDate: 'September 20, 2026, 11:59:00 PM'));
      expect(spent, isFalse);
      expect(llm.requests, isEmpty);
      expect(store.get(36100), isNull);
    });

    test('a thread started on the guide\'s day is checked', () async {
      final llm = _FakeLlm();
      expect(await checker(llm).check(_post(postDate: 'September 21, 2026, 01:00:00 AM')),
          isTrue);
      expect(store.get(36100), isNotNull);
    });

    test('an old thread edited since the guide is checked', () async {
      final llm = _FakeLlm();
      final old = QbModDetail(
        topicId: 9583,
        title: '[0.98a] Old Mod',
        postDate: 'May 04, 2014, 01:33:25 AM',
        lastEditDate: 'October 30, 2026, 08:07:22 AM by Someone',
        contentHtml: '<p>Old.</p>',
      );
      expect(await checker(llm).check(old), isTrue);
      final untouched = QbModDetail(
        topicId: 9584,
        title: '[0.98a] Older Mod',
        postDate: 'May 04, 2014, 01:33:25 AM',
        lastEditDate: 'August 30, 2026, 08:07:22 AM by Someone',
        contentHtml: '<p>Old.</p>',
      );
      expect(await checker(llm).check(untouched), isFalse);
      expect(postGuideApplies(QbModDetail(topicId: 1, postDate: 'May 04, 2014, 01:33:25 AM',
          lastEditDate: 'Today at 07:18:30 AM by Kevin')), isTrue);
    });

    test('"Today at" counts as recent', () {
      expect(isAfterPostGuide('Today at 03:12:22 PM', null), isTrue);
      expect(isAfterPostGuide(null, 'Yesterday at 03:12:22 PM'), isTrue);
      expect(isAfterPostGuide(null, null), isFalse);
    });

    test('a placeholder post is never sent', () async {
      final llm = _FakeLlm();
      final detail = QbModDetail(
          topicId: 1, postDate: 'October 02, 2026, 10:00:00 AM', isPlaceholderDetail: true);
      expect(await checker(llm).check(detail), isFalse);
      expect(llm.requests, isEmpty);
    });
  });

  group('answers', () {
    test('a failing item carries its fixed reason, eight words or fewer', () async {
      await checker(_FakeLlm(answers: {'sourceCode': 'no'})).check(_post());
      final results = postGuideResults(store.get(36100)!);
      final failing = results.where((r) => r.fails).toList();
      expect(failing.map((r) => r.item.id), contains('sourceCode'));
      expect(failing.first.toMap()['reason'], 'No source code');
      for (final item in postGuideItems) {
        expect(item.reason.split(' ').length, lessThanOrEqualTo(8), reason: item.id);
      }
    });

    test('code answers the title and the pictures, never the LLM', () async {
      await checker(_FakeLlm()).check(_post(title: 'My Mod v1.0'));
      final results = {for (final r in postGuideResults(store.get(36100)!)) r.item.id: r};
      expect(results['gameVersionInTitle']!.answer, GuideAnswer.no);
      expect(results['gameVersionInTitle']!.by, GuideAnsweredBy.rules);
      expect(results['pictures']!.answer, GuideAnswer.no);
    });

    test('a download the rules found wins over the LLM\'s "no"', () async {
      await checker(_FakeLlm(answers: {'externalDownload': 'no'})).check(_post(
        links: [LinkRef(url: 'https://github.com/a/b/releases/x.zip', isDownloadable: true)],
      ));
      final result = postGuideResults(store.get(36100)!)
          .firstWhere((r) => r.item.id == 'externalDownload');
      expect(result.answer, GuideAnswer.yes);
      expect(result.by, GuideAnsweredBy.rules);
    });

    test('a forum attachment is not a download for the rules; the LLM decides', () async {
      await checker(_FakeLlm(answers: {'externalDownload': 'no'})).check(_post(
        links: [
          LinkRef(
              url: 'https://fractalsoftworks.com/forum/index.php?action=dlattach;topic=1.0;attach=2',
              isDownloadable: true),
        ],
      ));
      final result = postGuideResults(store.get(36100)!)
          .firstWhere((r) => r.item.id == 'externalDownload');
      expect(result.answer, GuideAnswer.no);
      expect(result.by, GuideAnsweredBy.llm);
    });

    test('badges are not pictures', () {
      final badge = _post(images: [ImageRef(originalUrl: 'https://img.shields.io/badge/x.svg')]);
      final shot = _post(images: [ImageRef(originalUrl: 'https://i.imgur.com/abc.png')]);
      expect(postGuideRules(badge)['pictures'], GuideAnswer.no);
      expect(postGuideRules(shot)['pictures'], GuideAnswer.yes);
    });

    test('"notApplicable" is dropped where the question does not allow it', () {
      final answers = PostGuideChecker.parseAnswer(jsonEncode({
        'sourceCode': 'notApplicable',
        'aiDisclaimer': 'notApplicable',
        'downloadNearTop': 'maybe',
      }))!;
      expect(answers.containsKey('sourceCode'), isFalse);
      expect(answers['aiDisclaimer'], GuideAnswer.notApplicable);
      expect(answers.containsKey('downloadNearTop'), isFalse);
    });

    test("a source code link the post's own read found wins over the LLM's no", () async {
      await checker(_FakeLlm(answers: {'sourceCode': 'no'})).check(_post(), sourceCodeFound: true);
      final result = postGuideResults(store.get(36100)!).firstWhere((r) => r.item.id == 'sourceCode');
      expect(result.answer, GuideAnswer.yes);
      expect(result.by, GuideAnsweredBy.rules);
    });

    test('"notApplicable" is only offered where a question allows it', () {
      final properties = PostGuideChecker.responseSchema['properties'] as Map<String, dynamic>;
      expect((properties['sourceCode'] as Map)['enum'], ['yes', 'no']);
      expect((properties['aiDisclaimer'] as Map)['enum'], ['yes', 'no', 'notApplicable']);
      expect((properties['downloadNearTop'] as Map)['enum'], ['yes', 'no', 'notApplicable']);
    });

    test('the game version may sit anywhere in brackets', () {
      expect(hasGameVersionInTitle('[0.98a] My Mod'), isTrue);
      expect(hasGameVersionInTitle('My Mod (0.97a-RC11)'), isTrue);
      expect(hasGameVersionInTitle('My Mod [v1.0]'), isFalse);
      expect(hasGameVersionInTitle('[-] TriOS'), isFalse);
    });
  });

  group('saved answers', () {
    test('an unchanged post is not sent again', () async {
      final llm = _FakeLlm();
      await checker(llm).check(_post());
      expect(await checker(llm).check(_post()), isFalse);
      expect(llm.requests, hasLength(1));
    });

    test('an edited post is sent again', () async {
      final llm = _FakeLlm();
      await checker(llm).check(_post());
      await checker(llm).check(_post(html: '<p>Adds ships and weapons.</p>'));
      expect(llm.requests, hasLength(2));
    });

    test('code answers follow the post without a new call', () async {
      final llm = _FakeLlm();
      await checker(llm).check(_post());
      // The same post, but the rules now find a download in it.
      await checker(llm).check(_post(
          links: [LinkRef(url: 'https://github.com/a/b.zip', isDownloadable: true)]));
      expect(llm.requests, hasLength(1));
      expect(store.get(36100)!.rules['externalDownload'], GuideAnswer.yes);
    });

    test('a failed call keeps the old answer and spends a call', () async {
      final llm = _FakeLlm();
      await checker(llm).check(_post());
      final before = store.get(36100)!;
      llm.fail = true;
      final c = checker(llm);
      expect(await c.check(_post(html: '<p>Edited.</p>')), isTrue);
      expect(c.failureCount, 1);
      expect(store.get(36100)!.fingerprint, before.fingerprint);
    });

    test('no budget left means no call', () async {
      final llm = _FakeLlm();
      expect(await checker(llm, budget: 0).check(_post()), isFalse);
      expect(llm.requests, isEmpty);
    });

    test('the file reads back what was saved', () async {
      await checker(_FakeLlm(answers: {'reusePermissions': 'no'})).check(_post());
      final again = PostGuideStore(dir.path);
      await again.load();
      final entry = again.get(36100)!;
      expect(entry.llm['reusePermissions'], GuideAnswer.no);
      expect(entry.model, 'scraper');
    });
  });

  test('the prompt shows spoilers and the title', () {
    final prompt = PostGuideChecker.userPrompt(
        _post(html: '<div class="sp-wrap"><div class="sp-head">FAQ</div><div class="sp-body">Q and A</div></div>'),
        maxInputChars: 60000);
    expect(prompt, contains('[0.98a] My Mod v1.0'));
    expect(PostGuideChecker.systemPrompt, contains('sourceCode:'));
    expect(PostGuideChecker.systemPrompt, isNot(contains('gameVersionInTitle')));
  });
}
