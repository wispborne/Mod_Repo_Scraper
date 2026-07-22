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

  /// A small trial of the LLM prompt that writes a report and saves nothing.
  llmTest,

  /// Build `forum-data-bundle.json` again from what is already saved.
  rebuildBundle,
}

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

  const JobRequest({
    required this.kind,
    this.topicIds = const [],
    this.scope = ScopeType.newData,
    this.boards = const {ScrapeBoard.main, ScrapeBoard.libraries},
    this.maxPagesMain,
    this.maxPagesLesser,
    this.maxPagesLibraries,
    this.runLlm = false,
    this.replayAllowed = false,
    this.testLimit = 5,
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
