import 'dart:io' as io;

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path/path.dart' as p;

import '../bot/scraper/qb/bundle_publisher.dart';
import '../bot/scraper/qb/download_resolver.dart';
import '../bot/scraper/qb/downloadable_probe_cache.dart';
import '../bot/scraper/qb/json_data_store.dart';
import '../bot/scraper/qb/llm/extraction_store.dart';
import '../bot/scraper/qb/llm/fallback_llm_client.dart';
import '../bot/scraper/qb/llm/llm_client.dart';
import '../bot/scraper/qb/llm/openai_client.dart';
import '../bot/scraper/qb/llm/post_extractor.dart';
import '../bot/scraper/qb/models/forum_data_bundle.dart';
import '../bot/scraper/qb/models/scrape_job.dart';
import '../bot/scraper/qb/scraper_engine.dart';
import '../bot/scraper/qb/throttled_client.dart';
import '../site/public_site_step.dart';
import '../utilities/caching_http_client.dart';
import 'bundle_snapshot_store.dart';
import 'cancel_token.dart';
import 'job.dart';
import 'run_reporter.dart';
import 'scraper_settings.dart';

/// How a job went. The job manager copies this onto the run's record.
class JobOutcome {
  final int itemsDone;
  final int itemsTotal;
  final int errors;

  /// Calls actually sent to the LLM. Topics served from saved answers are free
  /// and are not counted.
  final int llmCalls;

  /// Set when a limit cut the job short, in plain words. The job still counts
  /// as completed.
  final String? guardrailStop;

  /// True when the job stopped because it was asked to.
  final bool cancelled;

  const JobOutcome({
    this.itemsDone = 0,
    this.itemsTotal = 0,
    this.errors = 0,
    this.llmCalls = 0,
    this.guardrailStop,
    this.cancelled = false,
  });

  RunCounters toCounters() => RunCounters(
        itemsDone: itemsDone,
        itemsTotal: itemsTotal,
        errors: errors,
        llmCalls: llmCalls,
      );
}

/// Something that can do one job and say how it went.
///
/// [ScraperService] is the real one. Having the job manager depend on this much
/// and no more lets a test stand in a job that finishes when it is told to,
/// without a forum, an LLM, or a folder full of files.
abstract class JobRunner {
  /// [runId] names the run this job belongs to, so anything a job saves
  /// alongside the run's record and log can be filed under the same name. Null
  /// when nobody is keeping a history — a direct call in a test, say.
  Future<JobOutcome> runJob(
    JobRequest request, {
    RunReporter reporter,
    CancelToken? cancel,
    String? runId,
  });
}

/// The scraper as something you can call, rather than a program you run.
///
/// It is built once with the environment (where the files are, which services
/// it may talk to) and the guardrails (how much may be spent, how fast the
/// forum may be hit). Everything about *what* to do arrives with each
/// [runJob] call, as a [JobRequest]. The service never reads the config file's
/// job-shape keys, so nothing about a job can be changed behind the caller's
/// back.
class ScraperService implements JobRunner {
  final ScraperEnvironment environment;
  final ScraperGuardrails guardrails;

  final JsonDataStore store;
  final DownloadableProbeCache probeCache;
  final QbDownloadResolver resolver;

  /// Null when the environment has no LLM service set up.
  final LlmExtractionStore? llmStore;

  /// Keeps a copy of each bundle this service publishes, so two runs can be
  /// compared afterwards.
  final BundleSnapshotStore bundleSnapshots;

  /// Works out which mods released, and rebuilds the public website's files.
  final PublicSiteStep siteStep;

  final http.Client _linkClient;

  /// Makes the client used to reach the forum. Swapped out in tests.
  final http.Client Function() _createNetworkClient;

  /// Makes the LLM client, when something other than the configured service
  /// should answer. Only tests set this.
  final LlmClient Function()? _createLlmClient;

  bool _loaded = false;

