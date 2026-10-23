import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/common.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/scrape_job.dart';
import 'package:mod_repo_scraper/bot/scraper/scraped_mod.dart';
import 'package:mod_repo_scraper/catalog/discord_posts.dart';
import 'package:mod_repo_scraper/catalog/listing.dart';
import 'package:mod_repo_scraper/catalog/mod_catalog.dart';
import 'package:mod_repo_scraper/catalog/source_post.dart';
import 'package:mod_repo_scraper/manager/bundle_snapshot_store.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/merge_snapshot_store.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:mod_repo_scraper/manager/scraper_service.dart';
import 'package:mod_repo_scraper/manager/scraper_settings.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// An LLM that always answers with one mod named after the thread, and counts
/// how many times it was asked.
class FakeLlmClient implements LlmClient {
  int calls = 0;
  final List<String> prompts = [];

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    calls++;
    prompts.add(request.userPrompt);
    return const LlmResponse(
      content: '{"isMod": true, "mods": [{"name": "Test Mod", '
          '"role": "main", "downloads": [], "version": "1.0"}]}',
      finishReason: 'stop',
    );
  }
}

QbModDetail detailFor(int topicId, String title) => QbModDetail(
      topicId: topicId,
      title: '$title v1.0',
      author: 'someone',
      contentHtml: '<p>$title v1.0 — a mod for testing.</p>',
      scrapedAt: DateTime.utc(2026, 1, 1),
    );

