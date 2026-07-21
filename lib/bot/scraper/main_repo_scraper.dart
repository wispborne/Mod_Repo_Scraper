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
import 'package:mod_repo_scraper/utilities/caching_http_client.dart';
import 'package:mod_repo_scraper/utilities/console_progress_bar.dart';
import 'package:mod_repo_scraper/utilities/jsanity.dart';

import 'debug/merge_debug_collector.dart';
import 'debug/merge_debug_data.dart';
import 'discord_reader.dart';
import 'forum_scraper.dart';
import 'mod_merger.dart';
import 'mod_repo_cache.dart';
import 'nexus_reader.dart';
import 'qb/bundle_publisher.dart';
import 'qb/download_resolver.dart';
import 'qb/downloadable_probe_cache.dart';
import 'qb/json_data_store.dart';
import 'qb/llm/extraction_store.dart';
import 'qb/llm/fallback_llm_client.dart';
import 'qb/llm/llm_client.dart';
import 'qb/llm/openai_client.dart';
import 'qb/llm/post_extractor.dart';
import 'qb/models/scrape_job.dart';
import 'qb/scraper_engine.dart';
import 'qb/throttled_client.dart';
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

  /// Runs LLM test mode over posts already saved on disk, so the prompt can be
  /// tested without re-scraping. Targets [BotConfig.llmTestTopicIds] when set;
  /// otherwise samples stored posts in index order up to
  /// [BotConfig.llmTestLimit].
  static Future<void> _runLlmTestOverStore(
    BotConfig config,
    JsonDataStore store,
    QbDownloadResolver resolver,
    PostExtractor extractor,
  ) async {
    final ids = config.llmTestTopicIds;
    if (ids != null && ids.isNotEmpty) {
      final bar = ConsoleProgressBar.start('LLM test', ids.length);
      var seen = 0;
      for (final id in ids) {
        seen++;
        final detail = await store.loadDetail(id);
        if (detail == null) {
          timber.w(
              message: () =>
                  "LLM test: topic $id not found in the store; skipping.");
          bar.update(seen);
          continue;
        }
        await extractor.extractForTopic(
            detail, resolver.getCachedCandidates(id) ?? const []);
        bar.update(seen, item: detail.title);
      }
      bar.finish();
    } else {
      final index = await store.loadIndex();
      final bar = ConsoleProgressBar.start('LLM test', config.llmTestLimit);
      for (final summary in index) {
        if (extractor.testCallCount >= config.llmTestLimit) break;
        final detail = await store.loadDetail(summary.topicId);
        if (detail == null) continue;
        await extractor.extractForTopic(
            detail, resolver.getCachedCandidates(summary.topicId) ?? const []);
        bar.update(extractor.testCallCount, item: detail.title);
      }
      bar.finish();
    }
  }

  /// Saves the QB caches on the failure path. A run that broke has still fetched
  /// pages, resolved links and probed hosts; keeping that means the next run
  /// doesn't pay for it twice. Save errors are logged and swallowed so they
  /// can't hide the failure that got us here.
  static Future<void> _saveQbCachesQuietly(
    QbDownloadResolver resolver,
    DownloadableProbeCache probeCache,
  ) async {
    try {
      await resolver.saveCache();
      await probeCache.saveCache();
    } catch (e) {
      timber.w(message: () => "Could not save QB caches after the failure: $e");
    }
  }

  /// Why the extractor will not make any more calls this run, or null while it
  /// still can.
  static String? _llmStopReason(PostExtractor extractor) {
    if (extractor.hasBailed) {
      return "the LLM kept failing, so it stopped calling";
    }
    final cap = extractor.maxTopics;
    if (cap != null && extractor.liveCallCount >= cap) {
      return "it hit the per-run limit (llm_max_topics=$cap)";
    }
    return null;
  }

  /// Walks every topic in the mods index and makes sure each one has LLM
  /// results, whether or not it was scraped this run. A topic whose stored
  /// result is still good is served from the store and costs nothing, so a
  /// topic already extracted during the scrape is not paid for twice.
  ///
  /// Runs from both the normal path (after the scrape) and the reprocess-only
  /// path (instead of a scrape), so it says nothing about whether a scrape
  /// happened.
  static Future<void> _runLlmCoveragePass(
    JsonDataStore store,
    QbDownloadResolver resolver,
    LlmExtractionStore llmStore,
    PostExtractor extractor,
  ) async {
    final index = await store.loadIndex();
    final bar = ConsoleProgressBar.start('LLM coverage', index.length);

    var seen = 0;
    var alreadyHadResults = 0; // results were already stored when we got here
    var passCalls = 0; // sent to the LLM by this pass
    var skipped = 0; // no post saved on disk, or a stub post we never send
    var withoutResults = 0; // ends the run with nothing stored
    String? stopReason;

    for (final summary in index) {
      seen++;
      final detail = await store.loadDetail(summary.topicId);
      if (detail == null || detail.isPlaceholderDetail) {
        skipped++;
        bar.update(seen);
        continue;
      }

      // Read the store before the call, not after, so a topic extracted earlier
      // in this run (during the scrape) is counted as one we already had rather
      // than one this pass produced.
      if (llmStore.get(summary.topicId) != null) alreadyHadResults++;

      // Once the extractor has stopped calling, keep walking the index so the
      // count of what is left is right, but don't ask it for work it will
      // refuse.
      stopReason ??= _llmStopReason(extractor);
      if (stopReason == null) {
        final callsBefore = extractor.liveCallCount;
        await extractor.extractForTopic(
            detail, resolver.getCachedCandidates(summary.topicId) ?? const []);
        if (extractor.liveCallCount > callsBefore) passCalls++;
      }

      if (llmStore.get(summary.topicId) == null) withoutResults++;

      bar.update(seen, item: detail.title);
      if (seen % 50 == 0) {
        timber.i(
            message: () => "LLM: covered $seen/${index.length} topics "
                "($passCalls sent to the LLM so far)...");
      }
    }
    bar.finish();

    // The run's call count, not the pass's: topics scraped this run were sent
    // to the LLM inside the scrape loop, and those calls count against the same
    // per-run limit.
    final runCalls = extractor.liveCallCount;
    timber.i(
        message: () => "LLM coverage: ${index.length} topics in the index, "
            "$alreadyHadResults already had results, $passCalls sent to the LLM "
            "by this pass ($runCalls this run in total, counting topics done "
            "during the scrape), $skipped skipped (no post saved).");
    if (stopReason != null) {
      timber.w(
          message: () => "LLM: stopped early because $stopReason. "
              "$withoutResults topic(s) still have no LLM results; run again to "
              "carry on where this run stopped.");
    } else {
      timber.i(
          message: () => "LLM: $withoutResults topic(s) still have no LLM "
              "results.");
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
      Logger.root.level = Level.ALL;
      Logger.root.onRecord.listen((record) {
        final msg = '${record.loggerName}: ${record.message}';
        if (record.level >= Level.SEVERE) {
          timber.e(message: () => msg);
        } else if (record.level >= Level.WARNING) {
          timber.w(message: () => msg);
        } else {
          timber.i(message: () => msg);
        }
      });

      final qbCacheFile = File('${config.qbDataPath}/qb_raw_cache.json');
      final CachingClient? qbCachingClient;

      if (config.qbUseCached && await qbCacheFile.exists()) {
        timber.i(message: () => "Loading QB raw HTTP cache...");
        qbCachingClient = await CachingClient.fromFile(qbCacheFile.path);
      } else {
        // Records each response to the cache file as it arrives, rather than
        // holding the whole run's pages in memory and writing at the end.
        await qbCacheFile.parent.create(recursive: true);
        qbCachingClient = CachingClient(http.Client(), recordPath: qbCacheFile.path);
      }

      final qbClient = ThrottledClient(
        client: qbCachingClient,
        delayMs: qbCachingClient.isReplaying ? 0 : config.qbDelayMs,
      );
      // Console-only progress bar; it never touches the log file. Started
      // lazily on the first progress report so it gets the real topic count.
      ConsoleProgressBar? progressBar;

      final qbStore = JsonDataStore(config.qbDataPath);
      final qbEngine = QbScraperEngine(
        store: qbStore,
        client: qbClient,
      );
      final qbResolver = qbEngine.downloadResolver;

      try {
        timber.i(message: () => "Starting QB pipeline...");
        final qbStartTime = DateTime.now();

        final parsedScope = parseScopeType(config.qbScope);
        if (parsedScope == null) {
          timber.w(
              message: () =>
                  "Unrecognized qb_scope '${config.qbScope}'; accepted values "
                  "are ${ScopeType.values.map((e) => e.name).join(', ')}. "
                  "Using default '${ScopeType.newData.name}'.");
        }
        final scopeType = parsedScope ?? ScopeType.newData;

        final boards = config.qbBoards.map((name) {
          final board = ScrapeBoard.values.firstWhere(
            (b) => b.name == name,
            orElse: () {
              timber.w(message: () => "Unknown QB board name: '$name', defaulting to 'main'");
              return ScrapeBoard.main;
            },
          );
          return board;
        }).toSet();

        final scope = ScrapeScope(
          type: scopeType,
          boards: boards,
          maxPagesMain: config.qbMaxPagesMain,
          maxPagesLesser: config.qbLesserBoardMaxPages,
          maxPagesLibraries: config.qbMaxPagesLibraries,
        );

        await qbResolver.loadCache();
        await qbEngine.probeCache.loadCache();

        // --- Optional LLM post-extraction ---
        PostExtractor? extractor;
        LlmExtractionStore? llmStore;
        ThrottledClient? llmClient;
        ThrottledClient? llmFallbackClient;
        if (config.enableLlm) {
          llmStore = LlmExtractionStore(config.qbDataPath);
          // Test mode never touches the real store; load only for real runs so
          // resume works.
          if (!config.llmTestMode) {
            await llmStore.load();
          }
          // A dedicated throttled client keeps LLM calls spaced out and off the
          // scraper's caching HTTP client.
          llmClient = ThrottledClient(
            client: http.Client(),
            delayMs: 250,
            timeout: Duration(seconds: config.llmTimeoutSeconds),
          );
          final primary = OpenAiCompatibleClient(
            client: llmClient,
            baseUrl: config.llmBaseUrl,
            model: config.llmModel,
            apiToken: config.llmApiToken,
            disableThinking: config.llmDisableThinking,
            structuredOutput: config.llmStructuredOutput,
          );
          // When a fallback provider is configured, wrap the primary so a post
          // switches to the fallback only if the primary can't be reached.
          LlmClient llm = primary;
          if (config.llmFallbackEnabled) {
            llmFallbackClient = ThrottledClient(
              client: http.Client(),
              delayMs: 250,
              timeout: Duration(seconds: config.llmTimeoutSeconds),
            );
            final fallback = OpenAiCompatibleClient(
              client: llmFallbackClient,
              baseUrl: config.llmFallbackBaseUrl!,
              model: config.llmFallbackModel!,
              apiToken: config.llmFallbackApiToken,
              disableThinking: config.llmFallbackDisableThinking,
              structuredOutput: config.llmFallbackStructuredOutput,
            );
            llm = FallbackLlmClient(
              primary: primary,
              fallback: fallback,
              primaryLabel:
                  '${config.llmModel} @ ${config.llmBaseUrl}',
              fallbackLabel:
                  '${config.llmFallbackModel} @ ${config.llmFallbackBaseUrl}',
            );
          }
          extractor = PostExtractor(
            client: llm,
            store: llmStore,
            resolver: qbResolver,
            dataPath: config.qbDataPath,
            maxConsecutiveFailures: config.llmMaxConsecutiveFailures,
            maxTopics: config.llmMaxTopics,
            maxTokens: config.llmMaxTokens,
            maxInputChars: config.llmMaxInputChars,
            generateSummaries: config.enableLlmSummaries,
            testMode: config.llmTestMode,
            testLimit: config.llmTestLimit,
            testTopicIds: config.llmTestTopicIds,
          );
          if (config.llmApiToken == null) {
            timber.i(
                message: () =>
                    "LLM: no API key set; sending requests without one "
                    "(fine for local servers like Ollama).");
          }
          final fallbackNote = config.llmFallbackEnabled
              ? ", fallback ${config.llmFallbackModel} @ "
                  "${config.llmFallbackBaseUrl} (used only if the primary is "
                  "unreachable)"
              : "";
          final structuredNote = config.llmStructuredOutput
              ? ", structured output ON (forces valid JSON)"
              : "";
          timber.i(
              message: () => config.llmTestMode
                  ? "LLM extraction: TEST MODE (limit ${config.llmTestLimit}, "
                      "model ${config.llmModel}, endpoint ${config.llmBaseUrl}"
                      "$structuredNote$fallbackNote)"
                  : "LLM extraction enabled (model ${config.llmModel}, "
                      "endpoint ${config.llmBaseUrl}$structuredNote$fallbackNote)");
        }

        if (config.enableLlm && config.llmTestMode && extractor != null) {
          // Read posts already saved on disk — no scrape, no bundle write.
          // This is for testing the prompt without touching the real data.
          timber.i(
              message: () =>
                  "LLM TEST MODE: testing over already-stored posts (no scrape).");
          await _runLlmTestOverStore(config, qbStore, qbResolver, extractor);
          await extractor.writeTestReport();
          llmClient?.close();
          llmFallbackClient?.close();
          timber.i(
              message: () =>
                  "LLM test mode finished; the real bundle and caches were left untouched.");
        } else if (config.enableLlm &&
            config.llmSkipScrapeReprocessOnly &&
            extractor != null) {
          // Same coverage pass as the normal path, minus the scrape: make sure
          // every stored topic has LLM results, then rebuild the bundle. Topics
          // whose results are still good are skipped, so re-runs only pay for
          // new or changed ones.
          timber.i(
              message: () =>
                  "LLM: covering every stored topic (no scrape this run)...");
          await _runLlmCoveragePass(qbStore, qbResolver, llmStore!, extractor);
          await llmStore.flush();
          // The LLM path checks unknown links through the shared
          // "does this serve a file?" cache; keep those answers for next time.
          await qbEngine.probeCache.saveCache();
          llmClient?.close();
          llmFallbackClient?.close();

          final publisher = BundlePublisher(
            store: qbStore,
            resolver: qbResolver,
            llmStore: llmStore,
            outputPath: 'outputs',
          );
          final bundle = await publisher.createBundle();
          await publisher.writeLocal(bundle);
          timber.i(
              message: () =>
                  "LLM over stored posts complete in ${DateTime.now().difference(qbStartTime).inSeconds}s; bundle written.");
        } else {
          final qbResult = await qbEngine.run(
            scope,
            onProgress: (processed, total, item) {
              progressBar ??= ConsoleProgressBar.start('Scraping topics', total);
              progressBar!.update(processed, total: total, item: item);
            },
            onTopicSaved: (detail) async {
              final candidates =
                  await qbResolver.resolveForTopic(detail.topicId, detail.links);
              if (extractor != null) {
                await extractor.extractForTopic(detail, candidates);
              }
            },
          );

          // Entries saved by an older version of the resolver may be missing
          // its newer rules. Redo them from the links already on disk, so the
          // bundle stays complete without anyone forcing a full re-scrape.
          final outdated = qbResolver.outdatedTopicIds;
          if (outdated.isNotEmpty) {
            timber.i(
                message: () =>
                    "Redoing ${outdated.length} download entries saved by an older version...");
            final redoBar =
                ConsoleProgressBar.start('Updating downloads', outdated.length);
            var redone = 0;
            for (final topicId in outdated) {
              final detail = await qbStore.loadDetail(topicId);
              if (detail != null) {
                await qbResolver.resolveForTopic(topicId, detail.links);
              }
              redoBar.update(++redone);
            }
            redoBar.finish();
          }

          // Topics scraped this run were already sent to the LLM inside the
          // scrape loop above. This pass catches every other stored topic — the
          // ones the incremental scope found unchanged, and the ones saved
          // before the LLM was turned on — so switching the LLM on means the
          // bundle's LLM data is complete, not that it fills in over months of
          // re-scrapes. Topics done during the scrape come back as store hits
          // here, so they are not paid for twice.
          if (extractor != null) {
            await _runLlmCoveragePass(qbStore, qbResolver, llmStore!, extractor);
            // Save LLM results before the caches below, so the bundle written at
            // the end sees everything this pass produced.
            await llmStore.flush();
          }

          // Both caches are written as the run goes; these are the final saves
          // that pick up whatever came after the last one. The LLM pass checks
          // the links the model picked, which can add new probe answers, so save
          // after it rather than before.
          await qbResolver.saveCache();
          await qbEngine.probeCache.saveCache();

          llmClient?.close();
          llmFallbackClient?.close();

          timber.i(
              message: () => "QB scrape completed: ${qbResult.modsScraped} mods, "
                  "${qbResult.errors} errors, "
                  "${DateTime.now().difference(qbStartTime).inSeconds}s.");

          final publisher = BundlePublisher(
            store: qbStore,
            resolver: qbResolver,
            llmStore: llmStore,
            outputPath: 'outputs',
          );

          final bundle = await publisher.createBundle(scrapeResult: qbResult);
          await publisher.writeLocal(bundle);

          timber.i(message: () => "QB pipeline completed in ${DateTime.now().difference(qbStartTime).inSeconds}s.");
        }
      } catch (e, st) {
        timber.e(message: () => "QB pipeline failed: $e\n$st");

        // A failed run has still done real work: pages fetched, links resolved,
        // links probed. Keep it, so the next run doesn't pay for it again.
        await _saveQbCachesQuietly(qbResolver, qbEngine.probeCache);
      } finally {
        progressBar?.finish();
        if (!qbCachingClient.isReplaying) {
          // Responses were written as they arrived; this finishes off the file.
          timber.i(message: () => "Saving QB raw HTTP cache...");
          await qbCachingClient.saveToFile(qbCacheFile.path);
        } else {
          timber.i(message: () => "QB ran from cache; skipping cache save.");
        }
        qbClient.close();
      }
    }

    final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
    timber.i(message: () => "Total run completed in ${elapsedSeconds}s.");
    timber.i(message: () => "Total time: ${elapsedSeconds}s.");

    await Future.delayed(const Duration(seconds: 1));
    timber.i(message: () => "Wrote log to ${logFile.absolute.path}.");
    logOut.close();
  }
}