  /// Builds the store, the caches and the link client once. They are shared by
  /// every job, so the answers read from disk are read once.
  factory ScraperService({
    required ScraperEnvironment environment,
    required ScraperGuardrails guardrails,
    http.Client? linkClient,
    http.Client Function()? createNetworkClient,
    LlmClient Function()? createLlmClient,
  }) {
    final links = linkClient ??
        IOClient(
          io.HttpClient()..connectionTimeout = const Duration(seconds: 30),
        );
    final probeCache = DownloadableProbeCache(dataPath: environment.dataPath);
    return ScraperService._(
      environment: environment,
      guardrails: guardrails,
      store: JsonDataStore(environment.dataPath),
      probeCache: probeCache,
      resolver: QbDownloadResolver(
        client: links,
        dataPath: environment.dataPath,
        probeCache: probeCache,
      ),
      llmStore: environment.llm == null
          ? null
          : LlmExtractionStore(environment.dataPath),
      bundleSnapshots: BundleSnapshotStore(environment.dataPath,
          bundlesToKeep: guardrails.bundlesToKeep),
      siteStep: PublicSiteStep(
        dataPath: environment.dataPath,
        outputPath: environment.outputPath,
        sitePath: environment.sitePath,
      ),
      linkClient: links,
      createNetworkClient: createNetworkClient ?? http.Client.new,
      createLlmClient: createLlmClient,
    );
  }

  ScraperService._({
    required this.environment,
    required this.guardrails,
    required this.store,
    required this.probeCache,
    required this.resolver,
    required this.llmStore,
    required this.bundleSnapshots,
    required this.siteStep,
    required http.Client linkClient,
    required http.Client Function() createNetworkClient,
    LlmClient Function()? createLlmClient,
  })  : _linkClient = linkClient,
        _createNetworkClient = createNetworkClient,
        _createLlmClient = createLlmClient;

