import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/job_manager.dart';
import 'package:mod_repo_scraper/manager/manager_api.dart';
import 'package:mod_repo_scraper/manager/run_history_store.dart';
import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:mod_repo_scraper/viewer/server_app.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fake_job_runner.dart';

void main() {
  late Directory dir;
  late FakeJobRunner service;
  late JobManager manager;
  late Handler handler;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('manager-api-test');
    service = FakeJobRunner();
    manager = JobManager(service: service, history: RunHistoryStore(dir.path));
    await manager.load();
    handler = ManagerApi(manager: manager, dataPath: dir.path).router;
  });

  /// Waits until nothing is running, so the run's log file is closed before the
  /// folder is deleted.
  Future<void> waitForIdle() async {
    service.release();
    for (var i = 0; i < 200 && manager.currentRun != null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  tearDown(() async {
    await waitForIdle();
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  Future<Response> call(String method, String path, {Object? body}) async =>
      handler(
        Request(
          method,
          Uri.parse('http://localhost/$path'),
          body: body == null ? null : jsonEncode(body),
        ),
      );

  Future<Map<String, dynamic>> json(String method, String path,
      {Object? body}) async {
    final res = await call(method, path, body: body);
    return jsonDecode(await res.readAsString()) as Map<String, dynamic>;
  }

  test('a submitted job answers straight away with the queued record',
      () async {
    service.holdUntilReleased();

    final body = await json('POST', 'jobs', body: {
      'kind': 'extractLlm',
      'topicIds': [123, 456],
      'runLlm': true,
    });

    // The answer arrived while the job is still going.
    expect(body['id'], isNotEmpty);
    expect((body['request'] as Map)['kind'], 'extractLlm');
    expect(body['state'], anyOf('queued', 'running'));

    await service.started.future;
    service.release();
    expect(service.ran.single.topicIds, [123, 456]);
  });

  test('status shows the running job with its live phase and item', () async {
    service
      ..phaseName = 'Asking the LLM'
      ..itemName = 'Nexerelin'
      ..itemsTotal = 4
      ..holdUntilReleased();

    await json('POST', 'jobs', body: {
      'kind': 'extractLlm',
      'topicIds': [123],
    });
    await service.started.future;

    final body = await json('GET', 'status');
    expect(body['managerOn'], isTrue);
    expect(body['dataPath'], p.normalize(p.absolute(dir.path)));
    final current = body['current'] as Map<String, dynamic>;
    expect(current['phase'], 'Asking the LLM');
    expect(current['item'], 'Nexerelin');
    expect(current['itemsDone'], 1);
    expect(current['itemsTotal'], 4);
    expect((current['record'] as Map)['state'], 'running');

    service.release();
  });

  test('status carries nothing from the config file but the data path',
      () async {
    // The words a real config file would hold. None may appear in an answer.
    const secrets = [
      'llm_api_token',
      'sk-secret-token',
      'openrouter.ai',
      'deepseek/deepseek-chat',
      'modrepo_discord_auth_token',
    ];

    await json('POST', 'jobs', body: {'kind': 'rebuildBundle'});
    final text = await (await call('GET', 'status')).readAsString();

    for (final secret in secrets) {
      expect(text, isNot(contains(secret)));
    }
    // Only these fields, so nothing can slip in later without a test failing.
    final body = jsonDecode(text) as Map<String, dynamic>;
    expect(body.keys.toSet(), {'managerOn', 'dataPath', 'current', 'queued'});
  });

  group('bad requests are refused with a reason', () {
    test('a body that is not JSON', () async {
      final res = await handler(Request(
        'POST',
        Uri.parse('http://localhost/jobs'),
        body: 'not json at all',
      ));
      expect(res.statusCode, 400);
      expect(jsonDecode(await res.readAsString()), {
        'error': 'The job could not be read: the body is not JSON.',
      });
    });

    test('a kind nobody has heard of', () async {
      final res = await call('POST', 'jobs', body: {'kind': 'takeOverTheWorld'});
      expect(res.statusCode, 400);
      final body = jsonDecode(await res.readAsString()) as Map;
      expect(body['error'], contains('is not a kind of job'));
    });

    test('a per-topic kind with no topics', () async {
      final res = await call('POST', 'jobs',
          body: {'kind': 'rescrapeTopics', 'topicIds': <int>[]});
      expect(res.statusCode, 400);
      expect((jsonDecode(await res.readAsString()) as Map)['error'],
          contains('needs at least one topic id'));
    });

    test('nothing refused reaches the queue or the history', () async {
      await call('POST', 'jobs', body: {'kind': 'takeOverTheWorld'});
      await call('POST', 'jobs', body: {'kind': 'extractLlm'});
      await call('POST', 'jobs', body: 'rubbish');

      expect(service.ran, isEmpty);
      expect(manager.history.records, isEmpty);
      expect((await json('GET', 'runs'))['total'], 0);
    });
  });

  test('cancel stops the running job, and says so when nothing is running',
      () async {
    final idle = await json('POST', 'jobs/cancel');
    expect(idle['cancelled'], isFalse);
    expect(idle['message'], contains('Nothing is running'));

    service.holdUntilReleased();
    final queued = await json('POST', 'jobs', body: {'kind': 'rebuildBundle'});
    await service.started.future;

    final cancelled = await json('POST', 'jobs/cancel');
    expect(cancelled['cancelled'], isTrue);
    expect(cancelled['runId'], queued['id']);

    service.release();
    // Let the job finish and its record settle.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final record = await json('GET', 'runs/${queued['id']}');
    expect(record['state'], 'cancelled');
  });

  test('the runs list is newest first and pages', () async {
    for (var i = 0; i < 3; i++) {
      await manager.submit(JobRequest.rebuildBundle());
    }

    final all = await json('GET', 'runs');
    expect(all['total'], 3);
    final ids = [for (final r in all['items'] as List) r['id'] as String];
    final newestFirst = [...ids]..sort((a, b) => b.compareTo(a));
    expect(ids, newestFirst);

    final firstPage = await json('GET', 'runs?page=0&pageSize=2');
    expect((firstPage['items'] as List), hasLength(2));
    final secondPage = await json('GET', 'runs?page=1&pageSize=2');
    expect((secondPage['items'] as List), hasLength(1));
    expect((secondPage['items'] as List).first['id'], ids.last);

    // Everything on one page, for when you want to read the lot.
    final everything = await json('GET', 'runs?pageSize=0');
    expect((everything['items'] as List), hasLength(3));
    expect(everything['total'], 3);
    expect(everything['page'], 0);
    expect(everything['pageSize'], 0);
  });

  test('an unknown run id is a 404 on both the record and the log', () async {
    for (final path in ['runs/nope', 'runs/nope/log']) {
      final res = await call('GET', path);
      expect(res.statusCode, 404);
      expect((jsonDecode(await res.readAsString()) as Map)['error'],
          'No run called "nope".');
    }
  });

  test('a log tail returns that run\'s lines and no other run\'s', () async {
    final first = await manager.submit(JobRequest.rebuildBundle());
    final second = await manager.submit(JobRequest.rebuildBundle());

    // Write known lines into each run's own log file.
    File(p.join(dir.path, 'runs', first.logFileName))
        .writeAsStringSync('first line 1\nfirst line 2\nfirst line 3\n');
    File(p.join(dir.path, 'runs', second.logFileName))
        .writeAsStringSync('second line 1\nsecond line 2\n');

    final body = await json('GET', 'runs/${first.id}/log?tail=2');
    expect(body['runId'], first.id);
    expect(body['lines'], ['first line 2', 'first line 3']);
    expect(body['total'], 3);
    expect(body['lines'].toString(), isNot(contains('second')));
  });

  test('viewer routes still work when the manager is off', () async {
    final viewerDir = Directory(p.join(dir.path, 'viewer'))
      ..createSync(recursive: true);
    const reason = 'The manager is off: there is no config.properties to read.';
    final full = buildServerHandler(
      viewer: ViewerApi(DataAccess(
        dataDir: viewerDir.path,
        outputsDir: viewerDir.path,
        rootDir: viewerDir.path,
      )),
      managerHandler: ManagerApi.offHandler(reason),
    );

    for (final path in ['api/manager/status', 'api/manager/runs']) {
      final res =
          await full(Request('GET', Uri.parse('http://localhost/$path')));
      expect(res.statusCode, 503);
      final body = jsonDecode(await res.readAsString()) as Map;
      expect(body['managerOn'], isFalse);
      expect(body['error'], reason);
    }

    // A job cannot be started either.
    final refused = await full(Request(
      'POST',
      Uri.parse('http://localhost/api/manager/jobs'),
      body: jsonEncode({'kind': 'rebuildBundle'}),
    ));
    expect(refused.statusCode, 503);

    // The viewer still answers as it always did: no index file on disk, so the
    // friendly "missing" envelope.
    final topics =
        await full(Request('GET', Uri.parse('http://localhost/api/topics')));
    expect(topics.statusCode, 200);
    expect((jsonDecode(await topics.readAsString()) as Map)['missing'], isTrue);
  });
}
