import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/post_guide_check.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/post_guide_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:mod_repo_scraper/manager/scraper_service.dart';
import 'package:mod_repo_scraper/manager/scraper_settings.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Answers a post read with one mod, and a guide check with "no" for source
/// code and "yes" for everything else.
class _FakeLlm implements LlmClient {
  final List<String> guidePrompts = [];

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    if (request.schemaName == 'post_guide_check') {
      guidePrompts.add(request.userPrompt);
      return LlmResponse(content: jsonEncode({
        for (final item in postGuideItems)
          if (item.askLlm) item.id: item.id == 'sourceCode' ? 'no' : 'yes',
      }));
    }
    return LlmResponse(
      content: jsonEncode({
        'isMod': true,
        'mods': [
          {'name': 'A Mod', 'role': 'main', 'downloads': []},
        ],
      }),
      finishReason: 'stop',
    );
  }
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('post-guide-pass');
    final store = JsonDataStore(dir.path);
    await store.saveIndex([
      QbModSummary(
          topicId: 100,
          title: 'Old Mod',
          createdDate: 'May 04, 2025, 01:33:25 AM',
          scrapedAt: DateTime.utc(2026)),
      QbModSummary(
          topicId: 200,
          title: '[0.98a] New Mod',
          createdDate: 'October 02, 2026, 10:00:00 AM',
          scrapedAt: DateTime.utc(2026)),
    ]);
    await store.saveDetail(QbModDetail(
        topicId: 100,
        title: 'Old Mod',
        postDate: 'May 04, 2025, 01:33:25 AM',
        contentHtml: '<p>Old.</p>'));
    await store.saveDetail(QbModDetail(
        topicId: 200,
        title: '[0.98a] New Mod',
        postDate: 'October 02, 2026, 10:00:00 AM',
        contentHtml: '<p>New.</p>'));
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  ScraperService service(LlmClient llm) => ScraperService(
        environment: ScraperEnvironment(
          dataPath: dir.path,
          outputPath: p.join(dir.path, 'outputs'),
          llm: const LlmSettings(model: 'test-model', baseUrl: 'http://example.invalid'),
        ),
        guardrails: ScraperGuardrails(delayMs: 0),
        linkClient: MockClient((_) async => http.Response('', 404)),
        createNetworkClient: () => MockClient((_) async => http.Response('', 200)),
        createLlmClient: () => llm,
      );

  test('the LLM pass checks threads started since the guide, and only those', () async {
    final llm = _FakeLlm();
    final reporter = RecordingRunReporter();
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: reporter);

    expect(llm.guidePrompts, hasLength(1));
    expect(llm.guidePrompts.single, contains('[0.98a] New Mod'));

    final saved = PostGuideStore(dir.path);
    await saved.load();
    expect(saved.get(100), isNull);
    final failing = postGuideResults(saved.get(200)!).where((r) => r.fails).map((r) => r.item.reason);
    expect(failing, containsAll(['No source code', 'No pictures']));
    expect(reporter.logs.join('\n'), contains('Post guide:'));

    // Nothing changed, so the next run makes no guide call.
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());
    expect(llm.guidePrompts, hasLength(1));
  });
}
