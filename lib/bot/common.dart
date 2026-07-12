/*
 * This file is distributed under the GPLv3. An informal description follows:
 * - Anyone can copy, modify and distribute this software as long as the other points are followed.
 * - You must include the license and copyright notice with each and every distribution.
 * - You may use this software for commercial purposes.
 * - If you modify it, you must indicate changes made to the code.
 * - Any modifications of this code base MUST be distributed with the same license, GPLv3.
 * - This software is provided without warranty.
 * - The software author or license can not be held liable for any damages inflicted by the software.
 * The full license is available from <https://www.gnu.org/licenses/gpl-3.0.txt>.
 */

import 'dart:async';
import 'dart:io';

import 'package:dart_mappable/dart_mappable.dart';
import 'package:mod_repo_scraper/timber/log_level.dart';
import 'package:mod_repo_scraper/timber/timber.dart' as timber_lib;

part 'common.mapper.dart';

class Common {
  static const String serverId = "187635036525166592";

  static BotConfig? readConfig() {
    final configFilePath = 'config.properties';
    final file = File(configFilePath);

    try {
      if (!file.existsSync()) {
        stderr.writeln('Unable to find ${file.absolute.path}.');
        return null;
      }

      final properties = <String, String>{};
      final lines = file.readAsLinesSync();

      for (final line in lines) {
        if (line.trim().isEmpty || line.trim().startsWith('#')) {
          continue;
        }
        final parts = line.split('=');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join('=').trim();
          properties[key] = value;
        }
      }

      return BotConfig(
        lessScraping: properties['less_scraping']?.toLowerCase() == 'true',
        useCached: properties["use_cached"]?.toLowerCase() == 'true',
        enableForums: properties['enable_forums']?.toLowerCase() == 'true',
        enableDiscord: properties['enable_discord']?.toLowerCase() == 'true',
        enableNexus: properties['enable_nexus']?.toLowerCase() == 'true',
        logLevel: properties['log_level'] ?? 'INFO',
        discordAuthToken: properties['discord_auth_token'],
        nexusApiToken: properties['nexus_api_token'],
        discordServerId: properties['discord_serverId'],
        discordForumChannelIdsAndGameVersions:
            _parseForumChannelIds(properties['discord_forumChannelIdsAndGameVersions']),
        enableModRepo: properties['enable_mod_repo']?.toLowerCase() != 'false',
        keepAllGameVersionsFromSameSource:
            properties['keep_all_game_versions_from_same_source']?.toLowerCase() == 'true',
        // `generate_debug_html` is kept as a working alias so existing config
        // files keep producing merge debug output after the rename.
        generateMergeDebug: (properties['generate_merge_debug'] ??
                    properties['generate_debug_html'])
                ?.toLowerCase() ==
            'true',
        enableQb: properties['enable_qb']?.toLowerCase() == 'true',
        qbUseCached: properties['qb_use_cached']?.toLowerCase() == 'true',
        qbDataPath: _trimOrDefault(properties['qb_data_path'], 'qb_data')!,
        qbScope: _trimOrDefault(properties['qb_scope'], 'newData')!,
        qbBoards: _parseQbBoards(properties['qb_boards']),
        qbDelayMs: int.tryParse(properties['qb_delay_ms'] ?? '') ?? 1500,
        qbMaxPagesMain: int.tryParse(properties['qb_max_pages_main'] ?? ''),
        qbLesserBoardMaxPages:
            int.tryParse(properties['qb_lesser_board_max_pages'] ?? '') ?? 20,
        qbMaxPagesLibraries:
            int.tryParse(properties['qb_max_pages_libraries'] ?? ''),
        enableLlm: properties['enable_llm']?.toLowerCase() == 'true',
        llmApiToken: _trimOrNull(properties['llm_api_token']) ??
            _trimOrNull(properties['openrouter_api_token']),
        llmModel: _trimOrDefault(properties['llm_model'], 'deepseek/deepseek-chat')!,
        llmBaseUrl: _trimOrDefault(
            properties['llm_base_url'], 'https://openrouter.ai/api/v1/chat/completions')!,
        llmMaxConsecutiveFailures:
            int.tryParse(properties['llm_max_consecutive_failures'] ?? '') ?? 10,
        llmTimeoutSeconds:
            int.tryParse(properties['llm_timeout_seconds'] ?? '') ?? 120,
        llmMaxTopics: int.tryParse(properties['llm_max_topics'] ?? ''),
        llmMaxTokens: int.tryParse(properties['llm_max_tokens'] ?? ''),
        llmMaxInputChars:
            int.tryParse(properties['llm_max_input_chars'] ?? ''),
        llmDisableThinking:
            properties['llm_disable_thinking']?.toLowerCase() == 'true',
        enableLlmSummaries:
            properties['llm_summaries']?.toLowerCase() == 'true',
        llmSkipScrapeReprocessOnly:
            properties['llm_skip_scrape_reprocess_only']?.toLowerCase() ==
                'true',
        llmTestMode: properties['llm_test_mode']?.toLowerCase() == 'true',
        llmTestLimit: int.tryParse(properties['llm_test_limit'] ?? '') ?? 5,
        llmTestTopicIds: _parseTopicIds(properties['llm_test_topic_ids']),
        llmFallbackBaseUrl: _trimOrNull(properties['llm_fallback_base_url']),
        llmFallbackModel: _trimOrNull(properties['llm_fallback_model']),
        llmFallbackApiToken: _trimOrNull(properties['llm_fallback_api_token']),
        llmFallbackDisableThinking:
            properties['llm_fallback_disable_thinking']?.toLowerCase() == 'true',
      );
    } catch (e) {
      stderr.writeln(e);
      return null;
    }
  }

  /// Returns [value] trimmed, or [defaultValue] if blank/null.
  static String? _trimOrDefault(String? value, String? defaultValue) {
    final trimmed = value?.trim();
    return (trimmed != null && trimmed.isNotEmpty) ? trimmed : defaultValue;
  }

  /// Returns [value] trimmed, or null if blank/null.
  static String? _trimOrNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
  }

  /// Parses "123,456,789" into a Set of topic IDs. Blank/null → null (off).
  static Set<int>? _parseTopicIds(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final ids = value
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toSet();
    return ids.isEmpty ? null : ids;
  }

  /// Parses "main,libraries,lesser" into a Set of board names.
  static Set<String> _parseQbBoards(String? value) {
    if (value == null || value.trim().isEmpty) return {'main', 'libraries', 'lesser'};
    return value.split(',').map((s) => s.trim().toLowerCase()).where((s) => s.isNotEmpty).toSet();
  }

  /// Parses "channelId1:gameVersion1,channelId2:gameVersion2" into a Map.
  static Map<String, String>? _parseForumChannelIds(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      final entries = value.split(',');
      final map = <String, String>{};
      for (final entry in entries) {
        final parts = entry.split(':');
        if (parts.length >= 2) {
          map[parts[0].trim()] = parts[1].trim();
        }
      }
      return map.isEmpty ? null : map;
    } catch (e) {
      stderr.writeln('Error parsing discord_forumChannelIdsAndGameVersions: $e');
      return null;
    }
  }

  static Future<({File logFile, IOSink logOut})> initTimber({
    required BotConfig botConfig,
    required String logFilePath,
    bool writeImmediately = false,
    bool cleanStart = true,
  }) async {
    final logLevel = LogLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == botConfig.logLevel.toLowerCase(),
      orElse: () => LogLevel.info,
    );

    final logFile = File(logFilePath);

    if (cleanStart) {
      if (await logFile.exists()) {
        await logFile.delete();
      }
      await logFile.create();
    }

    final logOut = logFile.openWrite(mode: FileMode.append);

    timber_lib.Timber.plant(
      timber_lib.DebugTree(
        minLogLevelToShow: logLevel,
        appenders: [
          (level, log) {
            if (level >= logLevel) {
              logOut.writeln(log);
              if (writeImmediately) {
                logOut.flush();
              }
            }
          }
        ],
      ),
    );

    return (logFile: logFile, logOut: logOut);
  }
}

