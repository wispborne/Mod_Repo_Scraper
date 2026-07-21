/// A single chat request to the LLM: two messages (system rules + user post)
/// plus the fixed settings the extractor uses.
class LlmRequest {
  final String systemPrompt;
  final String userPrompt;
  final double temperature;
  final int maxTokens;

  /// The exact answer shape, as a JSON Schema. When set AND the client is
  /// configured for structured output, it is sent as `response_format:
  /// json_schema` so a compliant endpoint constrains the model to valid JSON in
  /// this shape. Clients not using structured output ignore it.
  final Map<String, dynamic>? jsonSchema;

  const LlmRequest({
    required this.systemPrompt,
    required this.userPrompt,
    this.temperature = 0,
    this.maxTokens = 6000,
    this.jsonSchema,
  });

  /// A copy with a different [temperature]. Used to retry a parse failure with
  /// a higher temperature, so a deterministic model samples differently instead
  /// of repeating the same unusable answer.
  LlmRequest copyWith({double? temperature}) => LlmRequest(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        temperature: temperature ?? this.temperature,
        maxTokens: maxTokens,
        jsonSchema: jsonSchema,
      );
}

/// Token counts and speeds for one LLM call, when the endpoint reports them.
///
/// Token counts come from the standard `usage` block. Speeds come from
/// llama.cpp's `timings` block (`prompt_per_second` for reading the prompt,
/// `predicted_per_second` for writing the answer); cloud endpoints usually
/// don't send these, so every field is optional.
class LlmCallStats {
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  /// Prompt-reading speed, tokens per second (llama.cpp `prompt_per_second`).
  final double? promptTokensPerSecond;

  /// Answer-writing speed, tokens per second (llama.cpp `predicted_per_second`).
  final double? completionTokensPerSecond;

  /// Time spent reading the prompt, in milliseconds (`prompt_ms`).
  final double? promptMs;

  /// Time spent writing the answer, in milliseconds (`predicted_ms`).
  final double? completionMs;

  const LlmCallStats({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.promptTokensPerSecond,
    this.completionTokensPerSecond,
    this.promptMs,
    this.completionMs,
  });

  /// True when nothing was reported (so we can skip storing an empty block).
  bool get isEmpty =>
      promptTokens == null &&
      completionTokens == null &&
      totalTokens == null &&
      promptTokensPerSecond == null &&
      completionTokensPerSecond == null &&
      promptMs == null &&
      completionMs == null;

  Map<String, dynamic> toJson() => {
        if (promptTokens != null) 'promptTokens': promptTokens,
        if (completionTokens != null) 'completionTokens': completionTokens,
        if (totalTokens != null) 'totalTokens': totalTokens,
        if (promptTokensPerSecond != null)
          'promptTokensPerSecond': promptTokensPerSecond,
        if (completionTokensPerSecond != null)
          'completionTokensPerSecond': completionTokensPerSecond,
        if (promptMs != null) 'promptMs': promptMs,
        if (completionMs != null) 'completionMs': completionMs,
      };

  factory LlmCallStats.fromJson(Map<String, dynamic> json) {
    double? asDouble(Object? v) => v is num ? v.toDouble() : null;
    int? asInt(Object? v) => v is num ? v.toInt() : null;
    return LlmCallStats(
      promptTokens: asInt(json['promptTokens']),
      completionTokens: asInt(json['completionTokens']),
      totalTokens: asInt(json['totalTokens']),
      promptTokensPerSecond: asDouble(json['promptTokensPerSecond']),
      completionTokensPerSecond: asDouble(json['completionTokensPerSecond']),
      promptMs: asDouble(json['promptMs']),
      completionMs: asDouble(json['completionMs']),
    );
  }
}

/// The model's answer, plus usage numbers for cost tracking and a
/// [finishReason] so we can tell if the answer was cut off.
class LlmResponse {
  /// The model's raw text answer (a JSON string the extractor parses).
  final String content;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final String? finishReason;

  /// Prompt-reading speed, tokens per second, when the endpoint reports it.
  final double? promptTokensPerSecond;

  /// Answer-writing speed, tokens per second, when the endpoint reports it.
  final double? completionTokensPerSecond;

  /// Prompt-reading time in milliseconds, when the endpoint reports it.
  final double? promptMs;

  /// Answer-writing time in milliseconds, when the endpoint reports it.
  final double? completionMs;

  const LlmResponse({
    required this.content,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.finishReason,
    this.promptTokensPerSecond,
    this.completionTokensPerSecond,
    this.promptMs,
    this.completionMs,
  });

  /// True when the model was cut off at the token limit.
  bool get wasTruncated => finishReason == 'length';

  /// The token counts and speeds bundled for storing/logging.
  LlmCallStats get stats => LlmCallStats(
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        totalTokens: totalTokens,
        promptTokensPerSecond: promptTokensPerSecond,
        completionTokensPerSecond: completionTokensPerSecond,
        promptMs: promptMs,
        completionMs: completionMs,
      );

  String get usageSummary {
    final b = StringBuffer(
        'prompt=$promptTokens completion=$completionTokens total=$totalTokens');
    if (promptTokensPerSecond != null) {
      b.write(' read=${promptTokensPerSecond!.toStringAsFixed(1)} tok/s');
    }
    if (completionTokensPerSecond != null) {
      b.write(' write=${completionTokensPerSecond!.toStringAsFixed(1)} tok/s');
    }
    return b.toString();
  }
}

/// Thrown when a call fails for any reason (network error, timeout, bad status
/// code, unreadable answer). The extractor retries once, then uses the
/// rule-based result instead.
class LlmException implements Exception {
  final String message;
  final Object? cause;

  LlmException(this.message, [this.cause]);

  @override
  String toString() =>
      'LlmException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Shared shape for any LLM service. The extractor only talks to this, so
/// switching providers needs no changes elsewhere.
abstract class LlmClient {
  /// Sends one request and returns the model's answer.
  ///
  /// Throws [LlmException] on failure. Does not retry — the caller handles
  /// that.
  Future<LlmResponse> complete(LlmRequest request);
}
