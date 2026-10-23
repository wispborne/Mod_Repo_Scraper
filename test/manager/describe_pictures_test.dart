import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/picture_caption_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:mod_repo_scraper/manager/scraper_service.dart';
import 'package:mod_repo_scraper/manager/scraper_settings.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Returns [words] for picture calls and one mod for post reads.
/// Records picture calls and post reads separately.
class _FakeLlm implements LlmClient {
  String words = 'New words';
  final List<List<String>> pictureCalls = [];
  final List<String> readCalls = [];

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    if (request.imageUrls.isNotEmpty) {
      pictureCalls.add(request.imageUrls);
      return LlmResponse(
        content: jsonEncode({
          'pictures': [
            for (final (i, _) in request.imageUrls.indexed)
              {'number': i + 1, 'kind': 'screenshot', 'fit': 'good', 'caption': words},
          ],
        }),
      );
    }
    readCalls.add(request.userPrompt);
    return LlmResponse(
      content: jsonEncode({
        'isMod': true,
        'mods': [
          {'name': 'Forum Mod', 'role': 'main', 'downloads': []},
        ],
      }),
      finishReason: 'stop',
    );
  }
}

String _picture(int topicId) => 'https://i.imgur.com/shot$topicId.png';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('describe-pictures');
    final store = JsonDataStore(dir.path);
    await store.saveIndex([
      for (final id in [123, 456])
        QbModSummary(topicId: id, title: 'Forum Mod $id', scrapedAt: DateTime.utc(2026)),
    ]);
    for (final id in [123, 456]) {
      await store.saveDetail(QbModDetail(
        topicId: id,
        title: 'Forum Mod $id',
        contentHtml: '<p>Forum Mod $id</p>',
        images: [ImageRef(originalUrl: _picture(id))],
      ));
    }
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  // The job describes pictures even with llm_caption_pictures off.
  ScraperService service(LlmClient llm, {int? maxTopics}) => ScraperService(
        environment: ScraperEnvironment(
          dataPath: dir.path,
          outputPath: p.join(dir.path, 'outputs'),
          llm: const LlmSettings(model: 'test-model', baseUrl: 'http://example.invalid'),
        ),
        guardrails: ScraperGuardrails(delayMs: 0, llmMaxTopics: maxTopics),
        linkClient: MockClient((_) async => http.Response('', 404)),
        createNetworkClient: () => MockClient((_) async => http.Response('', 200)),
        createLlmClient: () => llm,
      );

  Future<PictureCaptionStore> savedCaptions() async {
    final captions = PictureCaptionStore(dir.path);
    await captions.load();
    return captions;
  }

  String llmCache() => File(p.join(dir.path, 'llm-extraction-cache.json')).readAsStringSync();

  test('describes selected topic pictures again without rereading the post', () async {
    final llm = _FakeLlm();
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());
    final answersBefore = llmCache();
    final readsBefore = llm.readCalls.length;
    // Captioning is off, so the coverage pass did not describe any pictures.
    expect(llm.pictureCalls, isEmpty);

    final first = await service(llm)
        .runJob(JobRequest.describePictures(topicIds: [123]), reporter: RecordingRunReporter());
    llm.words = 'Newer words';
    await service(llm)
        .runJob(JobRequest.describePictures(topicIds: [123]), reporter: RecordingRunReporter());

    expect(first.llmCalls, 1);
    expect(llm.pictureCalls, [
      [_picture(123)],
      [_picture(123)],
    ], reason: 'a chosen topic is looked at again even when it has a description');
    expect((await savedCaptions()).captionFor(_picture(123))?.caption, 'Newer words');
    expect(llm.readCalls, hasLength(readsBefore));
    expect(llmCache(), answersBefore);

    // The next LLM pass does not read the post again either.
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());
    expect(llm.readCalls, hasLength(readsBefore));
  });

  test('with no topics selected, updates only missing or outdated descriptions', () async {
    final llm = _FakeLlm();
    final captions = PictureCaptionStore(dir.path);
    await captions.putCaption(
        _picture(123), const PictureCaption(kind: PictureKind.banner, caption: 'Current words'));
    await captions.flush();
    // An older caption prompt version makes the description outdated.
    final file = File(p.join(dir.path, PictureCaptionStore.fileName));
    final saved = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    (saved['pictures'] as Map<String, dynamic>)[_picture(456)] = {
      'v': PictureCaptionStore.captionVersion - 1,
      'kind': 'banner',
      'caption': 'Old words',
      'at': DateTime.utc(2026).toIso8601String(),
    };
    file.writeAsStringSync(jsonEncode(saved));

    await service(llm).runJob(JobRequest.describePictures(), reporter: RecordingRunReporter());

    expect(llm.pictureCalls, [
      [_picture(456)],
    ]);
    expect(llm.readCalls, isEmpty);
    final after = await savedCaptions();
    expect(after.captionFor(_picture(123))?.caption, 'Current words');
    expect(after.captionFor(_picture(456))?.caption, 'New words');
  });

  test('stops at the call limit and reports how many posts remain', () async {
    final llm = _FakeLlm();
    final reporter = RecordingRunReporter();

    final outcome = await service(llm, maxTopics: 1)
        .runJob(JobRequest.describePictures(), reporter: reporter);

    expect(llm.pictureCalls, hasLength(1));
    expect(outcome.guardrailStop, contains('Posts with images left to scan: 1'));
    expect(reporter.logs.join('\n'), contains('1 post still has images to scan'));

    // The next run carries on.
    await service(llm, maxTopics: 1).runJob(JobRequest.describePictures(), reporter: RecordingRunReporter());
    expect(llm.pictureCalls, hasLength(2));
  });
}
