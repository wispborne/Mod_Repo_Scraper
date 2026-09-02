import 'package:path/path.dart' as p;

import '../bot/common.dart';

/// Everything needed to talk to an LLM service. All of it is environment: no
/// job request can change the endpoint, the model, or the key.
class LlmSettings {
  final String? apiToken;
  final String model;
  final String baseUrl;
  final bool disableThinking;
  final bool structuredOutput;

  /// Whether the model is also asked for a short plain-English summary.
  final bool generateSummaries;

  /// A second service, used only when the first one can't be reached.
  final String? fallbackBaseUrl;
  final String? fallbackModel;
  final String? fallbackApiToken;
  final bool fallbackDisableThinking;
  final bool fallbackStructuredOutput;

  const LlmSettings({
    this.apiToken,
    required this.model,
    required this.baseUrl,
    this.disableThinking = false,
    this.structuredOutput = false,
    this.generateSummaries = false,
    this.fallbackBaseUrl,
    this.fallbackModel,
    this.fallbackApiToken,
    this.fallbackDisableThinking = false,
    this.fallbackStructuredOutput = false,
  });

  /// True when a fallback service is set up (both its URL and its model).
  bool get hasFallback =>
      (fallbackBaseUrl?.trim().isNotEmpty ?? false) &&
      (fallbackModel?.trim().isNotEmpty ?? false);

  factory LlmSettings.fromConfig(BotConfig config) => LlmSettings(
        apiToken: config.llmApiToken,
        model: config.llmModel,
        baseUrl: config.llmBaseUrl,
        disableThinking: config.llmDisableThinking,
        structuredOutput: config.llmStructuredOutput,
        generateSummaries: config.enableLlmSummaries,
        fallbackBaseUrl: config.llmFallbackBaseUrl,
        fallbackModel: config.llmFallbackModel,
        fallbackApiToken: config.llmFallbackApiToken,
        fallbackDisableThinking: config.llmFallbackDisableThinking,
        fallbackStructuredOutput: config.llmFallbackStructuredOutput,
      );
}

/// Where the scraper keeps its files and which services it may talk to.
///
/// This is the half of the config file a job can never argue with. The service
/// is handed it once, when it is built.
class ScraperEnvironment {
  /// The folder holding the mods index, the detail files, and the caches.
  final String dataPath;

  /// Where the published bundle is written.
  final String outputPath;

  /// Null when no LLM service is set up, which means no job can send anything
  /// to an LLM no matter what it asks for.
  final LlmSettings? llm;

  /// The public website's own files. Each mod's page is built out of the
  /// `index.html` in here, so it has to be the same folder a publish copies —
  /// the one `publish_site_path` names.
  final String sitePath;

  const ScraperEnvironment({
    required this.dataPath,
    this.outputPath = 'outputs',
    this.llm,
    this.sitePath = 'site',
  });

  /// Reads only environment keys. `llm_enabled` is read here for the one thing
  /// it says about the environment — whether an LLM service is set up at all.
  /// Whether a given run should use it is a field on the job request.
  factory ScraperEnvironment.fromConfig(BotConfig config,
          {String outputPath = 'outputs'}) =>
      ScraperEnvironment(
        dataPath: config.qbDataPath,
        outputPath: outputPath,
        llm: config.enableLlm ? LlmSettings.fromConfig(config) : null,
        sitePath: config.publishSitePath,
      );
}

/// The limits that bind every job, whoever asked for it: how much may be spent,
/// how fast the forum may be hit, how long to wait for an answer.
class ScraperGuardrails {
  /// Pause between forum requests, in milliseconds. Dropped to 0 when a run
  /// replays recorded pages, since nothing is being asked of the forum.
  final int delayMs;

  /// Most live LLM calls one run may make. Null means no limit. A run that
  /// stops here still counts as completed, and says so on its record.
  final int? llmMaxTopics;

  /// How many LLM calls may be going at the same time. The scrape starts a
  /// read per topic and moves on; this is how many of those reads may actually
  /// be talking to the model at once.
  final int llmMaxConcurrentCalls;

  /// Stop calling the LLM for the rest of the run after this many failures in
  /// a row.
  final int llmMaxConsecutiveFailures;

  /// How long to wait for one LLM reply, in seconds.
  final int llmTimeoutSeconds;

  /// Cap on how much the model may write per reply, in tokens. Null uses the
  /// prompt's own default.
  final int? llmMaxTokens;

  /// Cap on how much of a post's text is sent to the model. Null sends it all.
  final int? llmMaxInputChars;

  /// How many bundle snapshots to keep, so runs can be compared. 0 keeps
  /// everything.
  final int bundlesToKeep;

  const ScraperGuardrails({
    this.delayMs = 1500,
    this.llmMaxTopics,
    this.llmMaxConcurrentCalls = 3,
    this.llmMaxConsecutiveFailures = 10,
    this.llmTimeoutSeconds = 120,
    this.llmMaxTokens,
    this.llmMaxInputChars,
    this.bundlesToKeep = 500,
  });

  factory ScraperGuardrails.fromConfig(BotConfig config) => ScraperGuardrails(
        delayMs: config.qbDelayMs,
        llmMaxTopics: config.llmMaxTopics,
        llmMaxConcurrentCalls: config.llmMaxConcurrentCalls,
        llmMaxConsecutiveFailures: config.llmMaxConsecutiveFailures,
        llmTimeoutSeconds: config.llmTimeoutSeconds,
        llmMaxTokens: config.llmMaxTokens,
        llmMaxInputChars: config.llmMaxInputChars,
        bundlesToKeep: config.qbBundlesToKeep,
      );
}

