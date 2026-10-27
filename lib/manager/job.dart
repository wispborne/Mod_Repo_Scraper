import 'package:dart_mappable/dart_mappable.dart';

import '../bot/scraper/qb/models/scrape_job.dart';

part 'job.mapper.dart';

/// The kinds of work the manager can be asked for. Each per-topic kind lines up
/// with one cache layer, so re-running it throws away that layer's saved answers
/// for the chosen topics and nothing else.
@MappableEnum()
enum JobKind {
  /// Walk the boards and scrape, the way a plain CLI run does.
  fullRun,

  /// Fetch the chosen topics fresh and run the whole per-topic chain again.
  rescrapeTopics,

  /// Work out the chosen topics' downloads again, from the posts already saved.
  resolveDownloads,

  /// Ask the LLM about the chosen topics again, from the posts already saved.
  extractLlm,

  /// Make sure every stored topic has LLM results, without scraping.
  llmCoveragePass,

  /// Describe saved pictures without reading posts or dropping LLM answers.
  /// For selected topics, describe their pictures and those in Discord threads
  /// joined to them in the catalog again. Without a selection, describe saved
  /// pictures with missing or outdated descriptions.
  describePictures,

  /// Ask the LLM to match unmatched requirement names to mods.
  /// Then rebuild the bundle, the catalog and the website. No post is read again.
  matchRequirements,

  /// Save hand entries in `requirement-names.json` or remove saved answers.
  /// Then rebuild the website. No network or LLM calls.
  setRequirementNames,

  /// Save the author aliases to `author-aliases.json`, then rebuild every
  /// output from saved files. No network, no LLM.
  setAuthorAliases,

  /// A small trial of the LLM prompt that writes a report and saves nothing.
  llmTest,

  /// Build `forum-data-bundle.json` again from what is already saved.
  rebuildBundle,

  /// Merge the mod sources already saved on disk into `ModRepo.json`. No
  /// network.
  mergeModRepo,

  /// Fetch the chosen mod sources, then merge them into `ModRepo.json`.
  scrapeAndMerge,

  /// Publish the current output files to the target GitHub repo. No scrape, no
  /// merge — copies what is already in `outputs/` into a git clone and pushes.
  publishOutputs,

  /// Fetch the chosen sources and rebuild every output, in the order the
  /// pieces need: Discord and Nexus (and the old forum scraper for
  /// `ModRepo.json`) first, then the forum boards and the LLM, which reads the
  /// new Discord threads too, then the bundle, the catalog and the website.
  /// With no board chosen the forum is left alone.
  fetchAndUpdate,

  /// Rebuild every output from saved files: `ModRepo.json`, the bundle, the
  /// catalog and the website. No network, no LLM.
  rebuildFromSaved,

  /// Add one mod, Collection page or person to `takedowns.json`, then rebuild
  /// every output from saved files without it, and publish when asked.
  takeDown,

  /// Remove one entry from `takedowns.json`, then rebuild and publish the same
  /// way, so the mod comes back at its old address.
  restoreTakedown,
}

/// One change a `setRequirementNames` job makes to `requirement-names.json`.
@MappableClass()
class RequirementChange with RequirementChangeMappable {
  /// The requirement name as a post writes it.
  final String written;

  /// The mod it means, by permanent id. Null means none of our mods.
  final String? id;

  /// True removes the saved answer for [written]. The rules apply again.
  /// The LLM may be asked again. [id] is ignored.
  final bool forget;

  const RequirementChange({required this.written, this.id, this.forget = false});
}

/// The places ModRepo mods are scraped from. Which of these a job wants is job
/// shape; the tokens needed to reach them are environment.
@MappableEnum()
enum ModSourceKind { forum, discord, nexus }

/// How a run ended, or that it hasn't yet.
@MappableEnum()
enum RunState {
  /// Waiting for the job in front of it.
  queued,
  running,
  completed,
  failed,

  /// Stopped on request. Whatever it had finished is still saved.
  cancelled,

  /// Still marked running when the program started again — so the run died
  /// with the program and we never saw it end.
  interrupted,
}

/// Everything the manager needs to know to do one job.
///
/// A request says what to do, never where to do it: tokens, endpoints, the data
/// folder and the spend caps all come from how the service was built, so no
/// caller can talk the service into using a different endpoint or a bigger cap.
@MappableClass()
class JobRequest with JobRequestMappable {
  final JobKind kind;

