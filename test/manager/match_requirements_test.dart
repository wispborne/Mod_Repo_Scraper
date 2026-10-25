import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:mod_repo_scraper/manager/scraper_service.dart';
import 'package:mod_repo_scraper/manager/scraper_settings.dart';
import 'package:mod_repo_scraper/site/requirement_names.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// What each saved topic is called and what its post says it needs.
const _topics = {
  1: ('LazyLib', <String>[]),
  2: ('Ship Pack', ['Lazee Lib']),
  3: ('Mod Three', ['LazyLib']),
  4: ('Mod Four', ['LazyLib']),
  5: ('Mod Five', ['LazyLib']),
};

/// Reads each post as the one mod its title names. Requirement questions are
/// answered only while [answerRequirements] is on, and fail otherwise.
class _FakeLlm implements LlmClient {
  bool answerRequirements = false;
  final List<String> postReads = [];
  final List<String> requirementCalls = [];

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    if (request.schemaName == 'requirement_names') {
      requirementCalls.add(request.userPrompt);
      if (!answerRequirements) throw LlmException('not answering yet');
      return LlmResponse(
        content: jsonEncode({
          'answers': [
            {'name': 'Lazee Lib', 'id': 'lazylib'},
          ],
        }),
      );
    }
    postReads.add(request.userPrompt);
    final (name, needs) = _topics.values
        .firstWhere((t) => request.userPrompt.contains('${t.$1} by'));
    return LlmResponse(
      content: jsonEncode({
        'isMod': true,
        'mods': [
          {
            'name': name,
            'role': 'main',
            'downloads': [],
            'needs': needs,
          },
        ],
      }),
      finishReason: 'stop',
    );
  }
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('match-requirements');
    final store = JsonDataStore(dir.path);
    await store.saveIndex([
      for (final MapEntry(key: id, value: (name, _)) in _topics.entries)
        QbModSummary(
            topicId: id, title: name, author: 'Someone', scrapedAt: DateTime.utc(2026)),
    ]);
    for (final MapEntry(key: id, value: (name, needs)) in _topics.entries) {
      await store.saveDetail(QbModDetail(
        topicId: id,
        title: name,
        contentHtml: '<p>$name by Someone.</p>'
            '${needs.isEmpty ? '' : '<p>Requires ${needs.join(', ')}.</p>'}',
      ));
    }
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  ScraperService service(LlmClient llm) => ScraperService(
        environment: ScraperEnvironment(
          dataPath: dir.path,
          outputPath: p.join(dir.path, 'outputs'),
          sitePath: p.join(dir.path, 'no-site'),
          sourceCachePath: dir.path,
          llm: const LlmSettings(model: 'test-model', baseUrl: 'http://example.invalid'),
        ),
        guardrails: const ScraperGuardrails(delayMs: 0),
        linkClient: MockClient((_) async => http.Response('', 404)),
        createNetworkClient: () => MockClient((_) async => http.Response('', 200)),
        createLlmClient: () => llm,
      );

  List<dynamic> needsOf(String name) {
    final mods = jsonDecode(File(p.join(dir.path, 'outputs', 'site', 'mods.json'))
        .readAsStringSync())['mods'] as List;
    return (mods.firstWhere((m) => m['name'] == name) as Map)['needs'] as List;
  }

  test('matches requirement names without reading any post again', () async {
    final llm = _FakeLlm();
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());
    expect(llm.postReads, hasLength(_topics.length));
    expect(llm.requirementCalls, hasLength(1),
        reason: 'any job with the LLM on asks about unmatched names');
    expect(needsOf('Ship Pack').single['id'], isNull);

    llm.answerRequirements = true;
    final outcome = await service(llm)
        .runJob(JobRequest.matchRequirements(), reporter: RecordingRunReporter());

    expect(llm.postReads, hasLength(_topics.length), reason: 'no post is read again');
    expect(llm.requirementCalls, hasLength(2));
    expect(llm.requirementCalls.last, contains('- Lazee Lib'));
    expect(outcome.llmCalls, 1);
    expect(needsOf('Ship Pack').single, {'name': 'LazyLib', 'id': 'lazylib'});
    expect((RequirementNameStore(dir.path)..load()).answerFor('Lazee Lib')?.id, 'lazylib');

    // Answered once, never asked again.
    await service(llm).runJob(JobRequest.matchRequirements(), reporter: RecordingRunReporter());
    expect(llm.requirementCalls, hasLength(2));
  });

  test('a hand entry from the viewer is saved and the website rebuilt', () async {
    final llm = _FakeLlm();
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());
    final reads = llm.postReads.length;

    await service(llm).runJob(
      JobRequest.setRequirementNames(
          const [RequirementChange(written: 'Lazee Lib', id: 'lazylib')]),
      reporter: RecordingRunReporter(),
    );

    expect(llm.postReads, hasLength(reads), reason: 'no post is read again');
    expect(needsOf('Ship Pack').single, {'name': 'LazyLib', 'id': 'lazylib'});
    final saved = (RequirementNameStore(dir.path)..load()).answerFor('Lazee Lib')!;
    expect(saved.by, RequirementAnswerBy.hand);

    final report = jsonDecode(File(p.join(dir.path, RequirementNameStore.reportFileName))
        .readAsStringSync()) as Map;
    final row = (report['names'] as List).firstWhere((n) => n['written'] == 'Lazee Lib');
    expect(row, containsPair('by', 'hand'));
    expect(row, containsPair('id', 'lazylib'));
    expect((report['mods'] as List).map((m) => m['id']), contains('lazylib'));

    await service(llm).runJob(
      JobRequest.setRequirementNames(const [RequirementChange(written: 'Lazee Lib', forget: true)]),
      reporter: RecordingRunReporter(),
    );
    expect((RequirementNameStore(dir.path)..load()).answerFor('Lazee Lib'), isNull);
  });

  test('a change pointing at a mod the catalog does not have changes nothing', () async {
    final llm = _FakeLlm();
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());

    await expectLater(
      service(llm).runJob(
        JobRequest.setRequirementNames(const [
          RequirementChange(written: 'Ship Pack Lib', id: 'lazylib'),
          RequirementChange(written: 'Lazee Lib', id: 'no-such-mod'),
        ]),
        reporter: RecordingRunReporter(),
      ),
      throwsA(isA<StateError>()),
    );
    expect((RequirementNameStore(dir.path)..load()).answerFor('Ship Pack Lib'), isNull);
  });
}