  /// Reads the saved caches. Call once before the first job; later calls do
  /// nothing.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    await resolver.loadCache();
    await probeCache.loadCache();
    await llmStore?.load();
  }

  /// Runs one job and says how it went. Never throws for a job that merely did
  /// badly — a job that breaks throws, and the caller records the failure.
  @override
  Future<JobOutcome> runJob(
    JobRequest request, {
    RunReporter reporter = const SilentRunReporter(),
    CancelToken? cancel,
    String? runId,
  }) async {
    await load();
    switch (request.kind) {
      case JobKind.fullRun:
        return _fullRun(request, reporter, cancel, runId);
      case JobKind.rescrapeTopics:
        return _rescrapeTopics(request, reporter, cancel, runId);
      case JobKind.resolveDownloads:
        return _resolveDownloads(request, reporter, cancel, runId);
      case JobKind.extractLlm:
        return _extractLlm(request, reporter, cancel, runId);
      case JobKind.llmCoveragePass:
        return _llmCoveragePassJob(request, reporter, cancel, runId);
      case JobKind.llmTest:
        return _llmTest(request, reporter, cancel);
      case JobKind.rebuildBundle:
        return _rebuildBundleJob(reporter, runId);
      case JobKind.mergeModRepo:
      case JobKind.scrapeAndMerge:
        // The merge kinds belong to the ModRepo service. A JobRouter sends them
        // there; this service only ever sees them if it was wired up on its own.
        throw ArgumentError(
            'The QB service cannot run ${request.kind.name}; that is a ModRepo '
            'job.');
      case JobKind.publishOutputs:
        // Publishing belongs to the publish service, reached through a
        // JobRouter. This service only sees it if it was wired up on its own.
        throw ArgumentError(
            'The QB service cannot run ${request.kind.name}; that is a publish '
            'job.');
    }
  }

  // ---------------------------------------------------------------------------
  // Job kinds
  // ---------------------------------------------------------------------------

  Future<JobOutcome> _fullRun(
    JobRequest request,
    RunReporter reporter,
    CancelToken? cancel,
    String? runId,
  ) async {
    final scope = ScrapeScope(
      type: request.scope,
      boards: request.boards,
      maxPagesMain: request.maxPagesMain,
      maxPagesLesser: request.maxPagesLesser,
      maxPagesLibraries: request.maxPagesLibraries,
    );

    final client = await _openForumClient(allowReplay: request.replayAllowed);
    final llm = _buildExtractor(request);
    try {
      final result = await _scrape(
          scope, client, llm?.extractor, reporter, cancel, 'Scraping topics');

      await _redoOutdatedDownloads(reporter, cancel);

      // Topics scraped just now were already sent to the LLM inside the scrape
      // loop. This pass catches every other stored topic — the ones the
      // incremental scope found unchanged, and the ones saved before the LLM
      // was switched on — so the bundle's LLM data is complete rather than
      // filling in over months of re-scrapes. Topics done during the scrape
      // come back as saved answers here, so they are not paid for twice.
      if (llm != null) {
        await _llmCoveragePass(llm.extractor, reporter, cancel);
        await llmStore!.flush();
      }

      await _saveCaches();
      reporter.log('QB scrape completed: ${result.modsScraped} mods, '
          '${result.errors} errors.');

      await _rebuildBundle(
          scrapeResult: result, runId: runId, reporter: reporter);

      return JobOutcome(
        itemsDone: result.modsScraped,
        itemsTotal: result.modsScraped,
        errors: result.errors,
        llmCalls: llm?.extractor.liveCallCount ?? 0,
        guardrailStop: llm == null ? null : _llmStopReason(llm.extractor),
        cancelled: cancel?.isCancelled ?? false,
      );
    } finally {
      llm?.close();
      await client.close();
    }
  }

  Future<JobOutcome> _rescrapeTopics(
    JobRequest request,
    RunReporter reporter,
    CancelToken? cancel,
    String? runId,
  ) async {
    if (request.topicIds.isEmpty) {
      reporter.log('Nothing to re-scrape: no topics were named.');
      return const JobOutcome();
    }

    // Always live. Replaying recorded pages would defeat the point of asking
    // for one mod to be looked at again.
    final client = await _openForumClient(allowReplay: false);
    final llm = _buildExtractor(request);
    try {
      final scope =
          ScrapeScope(type: ScopeType.topics, topicIds: request.topicIds);
      final result = await _scrape(scope, client, llm?.extractor, reporter,
          cancel, 'Re-scraping topics');

      if (llm != null) await llmStore!.flush();
      await _saveCaches();
      await _rebuildBundle(runId: runId, reporter: reporter);

      return JobOutcome(
        itemsDone: result.modsScraped,
        itemsTotal: request.topicIds.length,
        errors: result.errors,
        llmCalls: llm?.extractor.liveCallCount ?? 0,
        guardrailStop: llm == null ? null : _llmStopReason(llm.extractor),
        cancelled: cancel?.isCancelled ?? false,
      );
    } finally {
      llm?.close();
      await client.close();
    }
  }

  Future<JobOutcome> _resolveDownloads(
    JobRequest request,
    RunReporter reporter,
    CancelToken? cancel,
    String? runId,
  ) async {
    final ids = request.topicIds;
    if (ids.isEmpty) {
      reporter.log('Nothing to work out: no topics were named.');
      return const JobOutcome();
    }

    reporter.phase('Working out downloads');
    // Only this layer's answers go: the saved posts and the LLM results for
    // these topics are left alone.
    resolver.dropTopics(ids);

    var done = 0;
    var errors = 0;
    for (final id in ids) {
      if (cancel?.isCancelled ?? false) break;
      final detail = await store.loadDetail(id);
      if (detail == null) {
        errors++;
        reporter.log('Topic $id has no saved post; skipping.');
      } else {
        probeCache.dropUrls(detail.allLinks.map((l) => l.url));
        await resolver.resolveForTopic(id, detail.allLinks);
      }
      reporter.progress(++done, ids.length,
          item: detail?.title, errors: errors);
    }

    await _saveCaches();
    await _rebuildBundle(runId: runId, reporter: reporter);

    return JobOutcome(
      itemsDone: done,
      itemsTotal: ids.length,
      errors: errors,
      cancelled: cancel?.isCancelled ?? false,
    );
  }

  Future<JobOutcome> _extractLlm(
    JobRequest request,
    RunReporter reporter,
    CancelToken? cancel,
    String? runId,
  ) async {
    final ids = request.topicIds;
    if (ids.isEmpty) {
      reporter.log('Nothing to ask the LLM about: no topics were named.');
      return const JobOutcome();
    }
    final llm = _buildExtractor(request);
    if (llm == null) {
      reporter.log('No LLM service is set up, so nothing was sent.');
      return JobOutcome(itemsTotal: ids.length);
    }

    reporter.phase('Asking the LLM');
    // Only the LLM's saved answers go; the posts and the download answers for
    // these topics stay exactly as they are.
    llmStore!.dropTopics(ids);

    var done = 0;
    var errors = 0;
    try {
      // These are always live calls (the saved answers were just dropped), so
      // a few at a time is where the limit really shows: up to
      // llm_max_concurrent_calls topics talk to the model at once.
      await _fewAtATime(ids, guardrails.llmMaxConcurrentCalls,
          () => cancel?.isCancelled ?? false, (id) async {
        final detail = await store.loadDetail(id);
        if (detail == null) {
          errors++;
          reporter.log('Topic $id has no saved post; skipping.');
        } else {
          await llm.extractor
              .extractForTopic(detail, resolver.getCachedCandidates(id) ?? []);
        }
        reporter.progress(++done, ids.length,
            item: detail?.title,
            errors: errors,
            llmCalls: llm.extractor.liveCallCount);
      });
      await llmStore!.flush();
      // The LLM checks the links it picked through the shared "does this serve
      // a file?" cache, so save those answers too.
      await probeCache.saveCache();
      await _rebuildBundle(runId: runId, reporter: reporter);

      return JobOutcome(
        itemsDone: done,
        itemsTotal: ids.length,
        errors: errors,
        llmCalls: llm.extractor.liveCallCount,
        guardrailStop:
            _llmStopReason(llm.extractor, leftOver: ids.length - done),
        cancelled: cancel?.isCancelled ?? false,
      );
    } finally {
      llm.close();
    }
  }

  Future<JobOutcome> _llmCoveragePassJob(
    JobRequest request,
    RunReporter reporter,
    CancelToken? cancel,
    String? runId,
  ) async {
    final llm = _buildExtractor(request);
    if (llm == null) {
      reporter.log('No LLM service is set up, so nothing was sent.');
      return const JobOutcome();
    }
    try {
      final pass = await _llmCoveragePass(llm.extractor, reporter, cancel);
      await llmStore!.flush();
      await probeCache.saveCache();
      await _rebuildBundle(runId: runId, reporter: reporter);
      return JobOutcome(
        itemsDone: pass.seen,
        itemsTotal: pass.total,
        llmCalls: llm.extractor.liveCallCount,
        guardrailStop:
            _llmStopReason(llm.extractor, leftOver: pass.withoutResults),
        cancelled: cancel?.isCancelled ?? false,
      );
    } finally {
      llm.close();
    }
  }

  /// A small trial of the prompt over posts already saved on disk. Nothing is
  /// written except the report, so the real bundle and caches are untouched.
  Future<JobOutcome> _llmTest(
    JobRequest request,
    RunReporter reporter,
    CancelToken? cancel,
  ) async {
    final llm = _buildExtractor(request, testMode: true);
    if (llm == null) {
      reporter.log('No LLM service is set up, so nothing was sent.');
      return const JobOutcome();
    }
    final extractor = llm.extractor;
    try {
      reporter.phase('LLM test');
      final ids = request.topicIds;
      if (ids.isNotEmpty) {
        var seen = 0;
        for (final id in ids) {
          if (cancel?.isCancelled ?? false) break;
          seen++;
          final detail = await store.loadDetail(id);
          if (detail == null) {
            reporter.log('LLM test: topic $id is not saved on disk; skipping.');
            reporter.progress(seen, ids.length,
                llmCalls: extractor.testCallCount);
            continue;
          }
          await extractor.extractForTopic(
              detail, resolver.getCachedCandidates(id) ?? const []);
          reporter.progress(seen, ids.length,
              item: detail.title, llmCalls: extractor.testCallCount);
        }
      } else {
        final index = await store.loadIndex();
        for (final summary in index) {
          if (cancel?.isCancelled ?? false) break;
          if (extractor.testCallCount >= request.testLimit) break;
          final detail = await store.loadDetail(summary.topicId);
          if (detail == null) continue;
          await extractor.extractForTopic(detail,
              resolver.getCachedCandidates(summary.topicId) ?? const []);
          reporter.progress(extractor.testCallCount, request.testLimit,
              item: detail.title, llmCalls: extractor.testCallCount);
        }
      }
      await extractor.writeTestReport();
      reporter.log('LLM test finished; the real bundle and caches were left '
          'untouched.');
      return JobOutcome(
        itemsDone: extractor.testCallCount,
        itemsTotal: request.topicIds.isNotEmpty
            ? request.topicIds.length
            : request.testLimit,
        llmCalls: extractor.testCallCount,
        cancelled: cancel?.isCancelled ?? false,
      );
    } finally {
      llm.close();
    }
  }

  Future<JobOutcome> _rebuildBundleJob(
      RunReporter reporter, String? runId) async {
    reporter.phase('Building the bundle');
    await _rebuildBundle(runId: runId, reporter: reporter);
    return const JobOutcome();
  }

  // ---------------------------------------------------------------------------
  // Shared steps
  // ---------------------------------------------------------------------------

  /// Runs the engine with the per-topic chain: work out the downloads, then ask
  /// the LLM, for each topic as it is saved.
  ///
  /// The model is far slower than the forum, so the LLM reads run beside the
  /// scrape rather than inside it: each saved topic starts its read here and
  /// the scrape moves straight on to the next fetch. The extractor holds
  /// everyone to `llm_max_concurrent_calls` reads at once. Every read started
  /// is waited for before this returns, so a finished scrape is still a
  /// fully-extracted one.
  Future<ScrapeResult> _scrape(
    ScrapeScope scope,
    _ForumClient client,
    PostExtractor? extractor,
    RunReporter reporter,
    CancelToken? cancel,
    String phaseName,
  ) async {
    reporter.phase(phaseName);
    final engine = QbScraperEngine(
      store: store,
      client: client.throttled,
      probeCache: probeCache,
      downloadResolver: resolver,
    );

    final llmReads = <Future<void>>{};
    var readsStarted = 0;

    ScrapeResult result;
    try {
      result = await engine.run(
        scope,
        onProgress: (processed, total, item) => reporter.progress(
          processed,
          total,
          item: item,
          // The engine counts its own failures and only says so at the end, so
          // errors are left alone here. LLM calls are ours to count, and a
          // scrape is the longest job there is — worth knowing what it has
          // spent while it is still going.
          llmCalls: extractor?.liveCallCount,
        ),
        onTopicSaved: (detail) async {
          final candidates =
              await resolver.resolveForTopic(detail.topicId, detail.allLinks);
          if (extractor != null) {
            readsStarted++;
            late Future<void> read;
            read = extractor
                .extractForTopic(detail, candidates)
                .then((_) {}) // whether a call was spent doesn't matter here
                .catchError((Object e) {
              reporter.log('LLM read failed for topic ${detail.topicId}: $e');
            }).whenComplete(() => llmReads.remove(read));
            llmReads.add(read);
          }
        },
        shouldStop: () => cancel?.isCancelled ?? false,
      );
    } catch (e) {
      // The scrape is failing; don't leave reads writing in the background
      // while the job is torn down. Ones talking to the model finish and are
      // kept, the rest come back without calling.
      extractor?.stopNewCalls();
      while (llmReads.isNotEmpty) {
        await Future.any(llmReads.toList());
      }
      rethrow;
    }

    // The forum work is done; wait for the reads still going. On a cancelled
    // run only the reads already talking to the model are finished — the
    // queued ones come back without calling, so Ctrl-C stops the spending too.
    if (llmReads.isNotEmpty && extractor != null) {
      reporter.phase('Finishing LLM reads');
      while (llmReads.isNotEmpty) {
        if (cancel?.isCancelled ?? false) extractor.stopNewCalls();
        await Future.any(llmReads.toList());
        reporter.progress(readsStarted - llmReads.length, readsStarted,
            llmCalls: extractor.liveCallCount);
      }
    }
    return result;
  }

  /// Runs [work] over [items] with up to [atOnce] going at the same time.
  /// Stops starting new work once [shouldStop] says so; work already started
  /// is finished either way. A throw from [work] stops new work too, and is
  /// re-thrown once everything already started has finished — never sooner,
  /// so no started future is left running behind the caller's back.
  Future<void> _fewAtATime<T>(
    Iterable<T> items,
    int atOnce,
    bool Function() shouldStop,
    Future<void> Function(T item) work,
  ) async {
    final limit = atOnce < 1 ? 1 : atOnce;
    final pending = <Future<void>>{};
    Object? firstError;
    StackTrace? firstStack;

    for (final item in items) {
      while (pending.length >= limit) {
        await Future.any(pending.toList());
      }
      // Checked after the wait at the window, not before it: a stop asked for
      // while this spot in line was waiting must win, or one more piece of
      // work slips out after a cancel.
      if (shouldStop() || firstError != null) break;
      late Future<void> f;
      f = work(item).catchError((Object e, StackTrace s) {
        firstError ??= e;
        firstStack ??= s;
      }).whenComplete(() => pending.remove(f));
      pending.add(f);
    }
    while (pending.isNotEmpty) {
      await Future.any(pending.toList());
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStack!);
    }
  }

  /// Entries saved by an older version of the resolver may be missing its newer
  /// rules. Redo them from the links already on disk, so the bundle stays
  /// complete without anyone forcing a full re-scrape.
  Future<void> _redoOutdatedDownloads(
      RunReporter reporter, CancelToken? cancel) async {
    final outdated = resolver.outdatedTopicIds;
    if (outdated.isEmpty) return;

    reporter.log('Redoing ${outdated.length} download entries saved by an '
        'older version...');
    reporter.phase('Updating downloads');
    var done = 0;
    for (final topicId in outdated) {
      if (cancel?.isCancelled ?? false) break;
      final detail = await store.loadDetail(topicId);
      if (detail != null) {
        await resolver.resolveForTopic(topicId, detail.allLinks);
      }
      reporter.progress(++done, outdated.length);
    }
  }

  /// Walks every topic in the mods index and makes sure each one has LLM
  /// results, whether or not it was scraped this run. A topic whose saved
  /// result is still good costs nothing, so a topic already done during the
  /// scrape is not paid for twice.
  Future<_CoverageTally> _llmCoveragePass(
    PostExtractor extractor,
    RunReporter reporter,
    CancelToken? cancel,
  ) async {
    final index = await store.loadIndex();
    reporter.phase('LLM coverage');

    var seen = 0;
    var alreadyHadResults = 0; // results were already saved when we got here
    var passCalls = 0; // sent to the LLM by this pass
    var skipped = 0; // no post saved on disk, or a stub post we never send
    var withoutResults = 0; // ends the run with nothing saved
    String? stopReason;

    // A few topics at a time — up to llm_max_concurrent_calls, the same limit
    // the extractor holds everyone to. Most topics are saved answers and cost
    // nothing; the ones that do need a call overlap instead of queueing one
    // behind another. The tallies are safe to bump from the overlapping
    // futures because Dart runs them on one thread.
    await _fewAtATime(index, guardrails.llmMaxConcurrentCalls,
        () => cancel?.isCancelled ?? false, (summary) async {
      final detail = await store.loadDetail(summary.topicId);
      if (detail == null || detail.isPlaceholderDetail) {
        seen++;
        skipped++;
        reporter.progress(seen, index.length,
            llmCalls: extractor.liveCallCount);
        return;
      }

      // Read the store before the call, not after, so a topic done earlier in
      // this run counts as one we already had rather than one this pass made.
      if (llmStore!.get(summary.topicId) != null) alreadyHadResults++;

      // Once the extractor has stopped calling, keep walking the index so the
      // count of what is left is right, but don't ask it for work it will
      // refuse.
      stopReason ??= _llmStopReason(extractor);
      if (stopReason == null) {
        final spentACall = await extractor.extractForTopic(
            detail, resolver.getCachedCandidates(summary.topicId) ?? const []);
        if (spentACall) passCalls++;
      }

      if (llmStore!.get(summary.topicId) == null) withoutResults++;

      seen++;
      reporter.progress(seen, index.length,
          item: detail.title, llmCalls: extractor.liveCallCount);
      if (seen % 50 == 0) {
        reporter.log('LLM: covered $seen/${index.length} topics '
            '($passCalls sent to the LLM so far)...');
      }
    });

    // The run's call count, not the pass's: topics scraped this run were sent
    // to the LLM inside the scrape loop, and those calls count against the same
    // per-run limit.
    reporter.log('LLM coverage: ${index.length} topics in the index, '
        '$alreadyHadResults already had results, $passCalls sent to the LLM by '
        'this pass (${extractor.liveCallCount} this run in total, counting '
        'topics done during the scrape), $skipped skipped (no post saved).');
    if (stopReason != null) {
      reporter.log('LLM: stopped early because $stopReason. $withoutResults '
          'topic(s) still have no LLM results; run again to carry on where '
          'this run stopped.');
    } else {
      reporter.log('LLM: $withoutResults topic(s) still have no LLM results.');
    }

    return _CoverageTally(
        seen: seen, total: index.length, withoutResults: withoutResults);
  }

  /// Publishes the bundle, and saves a snapshot of what went out so this run
  /// can be compared with the ones either side of it.
  ///
  /// Every job kind that publishes comes through here, so none of them has to
  /// know snapshots exist.
  Future<void> _rebuildBundle(
      {ScrapeResult? scrapeResult,
      String? runId,
      RunReporter? reporter}) async {
    final publisher = BundlePublisher(
      store: store,
      resolver: resolver,
      llmStore: llmStore,
      outputPath: environment.outputPath,
    );
    final bundle = await publisher.createBundle(scrapeResult: scrapeResult);
    await publisher.writeLocal(bundle);
    await _saveBundleSnapshot(bundle, runId, reporter);

    // The bundle is half of what the public website is built from, and the only
    // thing a mod's version can be read from. This is the one place a release
    // is ever recorded.
    reporter?.phase('Website files');
    await siteStep.afterBundle(bundle, bundleId: runId, log: reporter?.log);
  }

  /// Keeps a copy of the bundle just published, minus the posts' text.
  ///
  /// A snapshot going wrong must never fail a run that has already published
  /// its bundle — the output is the job, and this is only paperwork about it.
  Future<void> _saveBundleSnapshot(
      ForumDataBundle bundle, String? runId, RunReporter? reporter) async {
    if (runId == null) return;
    try {
      await bundleSnapshots.save(runId, bundle.toMap());
    } catch (e) {
      reporter?.log('The bundle was published, but this run\'s snapshot of it '
          'could not be saved, so there will be nothing to compare it against '
          'later: $e');
    }
  }

  /// Both caches are written as the run goes; these are the final saves that
  /// pick up whatever came after the last one. The LLM step checks the links
  /// the model picked, which can add new probe answers, so this runs after it.
  Future<void> _saveCaches() async {
    await resolver.saveCache();
    await probeCache.saveCache();
  }

  /// Why the extractor will not make any more calls this run, or null while it
  /// still can.
  String? _llmStopReason(PostExtractor extractor, {int? leftOver}) {
    final left = (leftOver != null && leftOver > 0)
        ? ' $leftOver topic(s) were left'
        : '';
    if (extractor.hasBailed) {
      return 'the LLM kept failing, so it stopped calling.$left';
    }
    final cap = extractor.maxTopics;
    if (cap != null && extractor.liveCallCount >= cap) {
      return 'it hit the per-run limit (llm_max_topics=$cap).$left';
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Per-job plumbing
  // ---------------------------------------------------------------------------

  /// Opens the client used to reach the forum for one job. When replaying is
  /// allowed and a recorded file exists, pages come from the file and the
  /// polite pause drops to nothing; otherwise pages are fetched live and each
  /// response is written to the file as it arrives.
  Future<_ForumClient> _openForumClient({required bool allowReplay}) async {
    final cacheFile =
        io.File(p.join(environment.dataPath, 'qb_raw_cache.json'));
    final CachingClient caching;
    if (allowReplay && await cacheFile.exists()) {
      caching = await CachingClient.fromFile(cacheFile.path);
    } else {
      await cacheFile.parent.create(recursive: true);
      caching =
          CachingClient(_createNetworkClient(), recordPath: cacheFile.path);
    }
    final throttled = ThrottledClient(
      client: caching,
      delayMs: caching.isReplaying ? 0 : guardrails.delayMs,
    );
    return _ForumClient(caching, throttled, cacheFile.path);
  }

  /// Builds the LLM pieces for one job, or null when this job doesn't want the
  /// LLM or no LLM service is set up. Each job gets its own extractor, so the
  /// spend cap counts per run.
  _JobLlm? _buildExtractor(JobRequest request, {bool testMode = false}) {
    final settings = environment.llm;
    if (!request.runLlm || settings == null || llmStore == null) return null;

    final override = _createLlmClient;
    if (override != null) {
      return _JobLlm(_buildPostExtractor(override(), request, settings,
          testMode: testMode));
    }

    final timeout = Duration(seconds: guardrails.llmTimeoutSeconds);
    // A client of its own keeps LLM calls spaced out and off the scraper's
    // recording client.
    final primaryClient =
        ThrottledClient(client: http.Client(), delayMs: 250, timeout: timeout);
    final primary = OpenAiCompatibleClient(
      client: primaryClient,
      baseUrl: settings.baseUrl,
      model: settings.model,
      apiToken: settings.apiToken,
      disableThinking: settings.disableThinking,
      structuredOutput: settings.structuredOutput,
    );

    ThrottledClient? fallbackClient;
    LlmClient client = primary;
    if (settings.hasFallback) {
      fallbackClient = ThrottledClient(
          client: http.Client(), delayMs: 250, timeout: timeout);
      final fallback = OpenAiCompatibleClient(
        client: fallbackClient,
        baseUrl: settings.fallbackBaseUrl!,
        model: settings.fallbackModel!,
        apiToken: settings.fallbackApiToken,
        disableThinking: settings.fallbackDisableThinking,
        structuredOutput: settings.fallbackStructuredOutput,
      );
      client = FallbackLlmClient(
        primary: primary,
        fallback: fallback,
        primaryLabel: '${settings.model} @ ${settings.baseUrl}',
        fallbackLabel:
            '${settings.fallbackModel} @ ${settings.fallbackBaseUrl}',
      );
    }

    return _JobLlm(
      _buildPostExtractor(client, request, settings, testMode: testMode),
      primaryClient,
      fallbackClient,
    );
  }

  PostExtractor _buildPostExtractor(
    LlmClient client,
    JobRequest request,
    LlmSettings settings, {
    required bool testMode,
  }) =>
      PostExtractor(
        client: client,
        store: llmStore!,
        resolver: resolver,
        dataPath: environment.dataPath,
        maxConsecutiveFailures: guardrails.llmMaxConsecutiveFailures,
        maxTopics: guardrails.llmMaxTopics,
        maxConcurrentCalls: guardrails.llmMaxConcurrentCalls,
        maxTokens: guardrails.llmMaxTokens,
        maxInputChars: guardrails.llmMaxInputChars,
        generateSummaries: settings.generateSummaries,
        testMode: testMode,
        testLimit: request.testLimit,
        testTopicIds:
            request.topicIds.isEmpty ? null : request.topicIds.toSet(),
      );

  /// Closes the shared client used to look at download links.
  void close() => _linkClient.close();
}

/// The forum client for one job, with the recording file it writes to.
class _ForumClient {
  final CachingClient caching;
  final ThrottledClient throttled;
  final String cachePath;

  _ForumClient(this.caching, this.throttled, this.cachePath);

  /// Finishes off the recording file (responses were written as they arrived)
  /// and closes the client.
  Future<void> close() async {
    if (!caching.isReplaying) {
      await caching.saveToFile(cachePath);
    }
    throttled.close();
  }
}

/// The LLM pieces for one job, so they can all be closed together.
class _JobLlm {
  final PostExtractor extractor;
  final ThrottledClient? _primary;
  final ThrottledClient? _fallback;

  _JobLlm(this.extractor, [this._primary, this._fallback]);

  void close() {
    _primary?.close();
    _fallback?.close();
  }
}

/// What one coverage pass got through.
class _CoverageTally {
  final int seen;
  final int total;
  final int withoutResults;

  _CoverageTally(
      {required this.seen, required this.total, required this.withoutResults});
}
