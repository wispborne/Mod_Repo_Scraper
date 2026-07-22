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

  const ScraperEnvironment({
    required this.dataPath,
    this.outputPath = 'outputs',
    this.llm,
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

  const ScraperGuardrails({
    this.delayMs = 1500,
    this.llmMaxTopics,
    this.llmMaxConsecutiveFailures = 10,
    this.llmTimeoutSeconds = 120,
    this.llmMaxTokens,
    this.llmMaxInputChars,
  });

  factory ScraperGuardrails.fromConfig(BotConfig config) => ScraperGuardrails(
        delayMs: config.qbDelayMs,
        llmMaxTopics: config.llmMaxTopics,
        llmMaxConsecutiveFailures: config.llmMaxConsecutiveFailures,
        llmTimeoutSeconds: config.llmTimeoutSeconds,
        llmMaxTokens: config.llmMaxTokens,
        llmMaxInputChars: config.llmMaxInputChars,
      );
}
