import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/manager/job_manager.dart';
import 'package:mod_repo_scraper/manager/manager_api.dart';
import 'package:mod_repo_scraper/manager/run_history_store.dart';
import 'package:mod_repo_scraper/manager/self_update.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fake_job_runner.dart';

void main() {
  late Directory dir;
  late List<List<String>> commands;
  late int giteaAsks;
  late DateTime clock;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('self-update-test');
    commands = [];
    giteaAsks = 0;
    clock = DateTime.now();
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// The program folder as a release leaves it: the update script beside it.
  void addScript() {
    final script = File(p.join(dir.path, SelfUpdate.scriptName))
      ..writeAsStringSync('#!/usr/bin/env bash\n');
    if (Platform.isLinux) Process.runSync('chmod', ['+x', script.path]);
  }

  SelfUpdate updater({
    int? installed = 48,
    int? latest = 52,
    int? Function()? latestNow,
    bool busy = false,
    bool isLinux = true,
    int startExitCode = 0,
    String unitLoadState = 'loaded',
    String? unitFolder,
  }) =>
      SelfUpdate(
        rootDir: dir.path,
        installedBuild: () => installed,
        busy: () => busy,
        isLinux: isLinux,
        now: () => clock,
        fetchLatestBuild: () async {
          giteaAsks++;
          return latestNow != null ? latestNow() : latest;
        },
        runCommand: (exe, args) async {
          commands.add([exe, ...args]);
          if (exe == 'systemctl' && args.first == 'show') {
            return ProcessResult(
                0,
                0,
                'LoadState=$unitLoadState\n'
                'WorkingDirectory=${unitFolder ?? dir.path}\n',
                '');
          }
          return ProcessResult(0, startExitCode, '',
              startExitCode == 0 ? '' : 'Interactive authentication required.');
        },
      );

  File log() => File(p.join(dir.path, SelfUpdate.logFileName));

  group('reading the newest release', () {
    test('the build number is read off the newest release\'s tag', () async {
      late http.Request asked;
      final client = MockClient((request) async {
        asked = request;
        return http.Response('{"id":3,"tag_name":"v52","name":"v52"}', 200);
      });
      expect(
          await SelfUpdate.latestReleaseBuild(token: 'abc', client: client),
          52);
      expect(asked.url.toString(), SelfUpdate.latestReleaseUrl);
      expect(asked.headers['Authorization'], 'token abc');
    });

    test('no token means Gitea is not asked at all', () async {
      var asks = 0;
      final client = MockClient((_) async {
        asks++;
        return http.Response('{"tag_name":"v52"}', 200);
      });
      expect(
          await SelfUpdate.latestReleaseBuild(token: null, client: client),
          isNull);
      expect(asks, 0);
    });

    test('a refusal from Gitea is no answer', () async {
      final client = MockClient((_) async => http.Response(
          '{"message":"Only signed in user is allowed to call APIs."}', 403));
      expect(
          await SelfUpdate.latestReleaseBuild(token: 'bad', client: client),
          isNull);
    });

    test('a tag that is not v and a number is no answer', () {
      expect(SelfUpdate.buildFromTag('v7'), 7);
      expect(SelfUpdate.buildFromTag(null), isNull);
      expect(SelfUpdate.buildFromTag('beta'), isNull);
      expect(SelfUpdate.buildFromTag('v1.2'), isNull);
    });

    test('the token is read from the file beside the server, without the '
        'line end', () {
      expect(SelfUpdate.readToken(dir.path), isNull);
      File(p.join(dir.path, SelfUpdate.tokenFileName))
          .writeAsStringSync('abc123\n');
      expect(SelfUpdate.readToken(dir.path), 'abc123');
    });

    test('Gitea is asked once, then the answer is reused for a while',
        () async {
      addScript();
      final update = updater();
      await update.status();
      await update.status();
      expect(giteaAsks, 1);

      clock = clock.add(SelfUpdate.checkEvery + const Duration(seconds: 1));
      await update.status();
      expect(giteaAsks, 2);
    });

    test('a failed ask keeps the last answer and tries again sooner',
        () async {
      addScript();
      int? answer = 52;
      final update = updater(latestNow: () => answer);
      expect((await update.status())['latest'], 52);

      answer = null;
      clock = clock.add(SelfUpdate.checkEvery + const Duration(seconds: 1));
      expect((await update.status())['latest'], 52);

      clock = clock.add(SelfUpdate.retryCheckAfter + const Duration(seconds: 1));
      await update.status();
      expect(giteaAsks, 3);
    });
  });

  group('whether an update is offered', () {
    test('a newer release on a machine that is set up can be updated to',
        () async {
      addScript();
      final status = await updater().status();
      expect(status['supported'], isTrue);
      expect(status['available'], isTrue);
      expect(status['canUpdate'], isTrue);
      expect(status['installed'], 48);
      expect(status['latest'], 52);
      expect(status['lastUpdate'], isNull);
    });

    test('anywhere but Linux it is not offered, and Gitea is not asked',
        () async {
      addScript();
      final status = await updater(isLinux: false).status();
      expect(status['supported'], isFalse);
      expect(status['canUpdate'], isFalse);
      expect(status['reason'], contains('Linux'));
      expect(giteaAsks, 0);
    });

    test('without the update script beside the server it is not offered',
        () async {
      final status = await updater().status();
      expect(status['supported'], isFalse);
      expect(status['reason'], contains(SelfUpdate.scriptName));
    });

    test('already on the newest release, there is nothing to do', () async {
      addScript();
      final status = await updater(installed: 52).status();
      expect(status['available'], isFalse);
      expect(status['canUpdate'], isFalse);
      expect(status['reason'], contains('already on the newest'));
    });

    test('a running or waiting job holds it back, because a restart stops it',
        () async {
      addScript();
      final status = await updater(busy: true).status();
      expect(status['available'], isTrue);
      expect(status['canUpdate'], isFalse);
      expect(status['reason'], contains('job is running'));
    });

    test('without the update unit installed it is not offered', () async {
      addScript();
      final status = await updater(unitLoadState: 'not-found').status();
      expect(status['supported'], isFalse);
      expect(status['reason'], contains(SelfUpdate.unitName));
      expect(giteaAsks, 0);
    });

    test('a unit working in another folder is not used, because its log '
        'would never be read', () async {
      addScript();
      final status =
          await updater(unitFolder: p.join(dir.path, 'elsewhere')).status();
      expect(status['supported'], isFalse);
      expect(status['reason'], contains('WorkingDirectory'));
    });

    test('Gitea not answering holds it back', () async {
      addScript();
      final status = await updater(latest: null).status();
      expect(status['canUpdate'], isFalse);
      expect(status['reason'], contains('Gitea'));
      expect(status['reason'], contains(SelfUpdate.tokenFileName));
    });
  });

  group('starting an update', () {
    test('starts the fixed update unit and nothing else, without sudo',
        () async {
      addScript();
      final update = updater();
      expect(await update.start(), isNull);

      expect(commands.where((c) => c.first == 'sudo'), isEmpty);
      final start = commands.singleWhere((c) => c.contains('start'));
      // --no-block, or systemctl would wait on an update that stops this
      // server.
      expect(start, ['systemctl', 'start', '--no-block', SelfUpdate.unitName]);

      expect(log().readAsStringSync(), contains('v48 to v52'));
      expect(update.isRunning, isTrue);
      expect((await update.status())['canUpdate'], isFalse);
    });

    test('is refused, with the reason, when it may not run now', () async {
      addScript();
      final reason = await updater(busy: true).start();
      expect(reason, contains('job is running'));
      expect(commands.where((c) => c.contains('start')), isEmpty);
      expect(log().existsSync(), isFalse);
    });

    test('systemd saying no is reported in plain words and ends the update',
        () async {
      addScript();
      final update = updater(startExitCode: 1);
      final reason = await update.start();
      expect(reason, contains('Interactive authentication required'));
      expect(reason, contains('starsector-scraper-update.rules'));

      final last = update.lastUpdate()!;
      expect(last.running, isFalse);
      expect(last.exitCode, 1);
      expect(update.isRunning, isFalse);
    });
  });

  group('reading the last update back', () {
    test('the unit file writes exactly the last line the server looks for',
        () {
      final unit = File(p.join('tool', 'starsector-scraper-update.service'))
          .readAsStringSync();
      // systemd writes \$\$ as a plain \$.
      expect(
          unit,
          contains('echo "${SelfUpdate.finishedPrefix}\$\$?" '
              '>>${SelfUpdate.logFileName}'));
      expect(
          unit,
          contains('./${SelfUpdate.scriptName} '
              '>>${SelfUpdate.logFileName} 2>&1'));
    });

    test('the unit\'s last line gives how it ended', () {
      log().writeAsStringSync('Started from the viewer.\n'
          'Downloading the latest release...\n'
          'Updated to v52. The server is up and answering.\n'
          '${SelfUpdate.finishedPrefix}0\n');
      final last = updater().lastUpdate()!;
      expect(last.running, isFalse);
      expect(last.exitCode, 0);
      expect(last.lines, isNot(contains(startsWith(SelfUpdate.finishedPrefix))));
      expect(last.lines.last, startsWith('Updated to v52'));
    });

    test('no last line yet means it is still going', () {
      log().writeAsStringSync('Downloading the latest release...\n');
      clock = DateTime.now();
      final last = updater().lastUpdate()!;
      expect(last.running, isTrue);
      expect(last.exitCode, isNull);
    });

    test('no last line and nothing written for a long time means it died', () {
      log().writeAsStringSync('Downloading the latest release...\n');
      clock = DateTime.now().add(SelfUpdate.staleAfter * 2);
      final last = updater().lastUpdate()!;
      expect(last.running, isFalse);
      expect(last.died, isTrue);
    });
  });

  group('through the manager API', () {
    late JobManager manager;
    late FakeJobRunner service;

    setUp(() async {
      service = FakeJobRunner();
      manager = JobManager(
          service: service,
          history: RunHistoryStore(p.join(dir.path, 'data')));
      await manager.load();
    });

    tearDown(() async {
      service.release();
      for (var i = 0; i < 200 && manager.currentRun != null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });

    Future<Response> call(Handler handler, String method, String path,
            {Object? body}) async =>
        handler(Request(method, Uri.parse('http://localhost/$path'),
            body: body == null ? null : jsonEncode(body)));

    test('a server with no updater says it cannot update itself', () async {
      final handler =
          ManagerApi(manager: manager, dataPath: dir.path).router;
      final res = await call(handler, 'GET', 'update');
      final body = jsonDecode(await res.readAsString()) as Map;
      expect(res.statusCode, 200);
      expect(body['supported'], isFalse);

      final post = await call(handler, 'POST', 'update');
      expect(post.statusCode, HttpStatus.conflict);
    });

    test('no job can be started while the update is going', () async {
      addScript();
      final update = updater();
      final handler = ManagerApi(
              manager: manager, dataPath: dir.path, selfUpdate: update)
          .router;
      clock = DateTime.now();
      final started = await call(handler, 'POST', 'update');
      expect(started.statusCode, HttpStatus.accepted);

      final job = await call(handler, 'POST', 'jobs',
          body: {'kind': 'rebuildBundle'});
      expect(job.statusCode, HttpStatus.conflict);
      final body = jsonDecode(await job.readAsString()) as Map;
      expect(body['error'], contains('updating'));
      expect(manager.currentRun, isNull);
    });
  });
}
