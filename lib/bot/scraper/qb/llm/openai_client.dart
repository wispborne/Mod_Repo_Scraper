import 'dart:async';
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
///
/// The answer is streamed, so there are two time limits. [idleTimeout] is how
/// long to wait with nothing new arriving: a slow model that is still writing
/// is left alone, and a server that has stopped answering is caught. The wait
/// for the first words counts too, and that covers the model loading and
/// reading the prompt. [totalTimeout] caps the whole call, which is what stops
/// a model stuck repeating itself, since that one never goes quiet.
///
/// A server that ignores `stream: true` and sends the whole answer at once is
/// read as before.
class OpenAiCompatibleClient implements LlmClient {
  final ThrottledClient _client;
  final String _baseUrl;
  final String _model;

  /// API key. Optional — local servers (Ollama, LM Studio, ...) need none, so
  /// when this is null/blank, requests are sent without one.
  final String? _apiToken;

  /// When true, ask the endpoint to turn off "thinking" for reasoning models
  /// (Qwen3, ...). OpenRouter receives its `reasoning.enabled` control. Other
  /// endpoints receive the existing local-server controls.
  final bool _disableThinking;

  /// When true, and the request carries a schema, ask the endpoint to force the
  /// answer into that exact JSON shape (`response_format: json_schema`). A
  /// server that honours it (e.g. llama.cpp) then cannot emit broken JSON. Off
  /// for endpoints that reject or ignore it (OpenRouter and most cloud
  /// providers), which fall back to the weaker `json_object` hint.
  final bool _structuredOutput;

  /// Longest wait with nothing new arriving, including the wait for the first
  /// words.
  final Duration _idleTimeout;

  /// Longest the whole call may take.
  final Duration _totalTimeout;

