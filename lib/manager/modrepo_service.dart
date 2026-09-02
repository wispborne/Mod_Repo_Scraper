import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../bot/scraper/debug/merge_debug_collector.dart';
import '../bot/scraper/debug/merge_debug_data.dart';
import '../bot/scraper/discord_reader.dart';
import '../bot/scraper/forum_scraper.dart';
import '../bot/scraper/mod_merger.dart';
import '../bot/scraper/nexus_reader.dart';
import '../bot/scraper/scraped_mod.dart';
import '../site/public_site_step.dart';
import '../utilities/caching_http_client.dart';
import '../utilities/jsanity.dart';
import 'cancel_token.dart';
import 'job.dart';
import 'merge_snapshot_store.dart';
import 'run_reporter.dart';
import 'scraper_service.dart';
import 'scraper_settings.dart';

/// The ModRepo pipeline as something you can call, rather than a program you
/// run.
///
/// Same split as the QB side: built once with the environment (where the files
/// are, which tokens it has) and the guardrails (how long a source gets, how
/// many merge snapshots to keep). What one job actually does arrives with the
/// request. It never reads the config file.
class ModRepoService implements JobRunner {
  final ModRepoEnvironment environment;
  final ModRepoGuardrails guardrails;
  final MergeSnapshotStore snapshots;

  /// Rebuilds the public website's files once a merge has landed. The merged
  /// mods are half of what that site is built from.
  final PublicSiteStep siteStep;

  /// Makes the client used to reach Discord. Swapped out in tests.
  final http.Client Function() _createNetworkClient;

  final Jsanity _jsanity = Jsanity();

  ModRepoService({
    required this.environment,
    this.guardrails = const ModRepoGuardrails(),
    MergeSnapshotStore? snapshots,
    PublicSiteStep? siteStep,
    http.Client Function()? createNetworkClient,
  })  : snapshots = snapshots ??
            MergeSnapshotStore(environment.snapshotPath,
                mergesToKeep: guardrails.mergesToKeep),
        siteStep = siteStep ??
            PublicSiteStep(
              dataPath: environment.snapshotPath,
              outputPath: environment.outputPath,
              sitePath: environment.sitePath,
            ),
        _createNetworkClient = createNetworkClient ?? http.Client.new;

  @override
  Future<JobOutcome> runJob(
    JobRequest request, {
    RunReporter reporter = const SilentRunReporter(),
    CancelToken? cancel,
    String? runId,
  }) async {
    switch (request.kind) {
      case JobKind.mergeModRepo:
        return _merge(request, reporter, cancel, runId, scrapeFirst: false);
      case JobKind.scrapeAndMerge:
        return _merge(request, reporter, cancel, runId, scrapeFirst: true);
      default:
        throw ArgumentError(
            'The ModRepo service cannot run ${request.kind.name}; that is a QB '
            'job.');
    }
  }

  // ---------------------------------------------------------------------------

  Future<JobOutcome> _merge(
    JobRequest request,
    RunReporter reporter,
    CancelToken? cancel,
    String? runId, {
    required bool scrapeFirst,
  }) async {
    final mods = <ScrapedMod>[];
    var errors = 0;

    for (final source in ModSourceKind.values) {
      if (cancel?.isCancelled ?? false) return _stopped(reporter, mods.length);

      final wanted = !scrapeFirst || request.modSources.contains(source);
      if (!wanted) {
        reporter.log('Skipping ${_sourceName(source)}: this job did not ask '
            'for it.');
        continue;
      }

      reporter.phase(_sourceName(source));
      final result = await _loadSource(source, request, reporter,
          scrapeFirst: scrapeFirst);
      mods.addAll(result.mods);
      if (result.failed) errors++;
    }

    if (cancel?.isCancelled ?? false) return _stopped(reporter, mods.length);

    reporter.phase('Merge');
    reporter.progress(0, mods.length, errors: errors);
    reporter.log('Merging ${mods.length} mods from all sources...');

    final collector = request.collectMergeDebug ? MergeDebugCollector() : null;
    final started = DateTime.now();
    final merged = await ModMerger().merge(
      mods,
      keepAllGameVersionsFromSameSource: request.keepAllGameVersions,
      debugCollector: collector,
    );
    reporter.log('Merge finished in '
        '${DateTime.now().difference(started).inMilliseconds}ms: '
        '${mods.length} in, ${merged.length} out.');
    reporter.progress(mods.length, mods.length, errors: errors);

    // A merge that was stopped part-way leaves the old output alone: half a
    // merged repo is worse than yesterday's whole one.
    if (cancel?.isCancelled ?? false) {
      reporter.log('Cancelled before saving. ModRepo.json was left as it was.');
      return _stopped(reporter, mods.length, errors: errors);
    }

    reporter.phase('Save');
    await _saveMergedMods(merged, reporter);
    if (collector != null) {
      await _saveMergeDebug(collector.data, runId, reporter);
    }

    reporter.phase('Website files');
    await siteStep.afterMerge(merged, log: reporter.log);

    return JobOutcome(
      itemsDone: merged.length,
      itemsTotal: mods.length,
      errors: errors,
    );
  }