  /// The topics this job is about, for the per-topic kinds. Ignored by kinds
  /// that work over everything.
  final List<int> topicIds;

  /// The Discord threads an `extractLlm` job reads again, by thread id. Their
  /// saved answers are dropped first, the same as [topicIds]'.
  final List<String> discordThreadIds;

  /// Which topics a `fullRun` should walk.
  final ScopeType scope;

  /// Which forum boards a `fullRun` should walk.
  final Set<ScrapeBoard> boards;

  /// Page limits for a `fullRun`, used when [scope] is `pages`. Null means "all
  /// pages of that board".
  final int? maxPagesMain;
  final int? maxPagesLesser;
  final int? maxPagesLibraries;

  /// Whether this job should send posts to the LLM. Only says what the job
  /// wants — if the service was built without LLM settings, nothing is sent.
  final bool runLlm;

  /// Whether a `fullRun` may replay recorded pages instead of fetching them.
  /// The per-topic kinds ignore this and always fetch live: the point of
  /// reprocessing one mod is to get fresh data.
  final bool replayAllowed;

  /// How many live LLM calls an `llmTest` job may make.
  final int testLimit;

  /// Which mod sources a `scrapeAndMerge` should fetch. A source with no token
  /// set up is skipped with a line in the log; asking for it is not an error.
  /// Ignored by `mergeModRepo`, which reads whatever is already on disk.
  final Set<ModSourceKind> modSources;

  /// How many forum pages a `scrapeAndMerge` walks. Null means the usual full
  /// count.
  final int? modForumPages;
  final int? moddingForumPages;

  /// Whether a merge keeps every game version a single source lists, instead of
  /// keeping only the newest.
  final bool keepAllGameVersions;

  /// Whether a merge collects the data behind the Merge Explorer. Runs started
  /// from the website always ask for it; the CLI asks when
  /// `modrepo_merge_debug` is on. On a QB job it means the catalog built at
  /// the end collects it.
  final bool collectMergeDebug;

  /// Whether a merge writes only the old `ModRepo.json`, leaving the catalog
  /// and the website to the step that runs after it. Only `JobRouter` sets
  /// this, for the merge half of [JobKind.fetchAndUpdate] and
  /// [JobKind.rebuildFromSaved].
  final bool oldRepoOnly;

  /// The mod or Collection id a `takeDown` job takes down.
  final String? takedownModId;

  /// The names of the person a `takeDown` job takes down, when it is not
  /// [takedownModId].
  final List<String> takedownAuthors;

  /// The entry a `restoreTakedown` job removes: a mod entry's id, or
  /// `author:` and an author entry's first name.
  final String? takedownEntry;

  /// Whether a `takeDown` or `restoreTakedown` job publishes when it is done.
  final bool publishAfter;

  /// The hand entries a `setRequirementNames` job saves or removes.
  final List<RequirementChange> requirementChanges;

  /// The whole alias list a `setAuthorAliases` job saves: one row per person,
  /// the name to publish first.
  final List<List<String>> authorAliasPeople;

  /// Pairs of names a `setAuthorAliases` job saves as different people, so
  /// the viewer stops suggesting them.
  final List<List<String>> authorAliasNotSame;

  const JobRequest({
    required this.kind,
    this.topicIds = const [],
    this.discordThreadIds = const [],
    this.scope = ScopeType.newData,
    this.boards = const {ScrapeBoard.main, ScrapeBoard.libraries},
    this.maxPagesMain,
    this.maxPagesLesser,
    this.maxPagesLibraries,
    this.runLlm = false,
    this.replayAllowed = false,
    this.testLimit = 5,
    this.modSources = const {
      ModSourceKind.forum,
      ModSourceKind.discord,
      ModSourceKind.nexus
    },
    this.modForumPages,
    this.moddingForumPages,
    this.keepAllGameVersions = false,
    this.collectMergeDebug = false,
    this.oldRepoOnly = false,
    this.takedownModId,
    this.takedownAuthors = const [],
    this.takedownEntry,
    this.publishAfter = false,
    this.requirementChanges = const [],
    this.authorAliasPeople = const [],
    this.authorAliasNotSame = const [],
  });

