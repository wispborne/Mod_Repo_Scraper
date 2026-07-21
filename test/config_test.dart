import 'dart:io';

import 'package:mod_repo_scraper/bot/common.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/scrape_job.dart';
import 'package:test/test.dart';

/// Writes [contents] to a throwaway config file and reads it back through
/// [Common.readConfig], cleaning up afterwards.
BotConfig? readConfigFrom(String contents) {
  final dir = Directory.systemTemp.createTempSync('config_test');
  try {
    final file = File('${dir.path}/config.properties')
      ..writeAsStringSync(contents);
    return Common.readConfig(configFilePath: file.path);
  } finally {
    dir.deleteSync(recursive: true);
  }
}

void main() {
  group('config keys load under their new names', () {
    test('every group prefix is read', () {
      final config = readConfigFrom('''
log_level=DEBUG
modrepo_enabled=true
modrepo_use_cached=true
modrepo_less_scraping=true
modrepo_forums_enabled=true
modrepo_discord_enabled=true
modrepo_nexus_enabled=true
modrepo_discord_auth_token=discord-token
modrepo_nexus_api_token=nexus-token
modrepo_discord_server_id=12345
modrepo_discord_forum_channels=111:0.97a,222:0.98a
modrepo_keep_all_game_versions=true
modrepo_merge_debug=true
qb_enabled=true
qb_use_cached=true
qb_data_path=some_dir
qb_scope=all
qb_boards=main,lesser
qb_delay_ms=250
qb_max_pages_main=15
qb_max_pages_lesser=7
qb_max_pages_libraries=3
llm_enabled=true
llm_api_token=llm-token
llm_model=some-model
llm_base_url=http://localhost:8080/v1/chat/completions
llm_reprocess_only=true
llm_summaries=true
''');

      expect(config, isNotNull);
      expect(config!.logLevel, 'DEBUG');

      // ModRepo.
      expect(config.enableModRepo, isTrue);
      expect(config.useCached, isTrue);
      expect(config.lessScraping, isTrue);
      expect(config.enableForums, isTrue);
      expect(config.enableDiscord, isTrue);
      expect(config.enableNexus, isTrue);
      expect(config.discordAuthToken, 'discord-token');
      expect(config.nexusApiToken, 'nexus-token');
      expect(config.discordServerId, '12345');
      expect(config.discordForumChannelIdsAndGameVersions,
          {'111': '0.97a', '222': '0.98a'});
      expect(config.keepAllGameVersionsFromSameSource, isTrue);
      expect(config.generateMergeDebug, isTrue);

      // QB.
      expect(config.enableQb, isTrue);
      expect(config.qbUseCached, isTrue);
      expect(config.qbDataPath, 'some_dir');
      expect(config.qbScope, 'all');
      expect(config.qbBoards, {'main', 'lesser'});
      expect(config.qbDelayMs, 250);
      expect(config.qbMaxPagesMain, 15);
      expect(config.qbLesserBoardMaxPages, 7);
      expect(config.qbMaxPagesLibraries, 3);

      // LLM.
      expect(config.enableLlm, isTrue);
      expect(config.llmApiToken, 'llm-token');
      expect(config.llmModel, 'some-model');
      expect(config.llmBaseUrl, 'http://localhost:8080/v1/chat/completions');
      expect(config.llmSkipScrapeReprocessOnly, isTrue);
      expect(config.enableLlmSummaries, isTrue);
    });

    test('old key names no longer load; defaults apply instead', () {
      final config = readConfigFrom('''
enable_forums=true
enable_qb=true
enable_llm=true
use_cached=true
qb_lesser_board_max_pages=99
generate_merge_debug=true
generate_debug_html=true
openrouter_api_token=old-token
llm_skip_scrape_reprocess_only=true
''');

      expect(config, isNotNull);
      expect(config!.enableForums, isFalse);
      expect(config.enableQb, isFalse);
      expect(config.enableLlm, isFalse);
      expect(config.useCached, isFalse);
      expect(config.generateMergeDebug, isFalse);
      expect(config.llmSkipScrapeReprocessOnly, isFalse);
      // The dropped alias must not feed the token any more.
      expect(config.llmApiToken, isNull);
      // Falls back to the default rather than the old key's 99.
      expect(config.qbLesserBoardMaxPages, 20);
    });
  });

  group('unknown config keys', () {
    test('a typo is reported', () {
      expect(Common.unknownConfigKeys(['qb_delay_sm', 'qb_delay_ms']),
          ['qb_delay_sm']);
    });

    test('a stale old-name key is reported', () {
      expect(
          Common.unknownConfigKeys([
            'enable_forums',
            'generate_debug_html',
            'openrouter_api_token',
            'qb_lesser_board_max_pages',
          ]),
          [
            'enable_forums',
            'generate_debug_html',
            'openrouter_api_token',
            'qb_lesser_board_max_pages',
          ]);
    });

    test('every key the shipped config.properties uses is recognized', () {
      final keys = File('config.properties')
          .readAsLinesSync()
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty && !line.startsWith('#'))
          .where((line) => line.contains('='))
          .map((line) => line.split('=').first.trim());

      expect(Common.unknownConfigKeys(keys), isEmpty);
    });
  });

  group('qb_scope values', () {
    test('snake_case spellings resolve', () {
      expect(parseScopeType('new_data'), ScopeType.newData);
      expect(parseScopeType('libraries_only'), ScopeType.librariesOnly);
    });

    test('camelCase spellings resolve', () {
      expect(parseScopeType('newData'), ScopeType.newData);
      expect(parseScopeType('librariesOnly'), ScopeType.librariesOnly);
    });

    test('the single-word scopes resolve', () {
      expect(parseScopeType('all'), ScopeType.all);
      expect(parseScopeType('pages'), ScopeType.pages);
      expect(parseScopeType('topics'), ScopeType.topics);
    });

    test('an unrecognized value returns null so the caller can default', () {
      expect(parseScopeType('everything'), isNull);
      expect(parseScopeType(''), isNull);
    });
  });
}
