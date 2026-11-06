import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/catalog/discord_posts.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:mod_repo_scraper/manager/scraper_service.dart';
import 'package:mod_repo_scraper/manager/scraper_settings.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// An LLM that answers every post with one mod, and keeps every prompt it was
/// sent.
class _FakeLlm implements LlmClient {
  final List<String> prompts = [];

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    prompts.add(request.userPrompt);
    return LlmResponse(
      content: jsonEncode({
        'isMod': true,
        'mods': [
          {'name': 'Some Mod', 'role': 'main', 'downloads': []},
        ],
      }),
      finishReason: 'stop',
    );
  }

  /// Which posts were read, by the name each prompt carries.
  List<String> get postsRead => [
        for (final prompt in prompts)
          RegExp(r'(Forum Mod \d+|Thread \d+)').firstMatch(prompt)?.group(1) ?? '?',
      ];
}

DiscordThreadPost _thread(String id) => DiscordThreadPost(
      threadId: id,
      name: 'Thread $id',
      author: 'Author',
      url: 'https://discord.com/channels/1/$id/$id',
      messages: [
        DiscordOpeningMessage(id: id, content: 'Thread $id is a mod.', timestamp: DateTime.utc(2026, 1, 1)),
      ],
    );

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('llm-reread-all');
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

  // One call at a time keeps the calls in the same order as the posts.
  ScraperService service(LlmClient llm, {int? maxTopics}) => ScraperService(
        environment: ScraperEnvironment(
          dataPath: dir.path,
          outputPath: p.join(dir.path, 'outputs'),
          llm: const LlmSettings(model: 'test-model', baseUrl: 'http://example.invalid'),
        ),
        guardrails: ScraperGuardrails(delayMs: 0, llmMaxTopics: maxTopics, llmMaxConcurrentCalls: 1),
        linkClient: MockClient((_) async => http.Response('', 404)),
        createNetworkClient: () => MockClient((_) async => http.Response('', 200)),
        createLlmClient: () => llm,
      );

  File cacheFile() => File(p.join(dir.path, 'llm-extraction-cache.json'));

  Map<String, dynamic> llmCache() => jsonDecode(cacheFile().readAsStringSync()) as Map<String, dynamic>;

  /// Sets each saved answer's time, or removes it when null.
  void setAnswerTimes(Map<String, DateTime?> times) {
    final cache = llmCache();
    for (final MapEntry(:key, :value) in times.entries) {
      final entry = cache[key] as Map<String, dynamic>;
      if (value == null) {
        entry.remove('answeredAt');
      } else {
        entry['answeredAt'] = value.toIso8601String();
      }
    }
    cacheFile().writeAsStringSync(jsonEncode(cache));
  }

  const allPosts = ['123', '456', 'discord:900', 'discord:901'];

  test('every new answer records when it was made', () async {
    final before = DateTime.now().toUtc().subtract(const Duration(seconds: 1));
    await service(_FakeLlm()).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());
    final after = DateTime.now().toUtc().add(const Duration(seconds: 1));

    for (final key in allPosts) {
      final saved = (llmCache()[key] as Map<String, dynamic>)['answeredAt'] as String?;
      expect(saved, isNotNull, reason: key);
      final when = DateTime.parse(saved!);
      expect(when.isUtc, isTrue);
      expect(when.isAfter(before) && when.isBefore(after), isTrue, reason: '$key: $when');
    }
  });

  group('the answer time on a saved answer', () {
    Map<String, dynamic> oldEntry() => {
          'fingerprint': 'abc',
          'schemaVersion': LlmExtractionStore.schemaVersion,
          'promptVersion': 7,
          'isMod': true,
          'mods': [],
        };

    test('an answer saved before the field existed reads with no time, and writes none', () {
      final entry = LlmStoreEntry.fromJson(oldEntry());
      expect(entry.answeredAt, isNull);
      expect(entry.fingerprint, 'abc');
      expect(entry.toJson().containsKey('answeredAt'), isFalse);
      expect(entry.answeredBefore(DateTime.utc(1970)), isTrue, reason: 'no time counts as the oldest');
    });

    test('a time is written in UTC and read back', () {
      final entry = LlmStoreEntry.fromJson({...oldEntry(), 'answeredAt': '2026-03-04T05:06:07.000Z'});
      expect(entry.answeredAt, DateTime.utc(2026, 3, 4, 5, 6, 7));
      expect(entry.toJson()['answeredAt'], '2026-03-04T05:06:07.000Z');
      expect(entry.answeredBefore(DateTime.utc(2026, 3, 4, 5, 6, 8)), isTrue);
      expect(entry.answeredBefore(DateTime.utc(2026, 3, 4, 5, 6, 7)), isFalse);
    });

    test('an old cache file loads as before', () async {
      cacheFile().writeAsStringSync(jsonEncode({'123': oldEntry(), 'discord:900': oldEntry()}));
      final store = LlmExtractionStore(dir.path);
      await store.load();
      expect(store.get(123)?.answeredAt, isNull);
      expect(store.getDiscord('900')?.fingerprint, 'abc');
    });

    test('a moved answer keeps its time', () async {
      final store = LlmExtractionStore(dir.path);
      await store.putKey(
          '123',
          LlmStoreEntry(
            fingerprint: 'old',
            schemaVersion: LlmExtractionStore.schemaVersion,
            promptVersion: 7,
            mods: const [],
            answeredAt: DateTime.utc(2025, 5, 5),
          ));
      expect(await store.moveFingerprint('123', oldFingerprint: 'old', newFingerprint: 'new', promptVersion: 7),
          isTrue);
      expect(store.get(123)?.answeredAt, DateTime.utc(2025, 5, 5));
    });
  });

  test('Only changed: an up-to-date answer costs no call, even with no time', () async {
    final llm = _FakeLlm();
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());
    expect(llm.prompts, hasLength(4));
    setAnswerTimes({for (final key in allPosts) key: null});

    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());

    expect(llm.prompts, hasLength(4));
    expect(llmCache()['123'], isNot(contains('answeredAt')), reason: 'nothing was read, so nothing changed');
  });

  test('All, under the call limit: every saved post is read once', () async {
    final llm = _FakeLlm();
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());
    llm.prompts.clear();

    final reporter = RecordingRunReporter();
    final outcome = await service(llm, maxTopics: 10)
        .runJob(JobRequest.llmCoveragePass(rereadAll: true), reporter: reporter);

    expect(llm.postsRead..sort(), ['Forum Mod 123', 'Forum Mod 456', 'Thread 900', 'Thread 901']);
    expect(outcome.llmCalls, 4);
    expect(reporter.logs.any((l) => l.contains('reading every saved post again, oldest answer first')), isTrue,
        reason: reporter.logs.join('\n'));
  });

  test('All reads the oldest answers first, and a capped run is carried on by the next', () async {
    final llm = _FakeLlm();
    await service(llm).runJob(JobRequest.llmCoveragePass(), reporter: RecordingRunReporter());
    setAnswerTimes({
      '123': null,
      '456': DateTime.utc(2020),
      'discord:900': DateTime.utc(2019),
      'discord:901': DateTime.utc(2021),
    });
    llm.prompts.clear();

    await service(llm, maxTopics: 2).runJob(JobRequest.llmCoveragePass(rereadAll: true), reporter: RecordingRunReporter());
    expect(llm.postsRead, ['Forum Mod 123', 'Thread 900'],
        reason: 'no time first, then the oldest, forum and Discord in one order');
    llm.prompts.clear();

    await service(llm, maxTopics: 2).runJob(JobRequest.llmCoveragePass(rereadAll: true), reporter: RecordingRunReporter());
    expect(llm.postsRead, ['Forum Mod 456', 'Thread 901'], reason: 'the posts the first run did not reach');
  });

  test('the request field defaults to off and travels as llmRereadAll', () {
    expect(const JobRequest(kind: JobKind.llmCoveragePass).llmRereadAll, isFalse);
    final map = JobRequest.llmCoveragePass(rereadAll: true).toMap();
    expect(map['llmRereadAll'], isTrue);
    expect(JobRequestMapper.fromMap({'kind': 'llmCoveragePass'}).llmRereadAll, isFalse);
  });
}