  OpenAiCompatibleClient({
    required ThrottledClient client,
    required String baseUrl,
    required String model,
    String? apiToken,
    bool disableThinking = false,
    bool structuredOutput = false,
    Duration idleTimeout = const Duration(minutes: 3),
    Duration totalTimeout = const Duration(minutes: 15),
  })  : _client = client,
        _baseUrl = baseUrl,
        _model = model,
        _apiToken = apiToken,
        _disableThinking = disableThinking,
        _structuredOutput = structuredOutput,
        _idleTimeout = idleTimeout,
        _totalTimeout = totalTimeout;

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    final uri = Uri.tryParse(_baseUrl);
    if (uri == null) {
      throw LlmException('Invalid llm_base_url: "$_baseUrl"');
    }

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
      'stream': true,
      // Token counts come in the last chunk only when asked for.
      'stream_options': {'include_usage': true},
    };
    if (_disableThinking) {
      if (uri.host.toLowerCase() == 'openrouter.ai') {
        payload['reasoning'] = {'enabled': false};
      } else {
        // Keep the working local-server controls unchanged.
        payload['think'] = false;
        payload['chat_template_kwargs'] = {'enable_thinking': false};
      }
    }

    final httpRequest = http.Request('POST', uri)
      ..headers.addAll({
        if (_apiToken != null && _apiToken!.isNotEmpty)
          'Authorization': 'Bearer $_apiToken',
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode(payload);

    final clock = Stopwatch()..start();
    try {
      final pending = _client.send(httpRequest);
      final http.StreamedResponse response;
      try {
        response = await _limit(pending, clock);
      } on TimeoutException {
        // If the answer turns up after all, close it rather than leave the
        // connection open.
        unawaited(pending
            .then((r) => r.stream.listen(null).cancel())
            .catchError((Object _) {}));
        rethrow;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final text = await _limit(response.stream.bytesToString(), clock);
        throw LlmException(
            'Error response (status ${response.statusCode}): ${_previewBody(text)}');
      }

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('text/event-stream')) {
        // The server ignored `stream: true` and sent the whole answer at once.
        final text = await _limit(response.stream.bytesToString(), clock);
        return _parseResponse(text);
      }
      return await _readStream(response, clock);
    } on LlmException {
      rethrow;
    } catch (e) {
      // Network error or timeout.
      throw LlmException('Request failed', e);
    }
  }

  /// Waits for [future] no longer than the idle limit, or than what is left of
  /// the total limit if that is less. Throws [TimeoutException] saying which
  /// limit was hit.
  Future<T> _limit<T>(Future<T> future, Stopwatch clock) {
    final left = _totalTimeout - clock.elapsed;
    final totalTimedOut = TimeoutException(
        'No complete answer after ${_totalTimeout.inSeconds} s', _totalTimeout);
    if (left <= Duration.zero) throw totalTimedOut;
    if (left <= _idleTimeout) {
      return future.timeout(left, onTimeout: () => throw totalTimedOut);
    }
    return future.timeout(_idleTimeout,
        onTimeout: () => throw TimeoutException(
            'Nothing new from the model for ${_idleTimeout.inSeconds} s',
            _idleTimeout));
  }

  /// Reads a server-sent-events answer: each `data:` line is one JSON chunk
  /// carrying the next piece of text, and `data: [DONE]` ends it. Token counts
  /// and llama.cpp's `timings` arrive in the last chunks.
  Future<LlmResponse> _readStream(
      http.StreamedResponse response, Stopwatch clock) async {
    final lines = StreamIterator(response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter()));
    final content = StringBuffer();
    String? finishReason;
    Object? usage;
    Object? timings;
    var done = false;
    try {
      while (await _limit(lines.moveNext(), clock)) {
        // Blank lines end an event. Lines starting with ":" are comments, which
        // some providers send to keep the connection open.
        final line = lines.current;
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data == '[DONE]') {
          done = true;
          break;
        }

        final Object? chunk;
        try {
          chunk = jsonDecode(data);
        } catch (e) {
          throw LlmException('Could not read a chunk of the answer', e);
        }
        if (chunk is! Map<String, dynamic>) continue;

        // OpenRouter reports a failure part-way through as a chunk of its own.
        final error = chunk['error'];
        if (error != null) {
          throw LlmException('Error part-way through the answer: '
              '${_previewBody(jsonEncode(error))}');
        }

        final choices = chunk['choices'];
        if (choices is List && choices.isNotEmpty) {
          final choice = choices.first;
          if (choice is Map<String, dynamic>) {
            final delta = choice['delta'];
            if (delta is Map<String, dynamic> && delta['content'] is String) {
              content.write(delta['content']);
            }
            if (choice['finish_reason'] is String) {
              finishReason = choice['finish_reason'] as String;
            }
          }
        }
        if (chunk['usage'] is Map) usage = chunk['usage'];
        if (chunk['timings'] is Map) timings = chunk['timings'];
      }
    } finally {
      // Closes the connection if we stopped early, so the server stops too.
      await lines.cancel();
    }

    if (!done && finishReason == null) {
      throw LlmException('The answer stopped arriving before it was finished');
    }
    return _buildResponse(
      content: content.toString(),
      finishReason: finishReason,
      usage: usage,
      timings: timings,
    );
  }

  /// Reads an answer sent all at once.
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
    final rawContent =
        message is Map<String, dynamic> ? message['content'] : null;

    return _buildResponse(
      content: rawContent is String ? rawContent : null,
      finishReason: firstChoice['finish_reason'] as String?,
      usage: decoded['usage'],
      timings: decoded['timings'],
    );
  }

  LlmResponse _buildResponse({
    required String? content,
    required String? finishReason,
    required Object? usage,
    required Object? timings,
  }) {
    if (content == null || content.trim().isEmpty) {
      final why = finishReason == 'length'
          ? 'the answer was cut off at the token limit (finish_reason=length) — '
              'a thinking model can use every token before it answers; raise the '
              "max tokens or turn the model's thinking off"
          : 'the model returned an empty message (finish_reason=$finishReason)';
      throw LlmException('No answer text in the response: $why');
    }

    int? asInt(Object? v) => v is int ? v : (v is num ? v.toInt() : null);

    // llama.cpp reports speed in a `timings` block. Cloud endpoints omit it, so
    // every field here may be absent.
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
      model: _model,
      endpoint: endpointLabel(_baseUrl),
    );
  }

  /// The endpoint's address as it is safe to save and show: scheme, host, port
  /// and path only. A user name, password or query string (where some setups
  /// put a key) is left off.
  static String endpointLabel(String baseUrl) {
    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null || uri.host.isEmpty) return baseUrl.trim();
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString();
  }

  static String _previewBody(String body) =>
      body.length > 300 ? '${body.substring(0, 300)}…' : body;
}