@MappableClass()
class BotConfig with BotConfigMappable {
  final bool lessScraping;
  final bool useCached;
  final bool enableForums;
  final bool enableDiscord;
  final bool enableNexus;
  final String logLevel;
  final String? discordAuthToken;
  final String? nexusApiToken;
  final String? discordServerId;
  final Map<String, String>? discordForumChannelIdsAndGameVersions;
  final bool enableModRepo;
  final bool keepAllGameVersionsFromSameSource;
  final bool generateMergeDebug;
  final bool enableQb;
  final bool qbUseCached;
  final String qbDataPath;
  final String qbScope;
  final Set<String> qbBoards;
  final int qbDelayMs;
  // Per-board page limits for the QB scraper; applied only when qbScope == 'pages'.
  // null means scrape all pages for that board. The lesser board is additionally
  // hard-capped at ForumConstants.lesserBoardMaxPages.
  final int? qbMaxPagesMain;
  final int qbLesserBoardMaxPages;
  final int? qbMaxPagesLibraries;

  // --- LLM post-extraction (all off by default) ---
  /// Main switch. When false, no LLM calls are made and the bundle keeps its
  /// original format.
  final bool enableLlm;
  /// API key for the LLM service. Optional: cloud services (OpenRouter,
  /// OpenAI, DeepSeek, ...) need one; local servers (Ollama, LM Studio, ...)
  /// do not, so a blank key still works — requests are sent without one.
  final String? llmApiToken;
  final String llmModel;
  /// The URL of any OpenAI-compatible chat service.
  final String llmBaseUrl;
  /// Stop calling the LLM for the rest of the run after this many failures in a
  /// row (any success resets the count). Catches a broken or offline service.
  final int llmMaxConsecutiveFailures;
  /// How long to wait for one LLM reply before giving up, in seconds. A local
  /// model writing a long answer for a big post can easily need more than a
  /// minute, so this defaults to 120. A timed-out call is not retried (a retry
  /// with the same limit would almost always time out again); it falls straight
  /// back to the rule-based result.
  final int llmTimeoutSeconds;
  /// Optional limit on how many posts the LLM may process per run.
  /// null = no limit (already-processed posts are skipped anyway).
  final int? llmMaxTopics;
  /// Cap on how much the model may write per reply (in tokens — roughly one
  /// token per word). null = the built-in default (4000). Reasoning models
  /// (Qwen3, ...) spend part of their output "thinking" before they answer, so
  /// if thinking can't be turned off they need a much bigger limit (the Qwen3
  /// card uses 32768) or the reply is cut off before the JSON is written.
  final int? llmMaxTokens;
  /// Cap on how many characters of the post's body text are sent to the model.
  /// null = no cap (send the whole post). Keeps a very long post from
  /// exceeding the model's input size limit (which shows up as a
  /// "Context size has been exceeded" error). Only the post body is trimmed;
  /// the thread title and the link list are always sent in full, so downloads
  /// are still checked against the full post text, not the trimmed copy.
  final int? llmMaxInputChars;
  /// Ask the server to turn off "thinking" for reasoning models (Qwen3, ...).
  /// This task is plain extraction, so thinking only wastes output space and
  /// can fill the whole reply before the answer is written. Only for local
  /// servers (Ollama, vLLM, ...); leave off for cloud services, which reject
  /// the extra request fields.
  final bool llmDisableThinking;
  /// When true, the same per-mod LLM call also writes a short, plain-English
  /// summary of the mod: one sentence and one paragraph. Unlike the other LLM
  /// fields, these are written in the model's own words rather than copied from
  /// the post. Turning this on re-runs affected posts; turning it off leaves the
  /// saved results as they are.
  final bool enableLlmSummaries;
  /// Skip the forum scrape entirely and instead run the LLM over every post
  /// already saved on disk, then rebuild the bundle. Picks up where it left
  /// off, so re-runs only handle new or changed posts. When false, a normal
  /// scrape runs and the LLM extracts each topic as it is saved.
  final bool llmSkipScrapeReprocessOnly;
  /// When true, runs a small, temporary trial and writes a report instead of
  /// touching the real bundle or cache.
  final bool llmTestMode;
  final int llmTestLimit;
  /// Specific topic IDs to target in test mode; null = sample the hard posts.
  final Set<int>? llmTestTopicIds;

