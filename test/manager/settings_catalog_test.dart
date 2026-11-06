import 'dart:io';

import 'package:mod_repo_scraper/bot/common.dart';
import 'package:mod_repo_scraper/manager/config_file_editor.dart';
import 'package:mod_repo_scraper/manager/settings_catalog.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('settings-catalog-test');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  /// Reads a config file holding just [lines].
  BotConfig readLines(List<String> lines) {
    final file = File(p.join(dir.path, 'config.properties'))
      ..writeAsStringSync(lines.join('\n'));
    return Common.readConfig(configFilePath: file.path)!;
  }

  final exampleText = File('config.example.properties').readAsStringSync();
  List<String> exampleKeys() => [
        for (final line in exampleText.split('\n'))
          if (ConfigFileEditor.keyOn(line) != null)
            ConfigFileEditor.keyOn(line)!,
      ];

  test('the catalogue holds every recognised key, once, and no other', () {
    final keys = SettingsCatalog.settings.map((s) => s.key).toList();
    expect(keys.toSet().length, keys.length, reason: 'a key is listed twice');
    expect(keys.toSet(), Common.recognizedKeys);
  });

  test('the catalogue follows the order of config.example.properties', () {
    expect(SettingsCatalog.settings.map((s) => s.key).toList(), exampleKeys());
  });

  test('each default gives the same settings as an empty file', () {
    final empty = readLines(const []);
    for (final spec in SettingsCatalog.settings) {
      final withDefault = readLines(['${spec.key} = ${spec.defaultValue}']);
      expect(withDefault, empty,
          reason: '${spec.key} = "${spec.defaultValue}" is not its default');
      expect(withDefault.toMap(), empty.toMap(), reason: spec.key);
    }
  });

  test('a value other than the default is noticed as one', () {
    // Proves the check above can fail: equal settings are not just any two.
    final empty = readLines(const []);
    expect(readLines(['qb_boards = main']), isNot(empty));
    expect(readLines(['llm_max_topics = 300']), isNot(empty));
  });

  test('each default passes its own checks and does not differ', () {
    for (final spec in SettingsCatalog.settings) {
      expect(SettingsCatalog.differsFromDefault(spec, spec.defaultValue),
          isFalse,
          reason: spec.key);
      if (spec.isSecret) continue;
      expect(SettingsCatalog.problemWith(spec, spec.defaultValue), isNull,
          reason: spec.key);
    }
  });

  test('the secrets are the four tokens', () {
    expect(
        SettingsCatalog.settings
            .where((s) => s.group == SettingGroup.secret)
            .map((s) => s.key)
            .toSet(),
        {
          'modrepo_discord_auth_token',
          'modrepo_nexus_api_token',
          'llm_api_token',
          'llm_fallback_api_token',
        });
  });

  test('only the data folder and the log level need a restart', () {
    expect(
        SettingsCatalog.settings
            .where((s) => s.restart)
            .map((s) => s.key)
            .toSet(),
        {'qb_data_path', 'log_level'});
  });

  group('notes', () {
    final notes = SettingsCatalog.readNotes(exampleText);

    test('every setting has a note', () {
      for (final spec in SettingsCatalog.settings) {
        expect(notes[spec.key], isNotEmpty, reason: spec.key);
      }
    });

    test('a note is the comment straight above, without the # marks', () {
      expect(notes['qb_delay_ms'],
          startsWith('How long to wait between forum requests, in '
              'milliseconds. Be kind to the forum:'));
      expect(notes['qb_delay_ms'], isNot(contains('#')));
    });

    test('keys next to each other share the comment above them', () {
      expect(notes['modrepo_discord_enabled'],
          notes['modrepo_forums_enabled']);
      expect(notes['llm_fallback_model'], notes['llm_fallback_base_url']);
    });

    test('a list keeps a line for each item, and paragraphs stay apart', () {
      final scope = notes['qb_scope']!.split('\n');
      expect(scope.first, 'Which topics a run should walk:');
      expect(scope, contains(startsWith('new_data')));
      expect(scope, contains(startsWith('libraries_only')));

      final idle = notes['llm_idle_timeout_seconds']!;
      expect(idle, contains('\n\n'));
      expect(idle, isNot(contains('---')));
    });

    test('no example file means no notes, not a failure', () {
      expect(SettingsCatalog.readNotes(''), isEmpty);
    });
  });

  group('checking values', () {
    String? problem(String key, String value) =>
        SettingsCatalog.problemWith(SettingsCatalog.byKey(key)!, value);

    test('whole numbers and their minimums', () {
      expect(problem('llm_max_topics', '300'), isNull);
      expect(problem('llm_max_topics', 'lots'), 'must be a whole number');
      expect(problem('llm_max_concurrent_calls', '0'), 'must be 1 or more');
      expect(problem('qb_runs_to_keep', '0'), isNull);
      expect(problem('llm_max_topics', ''), isNull, reason: 'blank = no cap');
      expect(problem('qb_delay_ms', ''), contains('cannot be blank'));
    });

    test('yes-or-no settings', () {
      expect(problem('llm_enabled', 'TRUE'), isNull);
      expect(problem('llm_enabled', 'yes'), 'must be true or false');
    });

    test('choices, in any case and in their other spellings', () {
      expect(problem('log_level', 'debug'), isNull);
      expect(problem('log_level', 'WARNING'), contains('must be one of'));
      expect(problem('qb_scope', 'new_data'), isNull);
      final scope = SettingsCatalog.byKey('qb_scope')!;
      expect(SettingsCatalog.canonical(scope, 'new_data'), 'newData');
      expect(SettingsCatalog.differsFromDefault(scope, 'new_data'), isFalse);
    });

    test('addresses', () {
      expect(problem('llm_base_url', 'http://localhost:8080/v1'), isNull);
      expect(problem('llm_base_url', 'localhost:8080'), contains('http://'));
      expect(problem('llm_fallback_base_url', ''), isNull);
      expect(problem('publish_repo_url', 'git@github.com:me/repo.git'), isNull);
      expect(problem('llm_base_url', 'git@github.com:me/repo.git'),
          isNotNull);
    });

    test('a hidden part sent back is refused', () {
      expect(problem('llm_base_url', 'https://•••@example.com/v1'),
          contains('hidden part'));
    });

    test('a value must be on one line', () {
      expect(problem('llm_model', 'a\nllm_api_token = x'),
          'must be on one line');
    });

    test('lists with rules of their own', () {
      expect(problem('qb_boards', 'main, lesser'), isNull);
      expect(problem('qb_boards', 'main,everything'), isNotNull);
      expect(problem('llm_test_topic_ids', '123, 456'), isNull);
      expect(problem('llm_test_topic_ids', '123,abc'), isNotNull);
      expect(problem('modrepo_discord_forum_channels', '1:0.97a,2:0.98a'),
          isNull);
      expect(problem('modrepo_discord_forum_channels', '1'), isNotNull);
    });
  });

  group('hiding the secret parts of an address', () {
    test('a user name and password', () {
      final shown = SettingsCatalog.maskAddress(
          'https://david:hunter2@llm.example.com/v1/chat/completions');
      expect(shown.value, 'https://•••@llm.example.com/v1/chat/completions');
      expect(shown.masked, isTrue);
    });

    test('a key in the query', () {
      final shown =
          SettingsCatalog.maskAddress('https://example.com/v1?key=abc#top');
      expect(shown.value, 'https://example.com/v1?•••#top');
      expect(shown.masked, isTrue);
    });

    test('an address with nothing to hide is left alone', () {
      for (final plain in [
        'https://openrouter.ai/api/v1/chat/completions',
        'git@github.com:wispborne/StarsectorModRepo.git',
        '',
      ]) {
        final shown = SettingsCatalog.maskAddress(plain);
        expect(shown.value, plain);
        expect(shown.masked, isFalse);
      }
    });
  });
}