QbModSummary summaryFor(int topicId, String title) => QbModSummary(
      topicId: topicId,
      topicUrl: 'https://fractalsoftworks.com/forum/index.php?topic=$topicId',
      title: '$title v1.0',
      author: 'someone',
      scrapedAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('scraper-service-test');
    final store = JsonDataStore(dir.path);
    await store.saveIndex([summaryFor(123, 'One'), summaryFor(456, 'Two')]);
    await store.saveDetail(detailFor(123, 'One'));
    await store.saveDetail(detailFor(456, 'Two'));
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  ScraperService makeService({
    LlmClient? llm,
    int? llmMaxTopics,
    http.Client Function()? createNetworkClient,
  }) =>
      ScraperService(
        environment: ScraperEnvironment(
          dataPath: dir.path,
          outputPath: p.join(dir.path, 'outputs'),
          sourceCachePath: dir.path,
          llm: llm == null
              ? null
              : const LlmSettings(
                  model: 'test-model', baseUrl: 'http://example.invalid'),
        ),
        guardrails: ScraperGuardrails(delayMs: 0, llmMaxTopics: llmMaxTopics),
        linkClient: MockClient((_) async => http.Response('', 404)),
        createNetworkClient: createNetworkClient ??
            () => MockClient((_) async => http.Response('', 200)),
        createLlmClient: llm == null ? null : () => llm,
      );

  Map<String, dynamic> readLlmCache() =>
      jsonDecode(File(p.join(dir.path, 'llm-extraction-cache.json'))
          .readAsStringSync()) as Map<String, dynamic>;

  test('the job says what to do, not the config file', () async {
    // The config file asks for a full run over everything...
    const config = BotConfig(
      lessScraping: false,
      enableForums: false,
      enableDiscord: false,
      enableNexus: false,
      logLevel: 'INFO',
      qbScope: 'all',
      enableLlm: true,
    );
    final environment = ScraperEnvironment.fromConfig(config);
    expect(environment.dataPath, config.qbDataPath);

    // ...but the request is what the service acts on.
    final llm = FakeLlmClient();
    final service = makeService(llm: llm);
    final outcome = await service.runJob(
      JobRequest.forTopics(JobKind.extractLlm, [123], runLlm: true),
      reporter: RecordingRunReporter(),
    );

    expect(outcome.itemsDone, 1);
    expect(llm.calls, 1);
    expect(readLlmCache().keys, ['123']);
  });

  test('asking the LLM again about one topic leaves the other alone',
      () async {
    final llm = FakeLlmClient();
    final service = makeService(llm: llm);
    await service.runJob(
      JobRequest.forTopics(JobKind.extractLlm, [123, 456], runLlm: true),
      reporter: RecordingRunReporter(),
    );
    final before = jsonEncode(readLlmCache()['456']);

    await service.runJob(
      JobRequest.forTopics(JobKind.extractLlm, [123], runLlm: true),
      reporter: RecordingRunReporter(),
    );

    expect(jsonEncode(readLlmCache()['456']), before);
    expect(llm.calls, 3, reason: 'two topics, then topic 123 again');
  });

  test('asking the LLM again about a topic reads its Discord threads too',
      () async {
    // The last catalog joined thread 900 to topic 123, and thread 901 to 456.
    await ModCatalog(generatedAt: DateTime.utc(2026, 1, 1), mods: [
      const CatalogMod(id: 'one', mod: ScrapedMod(name: 'One'), sourcePosts: [
        CatalogSourcePost(kind: SourceKind.forum, id: '123'),
        CatalogSourcePost(kind: SourceKind.discord, id: '900'),
      ]),
      const CatalogMod(id: 'two', mod: ScrapedMod(name: 'Two'), sourcePosts: [
        CatalogSourcePost(kind: SourceKind.forum, id: '456'),
        CatalogSourcePost(kind: SourceKind.discord, id: '901'),
      ]),
    ]).write(File(p.join(dir.path, 'outputs', ModCatalog.fileName)));
    await DiscordPostsFile.write(
        File(p.join(dir.path, DiscordPostsFile.fileName)), {
      for (final id in ['900', '901'])
        id: DiscordThreadPost(
          threadId: id,
          name: 'Thread $id',
          messages: [
            DiscordOpeningMessage(id: id, content: 'Thread $id v1.0 is out.'),
          ],
        ),
    });

    final llm = FakeLlmClient();
    final reporter = RecordingRunReporter();
    final outcome = await makeService(llm: llm).runJob(
      JobRequest.forTopics(JobKind.extractLlm, [123], runLlm: true),
      reporter: reporter,
    );

    expect(llm.calls, 2, reason: 'topic 123, then Discord thread 900');
    expect(outcome.itemsTotal, 2);
    expect(readLlmCache().keys, unorderedEquals(['123', 'discord:900']));
    expect(reporter.logs.join('\n'), contains('Thread 900'));

    // The thread's saved answer is still current, so asking again about the
    // topic re-reads the topic and costs nothing for the thread.
    final threadBefore = jsonEncode(readLlmCache()['discord:900']);
    await makeService(llm: llm).runJob(
      JobRequest.forTopics(JobKind.extractLlm, [123], runLlm: true),
      reporter: RecordingRunReporter(),
    );
    expect(llm.calls, 3, reason: 'only topic 123 was read again');
    expect(jsonEncode(readLlmCache()['discord:900']), threadBefore);
  });

  test('working out downloads again leaves the LLM results alone', () async {
    final llm = FakeLlmClient();
    final service = makeService(llm: llm);
    await service.runJob(
      JobRequest.forTopics(JobKind.extractLlm, [123], runLlm: true),
      reporter: RecordingRunReporter(),
    );
    final before = File(p.join(dir.path, 'llm-extraction-cache.json'))
        .readAsStringSync();

    await service.runJob(
      JobRequest.forTopics(JobKind.resolveDownloads, [123]),
      reporter: RecordingRunReporter(),
    );

    expect(
        File(p.join(dir.path, 'llm-extraction-cache.json')).readAsStringSync(),
        before);
    expect(llm.calls, 1, reason: 'the download job never asks the LLM');
  });

  test('the spend cap binds a job that asked for more', () async {
    final llm = FakeLlmClient();
    final service = makeService(llm: llm, llmMaxTopics: 1);

    final outcome = await service.runJob(
      JobRequest.forTopics(JobKind.extractLlm, [123, 456], runLlm: true),
      reporter: RecordingRunReporter(),
    );

    expect(llm.calls, 1);
    expect(outcome.llmCalls, 1);
    expect(outcome.guardrailStop, contains('llm_max_topics=1'));
  });

  test('progress goes to the reporter, and the bundle is rebuilt', () async {
    final reporter = RecordingRunReporter();
    final service = makeService();

    await service.runJob(
      JobRequest.forTopics(JobKind.resolveDownloads, [123, 456]),
      reporter: reporter,
    );

    expect(reporter.phases, contains('Working out downloads'));
    expect(reporter.updates.map((u) => u.done), [1, 2]);
    expect(
        File(p.join(dir.path, 'outputs', 'forum-data-bundle.json')).existsSync(),
        isTrue);
  });

  test('re-scraping a topic fetches it live, even with pages on disk',
      () async {
    // A recorded file exists, so a full run set to replay would use it.
    await File(p.join(dir.path, 'qb_raw_cache.json')).writeAsString('[]');

    var liveClientsMade = 0;
    final service = makeService(createNetworkClient: () {
      liveClientsMade++;
      return MockClient((_) async => http.Response('', 200));
    });

    await service.runJob(
      JobRequest(
          kind: JobKind.rescrapeTopics,
          topicIds: [123],
          replayAllowed: true),
      reporter: RecordingRunReporter(),
    );

    expect(liveClientsMade, 1,
        reason: 'a per-topic job always goes to the network');
  });

  test('a full run set to replay does not go to the network', () async {
    await File(p.join(dir.path, 'qb_raw_cache.json')).writeAsString('[]');

    var liveClientsMade = 0;
    final service = makeService(createNetworkClient: () {
      liveClientsMade++;
      return MockClient((_) async => http.Response('', 200));
    });

    await service.runJob(
      JobRequest.fullRun(scope: ScopeType.topics, replayAllowed: true),
      reporter: RecordingRunReporter(),
    );

    expect(liveClientsMade, 0);
  });

  group('bundle snapshots', () {
    test('a run that publishes the bundle leaves a snapshot named after it',
        () async {
      final service = makeService();
      await service.runJob(
        JobRequest.rebuildBundle(),
        reporter: RecordingRunReporter(),
        runId: '20260722T120000Z-rebuildBundle',
      );

      final saved = service.bundleSnapshots.list();
      expect(saved.map((s) => s.id), ['20260722T120000Z-rebuildBundle']);

      // It is a snapshot, not a bundle: the posts' text is not in it.
      final back =
          service.bundleSnapshots.readRaw('20260722T120000Z-rebuildBundle')!;
      final details = back['details'] as Map;
      expect(details, isNotEmpty);
      for (final detail in details.values) {
        expect((detail as Map).containsKey('contentHtml'), isFalse);
        expect(detail[BundleSnapshotStore.fingerprintKey], isNotNull);
      }

      // The bundle that went out still has everything in it.
      final published = jsonDecode(
              File(p.join(dir.path, 'outputs', 'forum-data-bundle.json'))
                  .readAsStringSync())
          as Map<String, dynamic>;
      final publishedDetail =
          (published['details'] as Map).values.first as Map;
      expect(publishedDetail['contentHtml'], isNotNull);
    });

    test('a job that publishes nothing leaves no snapshot', () async {
      // A prompt trial saves nothing and publishes nothing, so there is
      // nothing about it to compare. Every other kind ends by publishing the
      // bundle, and so leaves a snapshot.
      final service = makeService(llm: FakeLlmClient());
      await service.runJob(
        JobRequest.llmTest(topicIds: [123], limit: 1),
        reporter: RecordingRunReporter(),
        runId: '20260722T120000Z-llmTest',
      );

      expect(service.bundleSnapshots.list(), isEmpty);
    });

    test('a per-topic job that republishes leaves one too', () async {
      final service = makeService(llm: FakeLlmClient());
      await service.runJob(
        JobRequest.forTopics(JobKind.extractLlm, [123], runLlm: true),
        reporter: RecordingRunReporter(),
        runId: '20260722T120000Z-extractLlm',
      );

      expect(service.bundleSnapshots.list().map((s) => s.id),
          ['20260722T120000Z-extractLlm']);
    });

    test('with no run to file it under, nothing is saved', () async {
      final service = makeService();
      await service.runJob(
        JobRequest.rebuildBundle(),
        reporter: RecordingRunReporter(),
      );

      expect(service.bundleSnapshots.list(), isEmpty);
    });
  });

  group('the catalog diff data', () {
    test('a rebuild that asks for it saves the data behind Catalog diff',
        () async {
      final service = makeService();
      await service.runJob(
        const JobRequest(kind: JobKind.rebuildBundle, collectMergeDebug: true),
        reporter: RecordingRunReporter(),
        runId: '20260722T120000Z-rebuildFromSaved',
      );

      expect(File(p.join(dir.path, 'merge-debug.json')).existsSync(), isTrue);
      expect(MergeSnapshotStore(dir.path).list().map((s) => s.id),
          ['20260722T120000Z-rebuildFromSaved']);
    });

    test('a rebuild that does not ask for it saves none', () async {
      final service = makeService();
      await service.runJob(
        JobRequest.rebuildBundle(),
        reporter: RecordingRunReporter(),
        runId: '20260722T120000Z-rebuildBundle',
      );

      expect(File(p.join(dir.path, 'merge-debug.json')).existsSync(), isFalse);
      expect(MergeSnapshotStore(dir.path).list(), isEmpty);
    });
  });
}