  JobOutcome _stopped(RunReporter reporter, int itemsTotal, {int errors = 0}) {
    reporter.log('Merge job cancelled. Nothing was written.');
    return JobOutcome(
      itemsTotal: itemsTotal,
      errors: errors,
      cancelled: true,
    );
  }

  /// Gets one source's mods: scraped when the job asked for a scrape and we can
  /// reach it, read from what that source last left on disk otherwise.
  ///
  /// `failed` means the source went wrong. The merge carries on with whatever
  /// that source last gave us, so one broken source cannot empty the repo, and
  /// the run ends with an error to its name.
  Future<({List<ScrapedMod> mods, bool failed})> _loadSource(
    ModSourceKind source,
    JobRequest request,
    RunReporter reporter, {
    required bool scrapeFirst,
  }) async {
    final name = _sourceName(source);
    final reachable = switch (source) {
      ModSourceKind.forum => true,
      ModSourceKind.discord => environment.hasDiscord,
      ModSourceKind.nexus => environment.hasNexus,
    };

    if (scrapeFirst && !reachable) {
      reporter.log('Skipping $name: it has no token set up. Add one to '
          'config.properties to include it.');
      return (mods: await _loadSaved(source, reporter), failed: false);
    }

    if (!scrapeFirst) {
      return (mods: await _loadSaved(source, reporter), failed: false);
    }

    final started = DateTime.now();
    try {
      final scraped = await _scrapeSource(source, request);
      reporter.log('$name scraping finished (${scraped.length} mods) in '
          '${DateTime.now().difference(started).inMilliseconds}ms.');
      if (scraped.isNotEmpty) await _writeCache(source, scraped, reporter);
      return (mods: scraped, failed: false);
    } catch (e) {
      reporter.log('$name went wrong: $e');
      final saved = await _loadSaved(source, reporter);
      if (saved.isNotEmpty) {
        reporter.log('Using the last saved $name results instead '
            '(${saved.length} mods).');
      }
      return (mods: saved, failed: true);
    }
  }

  /// What a source last left on disk: its `<name>_cache.json`, written after
  /// every successful scrape. That is the freshest thing we have for any of the
  /// three, Discord included.
  ///
  /// Discord has a second way back — `discord_raw_cache.json`, a recording of
  /// Discord's own answers — but it is only reached for when the cache file has
  /// nothing to give. The recording is only written by a job that was allowed
  /// to replay, which production never is, so on a real server it is either
  /// missing or months behind the cache file.
  Future<List<ScrapedMod>> _loadSaved(
      ModSourceKind source, RunReporter reporter) async {
    final cached = await _readCache(source, reporter);
    if (cached != null && cached.isNotEmpty) return cached;

    if (source == ModSourceKind.discord) {
      final replayed = await _replayDiscord(reporter);
      if (replayed.isNotEmpty) return replayed;
    }

    if (cached == null) {
      reporter.log('No saved ${_sourceName(source)} results to merge. Run a '
          'scrape to get some.');
    }
    return cached ?? const [];
  }

  Future<List<ScrapedMod>> _scrapeSource(
      ModSourceKind source, JobRequest request) async {
    switch (source) {
      case ModSourceKind.forum:
        return await ForumScraper.run(
              moddingForumPagesToScrape: request.moddingForumPages ?? 15,
              modForumPagesToScrape: request.modForumPages ?? 12,
            ).timeout(guardrails.sourceTimeout) ??
            const [];
      case ModSourceKind.nexus:
        return await NexusReader.readAllMessages(environment.toReaderConfig())
                .timeout(guardrails.sourceTimeout) ??
            const [];
      case ModSourceKind.discord:
        return _scrapeDiscord(request);
    }
  }

  File get _discordRawCacheFile =>
      File(p.join(environment.workingPath, 'discord_raw_cache.json'));

  /// Discord goes through a caching HTTP client, so the raw API answers can be
  /// replayed later without asking Discord again.
  Future<List<ScrapedMod>> _scrapeDiscord(JobRequest request) async {
    final cacheFile = _discordRawCacheFile;
    final http.Client client;

    if (request.replayAllowed && cacheFile.existsSync()) {
      client = await CachingClient.fromFile(cacheFile.path);
    } else if (request.replayAllowed) {
      // Writes each answer as it arrives, so a run that dies keeps what it got.
      client =
          CachingClient(_createNetworkClient(), recordPath: cacheFile.path);
    } else {
      client = _createNetworkClient();
    }

    try {
      return await DiscordReader.readAllMessages(environment.toReaderConfig(),
              httpClient: client) ??
          const [];
    } finally {
      if (client is CachingClient && !client.isReplaying) {
        await client.saveToFile(cacheFile.path);
      }
    }
  }

