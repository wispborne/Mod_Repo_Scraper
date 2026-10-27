import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
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

/// A picture attachment's address as Discord gives it, signed. [signature]
/// stands in for the parts Discord writes fresh on every fetch.
String _signedPicture(String signature) =>
    'https://cdn.discordapp.com/attachments/1/2/ships.png'
    '?ex=$signature&is=$signature&hm=${signature}abc&';

DiscordThreadPost _thread(String id, {String? picture}) => DiscordThreadPost(
      threadId: id,
      name: 'Fresh Mod 1.2',
      author: 'Author',
      url: 'https://discord.com/channels/1/$id/$id',
      messages: [
        DiscordOpeningMessage(
          id: id,
          content: '**Fresh Mod**\nDownload: https://github.com/a/fresh/releases/download/1.2/fresh.zip',
          timestamp: DateTime.utc(2026, 1, 1),
          images: [if (picture != null) DiscordImage(url: picture, filename: 'ships.png')],
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
    expect(llm.prompts.where((prompt) => prompt.contains('=== SOURCE ===')), hasLength(2));
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

  test('a thread whose picture was signed again is not read again', () async {
    // Discord writes a fresh signature on a picture's address every time a
    // message is fetched. The picture is the same, so the answer still is.
    final file = File(p.join(dir.path, DiscordPostsFile.fileName));
    await DiscordPostsFile.write(file, {'900': _thread('900', picture: _signedPicture('6ad863e6'))});
    final llm = _FakeLlm();
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());
    final calls = llm.prompts.length;
    expect(llm.prompts.any((prompt) => prompt.contains('ex=6ad863e6')), isTrue,
        reason: 'the model is still sent the real address\n${llm.prompts.join('\n-----\n')}');

    await DiscordPostsFile.write(file, {'900': _thread('900', picture: _signedPicture('6ad9b566'))});
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());

    expect(llm.prompts.length, calls);
  });

  test('a thread whose picture changed is read again', () async {
    final file = File(p.join(dir.path, DiscordPostsFile.fileName));
    await DiscordPostsFile.write(file, {'900': _thread('900', picture: _signedPicture('6ad863e6'))});
    final llm = _FakeLlm();
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());
    final calls = llm.prompts.length;

    await DiscordPostsFile.write(file, {
      '900': _thread('900', picture: _signedPicture('6ad863e6').replaceFirst('ships.png', 'stations.png')),
    });
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());

    expect(llm.prompts.length, calls + 1);
  });

  group('Re-run LLM on named Discord threads', () {
    test('reads a named thread again even when its saved answer is good, and no other', () async {
      final llm = _FakeLlm();
      await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());
      final calls = llm.prompts.length;

      final reporter = RecordingRunReporter();
      final record = await service(llm).runJob(
          const JobRequest(kind: JobKind.extractLlm, discordThreadIds: ['900'], runLlm: true),
          reporter: reporter);

      expect(llm.prompts.length, calls + 1, reason: reporter.logs.join('\n'));
      expect(llm.prompts.last, contains('Discord announcement thread'));
      expect(record.errors, 0);
      expect(llmCache().keys, containsAll(['discord:900', 'discord:901']));
    });

    test('a thread that was never saved is logged and counted as an error', () async {
      final reporter = RecordingRunReporter();
      final record = await service(_FakeLlm()).runJob(
          const JobRequest(kind: JobKind.extractLlm, discordThreadIds: ['404'], runLlm: true),
          reporter: reporter);

      expect(record.errors, 1);
      expect(reporter.logs.any((l) => l.contains('Discord thread 404 is not in')), isTrue,
          reason: reporter.logs.join('\n'));
    });
  });

  test('a file attached to the post reaches the model, and is never published', () async {
    const zip = 'https://cdn.discordapp.com/attachments/902/555/FreshMod.zip?ex=6ae03df6&is=6adeec76&hm=d72c&';
    await DiscordPostsFile.write(File(p.join(dir.path, DiscordPostsFile.fileName)), {
      '902': const DiscordThreadPost(
        threadId: '902',
        name: 'Fresh Mod',
        author: 'Author',
        url: 'https://discord.com/channels/1/902/902',
        messages: [
          DiscordOpeningMessage(id: '902', content: 'Fresh Mod: a full translation.', files: [
            DiscordFile(url: zip, filename: 'FreshMod.zip', contentType: 'application/zip'),
          ]),
        ],
      ),
    });
    final llm = _FakeLlm(downloadUrl: zip);
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());

    expect(llm.prompts.firstWhere((prompt) => prompt.contains('Discord announcement thread')),
        contains('FreshMod.zip'));
    final saved = (llmCache()['discord:902'] as Map<String, dynamic>)['mods'] as List;
    expect((saved.single['downloads'] as List).single['url'], zip,
        reason: 'the saved answer keeps the address it was read with');

    final details = File(p.join(dir.path, 'outputs', 'mod-catalog-details.json')).readAsStringSync();
    expect(details, isNot(contains('cdn.discordapp.com/attachments/902')));
    final thread = ((jsonDecode(details) as Map)['discordThreads'] as List).single as Map;
    final mod = (thread['mods'] as List).single as Map;
    expect(mod['name'], 'Fresh Mod', reason: 'the mod and its other facts still go out');
    expect(mod['downloads'] ?? const [], isEmpty,
        reason: "the mod's Discord link is how the reader gets the file");
  });

  group('withoutDiscordSignatures', () {
    test('takes off only the signature', () {
      expect(
        LlmExtractionStore.withoutDiscordSignatures(
            'see https://media.discordapp.net/attachments/1/2/a.png?ex=1&is=2&hm=3&=&format=webp&width=10 here'),
        'see https://media.discordapp.net/attachments/1/2/a.png?=&format=webp&width=10 here',
      );
      expect(LlmExtractionStore.withoutDiscordSignatures('[link: ${_signedPicture('1')}]'),
          '[link: https://cdn.discordapp.com/attachments/1/2/ships.png]');
    });

    test('leaves every other address alone', () {
      const text = 'https://example.com/a.zip?ex=1&is=2 and https://cdn.discordapp.com/attachments/1/2/a.zip';
      expect(LlmExtractionStore.withoutDiscordSignatures(text), text);
    });
  });

  test('an answer saved under the old fingerprint is moved, not paid for again', () async {
    final store = LlmExtractionStore(dir.path);
    await store.load();
    await store.putKey(
        'discord:900',
        LlmStoreEntry(
          fingerprint: 'old',
          schemaVersion: LlmExtractionStore.schemaVersion,
          promptVersion: 7,
          mods: const [],
        ));

    expect(
        await store.moveFingerprint('discord:900',
            oldFingerprint: 'something else', newFingerprint: 'new', promptVersion: 7),
        isFalse);
    expect(
        await store.moveFingerprint('discord:900', oldFingerprint: 'old', newFingerprint: 'new', promptVersion: 8),
        isFalse,
        reason: 'an answer from an older prompt is out of date anyway');
    expect(
        await store.moveFingerprint('discord:900', oldFingerprint: 'old', newFingerprint: 'new', promptVersion: 7),
        isTrue);
    expect(store.isFreshKey('discord:900', 'new', 7), isTrue);
  });
}
