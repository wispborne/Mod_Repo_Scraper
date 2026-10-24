import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../bot/scraper/debug/merge_debug_collector.dart';
import '../bot/scraper/discord_reader.dart';
import '../bot/scraper/forum_scraper.dart';
import '../bot/scraper/mod_merger.dart';
import '../bot/scraper/nexus_reader.dart';
import '../bot/scraper/scraped_mod.dart';
import '../catalog/catalog_step.dart';
import '../catalog/discord_posts.dart';
import '../catalog/takedowns.dart';
import '../site/public_site_step.dart';
import '../utilities/caching_http_client.dart';
import '../utilities/jsanity.dart';
import 'cancel_token.dart';
import 'job.dart';
import 'merge_debug_writer.dart';
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

  /// Saves the data behind the Merge view and Catalog diff.
  MergeDebugWriter get mergeDebugWriter => MergeDebugWriter(
      workingPath: environment.workingPath, snapshots: snapshots);

  /// Rebuilds the public website's files once a merge has landed. The merged
  /// mods are half of what that site is built from.
  final PublicSiteStep siteStep;

  /// Merges every source post's listings into `mod-catalog.json`.
  final CatalogStep catalogStep;

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
        catalogStep = CatalogStep(
          qbDataPath: environment.snapshotPath,
          sourceCachePath: environment.workingPath,
          outputPath: environment.outputPath,
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
    // Read before anything is fetched or written: a list that cannot be read
    // stops the job with ModRepo.json and the catalog as they were.
    final takedowns = TakedownList.read(environment.snapshotPath);

    final mods = <ScrapedMod>[];
    final bySource = <ModSourceKind, List<ScrapedMod>>{};
    var errors = 0;

    for (final source in ModSourceKind.values) {
      if (cancel?.isCancelled ?? false) return _stopped(reporter, mods.length);

      // A source this job did not ask to fetch still has its saved results.
      // Leaving them out would take its mods out of ModRepo.json.
      final fetch = scrapeFirst && request.modSources.contains(source);
      if (scrapeFirst && !fetch) {
        reporter.log('Skipping ${_sourceName(source)}: this job did not ask '
            'to fetch it, so its saved results are used.');
      }

      reporter.phase(_sourceName(source));
      final result =
          await _loadSource(source, request, reporter, scrapeFirst: fetch);
      mods.addAll(result.mods);
      bySource[source] = result.mods;
      if (result.failed) errors++;
    }

    if (cancel?.isCancelled ?? false) return _stopped(reporter, mods.length);

    reporter.phase('Merge');
    reporter.progress(0, mods.length, errors: errors);
    reporter.log('Merging ${mods.length} mods from all sources...');

    final collector = request.collectMergeDebug ? MergeDebugCollector() : null;
    final started = DateTime.now();
    // The old ModRepo.json, kept until the switch. The merge debug data is
    // the catalog's now, since that is the merge the Merge view explains.
    final merged = await ModMerger().merge(
      mods,
      keepAllGameVersionsFromSameSource: request.keepAllGameVersions,
    );
    reporter.log('Merge finished in '
        '${DateTime.now().difference(started).inMilliseconds}ms: '
        '${mods.length} in, ${merged.length} out.');

    if (cancel?.isCancelled ?? false) {
      reporter.log('Cancelled before saving. ModRepo.json and '
          'mod-catalog.json were left as they were.');
      return _stopped(reporter, mods.length, errors: errors);
    }

    // The forum half of the job builds the catalog and the website after this.
    final published = withoutTakedowns(merged, takedowns, reporter.log);

    if (request.oldRepoOnly) {
      reporter.phase('Save');
      await _saveMergedMods(published, reporter);
      return JobOutcome(
        itemsDone: merged.length,
        itemsTotal: mods.length,
        errors: errors,
      );
    }

    // The catalog: every source post's listings, merged once, each mod given
    // its permanent id through its source posts. Saved files only, and written
    // here only if nobody has asked to stop.
    final catalog = await catalogStep.run(
      discordMods: bySource[ModSourceKind.discord] ?? const [],
      nexusMods: bySource[ModSourceKind.nexus] ?? const [],
      debugCollector: collector,
      keepAllGameVersionsFromSameSource: request.keepAllGameVersions,
      takedowns: takedowns,
      isCancelled: () => cancel?.isCancelled ?? false,
      log: reporter.log,
    );
    reporter.progress(mods.length, mods.length, errors: errors);

    // A merge that was stopped part-way leaves the old output alone: half a
    // merged repo is worse than yesterday's whole one.
    if (catalog == null || (cancel?.isCancelled ?? false)) {
      reporter.log('Cancelled before saving. ModRepo.json was left as it was.');
      return _stopped(reporter, mods.length, errors: errors);
    }

    reporter.phase('Save');
    await _saveMergedMods(published, reporter);
    if (collector != null) {
      await mergeDebugWriter.save(collector.data, runId, reporter.log);
    }

    reporter.phase('Website files');
    await siteStep.afterMerge(catalog: catalog, log: reporter.log);

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
      final (scraped, discordThreads) = await _scrapeSource(source, request);
      reporter.log('$name scraping finished (${scraped.length} mods) in '
          '${DateTime.now().difference(started).inMilliseconds}ms.');
      if (scraped.isNotEmpty) {
        await _writeCache(source, scraped, reporter);
        // Saved with the cache file and under the same rule: only a scrape
        // that worked replaces it.
        if (discordThreads != null) {
          await _writeDiscordPosts(discordThreads, reporter);
        }
      }
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

  /// One source's scraped mods, and — for Discord — each thread's opening
  /// run, keyed by thread id.
  Future<(List<ScrapedMod>, Map<String, DiscordThreadPost>?)> _scrapeSource(
      ModSourceKind source, JobRequest request) async {
    switch (source) {
      case ModSourceKind.forum:
        return (
          await ForumScraper.run(
                moddingForumPagesToScrape: request.moddingForumPages ?? 15,
                modForumPagesToScrape: request.modForumPages ?? 12,
              ).timeout(guardrails.sourceTimeout) ??
              const <ScrapedMod>[],
          null
        );
      case ModSourceKind.nexus:
        return (
          await NexusReader.readAllMessages(environment.toReaderConfig())
                  .timeout(guardrails.sourceTimeout) ??
              const <ScrapedMod>[],
          null
        );
      case ModSourceKind.discord:
        final result = await _scrapeDiscord(request);
        return (result.mods, result.threads);
    }
  }

  File get _discordPostsFile =>
      File(p.join(environment.snapshotPath, DiscordPostsFile.fileName));

  Future<void> _writeDiscordPosts(
    Map<String, DiscordThreadPost> threads,
    RunReporter reporter,
  ) async {
    try {
      await DiscordPostsFile.write(_discordPostsFile, threads);
      reporter.log('Saved the opening messages of ${threads.length} Discord '
          'threads.');
    } catch (e) {
      reporter.log("Could not save the Discord threads' opening messages: $e");
    }
  }

  File get _discordRawCacheFile =>
      File(p.join(environment.workingPath, 'discord_raw_cache.json'));

  /// Discord goes through a caching HTTP client, so the raw API answers can be
  /// replayed later without asking Discord again.
  Future<DiscordReadResult> _scrapeDiscord(JobRequest request) async {
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
      return await DiscordReader.readAll(environment.toReaderConfig(),
              httpClient: client) ??
          const DiscordReadResult();
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

  /// The old merge's mods without the ones taken down, for `ModRepo.json`
  /// until the switch to the catalog.
  ///
  /// A mod is left out when one of its credited authors is named by an author
  /// entry, or when its forum topic or Discord thread (read from its links) is
  /// a whole post in a mod entry. A named key cannot be applied here: the old
  /// merge makes one mod per forum topic and has no LLM names, so blocking the
  /// topic would take the other mods on it too. Each such entry is logged.
  static List<ScrapedMod> withoutTakedowns(
    List<ScrapedMod> merged,
    TakedownList takedowns,
    void Function(String message) log,
  ) {
    if (takedowns.isEmpty) return merged;
    // Each whole post, with the shared forum topics its own entry names by
    // listing. An old mod on one of those topics stands for every mod on it,
    // so a whole post of the same entry must not take it out either.
    final wholePosts = <String, Set<String>>{};
    for (final entry in takedowns.mods) {
      final named = [for (final key in entry.posts) if (splitPostKey(key).$2 != null) key];
      if (named.isNotEmpty) {
        log('The takedown of "${entry.id}" is not applied to ModRepo.json for ${named.join(', ')}: the old merge '
            'makes one mod per forum topic, so TriOS keeps listing it until the switch.');
      }
      final sharedTopics = {for (final key in named) splitPostKey(key).$1};
      for (final key in entry.posts) {
        if (splitPostKey(key).$2 == null) wholePosts.putIfAbsent(key, () => {}).addAll(sharedTopics);
      }
    }

    final kept = <ScrapedMod>[];
    var left = 0;
    for (final mod in merged) {
      final urls = mod.getUrls();
      final topic = ModMerger.extractForumTopicId(urls[ModUrlType.Forum]);
      final thread = discordThreadIdOf(urls[ModUrlType.Discord]);
      bool blocks(String key) {
        final shared = wholePosts[key];
        return shared != null && (topic == null || !shared.contains('forum:$topic'));
      }

      final byPost = (topic != null && blocks('forum:$topic')) || (thread != null && blocks('discord:$thread'));
      final byAuthor = takedowns.authorMatch(mod.getAuthors());
      if (byPost || byAuthor != null) {
        left++;
        log('Left "${mod.name}" out of ModRepo.json: '
            '${byAuthor != null ? 'it credits ${byAuthor.credit}' : 'its post is taken down'}.');
        continue;
      }
      kept.add(mod);
    }
    if (left == 0) log('The takedowns left nothing out of ModRepo.json.');
    return kept;
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
///
/// The two kinds that need both pipelines ([JobKind.fetchAndUpdate] and
/// [JobKind.rebuildFromSaved]) are run here, as two steps of one job: the
/// ModRepo merge first, writing only the old `ModRepo.json`, then the QB half,
/// which ends by building the bundle, the catalog and the website. That order
/// matters: the Discord threads have to be fetched before the LLM can read
/// them, and the catalog has to be built after the LLM has read them.
class JobRouter implements JobRunner {
  final JobRunner qb;
  final JobRunner modRepo;
  final JobRunner publish;

  /// Changes `takedowns.json`. Null where nobody set it up, and the takedown
  /// kinds are then refused.
  final JobRunner? takedowns;

  const JobRouter({
    required this.qb,
    required this.modRepo,
    required this.publish,
    this.takedowns,
  });

  @override
  Future<JobOutcome> runJob(
    JobRequest request, {
    RunReporter reporter = const SilentRunReporter(),
    CancelToken? cancel,
    String? runId,
  }) {
    if (request.isPipelineKind) {
      return _runBoth(request, reporter: reporter, cancel: cancel, runId: runId);
    }
    if (request.isTakedownKind) {
      return _runTakedown(request, reporter: reporter, cancel: cancel, runId: runId);
    }
    return _runnerFor(request)
        .runJob(request, reporter: reporter, cancel: cancel, runId: runId);
  }

  Future<JobOutcome> _runBoth(
    JobRequest request, {
    required RunReporter reporter,
    CancelToken? cancel,
    String? runId,
  }) async {
    final fetch = request.kind == JobKind.fetchAndUpdate;
    // No board ticked means the forum is left alone altogether: neither
    // scraper goes near it, and its saved results are used.
    final scrapeForum = fetch && request.boards.isNotEmpty;

    final merge = await modRepo.runJob(
      JobRequest(
        kind: fetch ? JobKind.scrapeAndMerge : JobKind.mergeModRepo,
        // The old forum scraper feeds only ModRepo.json, and runs until the
        // switch. The catalog reads the forum from the QB store.
        modSources: {
          if (scrapeForum) ModSourceKind.forum,
          ...request.modSources.where((s) => s != ModSourceKind.forum),
        },
        keepAllGameVersions: request.keepAllGameVersions,
        oldRepoOnly: true,
      ),
      reporter: reporter,
      cancel: cancel,
      runId: runId,
    );
    if (merge.cancelled || (cancel?.isCancelled ?? false)) return merge;

    // With the forum left alone, the LLM still reads whatever Discord threads
    // were just fetched, through the catch-up pass.
    final qbOutcome = await qb.runJob(
      scrapeForum
          ? JobRequest(
              kind: JobKind.fullRun,
              scope: request.scope,
              boards: request.boards,
              maxPagesMain: request.maxPagesMain,
              maxPagesLesser: request.maxPagesLesser,
              maxPagesLibraries: request.maxPagesLibraries,
              runLlm: request.runLlm,
              collectMergeDebug: request.collectMergeDebug,
            )
          : JobRequest(
              kind: fetch && request.runLlm
                  ? JobKind.llmCoveragePass
                  : JobKind.rebuildBundle,
              runLlm: fetch && request.runLlm,
              collectMergeDebug: request.collectMergeDebug,
            ),
      reporter: reporter,
      cancel: cancel,
      runId: runId,
    );

    return JobOutcome(
      itemsDone: qbOutcome.itemsDone,
      itemsTotal: qbOutcome.itemsTotal,
      errors: merge.errors + qbOutcome.errors,
      llmCalls: qbOutcome.llmCalls,
      guardrailStop: qbOutcome.guardrailStop,
      cancelled: qbOutcome.cancelled,
    );
  }

  /// A takedown or a restore, as steps of one job: the list is changed, then
  /// `ModRepo.json` is merged again from saved files, then the catalog, the
  /// bundle and the website are rebuilt, and last the outputs are published
  /// when the request asks. No step scrapes or calls the LLM.
  ///
  /// The list is changed first and kept, even when the job is stopped after:
  /// the next rebuild applies it.
  Future<JobOutcome> _runTakedown(
    JobRequest request, {
    required RunReporter reporter,
    CancelToken? cancel,
    String? runId,
  }) async {
    final runner = takedowns;
    if (runner == null) {
      throw StateError('This manager was set up without a way to change the takedown list.');
    }
    await runner.runJob(request, reporter: reporter, cancel: cancel, runId: runId);
    if (cancel?.isCancelled ?? false) return const JobOutcome(cancelled: true);

    final merge = await modRepo.runJob(
      const JobRequest(kind: JobKind.mergeModRepo, oldRepoOnly: true),
      reporter: reporter,
      cancel: cancel,
      runId: runId,
    );
    if (merge.cancelled || (cancel?.isCancelled ?? false)) return merge;

    final rebuild = await qb.runJob(
      JobRequest(kind: JobKind.rebuildBundle, collectMergeDebug: request.collectMergeDebug),
      reporter: reporter,
      cancel: cancel,
      runId: runId,
    );
    if (rebuild.cancelled || (cancel?.isCancelled ?? false)) return rebuild;

    var errors = merge.errors + rebuild.errors;
    if (request.publishAfter) {
      final published = await publish.runJob(
        JobRequest.publishOutputs(),
        reporter: reporter,
        cancel: cancel,
        runId: runId,
      );
      errors += published.errors;
      if (published.cancelled) return published;
    }
    return JobOutcome(itemsDone: rebuild.itemsDone, itemsTotal: rebuild.itemsTotal, errors: errors);
  }

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
      JobKind.describePictures => 'scan images',
      JobKind.llmTest => 'LLM test',
      JobKind.rebuildBundle => 'rebuild the bundle',
      JobKind.mergeModRepo => 'merge from saved files',
      JobKind.scrapeAndMerge => 'scrape then merge',
      JobKind.publishOutputs => 'publish to GitHub',
      JobKind.fetchAndUpdate => 'fetch and update',
      JobKind.rebuildFromSaved => 'rebuild from saved files',
      JobKind.takeDown => 'take down',
      JobKind.restoreTakedown => 'restore a takedown',
    };
