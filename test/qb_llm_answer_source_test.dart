import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/openai_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/throttled_client.dart';
import 'package:test/test.dart';

/// Every stored LLM answer says which model wrote it and where it was asked,
/// so the viewer can show it. The address is saved without anything secret.
void main() {
  test('an answer carries the model and the endpoint it came from', () async {
    final client = OpenAiCompatibleClient(
      client: ThrottledClient(
        client: MockClient.streaming((request, body) async {
          final events = [
            'data: ${jsonEncode({
                  'choices': [
                    {
                      'delta': {'content': '{}'},
                      'finish_reason': 'stop'
                    }
                  ]
                })}\n\n',
            'data: [DONE]\n\n',
          ];
          return http.StreamedResponse(
              Stream.fromIterable(events.map(utf8.encode)), 200,
              headers: {'content-type': 'text/event-stream'});
        }),
        delayMs: 0,
      ),
      baseUrl: 'http://127.0.0.1:8080/v1/chat/completions',
      model: 'qwen3-27b',
    );

    final answer = await client
        .complete(const LlmRequest(systemPrompt: 's', userPrompt: 'u'));

    expect(answer.model, 'qwen3-27b');
    expect(answer.endpoint, 'http://127.0.0.1:8080/v1/chat/completions');
  });

  test('the saved endpoint leaves off a user name, password and query', () {
    expect(
      OpenAiCompatibleClient.endpointLabel(
          'https://user:secret@example.com:8443/v1/chat/completions?key=abc'),
      'https://example.com:8443/v1/chat/completions',
    );
  });

  test('the model and endpoint survive a save and a load', () {
    final entry = LlmStoreEntry(
      fingerprint: 'f',
      schemaVersion: LlmExtractionStore.schemaVersion,
      promptVersion: 1,
      mods: const [],
      model: 'qwen3-27b',
      endpoint: 'http://127.0.0.1:8080/v1/chat/completions',
    );

    final back = LlmStoreEntry.fromJson(
        jsonDecode(jsonEncode(entry.toJson())) as Map<String, dynamic>);

    expect(back.model, 'qwen3-27b');
    expect(back.endpoint, 'http://127.0.0.1:8080/v1/chat/completions');
    // Nothing about where the answer came from reaches the bundle.
    expect(back.toThreadData().toMap().keys, isNot(contains('model')));
  });
}