  // --- Optional fallback LLM provider ---
  /// The URL of a second OpenAI-compatible chat service, used only when the
  /// primary server can't be reached (e.g. a home PC that is usually asleep).
  /// The fallback is on only when this AND [llmFallbackModel] are both set;
  /// blank = no fallback, single-provider behaviour.
  final String? llmFallbackBaseUrl;
  /// The model to use on the fallback service. May differ from [llmModel] — the
  /// fallback often runs a full-precision model where the primary runs a quant.
  final String? llmFallbackModel;
  /// API key for the fallback service. Optional, same as [llmApiToken].
  final String? llmFallbackApiToken;
  /// "Turn off thinking" for the fallback service. Defaults to false — cloud
  /// services (OpenRouter, ...) reject the extra request fields, so leave it off
  /// unless the fallback is itself a local server.
  final bool llmFallbackDisableThinking;

  /// True when the fallback provider is configured (both URL and model set).
  bool get llmFallbackEnabled =>
      (llmFallbackBaseUrl?.trim().isNotEmpty ?? false) &&
      (llmFallbackModel?.trim().isNotEmpty ?? false);

  const BotConfig({
    required this.lessScraping,
    this.useCached = false,
    required this.enableForums,
    required this.enableDiscord,
    required this.enableNexus,
    required this.logLevel,
    this.discordAuthToken,
    this.nexusApiToken,
    this.discordServerId,
    this.discordForumChannelIdsAndGameVersions,
    this.enableModRepo = true,
    this.keepAllGameVersionsFromSameSource = false,
    this.generateMergeDebug = false,
    this.enableQb = false,
    this.qbUseCached = false,
    this.qbDataPath = 'qb_data',
    this.qbScope = 'newData',
    this.qbBoards = const {'main', 'libraries'},
    this.qbDelayMs = 1500,
    this.qbMaxPagesMain,
    this.qbLesserBoardMaxPages = 20,
    this.qbMaxPagesLibraries,
    this.enableLlm = false,
    this.llmApiToken,
    this.llmModel = 'deepseek/deepseek-chat',
    this.llmBaseUrl = 'https://openrouter.ai/api/v1/chat/completions',
    this.llmMaxConsecutiveFailures = 10,
    this.llmTimeoutSeconds = 120,
    this.llmMaxTopics,
    this.llmMaxTokens,
    this.llmMaxInputChars,
    this.llmDisableThinking = false,
    this.enableLlmSummaries = false,
    this.llmSkipScrapeReprocessOnly = false,
    this.llmTestMode = false,
    this.llmTestLimit = 5,
    this.llmTestTopicIds,
    this.llmFallbackBaseUrl,
    this.llmFallbackModel,
    this.llmFallbackApiToken,
    this.llmFallbackDisableThinking = false,
  });
}
