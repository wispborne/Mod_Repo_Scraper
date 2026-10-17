import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/prompt.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/catalog/discord_posts.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:mod_repo_scraper/manager/scraper_service.dart';
import 'package:mod_repo_scraper/manager/scraper_settings.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// An LLM that answers every post with one mod carrying [downloadUrl], and
/// keeps every prompt it was sent.
class _FakeLlm implements LlmClient {
  final String downloadUrl;
  final List<String> prompts = [];

  _FakeLlm({this.downloadUrl = 'https://github.com/a/fresh/releases/download/1.2/fresh.zip'});

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    prompts.add(request.userPrompt);
    return LlmResponse(
      content: jsonEncode({
        'isMod': true,
        'mods': [
          {
            'name': 'Fresh Mod',
            'role': 'main',
            'downloads': [
              {'url': downloadUrl, 'label': 'Download', 'kind': 'direct'},
            ],
          },
        ],
      }),
      finishReason: 'stop',
    );
  }
}

DiscordThreadPost _thread(String id) => DiscordThreadPost(
      threadId: id,
      name: 'Fresh Mod 1.2',
      author: 'Author',
      url: 'https://discord.com/channels/1/$id/$id',
      messages: [
        DiscordOpeningMessage(
          id: id,
          content: '**Fresh Mod**\nDownload: https://github.com/a/fresh/releases/download/1.2/fresh.zip',
          timestamp: DateTime.utc(2026, 1, 1),
        ),
        DiscordOpeningMessage(id: '${id}1', content: 'Update 1.1: fixed a crash.', timestamp: DateTime.utc(2026, 1, 2)),
        DiscordOpeningMessage(id: '${id}2', content: 'Update 1.2: new ships.', timestamp: DateTime.utc(2026, 1, 3)),
      ],
    );

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('discord-coverage');
    final store = JsonDataStore(dir.path);
    await store.saveIndex([
      for (final id in [123, 456]) QbModSummary(topicId: id, title: 'Forum Mod $id', scrapedAt: DateTime.utc(2026)),
    ]);
    for (final id in [123, 456]) {
      await store.saveDetail(QbModDetail(topicId: id, title: 'Forum Mod $id', contentHtml: '<p>Forum Mod $id</p>'));
    }
    await DiscordPostsFile.write(File(p.join(dir.path, DiscordPostsFile.fileName)), {
      '900': _thread('900'),
      '901': _thread('901'),
    });
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

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

  Map<String, dynamic> llmCache() =>
      jsonDecode(File(p.join(dir.path, 'llm-extraction-cache.json')).readAsStringSync()) as Map<String, dynamic>;

  test('the coverage pass reads saved Discord threads and files them under discord:<thread id>', () async {
    final llm = _FakeLlm();
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());

    expect(llmCache().keys, containsAll(['123', '456', 'discord:900', 'discord:901']));
    final entry = llmCache()['discord:900'] as Map<String, dynamic>;
    expect(entry['promptVersion'], ExtractionPrompt.discordPromptVersion);
    expect((entry['mods'] as List).single['name'], 'Fresh Mod');

    final discordPrompt = llm.prompts.firstWhere((prompt) => prompt.contains('Discord announcement thread'));
    expect(discordPrompt, contains('Fresh Mod 1.2'));
    expect(discordPrompt, contains('Update 1.1: fixed a crash.'));
    expect(discordPrompt, contains('Update 1.2: new ships.'));
    // The forum prompt never gains the Discord line.
    expect(llm.prompts.where((prompt) => prompt.contains('WHERE THIS IS FROM')), hasLength(2));
  });

  test('an unchanged thread is served from the store the next time', () async {
    final llm = _FakeLlm();
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());
    final calls = llm.prompts.length;

    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());

    expect(llm.prompts.length, calls, reason: 'nothing changed, so nothing is paid for again');
  });

  test('forum and Discord share one cap, and the report counts Discord apart', () async {
    final llm = _FakeLlm();
    final reporter = RecordingRunReporter();
    await service(llm, maxTopics: 3).runJob(JobRequest.llmCoveragePass(), reporter: reporter);

    expect(llm.prompts, hasLength(3));
    expect(reporter.logs.any((l) => l.contains('1 Discord thread(s) still have no LLM results')), isTrue,
        reason: reporter.logs.join('\n'));
  });

  test('a download the author never posted is dropped', () async {
    // Only a reply by somebody else carried this link, and replies are never
    // saved, so the model cannot have read it in the author's words.
    final llm = _FakeLlm(downloadUrl: 'https://example.com/someone-elses-beta.zip');
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());

    final mods = (llmCache()['discord:900'] as Map<String, dynamic>)['mods'] as List;
    final downloads = mods.isEmpty ? const [] : (mods.single['downloads'] as List? ?? const []);
    expect(downloads.map((d) => d['url']), isNot(contains('https://example.com/someone-elses-beta.zip')));
  });
}
