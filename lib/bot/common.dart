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
import 'package:usc_scraper/timber/ktx/timber_kt.dart' as timber;
import 'package:usc_scraper/timber/log_level.dart';
import 'package:usc_scraper/timber/timber.dart' as timber_lib;

part 'common.mapper.dart';

class Common {
  static const String serverId = "187635036525166592";

  /// Whether a url has a downloadable file on the other side.
  /// Requires Internet.
  static Future<bool> isDownloadable(String? url) async {
    if (url == null) return false;

    try {
      timber.d(message: () => 'Checking to see if $url is downloadable by opening a connection.');
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      final contentDisposition = response.headers.value('content-disposition');
      final hasAttachment = contentDisposition != null && contentDisposition.toLowerCase().startsWith('attachment');

      final contentType = response.headers.contentType;
      final downloadableContentTypes = [
        'application/octet-stream',
        'application/zip',
      ];
      final hasDownloadableContentType = contentType != null &&
          downloadableContentTypes.any((type) => contentType.mimeType.toLowerCase() == type.toLowerCase());

      final isDownloadable = hasAttachment || hasDownloadableContentType;

      timber.d(
          message: () =>
              'Url \'$url\': HasAttachment: $hasAttachment, HasDownloadableContentType: $hasDownloadableContentType.');

      return isDownloadable;
    } catch (e) {
      timber.d(t: e, message: () => 'Error checking if downloadable');
      return false;
    }
  }

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
        keepAllGameVersionsFromSameSource:
            properties['keep_all_game_versions_from_same_source']?.toLowerCase() == 'true',
        generateDebugHtml: properties['generate_debug_html']?.toLowerCase() == 'true',
      );
    } catch (e) {
      stderr.writeln(e);
      return null;
    }
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
  final bool keepAllGameVersionsFromSameSource;
  final bool generateDebugHtml;

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
    this.keepAllGameVersionsFromSameSource = false,
    this.generateDebugHtml = false,
  });
}
