import 'dart:io' as io;

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path/path.dart' as p;

import '../bot/scraper/debug/merge_debug_collector.dart';
import '../bot/scraper/qb/bundle_publisher.dart';
import '../bot/scraper/qb/download_resolver.dart';
import '../bot/scraper/qb/downloadable_probe_cache.dart';
import '../bot/scraper/qb/json_data_store.dart';
import '../bot/scraper/qb/llm/endpoint_cost.dart';
import '../bot/scraper/qb/llm/extraction_store.dart';
import '../bot/scraper/qb/llm/fallback_llm_client.dart';
import '../bot/scraper/qb/llm/llm_client.dart';
import '../bot/scraper/qb/llm/openai_client.dart';
import '../bot/scraper/qb/llm/picture_caption_store.dart';
import '../bot/scraper/qb/llm/picture_captioner.dart';
import '../bot/scraper/qb/llm/post_extractor.dart';
import '../bot/scraper/qb/models/forum_data_bundle.dart';
import '../bot/scraper/qb/models/scrape_job.dart';
import '../bot/scraper/qb/scraper_engine.dart';
import '../bot/scraper/qb/throttled_client.dart';
import '../catalog/catalog_step.dart';
import '../catalog/discord_posts.dart';
import '../catalog/mod_catalog.dart';
import '../catalog/source_post.dart';
import '../site/public_site_step.dart';
import '../utilities/caching_http_client.dart';
import 'bundle_snapshot_store.dart';
import 'cancel_token.dart';
import 'job.dart';
import 'merge_debug_writer.dart';
import 'merge_snapshot_store.dart';
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

  /// What the model saw in each post's pictures. Null, like [llmStore], when
  /// there is no LLM service.
  final PictureCaptionStore? pictureCaptions;

  /// Keeps a copy of each bundle this service publishes, so two runs can be
  /// compared afterwards.
  final BundleSnapshotStore bundleSnapshots;

  /// Works out which mods released, and rebuilds the public website's files.
  final PublicSiteStep siteStep;

  /// Merges every source post's listings into `mod-catalog.json`. Run after the
  /// bundle and before the website, so a job that changed the listings shows up
  /// in the catalog and on the site when it finishes.
  final CatalogStep catalogStep;

  /// Saves the data behind the Merge view and Catalog diff, for a job that
  /// asks for it ([JobRequest.collectMergeDebug]).
  final MergeDebugWriter mergeDebugWriter;

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
      pictureCaptions: environment.llm == null
          ? null
          : PictureCaptionStore(environment.dataPath),
      bundleSnapshots: BundleSnapshotStore(environment.dataPath,
          bundlesToKeep: guardrails.bundlesToKeep),
      siteStep: PublicSiteStep(
        dataPath: environment.dataPath,
        outputPath: environment.outputPath,
        sitePath: environment.sitePath,
      ),
      catalogStep: CatalogStep(
        qbDataPath: environment.dataPath,
        sourceCachePath: environment.sourceCachePath,
        outputPath: environment.outputPath,
      ),
      mergeDebugWriter: MergeDebugWriter(
        workingPath: environment.sourceCachePath,
        snapshots: MergeSnapshotStore(environment.dataPath,
            mergesToKeep: guardrails.mergesToKeep),
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
    required this.pictureCaptions,
    required this.bundleSnapshots,
    required this.siteStep,
    required this.catalogStep,
    required this.mergeDebugWriter,
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
    await pictureCaptions?.load();
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
      case JobKind.describePictures:
        return _describePictures(request, reporter, cancel, runId);
      case JobKind.llmTest:
        return _llmTest(request, reporter, cancel);
      case JobKind.rebuildBundle:
        return _rebuildBundleJob(request, reporter, runId);
      case JobKind.mergeModRepo:
      case JobKind.scrapeAndMerge:
        // The merge kinds belong to the ModRepo service. A JobRouter sends them
        // there; this service only ever sees them if it was wired up on its own.
        throw ArgumentError(
            'The QB service cannot run ${request.kind.name}; that is a ModRepo '
            'job.');
      case JobKind.fetchAndUpdate:
      case JobKind.rebuildFromSaved:
        // These run both pipelines, so a JobRouter runs them, handing this
        // service its own half as a fullRun or a rebuildBundle.
        throw ArgumentError(
            'The QB service cannot run ${request.kind.name} on its own; a '
            'JobRouter runs it.');
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
          scrapeResult: result,
          runId: runId,
          reporter: reporter,
          collectMergeDebug: request.collectMergeDebug);

      return JobOutcome(
        itemsDone: result.modsScraped,
        itemsTotal: result.modsScraped,
        errors: result.errors,
        llmCalls: llm?.extractor.liveCallCount ?? 0,
        guardrailStop: llm == null ? null : _llmStopReason(llm.extractor),
        cancelled: cancel?.isCancelled ?? false,
      );
    } finally {
      await llm?.close();
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
      await llm?.close();
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
    // The Discord threads the last catalog joined to these topics are the same
    // mods. Their saved answers are kept: a thread is read again only when its
    // prompt has changed, which is what describing its pictures does.
    final threads = _discordThreadsJoinedTo(ids, reporter);
    final total = ids.length + threads.length;

    // Only the LLM's saved answers for these topics go; the posts and the
    // download answers stay exactly as they are.
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
        reporter.progress(++done, total,
            item: detail?.title,
            errors: errors,
            llmCalls: llm.extractor.liveCallCount);
      });
      await _fewAtATime(threads, guardrails.llmMaxConcurrentCalls,
          () => cancel?.isCancelled ?? false, (thread) async {
        final source = thread.toSourcePost();
        final candidates =
            await resolver.resolveForDiscordThread(thread.threadId, source.allLinks);
        await llm.extractor.extractFor(source, candidates);
        reporter.progress(++done, total,
            item: thread.name,
            errors: errors,
            llmCalls: llm.extractor.liveCallCount);
      });
      await llmStore!.flush();
      // The LLM checks the links it picked through the shared "does this serve
      // a file?" cache, and a Discord thread's download rules may have run for
      // the first time, so save both.
      await _saveCaches();
      await _rebuildBundle(runId: runId, reporter: reporter);

      return JobOutcome(
        itemsDone: done,
        itemsTotal: total,
        errors: errors,
        llmCalls: llm.extractor.liveCallCount,
        guardrailStop:
            _llmStopReason(llm.extractor, leftOver: total - done),
        cancelled: cancel?.isCancelled ?? false,
      );
    } finally {
      await llm.close();
    }
  }

  /// The saved Discord threads that the last catalog built joined to
  /// [topicIds]. A thread the catalog names but the Discord scrape did not
  /// save is left out, and so is everything when either file is missing.
  List<DiscordThreadPost> _discordThreadsJoinedTo(
      List<int> topicIds, RunReporter reporter) {
    final List<String> threadIds;
    final DiscordPostsFile saved;
    try {
      threadIds = ModCatalog.read(catalogStep.outputFile)
              ?.discordThreadIdsFor(topicIds) ??
          const [];
      if (threadIds.isEmpty) return const [];
      saved = DiscordPostsFile.read(
          io.File(p.join(environment.dataPath, DiscordPostsFile.fileName)));
    } catch (e) {
      reporter.log('Could not read the catalog or the saved Discord posts, '
          'so no Discord thread is read again: $e');
      return const [];
    }
    final threads = [
      for (final id in threadIds)
        if (saved.threads[id] case final thread?) thread,
    ];
    if (threads.isNotEmpty) {
      reporter.log('Also checking ${threads.length} Discord '
          '${threads.length == 1 ? 'thread' : 'threads'} the catalog joined to '
          'these topics: ${threads.map((t) => t.name).join(', ')}. Each is read '
          'again only if its saved answer is out of date.');
    }
    return threads;
  }

  Future<JobOutcome> _llmCoveragePassJob(
    JobRequest request,
    RunReporter reporter,
    CancelToken? cancel,
    String? runId,
  ) async {
    final llm = _buildExtractor(request);
    if (llm == null) {
      // Still rebuilt: this pass can follow a Discord fetch, and the catalog
      // has to take in the threads that fetch brought back.
      reporter.log('No LLM service is set up, so nothing was sent.');
      await _rebuildBundle(
          runId: runId,
          reporter: reporter,
          collectMergeDebug: request.collectMergeDebug);
      return const JobOutcome();
    }
    try {
      final pass = await _llmCoveragePass(llm.extractor, reporter, cancel);
      await llmStore!.flush();
      await probeCache.saveCache();
      await _rebuildBundle(
          runId: runId,
          reporter: reporter,
          collectMergeDebug: request.collectMergeDebug);
      return JobOutcome(
        itemsDone: pass.seen,
        itemsTotal: pass.total,
        llmCalls: llm.extractor.liveCallCount,
        guardrailStop:
            _llmStopReason(llm.extractor, leftOver: pass.withoutResults),
        cancelled: cancel?.isCancelled ?? false,
      );
    } finally {
      await llm.close();
    }
  }

  /// Saves picture descriptions without changing LLM answers about posts.
  /// Descriptions are excluded from post fingerprints, so changing them
  /// does not cause another post read on the next LLM pass.
  ///
  /// For selected topics, describes their pictures and those in Discord
  /// threads joined to them in the last catalog again. Without a selection,
  /// checks all saved forum topics and Discord threads for pictures with
  /// missing descriptions or descriptions from a different
  /// [PictureCaptionStore.captionVersion].
  ///
  /// Runs even when `llm_caption_pictures` is off. Calls count against
  /// `llm_max_topics`, so a large backlog may need several runs.
  Future<JobOutcome> _describePictures(
    JobRequest request,
    RunReporter reporter,
    CancelToken? cancel,
    String? runId,
  ) async {
    final llm = _buildExtractor(request, describePictures: true);
    final captioner = llm?.extractor.captioner;
    if (llm == null || captioner == null) {
      await llm?.close();
      reporter.log('No LLM service is set up. No images were scanned.');
      return const JobOutcome();
    }
    final extractor = llm.extractor;
    final chosen = request.topicIds;
    final redo = chosen.isNotEmpty;

    final List<int> topicIds;
    final List<DiscordThreadPost> threads;
    if (redo) {
      topicIds = chosen;
      threads = _discordThreadsJoinedTo(chosen, reporter);
    } else {
      topicIds = [for (final summary in await store.loadIndex()) summary.topicId];
      threads = _savedDiscordThreads(reporter);
    }
    final total = topicIds.length + threads.length;

    reporter.phase('Scanning images');
    var done = 0;
    var errors = 0;
    var postsLookedAt = 0;
    var leftOver = 0;
    String? stopReason;

    Future<void> describe(SourcePost? source, String? label) async {
      stopReason ??= _llmStopReason(extractor);
      if (source != null) {
        if (stopReason != null || captioner.hasStopped) {
          if (captioner.picturesToLookAt(source, redo: redo).isNotEmpty) {
            leftOver++;
          }
        } else {
          final spent = await extractor.describePictures(source, redo: redo);
          if (spent == true) postsLookedAt++;
          if (spent == null) leftOver++;
        }
      }
      reporter.progress(++done, total,
          item: label, errors: errors, llmCalls: extractor.liveCallCount);
    }

    try {
      await _fewAtATime(topicIds, guardrails.llmMaxConcurrentCalls,
          () => cancel?.isCancelled ?? false, (id) async {
        final detail = await store.loadDetail(id);
        if (detail == null && redo) {
          errors++;
          reporter.log('Skipping topic $id. No saved post.');
        }
        await describe(
            detail == null ? null : SourcePost.fromForumDetail(detail),
            detail?.title);
      });
      await _fewAtATime(threads, guardrails.llmMaxConcurrentCalls,
          () => cancel?.isCancelled ?? false,
          (thread) => describe(thread.toSourcePost(), thread.name));

      final calls = captioner.callCount;
      reporter.log('Scanned images from $postsLookedAt '
          '${postsLookedAt == 1 ? 'post' : 'posts'} in $calls '
          '${calls == 1 ? 'call' : 'calls'}. ${pictureCaptions!.length} '
          'image records saved in total. No post was read again.');
      if (captioner.hasStopped) {
        reporter.log('Stopped scanning images after repeated call failures.');
      }
      if (leftOver > 0) {
        reporter.log('$leftOver '
            '${leftOver == 1 ? 'post still has' : 'posts still have'} images '
            'to scan. Run this again to continue.');
      }

      // Save descriptions before building the website, which reads them from disk.
      await pictureCaptions!.flush();
      await _rebuildBundle(runId: runId, reporter: reporter);

      return JobOutcome(
        itemsDone: done,
        itemsTotal: total,
        errors: errors,
        llmCalls: extractor.liveCallCount,
        guardrailStop: stopReason == null || leftOver == 0
            ? null
            : '$stopReason Posts with images left to scan: $leftOver.',
        cancelled: cancel?.isCancelled ?? false,
      );
    } finally {
      await llm.close();
    }
  }

  /// Returns Discord threads from the last scrape, sorted by id.
  /// Returns none if the file is missing, unreadable, or in the old format.
  List<DiscordThreadPost> _savedDiscordThreads(RunReporter reporter) {
    final file = io.File(p.join(environment.dataPath, DiscordPostsFile.fileName));
    try {
      return DiscordPostsFile.read(file).threads.values.toList()
        ..sort((a, b) => a.threadId.compareTo(b.threadId));
    } catch (e) {
      reporter.log('Could not read ${file.path}. Skipping Discord threads: $e');
      return const [];
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
      await llm.close();
    }
  }

  Future<JobOutcome> _rebuildBundleJob(
      JobRequest request, RunReporter reporter, String? runId) async {
    reporter.phase('Building the bundle');
    await _rebuildBundle(
        runId: runId,
        reporter: reporter,
        collectMergeDebug: request.collectMergeDebug);
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

    final discord = await _discordCoverage(extractor, reporter, cancel);

    final captioner = extractor.captioner;
    if (captioner != null) {
      reporter.log('Pictures: ${captioner.callCount} calls this run to look at '
          'pictures (counted in the LLM calls above); '
          '${extractor.pictureCaptions?.length ?? 0} pictures saved in all'
          '${captioner.hasStopped ? '. Stopped early after calls kept failing' : ''}.');
    }

    return _CoverageTally(
      seen: seen + discord.seen,
      total: index.length + discord.total,
      withoutResults: withoutResults + discord.withoutResults,
    );
  }

  /// The Discord half of the coverage pass: every thread saved in
  /// `discord-posts.json` is read the same way a forum topic is, through the
  /// same extractor. Nothing is fetched from Discord — the threads were saved
  /// by the last Discord scrape. They share the forum's per-run call limit and
  /// its limit on calls at once, because it is the same extractor.
  ///
  /// A thread's links go through the same download rules a forum topic's do,
  /// and the answers are cached under `discord:<thread id>`.
  Future<_CoverageTally> _discordCoverage(
    PostExtractor extractor,
    RunReporter reporter,
    CancelToken? cancel,
  ) async {
    final file = io.File(p.join(environment.dataPath, DiscordPostsFile.fileName));
    DiscordPostsFile saved;
    try {
      saved = DiscordPostsFile.read(file);
    } catch (e) {
      reporter.log('Could not read ${file.path}, so no Discord thread was '
          'sent to the LLM: $e');
      return _CoverageTally(seen: 0, total: 0, withoutResults: 0);
    }
    final threads = saved.threads.values.toList()
      ..sort((a, b) => a.threadId.compareTo(b.threadId));
    if (threads.isEmpty) {
      if (saved.legacyTexts.isNotEmpty) {
        reporter.log('LLM coverage: the saved Discord posts are in the old '
            'format, which the LLM does not read. The next Discord scrape '
            'replaces them.');
      }
      return _CoverageTally(seen: 0, total: 0, withoutResults: 0);
    }

    reporter.phase('LLM coverage (Discord)');
    var seen = 0;
    var alreadyHadResults = 0;
    var passCalls = 0;
    var withoutResults = 0;
    String? stopReason;

    await _fewAtATime(threads, guardrails.llmMaxConcurrentCalls,
        () => cancel?.isCancelled ?? false, (thread) async {
      final source = thread.toSourcePost();
      if (llmStore!.getDiscord(thread.threadId) != null) alreadyHadResults++;

      stopReason ??= _llmStopReason(extractor);
      if (stopReason == null) {
        final candidates =
            await resolver.resolveForDiscordThread(thread.threadId, source.allLinks);
        final spentACall = await extractor.extractFor(source, candidates);
        if (spentACall) passCalls++;
      }

      if (llmStore!.getDiscord(thread.threadId) == null) withoutResults++;

      seen++;
      reporter.progress(seen, threads.length,
          item: thread.name, llmCalls: extractor.liveCallCount);
      if (seen % 50 == 0) {
        reporter.log('LLM: covered $seen/${threads.length} Discord threads '
            '($passCalls sent to the LLM so far)...');
      }
    });

    reporter.log('LLM coverage (Discord): ${threads.length} saved threads, '
        '$alreadyHadResults already had results, $passCalls sent to the LLM by '
        'this pass.');
    if (stopReason != null) {
      reporter.log('LLM: stopped early because $stopReason. $withoutResults '
          'Discord thread(s) still have no LLM results; run again to carry on '
          'where this run stopped.');
    } else {
      reporter.log('LLM: $withoutResults Discord thread(s) still have no LLM '
          'results.');
    }

    return _CoverageTally(
        seen: seen, total: threads.length, withoutResults: withoutResults);
  }

  /// Publishes the bundle, and saves a snapshot of what went out so this run
  /// can be compared with the ones either side of it.
  ///
  /// Every job kind that publishes comes through here, so none of them has to
  /// know snapshots exist.
  ///
  /// [collectMergeDebug] also saves the data behind the Merge view and Catalog
  /// diff, from the catalog built here.
  Future<void> _rebuildBundle(
      {ScrapeResult? scrapeResult,
      String? runId,
      RunReporter? reporter,
      bool collectMergeDebug = false}) async {
    final publisher = BundlePublisher(
      store: store,
      resolver: resolver,
      llmStore: llmStore,
      outputPath: environment.outputPath,
    );
    final bundle = await publisher.createBundle(scrapeResult: scrapeResult);
    await publisher.writeLocal(bundle);
    await _saveBundleSnapshot(bundle, runId, reporter);

    // The bundle may have changed what a post holds — a topic the LLM has just
    // found four mods on is four listings now — so the catalog is merged again
    // before the website is built from it. Saved files only; no network.
    reporter?.phase('Catalog');
    final collector = collectMergeDebug ? MergeDebugCollector() : null;
    await catalogStep.run(debugCollector: collector, log: reporter?.log);
    if (collector != null) {
      await mergeDebugWriter.save(
          collector.data, runId, reporter?.log ?? (_) {});
    }

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
  ///
  /// [describePictures] gives the extractor a captioner whether or not
  /// `llm_caption_pictures` is on, for the picture description job.
  _JobLlm? _buildExtractor(JobRequest request,
      {bool testMode = false, bool describePictures = false}) {
    final settings = environment.llm;
    if (!request.runLlm || settings == null || llmStore == null) return null;

    final override = _createLlmClient;
    if (override != null) {
      final client = override();
      return _JobLlm(
        _buildPostExtractor(client, request, settings,
            testMode: testMode,
            captionClient: client,
            describePictures: describePictures),
        captions: pictureCaptions,
      );
    }

    final idleTimeout = Duration(seconds: guardrails.llmIdleTimeoutSeconds);
    final totalTimeout = Duration(seconds: guardrails.llmTimeoutSeconds);
    // A client of its own keeps LLM calls spaced out and off the scraper's
    // recording client.
    final primaryClient = ThrottledClient(client: http.Client(), delayMs: 250);
    final primary = OpenAiCompatibleClient(
      client: primaryClient,
      baseUrl: settings.baseUrl,
      model: settings.model,
      apiToken: settings.apiToken,
      disableThinking: settings.disableThinking,
      structuredOutput: settings.structuredOutput,
      idleTimeout: idleTimeout,
      totalTimeout: totalTimeout,
    );

    ThrottledClient? fallbackClient;
    LlmClient client = primary;
    if (settings.hasFallback) {
      fallbackClient = ThrottledClient(client: http.Client(), delayMs: 250);
      final fallback = OpenAiCompatibleClient(
        client: fallbackClient,
        baseUrl: settings.fallbackBaseUrl!,
        model: settings.fallbackModel!,
        apiToken: settings.fallbackApiToken,
        disableThinking: settings.fallbackDisableThinking,
        structuredOutput: settings.fallbackStructuredOutput,
        idleTimeout: idleTimeout,
        totalTimeout: totalTimeout,
      );
      client = FallbackLlmClient(
        primary: primary,
        fallback: fallback,
        primaryLabel: '${settings.model} @ ${settings.baseUrl}',
        fallbackLabel:
            '${settings.fallbackModel} @ ${settings.fallbackBaseUrl}',
        switchAllowed: _fallbackSwitchAllowed(settings),
      );
    }

    return _JobLlm(
      // Pictures go to the primary alone. A picture it cannot read must never
      // latch the fallback for the rest of the run, or start spending money
      // on a paid one.
      _buildPostExtractor(client, request, settings,
          testMode: testMode,
          captionClient: primary,
          describePictures: describePictures),
      primary: primaryClient,
      fallback: fallbackClient,
      captions: pictureCaptions,
    );
  }

  /// Whether the primary may fall over to the fallback at all.
  ///
  /// The only pairing that is blocked is a free primary with a paid fallback,
  /// because that is the one where switching starts spending money the run was
  /// not spending. `llm_fallback_free_to_paid` reopens it. Every other pairing —
  /// both paid, both free, or a paid primary with a cheaper fallback — is always
  /// allowed.
  static bool _fallbackSwitchAllowed(LlmSettings settings) {
    if (settings.fallbackFreeToPaid) return true;
    final primaryCost =
        endpointCost(baseUrl: settings.baseUrl, model: settings.model);
    final fallbackCost = endpointCost(
        baseUrl: settings.fallbackBaseUrl!, model: settings.fallbackModel!);
    return !(primaryCost == EndpointCost.free &&
        fallbackCost == EndpointCost.paid);
  }

  PostExtractor _buildPostExtractor(
    LlmClient client,
    JobRequest request,
    LlmSettings settings, {
    required bool testMode,
    required LlmClient captionClient,
    bool describePictures = false,
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
        pictureCaptions: pictureCaptions,
        captioner: (settings.captionPictures || describePictures) &&
                !testMode &&
                pictureCaptions != null
            ? PictureCaptioner(client: captionClient, store: pictureCaptions!)
            : null,
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
  final PictureCaptionStore? _captions;

  _JobLlm(this.extractor,
      {ThrottledClient? primary, ThrottledClient? fallback, PictureCaptionStore? captions})
      : _primary = primary,
        _fallback = fallback,
        _captions = captions;

  /// Saves the last picture descriptions and closes the clients. Called on the
  /// failure path too, so a run that breaks keeps what it looked at.
  Future<void> close() async {
    try {
      await _captions?.flush();
    } finally {
      _primary?.close();
      _fallback?.close();
    }
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