  /// Rebuilds the Discord mods from the recorded raw API answers, when there is
  /// a recording. Asks Discord nothing.
  ///
  /// No recording is the normal case and says nothing: the caller has already
  /// tried the cache file, and it is the one that reports coming up empty.
  Future<List<ScrapedMod>> _replayDiscord(RunReporter reporter) async {
    final cacheFile = _discordRawCacheFile;
    if (!cacheFile.existsSync()) return const [];
    try {
      final client = await CachingClient.fromFile(cacheFile.path);
      final mods = await DiscordReader.readAllMessages(
              environment.toReaderConfig(),
              httpClient: client) ??
          const <ScrapedMod>[];
      reporter.log('Read ${mods.length} Discord mods back from the saved '
          'answers.');
      return mods;
    } catch (e) {
      reporter.log('Could not read the saved Discord answers: $e');
      return const [];
    }
  }

  File _cacheFileFor(ModSourceKind source) => File(p.join(
      environment.workingPath,
      '${_sourceName(source).toLowerCase()}_cache.json'));

  Future<List<ScrapedMod>?> _readCache(
    ModSourceKind source,
    RunReporter reporter,
  ) async {
    final file = _cacheFileFor(source);
    if (!file.existsSync()) return null;
    try {
      final mods = _jsanity
          .fromJson<ScrapedMods>(
              await file.readAsString(), file.path, ScrapedModsMapper.fromMap)
          .items;
      reporter.log('Loaded ${mods.length} ${_sourceName(source)} mods from '
          'the saved file.');
      return mods;
    } catch (e) {
      reporter.log('Could not read the saved ${_sourceName(source)} file: $e');
      return null;
    }
  }

  Future<void> _writeCache(
    ModSourceKind source,
    List<ScrapedMod> mods,
    RunReporter reporter,
  ) async {
    try {
      await _cacheFileFor(source)
          .writeAsString(ScrapedMods(items: mods).toJson());
    } catch (e) {
      reporter.log('Could not save the ${_sourceName(source)} results: $e');
    }
  }

  Future<void> _saveMergedMods(
      List<ScrapedMod> merged, RunReporter reporter) async {
    final file = File(p.join(environment.outputPath, 'ModRepo.json'));
    if (!file.parent.existsSync()) file.parent.createSync(recursive: true);

    // Same shape ModRepoCache writes, kept as it was so TriOS reads it the same.
    final data = <String, dynamic>{
      'items': merged.map((m) => m.toMap()).toList(),
      'totalCount': merged.length,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    reporter.log('Saved ${merged.length} mods to ${file.absolute.path}.');
  }

  /// Writes the merge debug data twice: once as `merge-debug.json` where it has
  /// always gone, and once as this run's snapshot, so an older merge can still
  /// be looked at after the next one lands.
  Future<void> _saveMergeDebug(
    MergeDebugData data,
    String? runId,
    RunReporter reporter,
  ) async {
    MergeDebugDataMapper.ensureInitialized();
    final file = File(p.join(environment.workingPath, 'merge-debug.json'));
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data.toMap()));
    reporter.log('Merge debug data written to ${file.path}.');

    if (runId == null) return;
    try {
      final saved = await snapshots.save(runId, data);
      reporter.log('Saved this merge as ${p.basename(saved.path)}, so it can '
          'be compared with the next one.');
    } catch (e) {
      // A snapshot is a nice-to-have. Losing it must not fail a good merge.
      reporter.log('Could not save the merge snapshot: $e');
    }
  }

  String _sourceName(ModSourceKind source) => switch (source) {
        ModSourceKind.forum => 'Forum',
        ModSourceKind.discord => 'Discord',
        ModSourceKind.nexus => 'Nexus',
      };
}

/// Sends each job to whichever service owns that kind.
///
/// The manager runs one job at a time whatever kind it is, so the two pipelines
/// share a queue, a history and a lock while sharing no code, no files and no
/// secrets.
class JobRouter implements JobRunner {
  final JobRunner qb;
  final JobRunner modRepo;
  final JobRunner publish;

  const JobRouter({
    required this.qb,
    required this.modRepo,
    required this.publish,
  });

  @override
  Future<JobOutcome> runJob(
    JobRequest request, {
    RunReporter reporter = const SilentRunReporter(),
    CancelToken? cancel,
    String? runId,
  }) =>
      _runnerFor(request)
          .runJob(request, reporter: reporter, cancel: cancel, runId: runId);

  JobRunner _runnerFor(JobRequest request) {
    if (request.isPublishKind) return publish;
    if (request.isMergeKind) return modRepo;
    return qb;
  }
}

/// The plain-English name of a job kind, for logs and confirm boxes.
String jobKindLabel(JobKind kind) => switch (kind) {
      JobKind.fullRun => 'full scrape',
      JobKind.rescrapeTopics => 'rescrape topics',
      JobKind.resolveDownloads => 'work out downloads',
      JobKind.extractLlm => 'ask the LLM',
      JobKind.llmCoveragePass => 'LLM catch-up',
      JobKind.llmTest => 'LLM test',
      JobKind.rebuildBundle => 'rebuild the bundle',
      JobKind.mergeModRepo => 'merge from saved files',
      JobKind.scrapeAndMerge => 'scrape then merge',
      JobKind.publishOutputs => 'publish to GitHub',
    };