/// Where the ModRepo pipeline keeps its files and what it needs to reach the
/// mod sources.
///
/// The same split as the QB half: this is the part of the config file a job can
/// never argue with. No job request can name a token, a folder, or an output
/// path.
class ModRepoEnvironment {
  /// The folder holding the per-source cache files (`forum_cache.json` and
  /// friends) and `merge-debug.json`.
  final String workingPath;

  /// Where `ModRepo.json` is written.
  final String outputPath;

  /// Where merge snapshots are kept — one per merge run.
  final String snapshotPath;

  /// Null when no Discord token is set up, which means no job can scrape
  /// Discord no matter what it asks for.
  final String? discordAuthToken;
  final String? discordServerId;

  /// Channel id to game version, as the Discord reader wants it.
  final Map<String, String>? discordForumChannels;

  /// Null when no Nexus token is set up.
  final String? nexusApiToken;

  /// The public website's own files. Each mod's page is built out of the
  /// `index.html` in here, so it has to be the same folder a publish copies —
  /// the one `publish_site_path` names.
  final String sitePath;

  const ModRepoEnvironment({
    this.workingPath = '.',
    this.outputPath = 'outputs',
    required this.snapshotPath,
    this.discordAuthToken,
    this.discordServerId,
    this.discordForumChannels,
    this.nexusApiToken,
    this.sitePath = 'site',
  });

  /// True when Discord can actually be reached — a token, a server, and at
  /// least one channel. A job asking for a source we can't reach is skipped,
  /// not failed.
  bool get hasDiscord =>
      (discordAuthToken?.trim().isNotEmpty ?? false) &&
      (discordServerId?.trim().isNotEmpty ?? false) &&
      (discordForumChannels?.isNotEmpty ?? false);

  bool get hasNexus => (nexusApiToken?.trim().isNotEmpty ?? false);

  /// Reads only environment keys. The on/off switches for each source are job
  /// shape and are read where the request is built, not here.
  factory ModRepoEnvironment.fromConfig(
    BotConfig config, {
    String workingPath = '.',
    String outputPath = 'outputs',
  }) =>
      ModRepoEnvironment(
        workingPath: workingPath,
        outputPath: outputPath,
        snapshotPath: config.qbDataPath,
        discordAuthToken: config.discordAuthToken,
        discordServerId: config.discordServerId,
        discordForumChannels: config.discordForumChannelIdsAndGameVersions,
        sitePath: config.publishSitePath,
        nexusApiToken: config.nexusApiToken,
      );

  /// The Discord and Nexus readers still want a whole [BotConfig]. This hands
  /// them one holding nothing but the credentials they read, so the rest of the
  /// config file never reaches them.
  BotConfig toReaderConfig() => BotConfig(
        lessScraping: false,
        enableForums: false,
        enableDiscord: hasDiscord,
        enableNexus: hasNexus,
        logLevel: 'INFO',
        discordAuthToken: discordAuthToken,
        discordServerId: discordServerId,
        discordForumChannelIdsAndGameVersions: discordForumChannels,
        nexusApiToken: nexusApiToken,
      );
}

/// The limits every merge job runs under, whoever asked for it.
class ModRepoGuardrails {
  /// How long one source gets to answer before it is given up on.
  final Duration sourceTimeout;

  /// How many merge snapshots to keep. 0 keeps everything.
  final int mergesToKeep;

  const ModRepoGuardrails({
    this.sourceTimeout = const Duration(minutes: 2),
    this.mergesToKeep = 20,
  });

  factory ModRepoGuardrails.fromConfig(BotConfig config) => ModRepoGuardrails(
        mergesToKeep: config.modRepoMergesToKeep,
      );
}

/// Where a publish job sends the output files and where it keeps its working
/// clone.
///
/// The same split as the other pipelines: this is the part of the config file a
/// publish job can never argue with. No request can name the repo, the folder,
/// or a credential. There is no token here — publishing uses the host user's own
/// git and SSH key.
class PublishEnvironment {
  /// The folder holding the output files a publish reads (`ModRepo.json`,
  /// `forum-data-bundle.json`).
  final String outputPath;

  /// The repo the output files are pushed to.
  final String repoUrl;

  /// The folder the server keeps its working clone in. Kept apart from any
  /// folder a cron script wipes.
  final String cloneDir;

  /// The public website's own files — the HTML, the stylesheet and the scripts.
  /// They are copied into the clone alongside the data they read, so the pushed
  /// repo is a complete, servable website with no further step.
  final String sitePath;

  const PublishEnvironment({
    required this.outputPath,
    required this.repoUrl,
    required this.cloneDir,
    this.sitePath = 'site',
  });

  /// Reads only environment keys. When no clone folder is set, a `publish-clone`
  /// folder under `qb_data_path` is used — inside the data folder, and well away
  /// from any folder a cron run wipes.
  factory PublishEnvironment.fromConfig(
    BotConfig config, {
    String outputPath = 'outputs',
  }) =>
      PublishEnvironment(
        outputPath: outputPath,
        repoUrl: config.publishRepoUrl,
        cloneDir: config.publishCloneDir ??
            p.join(config.qbDataPath, 'publish-clone'),
        sitePath: config.publishSitePath,
      );
}
