import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/json_data_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/job_manager.dart';
import 'package:mod_repo_scraper/manager/run_history_store.dart';
import 'package:mod_repo_scraper/manager/scraper_service.dart';
import 'package:mod_repo_scraper/manager/scraper_settings.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// An LLM that answers with one mod, and lets the test do something on each
/// call — pause, or ask for the job to stop.
class ScriptedLlmClient implements LlmClient {
  int calls = 0;
  final Future<void> Function(int call)? onCall;

  ScriptedLlmClient({this.onCall});

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    calls++;
    await onCall?.call(calls);
    return const LlmResponse(
      content: '{"isMod": true, "mods": [{"name": "Test Mod", '
          '"role": "main", "downloads": [], "version": "1.0"}]}',
      finishReason: 'stop',
    );
  }
}

void main() {
  late Directory dir;
  final topicIds = [1, 2, 3, 4, 5];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('job-manager-test');
    final store = JsonDataStore(dir.path);
    await store.saveIndex([
      for (final id in topicIds)
        QbModSummary(
          topicId: id,
          topicUrl: 'https://example.invalid/?topic=$id',
          title: 'Mod $id v1.0',
          author: 'someone',
          scrapedAt: DateTime.utc(2026, 1, 1),
        )
    ]);
    for (final id in topicIds) {
      await store.saveDetail(QbModDetail(
        topicId: id,
        title: 'Mod $id v1.0',
        author: 'someone',
        contentHtml: '<p>Mod $id v1.0 — a mod for testing.</p>',
        scrapedAt: DateTime.utc(2026, 1, 1),
      ));
    }
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  JobManager makeManager(LlmClient llm) {
    final service = ScraperService(
      environment: ScraperEnvironment(
        dataPath: dir.path,
        outputPath: p.join(dir.path, 'outputs'),
        llm: const LlmSettings(
            model: 'test-model', baseUrl: 'http://example.invalid'),
      ),
      guardrails: const ScraperGuardrails(delayMs: 0),
      linkClient: MockClient((_) async => http.Response('', 404)),
      createNetworkClient: () => MockClient((_) async => http.Response('', 200)),
      createLlmClient: () => llm,
    );
    return JobManager(service: service, history: RunHistoryStore(dir.path));
  }

  test('a second job waits for the first to finish', () async {
    final order = <String>[];
    final llm = ScriptedLlmClient(onCall: (call) async {
      order.add('llm call $call');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    final manager = makeManager(llm);
    await manager.load();

    final first = manager.submit(
        JobRequest.forTopics(JobKind.extractLlm, [1, 2], runLlm: true));
    final second = manager.submit(JobRequest.rebuildBundle());

    final secondRecord = await second;
    order.add('bundle rebuilt');
    final firstRecord = await first;

    expect(order, ['llm call 1', 'llm call 2', 'bundle rebuilt']);
    expect(firstRecord.state, RunState.completed);
    expect(secondRecord.state, RunState.completed);
    expect(firstRecord.startedAt!.isAfter(secondRecord.startedAt!), isFalse);
  });

  test('cancel stops between topics, keeps saved work, and says so', () async {
    late JobManager manager;
    final llm = ScriptedLlmClient(onCall: (call) async {
      // Stop once two topics are done. The third never starts.
      if (call == 2) manager.cancelCurrent();
    });
    manager = makeManager(llm);
    await manager.load();

    final record = await manager
        .submit(JobRequest.forTopics(JobKind.extractLlm, topicIds, runLlm: true));

    expect(llm.calls, 2);
    expect(record.state, RunState.cancelled);
    expect(record.counters.itemsDone, 2);
    expect(record.counters.itemsTotal, topicIds.length);
    expect(record.counters.llmCalls, 2);

    // The two topics that were done are still saved.
    final saved = jsonDecode(File(p.join(dir.path, 'llm-extraction-cache.json'))
        .readAsStringSync()) as Map<String, dynamic>;
    expect(saved.keys.toSet(), {'1', '2'});
  });

  test('a run that was cancelled is on record with its own log file', () async {
    late JobManager manager;
    final llm = ScriptedLlmClient(onCall: (call) async {
      if (call == 1) manager.cancelCurrent();
    });
    manager = makeManager(llm);
    await manager.load();

    final record = await manager.submit(
        JobRequest.forTopics(JobKind.extractLlm, topicIds, runLlm: true));

    final history = RunHistoryStore(dir.path);
    await history.load();
    expect(history.byId(record.id)!.state, RunState.cancelled);
    expect(File(p.join(dir.path, 'runs', record.logFileName)).existsSync(),
        isTrue);
  });
}