  /// A scrape over the boards, the way the CLI has always run.
  factory JobRequest.fullRun({
    ScopeType scope = ScopeType.newData,
    Set<ScrapeBoard> boards = const {ScrapeBoard.main, ScrapeBoard.libraries},
    int? maxPagesMain,
    int? maxPagesLesser,
    int? maxPagesLibraries,
    bool runLlm = false,
    bool replayAllowed = false,
  }) =>
      JobRequest(
        kind: JobKind.fullRun,
        scope: scope,
        boards: boards,
        maxPagesMain: maxPagesMain,
        maxPagesLesser: maxPagesLesser,
        maxPagesLibraries: maxPagesLibraries,
        runLlm: runLlm,
        replayAllowed: replayAllowed,
      );

  /// One of the per-topic kinds, for the given topics.
  factory JobRequest.forTopics(
    JobKind kind,
    List<int> topicIds, {
    bool runLlm = false,
  }) =>
      JobRequest(kind: kind, topicIds: topicIds, runLlm: runLlm);

  /// Turns the whole `mods-index.json` over to the LLM, filling in whatever is
  /// missing. No scrape.
  factory JobRequest.llmCoveragePass() =>
      const JobRequest(kind: JobKind.llmCoveragePass, runLlm: true);

  /// Describes pictures for [topicIds] again. With no topics selected,
  /// describes saved pictures with missing or outdated descriptions.
  factory JobRequest.describePictures({List<int> topicIds = const []}) =>
      JobRequest(
          kind: JobKind.describePictures, topicIds: topicIds, runLlm: true);

  /// Asks the LLM about requirement names the rules could not match.
  /// Then rebuilds the website.
  factory JobRequest.matchRequirements() =>
      const JobRequest(kind: JobKind.matchRequirements, runLlm: true);

  /// Saves or removes the hand entries in [changes]. Then rebuilds the website.
  factory JobRequest.setRequirementNames(List<RequirementChange> changes) =>
      JobRequest(kind: JobKind.setRequirementNames, requirementChanges: changes);

  /// Saves the alias list, then rebuilds every output from saved files.
  factory JobRequest.setAuthorAliases(List<List<String>> people,
          {List<List<String>> notSame = const []}) =>
      JobRequest(
        kind: JobKind.setAuthorAliases,
        authorAliasPeople: people,
        authorAliasNotSame: notSame,
        collectMergeDebug: true,
      );

  /// A trial run of the prompt. Writes a report; touches nothing else.
  factory JobRequest.llmTest({List<int> topicIds = const [], int limit = 5}) =>
      JobRequest(
        kind: JobKind.llmTest,
        topicIds: topicIds,
        runLlm: true,
        testLimit: limit,
      );

  /// Rebuilds the published bundle from what is already saved.
  factory JobRequest.rebuildBundle() =>
      const JobRequest(kind: JobKind.rebuildBundle);

  /// Merges the mod sources already saved on disk. Costs no network time.
  factory JobRequest.mergeModRepo({
    bool keepAllGameVersions = false,
    bool collectMergeDebug = true,
  }) =>
      JobRequest(
        kind: JobKind.mergeModRepo,
        keepAllGameVersions: keepAllGameVersions,
        collectMergeDebug: collectMergeDebug,
      );

  /// Fetches the chosen mod sources and then merges them.
  factory JobRequest.scrapeAndMerge({
    Set<ModSourceKind> sources = const {
      ModSourceKind.forum,
      ModSourceKind.discord,
      ModSourceKind.nexus
    },
    int? modForumPages,
    int? moddingForumPages,
    bool keepAllGameVersions = false,
    bool collectMergeDebug = true,
    bool replayAllowed = false,
  }) =>
      JobRequest(
        kind: JobKind.scrapeAndMerge,
        modSources: sources,
        modForumPages: modForumPages,
        moddingForumPages: moddingForumPages,
        keepAllGameVersions: keepAllGameVersions,
        collectMergeDebug: collectMergeDebug,
        replayAllowed: replayAllowed,
      );

  /// Publishes the current `outputs/` files to the target GitHub repo. Carries
  /// no repo, no folder and no token: where it publishes is environment, so no
  /// caller can point it somewhere else.
  factory JobRequest.publishOutputs() =>
      const JobRequest(kind: JobKind.publishOutputs);

