import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/manager/delegation_client.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/job_manager.dart';
import 'package:mod_repo_scraper/manager/manager_api.dart';
import 'package:mod_repo_scraper/manager/run_history_store.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fake_job_runner.dart';

void main() {
  late Directory dir;
  late FakeJobRunner service;
  late JobManager manager;
  late RecordingRunReporter reporter;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('delegation-test');
    service = FakeJobRunner();
    manager = JobManager(service: service, history: RunHistoryStore(dir.path));
    await manager.load();
    reporter = RecordingRunReporter();
  });

  tearDown(() async {
    service.release();
    for (var i = 0; i < 200 && manager.currentRun != null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  /// A client that sends every request to a real [ManagerApi] over shelf, so
  /// the test covers the routes as well as the delegate.
  http.Client clientFor(Handler handler) => MockClient((request) async {
        // The routes are mounted under /api/manager on the real server.
        final path = request.url.path.replaceFirst('/api/manager', '');
        final res = await handler(Request(
          request.method,
          Uri.parse('http://localhost$path')
              .replace(query: request.url.query.isEmpty
                  ? null
                  : request.url.query),
          body: request.body.isEmpty ? null : request.body,
        ));
        return http.Response(await res.readAsString(), res.statusCode);
      });

  ManagerDelegate delegateTo(
    http.Client client, {
    String? dataPath,
  }) =>
      ManagerDelegate(
        managerUrl: 'http://127.0.0.1:8085',
        dataPath: dataPath ?? dir.path,
        reporter: reporter,
        client: client,
        pollInterval: const Duration(milliseconds: 5),
      );

  test('it delegates when the server is there and means the same folder',
      () async {
    final api = ManagerApi(manager: manager, dataPath: dir.path);
    final delegate = delegateTo(clientFor(api.router));

    final record = await delegate.run(JobRequest.rebuildBundle());

    expect(record, isNotNull);
    expect(record!.state, RunState.completed);
    expect(service.ran, hasLength(1), reason: 'the server did the work');
    expect(reporter.logs.first, contains('took the job as run'));
    expect(reporter.logs.last, contains('finished'));
  });

  test('a delegated run shows the same phases and progress', () async {
    service
      ..phaseName = 'Scraping topics'
      ..itemName = 'Nexerelin'
      ..itemsTotal = 9
      ..holdUntilReleased();
    final api = ManagerApi(manager: manager, dataPath: dir.path);
    final delegate = delegateTo(clientFor(api.router));

    final running = delegate.run(JobRequest.rebuildBundle());
    await service.started.future;
    // Let it poll a few times while the job is held.
    await Future<void>.delayed(const Duration(milliseconds: 40));
    service.release();
    await running;

    expect(reporter.phases, contains('Scraping topics'));
    final update = reporter.updates.first;
    expect(update.done, 1);
    expect(update.total, 9);
    expect(update.item, 'Nexerelin');
  });

  group('it falls back and says why', () {
    Future<void> expectFallback(ManagerDelegate delegate, String words) async {
      final record = await delegate.run(JobRequest.rebuildBundle());
      expect(record, isNull);
      expect(service.ran, isEmpty);
      final said = reporter.logs.join('\n');
      expect(said, contains('Not using the manager server'));
      expect(said, contains(words));
      expect(said, contains('Running the job here instead'));
    }

    test('nothing answers', () async {
      final delegate = delegateTo(MockClient((_) async {
        throw const SocketException('connection refused');
      }));
      await expectFallback(delegate, 'could not be reached');
    });

    test('the server is there but its manager is off', () async {
      final off = ManagerApi.offHandler('The manager is off: there is no '
          'config.properties to read.');
      final delegate = delegateTo(clientFor(off));
      await expectFallback(delegate, 'manager switched off');
    });

    test('the server works on another folder', () async {
      final api = ManagerApi(
          manager: manager, dataPath: p.join(dir.path, 'somewhere-else'));
      final delegate = delegateTo(clientFor(api.router));
      await expectFallback(delegate, 'but this run is about');
    });

    test('the server refuses the job', () async {
      final api = ManagerApi(manager: manager, dataPath: dir.path);
      final delegate = delegateTo(clientFor(api.router));

      // A per-topic job with no topics: the server says no.
      final record = await delegate
          .run(JobRequest.forTopics(JobKind.rescrapeTopics, const []));

      expect(record, isNull);
      expect(service.ran, isEmpty);
      expect(reporter.logs.join('\n'), contains('would not take the job'));
    });
  });

  test('Ctrl-C asks the manager to stop and waits for the record to settle',
      () async {
    service.holdUntilReleased();
    final api = ManagerApi(manager: manager, dataPath: dir.path);
    final delegate = delegateTo(clientFor(api.router));

    final interrupts = StreamController<void>();
    final running =
        delegate.run(JobRequest.rebuildBundle(), interrupts: interrupts.stream);
    await service.started.future;

    interrupts.add(null);
    // Give the cancel time to reach the server, then let the job notice.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    service.release();

    final record = await running;
    expect(record!.state, RunState.cancelled);
    expect(reporter.logs.join('\n'), contains('was stopped on request'));
    await interrupts.close();
  });

  test('a failed run says so, with the reason from its record', () async {
    service.throwThis = StateError('the forum said no');
    final api = ManagerApi(manager: manager, dataPath: dir.path);
    final delegate = delegateTo(clientFor(api.router));

    final record = await delegate.run(JobRequest.rebuildBundle());

    expect(record!.state, RunState.failed);
    final said = reporter.logs.join('\n');
    expect(said, contains('failed: '));
    expect(said, contains('the forum said no'));
  });

  test('a failed run also prints the end of its log', () async {
    // A stand-in server: the job fails right away and its log has three lines.
    const runId = '20260721T120000Z-fullRun';
    final failed = {
      'id': runId,
      'request': JobRequest.rebuildBundle().toMap(),
      'state': 'failed',
      'errorMessage': 'the forum said no',
      'logFileName': '$runId.log',
    };
    final delegate = delegateTo(MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/status')) {
        return http.Response(
            jsonEncode({
              'managerOn': true,
              'dataPath': p.normalize(p.absolute(dir.path)),
              'current': null,
              'queued': const [],
            }),
            200);
      }
      if (path.endsWith('/jobs')) return http.Response(jsonEncode(failed), 200);
      if (path.endsWith('/log')) {
        return http.Response(
            jsonEncode({
              'runId': runId,
              'lines': ['first thing', 'second thing', 'it broke'],
              'total': 3,
              'returned': 3,
            }),
            200);
      }
      return http.Response(jsonEncode(failed), 200);
    }));

    await delegate.run(JobRequest.rebuildBundle());

    final said = reporter.logs.join('\n');
    expect(said, contains("run $runId's log:"));
    expect(said, contains('it broke'));
  });

  test('a bad answer from the server is not treated as a manager', () async {
    final delegate = delegateTo(MockClient(
        (_) async => http.Response('<html>not a manager</html>', 200)));
    final record = await delegate.run(JobRequest.rebuildBundle());
    expect(record, isNull);
    expect(reporter.logs.join('\n'), contains('could not be reached'));
  });
}
