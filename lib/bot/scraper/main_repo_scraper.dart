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

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:mod_repo_scraper/bot/common.dart';
import 'package:mod_repo_scraper/timber/ktx/timber_kt.dart' as timber;
import 'package:mod_repo_scraper/manager/data_lock.dart';
import 'package:mod_repo_scraper/manager/delegation_client.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/job_manager.dart';
import 'package:mod_repo_scraper/manager/run_history_store.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:mod_repo_scraper/manager/scraper_service.dart';
import 'package:mod_repo_scraper/manager/scraper_settings.dart';
import 'package:mod_repo_scraper/utilities/caching_http_client.dart';
import 'package:mod_repo_scraper/utilities/jsanity.dart';

import 'debug/merge_debug_collector.dart';
import 'debug/merge_debug_data.dart';
import 'discord_reader.dart';
import 'forum_scraper.dart';
import 'mod_merger.dart';
import 'mod_repo_cache.dart';
import 'nexus_reader.dart';
import 'qb/models/scrape_job.dart';
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

    // --- ModRepo Pipeline (Forum/Discord/Nexus → merge → ModRepo.json) ---
    if (config.enableModRepo) {
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
          // Records each response to the cache file as it arrives, so a run that
          // is interrupted keeps what it already fetched.
          httpClient = CachingClient(http.Client(), recordPath: discordCacheFile.path);
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

          return results;
        } catch (e) {
          timber.e(message: () => "Error running Discord: $e");
          return <ScrapedMod>[];
        } finally {
          // The responses were written as they arrived; this just finishes off
          // the file. Runs on the error path too, so a failed run still keeps
          // the responses it got.
          if (httpClient is CachingClient && !httpClient.isReplaying) {
            timber.i(message: () => "Saving Discord raw HTTP cache...");
            await httpClient.saveToFile(discordCacheFile.path);
          }
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
      timber.i(
          message: () => "Discord scraping completed in ${DateTime.now().difference(startTime).inMilliseconds}ms.");
      final nexusMods = await nexusModsJob;
      timber.i(message: () => "Nexus scraping completed in ${DateTime.now().difference(startTime).inMilliseconds}ms.");
      timber.i(message: () => "All scraping completed in ${DateTime.now().difference(startTime).inMilliseconds}ms.");

      timber.i(
          message: () =>
              "Found ${forumMods.length} forum mods, ${discordMods.length} Discord mods, and ${nexusMods.length} Nexus mods.");
      timber.i(message: () => "Starting merge...");

      final debugCollector = config.generateMergeDebug ? MergeDebugCollector() : null;

      final mergeStartTime = DateTime.now();
      final mergedMods = await ModMerger().merge(
        [...forumMods, ...discordMods, ...nexusMods],
        keepAllGameVersionsFromSameSource: config.keepAllGameVersionsFromSameSource,
        debugCollector: debugCollector,
      );
      timber.i(message: () => "Merge completed in ${DateTime.now().difference(mergeStartTime).inMilliseconds}ms.");

      if (debugCollector != null) {
        timber.i(message: () => "Writing merge debug data...");
        MergeDebugDataMapper.ensureInitialized();
        final debugJson = const JsonEncoder.withIndent('  ')
            .convert(debugCollector.data.toMap());
        await File('merge-debug.json').writeAsString(debugJson);
        timber.i(message: () => "Merge debug data written to merge-debug.json.");
      }

      timber.i(message: () => "Saving ${mergedMods.length} mods to ${ModRepoCache.location.absolute.path}...");
      final saveStartTime = DateTime.now();
      modRepoCache.items = mergedMods;
      modRepoCache.totalCount = mergedMods.length;
      modRepoCache.lastUpdated = DateTime.now().toIso8601String();
      modRepoCache.save();
      timber.i(message: () => "Save completed in ${DateTime.now().difference(saveStartTime).inMilliseconds}ms.");
    } else {
      timber.i(message: () => "ModRepo pipeline disabled, skipping.");
    }

    // --- QB Pipeline ---
    if (config.enableQb) {
      await _runQbThroughManager(config);
    }

    final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
    timber.i(message: () => "Total run completed in ${elapsedSeconds}s.");
    timber.i(message: () => "Total time: ${elapsedSeconds}s.");

    await Future.delayed(const Duration(seconds: 1));
    timber.i(message: () => "Wrote log to ${logFile.absolute.path}.");
    logOut.close();
  }

  /// Turns the config file's job-shape keys into one job request and hands it to
  /// the manager. This is the only place those keys are read: the manager core
  /// itself is told what to do, never asked to look it up.
  ///
  /// When `qb_manager_url` names a running server, the job goes there instead,
  /// so a run started here and one started from a browser share one queue and
  /// one history. Anything that gets in the way of that — nothing answering, a
  /// server with no manager, a server working on another folder — is reported
  /// and the job runs here as usual.
  static Future<void> _runQbThroughManager(BotConfig config) async {
    _bridgeLoggingToTimber();

    final request = _buildQbRequest(config);
    final qbStartTime = DateTime.now();

    final managerUrl = config.qbManagerUrl;
    if (managerUrl != null && managerUrl.trim().isNotEmpty) {
      final reporter = ConsoleRunReporter();
      final delegate = ManagerDelegate(
        managerUrl: managerUrl.trim(),
        dataPath: config.qbDataPath,
        reporter: reporter,
      );
      try {
        timber.i(message: () => "Starting QB pipeline on the manager at "
            "$managerUrl...");
        final record = await delegate.run(
          request,
          interrupts: ProcessSignal.sigint.watch(),
        );
        if (record != null) {
          timber.i(
              message: () => "QB pipeline completed in "
                  "${DateTime.now().difference(qbStartTime).inSeconds}s "
                  "(run ${record.id}, on the manager).");
          if (record.state == RunState.failed) exitCode = 1;
          return;
        }
      } finally {
        reporter.finish();
        delegate.close();
      }
      // The delegate handed the job back, having said why. Carry on and run it
      // here.
    }

    await _runQbLocally(config, request, qbStartTime);
  }

  /// Runs the QB job in this process, the way it has always run.
  static Future<void> _runQbLocally(
    BotConfig config,
    JobRequest request,
    DateTime qbStartTime,
  ) async {
    final service = ScraperService(
      environment: ScraperEnvironment.fromConfig(config),
      guardrails: ScraperGuardrails.fromConfig(config),
    );
    final manager = JobManager(
      service: service,
      history: RunHistoryStore(config.qbDataPath,
          runsToKeep: config.qbRunsToKeep),
      lock: DataLock(dataPath: config.qbDataPath, label: 'cli'),
      makeReporter: (_) => ConsoleRunReporter(),
    );
    await manager.load();

    timber.i(message: () => "Starting QB pipeline...");
    try {
      final record = await manager.submit(request);
      if (record.errorMessage != null) {
        timber.e(message: () => "QB pipeline failed: ${record.errorMessage}");
        exitCode = 1;
      }
      timber.i(
          message: () => "QB pipeline completed in "
              "${DateTime.now().difference(qbStartTime).inSeconds}s "
              "(run ${record.id}).");
    } finally {
      service.close();
    }
  }

  /// The job the config file is asking for.
  static JobRequest _buildQbRequest(BotConfig config) {
    if (config.enableLlm && config.llmTestMode) {
      // Reads posts already saved on disk — no scrape, no bundle write. This is
      // for testing the prompt without touching the real data.
      timber.i(
          message: () =>
              "LLM TEST MODE: testing over already-stored posts (no scrape).");
      return JobRequest.llmTest(
        topicIds: config.llmTestTopicIds?.toList() ?? const [],
        limit: config.llmTestLimit,
      );
    }
    if (config.enableLlm && config.llmSkipScrapeReprocessOnly) {
      timber.i(
          message: () =>
              "LLM: covering every stored topic (no scrape this run)...");
      return JobRequest.llmCoveragePass();
    }

    final parsedScope = parseScopeType(config.qbScope);
    if (parsedScope == null) {
      timber.w(
          message: () =>
              "Unrecognized qb_scope '${config.qbScope}'; accepted values "
              "are ${ScopeType.values.map((e) => e.name).join(', ')}. "
              "Using default '${ScopeType.newData.name}'.");
    }

    final boards = config.qbBoards.map((name) {
      return ScrapeBoard.values.firstWhere(
        (b) => b.name == name,
        orElse: () {
          timber.w(
              message: () =>
                  "Unknown QB board name: '$name', defaulting to 'main'");
          return ScrapeBoard.main;
        },
      );
    }).toSet();

    return JobRequest.fullRun(
      scope: parsedScope ?? ScopeType.newData,
      boards: boards,
      maxPagesMain: config.qbMaxPagesMain,
      maxPagesLesser: config.qbLesserBoardMaxPages,
      maxPagesLibraries: config.qbMaxPagesLibraries,
      runLlm: config.enableLlm,
      replayAllowed: config.qbUseCached,
    );
  }

  /// The QB code logs through the `logging` package; send those lines to the
  /// same place everything else goes. The manager server does the same, so a
  /// run's own log file reads the same whichever side started it.
  static void _bridgeLoggingToTimber() => Common.bridgeLoggingToTimber();
}
