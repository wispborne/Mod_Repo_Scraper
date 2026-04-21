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
        generateDebugHtml: properties['generate_debug_html']?.toLowerCase() == 'true',
        enableQb: properties['enable_qb']?.toLowerCase() == 'true',
        qbDataPath: _trimOrDefault(properties['qb_data_path'], 'qb_data')!,
        qbScope: _trimOrDefault(properties['qb_scope'], 'newData')!,
        qbBoards: _parseQbBoards(properties['qb_boards']),
        qbDelayMs: int.tryParse(properties['qb_delay_ms'] ?? '') ?? 1500,
        qbLesserBoardMaxPages:
            int.tryParse(properties['qb_lesser_board_max_pages'] ?? '') ?? 20,
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
  final bool generateDebugHtml;
  final bool enableQb;
  final String qbDataPath;
  final String qbScope;
  final Set<String> qbBoards;
  final int qbDelayMs;
  final int qbLesserBoardMaxPages;

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
    this.generateDebugHtml = false,
    this.enableQb = false,
    this.qbDataPath = 'qb_data',
    this.qbScope = 'newData',
    this.qbBoards = const {'main', 'libraries'},
    this.qbDelayMs = 1500,
    this.qbLesserBoardMaxPages = 20,
  });
}
