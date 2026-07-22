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

import 'package:mod_repo_scraper/bot/common.dart';
import 'package:mod_repo_scraper/timber/ktx/timber_kt.dart' as timber;
import 'package:mod_repo_scraper/manager/data_lock.dart';
import 'package:mod_repo_scraper/manager/delegation_client.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/job_manager.dart';
import 'package:mod_repo_scraper/manager/modrepo_service.dart';
import 'package:mod_repo_scraper/manager/run_history_store.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:mod_repo_scraper/manager/scraper_service.dart';
import 'package:mod_repo_scraper/manager/scraper_settings.dart';

import 'qb/models/scrape_job.dart';

class MainRepoScraper {
  static const String forumBaseUrl = "https://fractalsoftworks.com/forum/index.php";
  static const bool verboseOutput = true;

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
      await _runMergeThroughManager(config);
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

  /// The merge job the config file is asking for.
  ///
  /// `modrepo_use_cached` decides which of the two merge kinds it is: on means
  /// merge what is already saved and touch nothing on the network, off means
  /// fetch the sources that are switched on and then merge.
  static JobRequest _buildMergeRequest(BotConfig config) {
    if (config.useCached) {
      timber.i(
          message: () =>
              "ModRepo: merging what is already saved (modrepo_use_cached is "
              "on, so nothing will be fetched).");
      return JobRequest.mergeModRepo(
        keepAllGameVersions: config.keepAllGameVersionsFromSameSource,
        collectMergeDebug: config.generateMergeDebug,
      );
    }

    final sources = <ModSourceKind>{
      if (config.enableForums) ModSourceKind.forum,
      if (config.enableDiscord) ModSourceKind.discord,
      if (config.enableNexus) ModSourceKind.nexus,
    };

    return JobRequest.scrapeAndMerge(
      sources: sources,
      modForumPages: config.lessScraping ? 3 : null,
      moddingForumPages: config.lessScraping ? 3 : null,
      keepAllGameVersions: config.keepAllGameVersionsFromSameSource,
      collectMergeDebug: config.generateMergeDebug,
      replayAllowed: config.useCached,
    );
  }

  /// Runs the merge, on the manager when one is set up and here otherwise —
  /// the same terms the QB job runs on, so a merge started here and one started
  /// from a browser share a queue, a history and a lock.
  static Future<void> _runMergeThroughManager(BotConfig config) async {
    _bridgeLoggingToTimber();

    final request = _buildMergeRequest(config);
    final startTime = DateTime.now();

    final managerUrl = config.qbManagerUrl;
    if (managerUrl != null && managerUrl.trim().isNotEmpty) {
      final reporter = ConsoleRunReporter();
      final delegate = ManagerDelegate(
        managerUrl: managerUrl.trim(),
        dataPath: config.qbDataPath,
        reporter: reporter,
      );
      try {
        timber.i(
            message: () => "Starting the merge on the manager at "
                "$managerUrl...");
        final record = await delegate.run(
          request,
          interrupts: ProcessSignal.sigint.watch(),
        );
        if (record != null) {
          timber.i(
              message: () => "Merge completed in "
                  "${DateTime.now().difference(startTime).inSeconds}s "
                  "(run ${record.id}, on the manager).");
          if (record.state == RunState.failed) exitCode = 1;
          return;
        }
      } finally {
        reporter.finish();
        delegate.close();
      }
      // The delegate handed the job back, having said why. Run it here.
    }

    final manager = JobManager(
      service: ModRepoService(
        environment: ModRepoEnvironment.fromConfig(config),
        guardrails: ModRepoGuardrails.fromConfig(config),
      ),
      history: RunHistoryStore(config.qbDataPath,
          runsToKeep: config.qbRunsToKeep),
      lock: DataLock(dataPath: config.qbDataPath, label: 'cli'),
      makeReporter: (_) => ConsoleRunReporter(),
    );
    await manager.load();

    final record = await manager.submit(request);
    if (record.errorMessage != null) {
      timber.e(message: () => "Merge failed: ${record.errorMessage}");
      exitCode = 1;
    }
    timber.i(
        message: () => "Merge completed in "
            "${DateTime.now().difference(startTime).inSeconds}s "
            "(run ${record.id}).");
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
