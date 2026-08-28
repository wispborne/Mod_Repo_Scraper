import 'dart:convert';

import 'package:http/http.dart' as http;

import '../throttled_client.dart';
import 'llm_client.dart';

/// [LlmClient] for any OpenAI-compatible chat-completions endpoint.
///
/// Works with OpenRouter, OpenAI, DeepSeek, Together, and local servers such as
/// Ollama, LM Studio, or llama.cpp — they all use the same
/// `/v1/chat/completions` format. The URL, model, and (optional) API key come
/// from config.
///
/// Uses a dedicated [ThrottledClient] so calls are spaced out even when several
/// topics are being processed at once, and LLM traffic stays off the scraper's
/// caching client.
class OpenAiCompatibleClient implements LlmClient {
  final ThrottledClient _client;
  final String _baseUrl;
  final String _model;

  /// API key. Optional — local servers (Ollama, LM Studio, ...) need none, so
  /// when this is null/blank, requests are sent without one.
  final String? _apiToken;

  /// When true, ask the endpoint to turn off "thinking" for reasoning models
  /// (Qwen3, ...). OpenRouter receives its `reasoning.effort` control. Other
  /// endpoints receive the existing local-server controls.
  final bool _disableThinking;

  /// When true, and the request carries a schema, ask the endpoint to force the
  /// answer into that exact JSON shape (`response_format: json_schema`). A
  /// server that honours it (e.g. llama.cpp) then cannot emit broken JSON. Off
  /// for endpoints that reject or ignore it (OpenRouter and most cloud
  /// providers), which fall back to the weaker `json_object` hint.
  final bool _structuredOutput;

  OpenAiCompatibleClient({
    required ThrottledClient client,
    required String baseUrl,
    required String model,
    String? apiToken,
    bool disableThinking = false,
    bool structuredOutput = false,
  })  : _client = client,
        _baseUrl = baseUrl,
        _model = model,
        _apiToken = apiToken,
        _disableThinking = disableThinking,
        _structuredOutput = structuredOutput;

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    final uri = Uri.tryParse(_baseUrl);
    if (uri == null) {
      throw LlmException('Invalid llm_base_url: "$_baseUrl"');
    }

    var userPrompt = request.userPrompt;

    // if (_disableThinking) {
    //   userPrompt = '/nothink $userPrompt';
    // }

    // Constrain the reply to JSON. A full schema (json_schema) makes a
    // compliant server emit only valid JSON in the exact shape, which removes
    // the main cause of a wasted call: a copied changelog with an unescaped
    // quote breaking the whole object. Where that isn't available, the weaker
    // json_object hint asks for valid JSON of any shape (some servers ignore
    // even this).
    final Map<String, dynamic> responseFormat =
        _structuredOutput && request.jsonSchema != null
            ? {
                'type': 'json_schema',
                'json_schema': {
                  'name': 'mod_extraction',
                  'strict': true,
                  'schema': request.jsonSchema,
                },
              }
            : {'type': 'json_object'};

    final payload = <String, dynamic>{
      'model': _model,
      'messages': [
        {'role': 'system', 'content': request.systemPrompt},
        {'role': 'user', 'content': request.userPrompt},
      ],
      'temperature': request.temperature,
      'response_format': responseFormat,
      'max_tokens': request.maxTokens,
      'stream': false,
    };
    if (_disableThinking) {
      if (uri.host.toLowerCase() == 'openrouter.ai') {
        payload['reasoning'] = {'effort': 'none'};
      } else {
        // Keep the working local-server controls unchanged.
        payload['think'] = false;
        payload['chat_template_kwargs'] = {'enable_thinking': false};
      }
    }
    final body = jsonEncode(payload);

    http.Response response;
    try {
      response = await _client.post(
        uri,
        headers: {
          if (_apiToken != null && _apiToken!.isNotEmpty)
            'Authorization': 'Bearer $_apiToken',
          'Content-Type': 'application/json',
        },
        body: body,
      );
    } catch (e) {
      // Network error or timeout.
      throw LlmException('Request failed', e);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LlmException(
          'Error response (status ${response.statusCode}): ${_previewBody(response.body)}');
    }

    return _parseResponse(response.body);
  }

  LlmResponse _parseResponse(String responseBody) {
    final Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(responseBody);
      if (parsed is! Map<String, dynamic>) {
        throw LlmException('Response body is not a JSON object');
      }
      decoded = parsed;
    } catch (e) {
      if (e is LlmException) rethrow;
      throw LlmException('Could not read the response body', e);
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw LlmException('Response has no choices');
    }
    final firstChoice = choices.first;
    if (firstChoice is! Map<String, dynamic>) {
      throw LlmException('choices[0] is not an object');
    }

    final message = firstChoice['message'];
    final finishReason = firstChoice['finish_reason'] as String?;

    final rawContent =
        message is Map<String, dynamic> ? message['content'] : null;
    final content = rawContent is String ? rawContent : null;

    if (content == null || content.trim().isEmpty) {
      final why = finishReason == 'length'
          ? 'the answer was cut off at the token limit (finish_reason=length) — '
              'a thinking model can use every token before it answers; raise the '
              "max tokens or turn the model's thinking off"
          : 'the model returned an empty message (finish_reason=$finishReason)';
      throw LlmException('No answer text in the response: $why');
    }

    final usage = decoded['usage'];
    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

    // llama.cpp reports speed in a `timings` block. Cloud endpoints omit it, so
    // every field here may be absent.
    final timings = decoded['timings'];
    double? timing(String key) =>
        timings is Map<String, dynamic> && timings[key] is num
            ? (timings[key] as num).toDouble()
            : null;

    return LlmResponse(
      content: content,
      promptTokens:
          usage is Map<String, dynamic> ? asInt(usage['prompt_tokens']) : null,
      completionTokens: usage is Map<String, dynamic>
          ? asInt(usage['completion_tokens'])
          : null,
      totalTokens:
          usage is Map<String, dynamic> ? asInt(usage['total_tokens']) : null,
      finishReason: finishReason,
      promptTokensPerSecond: timing('prompt_per_second'),
      completionTokensPerSecond: timing('predicted_per_second'),
      promptMs: timing('prompt_ms'),
      completionMs: timing('predicted_ms'),
    );
  }

  static String _previewBody(String body) =>
      body.length > 300 ? '${body.substring(0, 300)}…' : body;
}
