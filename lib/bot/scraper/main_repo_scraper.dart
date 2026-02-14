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

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mod_repo_scraper/bot/common.dart';
import 'package:mod_repo_scraper/timber/ktx/timber_kt.dart' as timber;
import 'package:mod_repo_scraper/utilities/caching_http_client.dart';
import 'package:mod_repo_scraper/utilities/jsanity.dart';

import 'debug/merge_debug_collector.dart';
import 'debug/merge_debug_html_generator.dart';
import 'discord_reader.dart';
import 'forum_scraper.dart';
import 'mod_merger.dart';
import 'mod_repo_cache.dart';
import 'nexus_reader.dart';
import 'scraped_mod.dart';

class MainRepoScraper {
  static const String forumBaseUrl = "https://fractalsoftworks.com/forum/index.php";
  static const bool verboseOutput = true;

  static Future<List<ScrapedMod>> _loadOrRun({
    required String name,
    required bool enabled,
    required bool useCached,
    required Jsanity jsanity,
    required Future<List<ScrapedMod>?> Function() run,
  }) async {
    final stepStartTime = DateTime.now();
    final cacheFile = File("${name.toLowerCase()}_cache.json");

    if (useCached && await cacheFile.exists()) {
      timber.i(message: () => "Loading $name from cache...");
      try {
        final json = await cacheFile.readAsString();
        final results = jsanity.fromJson<ScrapedMods>(json, cacheFile.path, ScrapedModsMapper.fromMap).items;
        timber.i(
            message: () =>
                "$name loaded from cache (${results.length} mods) in ${DateTime.now().difference(stepStartTime).inMilliseconds}ms.");
        return results;
      } catch (e) {
        timber.e(message: () => "Error loading $name cache: $e");
      }
    }

    if (!enabled) return [];

    try {
      final results = await run() ?? [];
      timber.i(
          message: () =>
              "$name scraping finished (${results.length} mods) in ${DateTime.now().difference(stepStartTime).inMilliseconds}ms.");
      if (results.isNotEmpty) {
        timber.i(message: () => "Saving ${results.length} $name results to cache...");
        final scrapedMods = ScrapedMods(items: results);
        await cacheFile.writeAsString(scrapedMods.toJson());
      }
      return results;
    } catch (e) {
      timber.e(message: () => "Error running $name: $e");
      return [];
    }
  }

  static Future<void> main(List<String> args) async {
    final config = Common.readConfig();
    if (config == null) return;

    final (:logFile, :logOut) = await Common.initTimber(
      botConfig: config,
      logFilePath: "ModRepo.log",
    );

    final startTime = DateTime.now();

    final jsanity = Jsanity();
    final modRepoCache = ModRepoCache();

    // Run scraping tasks in parallel
    final forumJob = _loadOrRun(
        name: "Forum",
        enabled: config.enableForums,
        useCached: config.useCached,
        jsanity: jsanity,
        run: () => ForumScraper.run(
              moddingForumPagesToScrape: config.lessScraping ? 3 : 15,
              modForumPagesToScrape: config.lessScraping ? 3 : 12,
            ).timeout(const Duration(seconds: 60 * 2)));

    // Discord uses a caching HTTP client to cache raw API responses,
    // allowing re-runs of the processing pipeline without hitting Discord.
    final discordCacheFile = File('discord_raw_cache.json');
    final discordJob = () async {
      if (!config.enableDiscord) return <ScrapedMod>[];

      final stepStartTime = DateTime.now();
      final http.Client httpClient;

      if (config.useCached && await discordCacheFile.exists()) {
        timber.i(message: () => "Loading Discord raw HTTP cache...");
        httpClient = await CachingClient.fromFile(discordCacheFile.path);
      } else if (config.useCached) {
        httpClient = CachingClient(http.Client());
      } else {
        // If useCached is false, don't generate a cache file.
        // We don't want to be doing this on production.
        httpClient = http.Client();
      }

      try {
        final results = await DiscordReader.readAllMessages(config, httpClient: httpClient) ?? [];
        timber.i(
            message: () =>
                "Discord scraping finished (${results.length} mods) in ${DateTime.now().difference(stepStartTime).inMilliseconds}ms.");

        if (httpClient is CachingClient && !httpClient.isReplaying) {
          timber.i(message: () => "Saving Discord raw HTTP cache...");
          await httpClient.saveToFile(discordCacheFile.path);
        }

        return results;
      } catch (e) {
        timber.e(message: () => "Error running Discord: $e");
        return <ScrapedMod>[];
      }
    }();

    final nexusModsJob = _loadOrRun(
      name: "Nexus",
      enabled: config.enableNexus,
      useCached: config.useCached,
      jsanity: jsanity,
      run: () => NexusReader.readAllMessages(config).timeout(const Duration(seconds: 60 * 2)),
    );

    final forumMods = await forumJob;
    timber.i(message: () => "Forum scraping completed in ${DateTime.now().difference(startTime).inMilliseconds}ms.");
    final discordMods = await discordJob;
    timber.i(message: () => "Discord scraping completed in ${DateTime.now().difference(startTime).inMilliseconds}ms.");
    final nexusMods = await nexusModsJob;
    timber.i(message: () => "Nexus scraping completed in ${DateTime.now().difference(startTime).inMilliseconds}ms.");
    timber.i(message: () => "All scraping completed in ${DateTime.now().difference(startTime).inMilliseconds}ms.");

    timber.i(
        message: () =>
            "Found ${forumMods.length} forum mods, ${discordMods.length} Discord mods, and ${nexusMods.length} Nexus mods.");
    timber.i(message: () => "Starting merge...");

    final debugCollector = config.generateDebugHtml ? MergeDebugCollector() : null;

    final mergeStartTime = DateTime.now();
    final mergedMods = await ModMerger().merge(
      [...forumMods, ...discordMods, ...nexusMods],
      keepAllGameVersionsFromSameSource: config.keepAllGameVersionsFromSameSource,
      debugCollector: debugCollector,
    );
    timber.i(message: () => "Merge completed in ${DateTime.now().difference(mergeStartTime).inMilliseconds}ms.");

    if (debugCollector != null) {
      timber.i(message: () => "Generating debug HTML report...");
      await MergeDebugHtmlGenerator.generate(debugCollector.data, 'MergeDebug.html');
      timber.i(message: () => "Debug HTML report written to MergeDebug.html.");
    }

    timber.i(message: () => "Saving ${mergedMods.length} mods to ${ModRepoCache.location.absolute.path}...");
    final saveStartTime = DateTime.now();
    modRepoCache.items = mergedMods;
    modRepoCache.totalCount = mergedMods.length;
    modRepoCache.lastUpdated = DateTime.now().toIso8601String();
    modRepoCache.save();
    timber.i(message: () => "Save completed in ${DateTime.now().difference(saveStartTime).inMilliseconds}ms.");

    final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
    timber.i(message: () => "Total run completed in ${elapsedSeconds}s.");
    timber.i(message: () => "Total time: ${elapsedSeconds}s.");
    timber.i(message: () => "Saved ${mergedMods.length} mods to ${ModRepoCache.location.absolute.path}.");

    await Future.delayed(const Duration(seconds: 1));
    timber.i(message: () => "Wrote log to ${logFile.absolute.path}.");
    logOut.close();
  }
}
