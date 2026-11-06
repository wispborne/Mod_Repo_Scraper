import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/common.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/job_manager.dart';
import 'package:mod_repo_scraper/manager/manager_api.dart';
import 'package:mod_repo_scraper/manager/run_history_store.dart';
import 'package:mod_repo_scraper/manager/settings_catalog.dart';
import 'package:mod_repo_scraper/manager/settings_file.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'fake_job_runner.dart';

const _json = {'content-type': 'application/json'};

void main() {
  // Made-up secrets. None of them may ever appear in an answer.
  const discordToken = 'discord-SECRET-1';
  const nexusToken = 'nexus-SECRET-2';
  const llmToken = 'sk-or-SECRET-3';
  const fallbackToken = 'sk-or-SECRET-4';
  const llmPassword = 'hunter2-SECRET-5';

  const configText = '# My settings.\n'
      'log_level = INFO\n'
      'modrepo_discord_auth_token = $discordToken\n'
      'modrepo_nexus_api_token = $nexusToken\n'
      'llm_api_token = $llmToken\n'
      'llm_fallback_api_token = $fallbackToken\n'
      'llm_base_url = https://david:$llmPassword@llm.example.com/v1\n'
      '\n'
      '# How many calls a run may make.\n'
      'llm_max_topics = 200\n'
      'qb_delay_ms = 1000\n'
      'qb_scope = new_data\n';

  late Directory dir;
  late String configPath;
  late FakeJobRunner service;
  late JobManager manager;
  late Handler handler;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('settings-api-test');
    configPath = p.join(dir.path, 'config.properties');
    File(configPath).writeAsStringSync(configText);
    service = FakeJobRunner();
    manager = JobManager(service: service, history: RunHistoryStore(dir.path));
    await manager.load();
    handler = ManagerApi(
      manager: manager,
      dataPath: dir.path,
      settings: SettingsFile(
        configPath: configPath,
        examplePath: 'config.example.properties',
      ),
    ).router;
  });

  tearDown(() async {
    service.release();
    for (var i = 0; i < 200 && manager.currentRun != null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  String fileText() => File(configPath).readAsStringSync();

  Future<Response> get() =>
      Future.value(handler(Request('GET', Uri.parse('http://localhost/settings'))));

  Future<Response> post(Object body) => Future.value(handler(Request(
        'POST',
        Uri.parse('http://localhost/settings'),
        body: jsonEncode(body),
        headers: _json,
      )));

  Future<Map<String, dynamic>> read(Response res) async =>
      jsonDecode(await res.readAsString()) as Map<String, dynamic>;

  Map<String, dynamic> settingIn(Map<String, dynamic> answer, String key) =>
      (answer['settings'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((s) => s['key'] == key);

  group('GET /settings', () {
    test('lists every setting, in order, with its groups', () async {
      final res = await get();
      expect(res.statusCode, 200);
      final answer = await read(res);
      expect(answer['file'], 'config.properties');
      expect(answer['groups'], [
        {'id': 'secret', 'label': 'Secrets'},
        {'id': 'environment', 'label': 'Environment'},
        {'id': 'limits', 'label': 'Limits'},
        {'id': 'jobShape', 'label': 'Command-line and cron runs only'},
      ]);
      expect([for (final s in answer['settings'] as List) s['key']],
          [for (final s in SettingsCatalog.settings) s.key]);
    });

    test('carries no secret: tokens say only whether they are set', () async {
      final res = await get();
      final text = await res.readAsString();
      for (final secret in [
        discordToken,
        nexusToken,
        llmToken,
        fallbackToken,
        llmPassword,
        'david:',
      ]) {
        expect(text, isNot(contains(secret)));
      }

      final answer = jsonDecode(text) as Map<String, dynamic>;
      final token = settingIn(answer, 'llm_api_token');
      expect(token['isSet'], isTrue);
      expect(token.containsKey('value'), isFalse);
      expect(token['differs'], isTrue);
      expect(settingIn(answer, 'modrepo_nexus_api_token')['isSet'], isTrue);

      final address = settingIn(answer, 'llm_base_url');
      expect(address['value'], 'https://•••@llm.example.com/v1');
      expect(address['masked'], isTrue);
    });

    test('a setting shows its value, default, note and whether it differs',
        () async {
      final answer = await read(await get());

      final topics = settingIn(answer, 'llm_max_topics');
      expect(topics['group'], 'limits');
      expect(topics['kind'], 'int');
      expect(topics['min'], 0);
      expect(topics['value'], '200');
      expect(topics['default'], '');
      expect(topics['differs'], isTrue);
      expect(topics['restart'], isFalse);
      expect(topics['note'], contains('How many live calls one run may make'));

      // The file's other spelling is shown as the choice it means.
      final scope = settingIn(answer, 'qb_scope');
      expect(scope['kind'], 'choice');
      expect(scope['choices'], contains('newData'));
      expect(scope['value'], 'newData');
      expect(scope['differs'], isFalse);

      // Not in the file: the default, unchanged.
      final summaries = settingIn(answer, 'llm_summaries');
      expect(summaries['value'], 'false');
      expect(summaries['differs'], isFalse);

      expect(settingIn(answer, 'qb_data_path')['restart'], isTrue);
      expect(settingIn(answer, 'llm_fallback_api_token')['isSet'], isTrue);
    });

    test('a server with no config file says so', () async {
      final bare = ManagerApi(manager: manager, dataPath: dir.path).router;
      final res = await bare(
          Request('GET', Uri.parse('http://localhost/settings')));
      expect(res.statusCode, HttpStatus.conflict);
      expect((await read(res))['error'], contains('without a config file'));
    });
  });

  group('POST /settings', () {
    test('saving a limit changes that line and nothing else', () async {
      final res = await post({
        'set': {'llm_max_topics': '300'},
      });
      expect(res.statusCode, 200);
      expect(await read(res), {
        'saved': ['llm_max_topics'],
        'jobRunning': false,
        'restartNeeded': <String>[],
      });
      expect(fileText(),
          configText.replaceFirst('llm_max_topics = 200', 'llm_max_topics = 300'));
      expect(Common.readConfig(configFilePath: configPath)!.llmMaxTopics, 300);
    });

    test('a bad value writes nothing and names the key', () async {
      final res = await post({
        'set': {'llm_max_topics': 'lots', 'qb_delay_ms': '2000'},
      });
      expect(res.statusCode, 400);
      final error = (await read(res))['error'] as String;
      expect(error, contains('llm_max_topics must be a whole number'));
      expect(error, isNot(contains('qb_delay_ms')));
      expect(fileText(), configText);
    });

    test('every bad key is named in one message', () async {
      final res = await post({
        'set': {
          'llm_max_topics': 'lots',
          'llm_enabled': 'maybe',
          'no_such_key': '1',
        },
        'clearSecrets': ['llm_model'],
      });
      expect(res.statusCode, 400);
      final error = (await read(res))['error'] as String;
      expect(error, startsWith('Nothing was saved.'));
      expect(error, contains('llm_max_topics'));
      expect(error, contains('llm_enabled must be true or false'));
      expect(error, contains('no_such_key is not a setting'));
      expect(error, contains('llm_model is not a token'));
      expect(fileText(), configText);
    });

    test('reset to default takes the line out', () async {
      final res = await post({
        'reset': ['qb_delay_ms'],
      });
      expect(res.statusCode, 200);
      expect(fileText(), isNot(contains('qb_delay_ms')));
      expect(Common.readConfig(configFilePath: configPath)!.qbDelayMs, 1500);
      final answer = await read(await get());
      expect(settingIn(answer, 'qb_delay_ms')['value'], '1500');
      expect(settingIn(answer, 'qb_delay_ms')['differs'], isFalse);
    });

    test('a token is set and cleared, and never sent back', () async {
      var res = await post({
        'set': {'llm_api_token': 'sk-or-NEW-SECRET'},
      });
      expect(res.statusCode, 200);
      expect(await res.readAsString(), isNot(contains('NEW-SECRET')));
      expect(fileText(), contains('llm_api_token = sk-or-NEW-SECRET\n'));

      res = await post({
        'clearSecrets': ['llm_api_token'],
      });
      expect(res.statusCode, 200);
      expect(fileText(), contains('\nllm_api_token =\n'));
      final answer = await read(await get());
      expect(settingIn(answer, 'llm_api_token')['isSet'], isFalse);
      expect(settingIn(answer, 'llm_api_token')['differs'], isFalse);
    });

    test('a hidden address sent back unchanged is refused', () async {
      final res = await post({
        'set': {'llm_base_url': 'https://•••@llm.example.com/v1'},
      });
      expect(res.statusCode, 400);
      expect((await read(res))['error'], contains('llm_base_url'));
      expect(fileText(), configText);
    });

    test('a new key is added at the end, and a restart key is named',
        () async {
      final res = await post({
        'set': {'llm_summaries': 'true', 'qb_data_path': 'other_data'},
      });
      final answer = await read(res);
      expect(answer['saved'], ['qb_data_path', 'llm_summaries']);
      expect(answer['restartNeeded'], ['qb_data_path']);
      expect(fileText(), startsWith(configText));
      expect(fileText(), contains('\nllm_summaries = true\n'));
      expect(fileText(), contains('\nqb_data_path = other_data\n'));
    });

    test('the answer says when a job is running', () async {
      service.holdUntilReleased();
      await manager.enqueue(const JobRequest(kind: JobKind.rebuildBundle));
      await service.started.future;

      final answer = await read(await post({
        'set': {'llm_max_topics': '300'},
      }));
      expect(answer['jobRunning'], isTrue);
      service.release();
    });

    test('a body that is not an object is refused', () async {
      final res = await handler(Request(
        'POST',
        Uri.parse('http://localhost/settings'),
        body: '[1, 2]',
        headers: _json,
      ));
      expect(res.statusCode, 400);
      expect(fileText(), configText);
    });
  });

  group('changing requests must come from the viewer', () {
    Future<Response> send(
      String path, {
      String host = 'http://127.0.0.1:8085',
      Map<String, String> headers = _json,
      String? body = '{"kind":"rebuildBundle"}',
    }) =>
        Future.value(handler(Request(
          'POST',
          Uri.parse('$host/$path'),
          body: body,
          headers: headers,
        )));

    test('another website is refused and nothing starts', () async {
      final res = await send('jobs',
          headers: {..._json, 'origin': 'https://evil.example.com'});
      expect(res.statusCode, HttpStatus.forbidden);
      expect((await read(res))['error'], contains('another website'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(service.ran, isEmpty);
      expect(manager.history.records, isEmpty);
    });

    test('a page on the same host but another port is refused', () async {
      final res = await send('settings',
          body: '{"set":{"llm_max_topics":"1"}}',
          headers: {..._json, 'origin': 'http://127.0.0.1:9999'});
      expect(res.statusCode, HttpStatus.forbidden);
      expect(fileText(), configText);
    });

    test('a request that is not JSON is refused', () async {
      final res = await send('jobs',
          headers: {'content-type': 'text/plain'});
      expect(res.statusCode, HttpStatus.forbidden);
      expect((await read(res))['error'], contains('JSON'));
      expect(manager.history.records, isEmpty);
    });

    test('a name that is not this machine is refused', () async {
      final res = await send('jobs',
          host: 'http://rebind.example.com:8085',
          headers: {..._json, 'origin': 'http://rebind.example.com:8085'});
      expect(res.statusCode, HttpStatus.forbidden);
      expect((await read(res))['error'], contains('127.0.0.1'));
    });

    test("the viewer's own page and the command line get through", () async {
      final fromPage = await send('jobs/cancel',
          body: '{}', headers: {..._json, 'origin': 'http://127.0.0.1:8085'});
      expect(fromPage.statusCode, 200);

      final fromLocalhost = await send('jobs/cancel',
          host: 'http://localhost:9000',
          body: '{}',
          headers: {..._json, 'origin': 'http://localhost:9000'});
      expect(fromLocalhost.statusCode, 200);

      // The CLI sends no Origin.
      final fromCli = await send('jobs/cancel', body: '{}');
      expect(fromCli.statusCode, 200);
    });

    test("a post with no content type is refused, even from the viewer's own page",
        () async {
      final res = await send('update',
          body: null, headers: {'origin': 'http://127.0.0.1:8085'});
      expect(res.statusCode, HttpStatus.forbidden);

      final bare = await send('update', body: null, headers: const {});
      expect(bare.statusCode, HttpStatus.forbidden);
    });

    test('reading is never refused', () async {
      final res = await handler(Request(
          'GET', Uri.parse('http://127.0.0.1:8085/status'),
          headers: {'origin': 'https://evil.example.com'}));
      expect(res.statusCode, 200);
    });
  });
}