  /// Fetches the chosen sources and rebuilds every output. [boards] says which
  /// forum boards to scrape; none leaves the forum alone. [sources] says which
  /// of Discord and Nexus to fetch.
  factory JobRequest.fetchAndUpdate({
    ScopeType scope = ScopeType.newData,
    Set<ScrapeBoard> boards = const {
      ScrapeBoard.main,
      ScrapeBoard.libraries,
      ScrapeBoard.lesser
    },
    Set<ModSourceKind> sources = const {ModSourceKind.discord},
    bool runLlm = true,
  }) =>
      JobRequest(
        kind: JobKind.fetchAndUpdate,
        scope: scope,
        boards: boards,
        modSources: sources,
        runLlm: runLlm,
        collectMergeDebug: true,
      );

  /// Rebuilds every output from saved files.
  factory JobRequest.rebuildFromSaved() => const JobRequest(
      kind: JobKind.rebuildFromSaved, collectMergeDebug: true);

  /// Takes down one mod or Collection page ([modId]) or one person
  /// ([authors]), then rebuilds every output.
  factory JobRequest.takeDown({
    String? modId,
    List<String> authors = const [],
    bool publishAfter = false,
  }) =>
      JobRequest(
        kind: JobKind.takeDown,
        takedownModId: modId,
        takedownAuthors: authors,
        publishAfter: publishAfter,
        collectMergeDebug: true,
      );

  /// Removes the takedown entry [entry] (see [takedownEntry]), then rebuilds
  /// every output.
  factory JobRequest.restoreTakedown(String entry, {bool publishAfter = false}) =>
      JobRequest(
        kind: JobKind.restoreTakedown,
        takedownEntry: entry,
        publishAfter: publishAfter,
        collectMergeDebug: true,
      );

  /// True for the two kinds that run both pipelines, one after the other.
  bool get isPipelineKind =>
      kind == JobKind.fetchAndUpdate || kind == JobKind.rebuildFromSaved;

  /// True for the two kinds that change the takedown list.
  bool get isTakedownKind =>
      kind == JobKind.takeDown || kind == JobKind.restoreTakedown;

  /// True for the kinds that change a list of corrections and then rebuild
  /// every output from saved files.
  bool get isCorrectionKind => isTakedownKind || kind == JobKind.setAuthorAliases;

  /// True for the two kinds that end in a merge.
  bool get isMergeKind =>
      kind == JobKind.mergeModRepo || kind == JobKind.scrapeAndMerge;

  /// True for the one kind the publish service owns.
  bool get isPublishKind => kind == JobKind.publishOutputs;
}

/// How much a run got through. Saved as the run goes, so a run that dies still
/// says how far it got.
@MappableClass()
class RunCounters with RunCountersMappable {
  /// Topics finished, and how many there were to do. The total is 0 until the
  /// job knows it.
  final int itemsDone;
  final int itemsTotal;

  /// Topics that failed along the way. A run can finish with errors.
  final int errors;

  /// Calls actually sent to the LLM. Topics served from saved answers cost
  /// nothing and are not counted.
  final int llmCalls;

  const RunCounters({
    this.itemsDone = 0,
    this.itemsTotal = 0,
    this.errors = 0,
    this.llmCalls = 0,
  });
}

/// The record of one run, kept in `runs/runs-index.json`.
@MappableClass()
class RunRecord with RunRecordMappable {
  /// `<UTC timestamp>-<kind>`, e.g. `20260721T153000Z-rescrapeTopics`. Sorts by
  /// time and reads as what it was.
  final String id;

  /// What was asked for — enough to ask for exactly the same thing again.
  final JobRequest request;

  final RunState state;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final RunCounters counters;

  /// Set when a spend cap or page cap cut the run short, in plain words. The
  /// run still counts as completed.
  final String? guardrailStop;

  /// Why the run failed, when it did.
  final String? errorMessage;

  /// The run's own log file, inside the same `runs/` folder.
  final String logFileName;

  const RunRecord({
    required this.id,
    required this.request,
    required this.state,
    this.startedAt,
    this.finishedAt,
    this.counters = const RunCounters(),
    this.guardrailStop,
    this.errorMessage,
    required this.logFileName,
  });
}
