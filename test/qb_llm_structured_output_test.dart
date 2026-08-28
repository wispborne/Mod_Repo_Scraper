import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/openai_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/prompt.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/throttled_client.dart';
import 'package:test/test.dart';

/// Captures the request body the client sends, and returns a canned answer.
class _CapturingClient {
  Map<String, dynamic>? lastBody;

  ThrottledClient build() => ThrottledClient(
        client: MockClient((req) async {
          lastBody = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {'content': '{"isMod":true,"mods":[]}'},
                  'finish_reason': 'stop',
                }
              ],
            }),
            200,
          );
        }),
        delayMs: 0,
      );
}

LlmRequest _request({Map<String, dynamic>? schema}) => LlmRequest(
      systemPrompt: 'sys',
      userPrompt: 'user',
      temperature: 0,
      maxTokens: 100,
      jsonSchema: schema,
    );

void main() {
  group('OpenAiCompatibleClient response_format', () {
    test('structured output on + a schema → sends json_schema', () async {
      final cap = _CapturingClient();
      final client = OpenAiCompatibleClient(
        client: cap.build(),
        baseUrl: 'http://localhost/v1/chat/completions',
        model: 'test',
        structuredOutput: true,
      );

      await client.complete(_request(schema: {
        'type': 'object',
        'properties': {
          'isMod': {'type': 'boolean'}
        },
      }));

      final rf = cap.lastBody!['response_format'] as Map<String, dynamic>;
      expect(rf['type'], 'json_schema');
      final js = rf['json_schema'] as Map<String, dynamic>;
      expect(js['strict'], true);
      expect(js['schema'], isA<Map<String, dynamic>>());
    });

    test('structured output off → sends the json_object hint', () async {
      final cap = _CapturingClient();
      final client = OpenAiCompatibleClient(
        client: cap.build(),
        baseUrl: 'http://localhost/v1/chat/completions',
        model: 'test',
        // structuredOutput defaults to false
      );

      await client.complete(_request(schema: {'type': 'object'}));

      expect(cap.lastBody!['response_format'], {'type': 'json_object'});
    });

    test('structured output on but no schema on the request → json_object',
        () async {
      final cap = _CapturingClient();
      final client = OpenAiCompatibleClient(
        client: cap.build(),
        baseUrl: 'http://localhost/v1/chat/completions',
        model: 'test',
        structuredOutput: true,
      );

      await client.complete(_request()); // schema null

      expect(cap.lastBody!['response_format'], {'type': 'json_object'});
    });
  });

  group('OpenAiCompatibleClient disable thinking', () {
    test('uses OpenRouter reasoning controls for OpenRouter', () async {
      final cap = _CapturingClient();
      final client = OpenAiCompatibleClient(
        client: cap.build(),
        baseUrl: 'https://openrouter.ai/api/v1/chat/completions',
        model: 'test',
        disableThinking: true,
      );

      await client.complete(_request());

      expect(cap.lastBody!['reasoning'], {'effort': 'none'});
      expect(cap.lastBody!, isNot(contains('think')));
      expect(cap.lastBody!, isNot(contains('chat_template_kwargs')));
    });

    test('keeps the existing local-server thinking controls', () async {
      final cap = _CapturingClient();
      final client = OpenAiCompatibleClient(
        client: cap.build(),
        baseUrl: 'http://localhost:8080/v1/chat/completions',
        model: 'test',
        disableThinking: true,
      );

      await client.complete(_request());

      expect(cap.lastBody!['think'], false);
      expect(cap.lastBody!['chat_template_kwargs'], {
        'enable_thinking': false,
      });
      expect(cap.lastBody!, isNot(contains('reasoning')));
    });
  });

  group('ExtractionPrompt.buildResponseSchema', () {
    test('is a strict object with the top-level shape', () {
      final s = ExtractionPrompt.buildResponseSchema();
      expect(s['type'], 'object');
      expect(s['additionalProperties'], false);
      expect(s['required'], containsAll(['isMod', 'mods']));

      final props = s['properties'] as Map<String, dynamic>;
      expect((props['isMod'] as Map)['type'], 'boolean');

      final item = ((props['mods'] as Map)['items']) as Map<String, dynamic>;
      expect(item['additionalProperties'], false);
      // Every property is required (what "strict" needs).
      final itemProps = (item['properties'] as Map).keys.toSet();
      expect((item['required'] as List).toSet(), itemProps);
      // A nullable field is a union type, not a bare string.
      expect((itemProps).contains('version'), isTrue);
      expect(((item['properties'] as Map)['version'] as Map)['type'],
          ['string', 'null']);
    });

    test('summary is present only when summaries are on', () {
      final without = ExtractionPrompt.buildResponseSchema();
      final withSum =
          ExtractionPrompt.buildResponseSchema(includeSummary: true);

      List<String> itemFields(Map<String, dynamic> schema) {
        final props = schema['properties'] as Map<String, dynamic>;
        final item = (props['mods'] as Map)['items'] as Map<String, dynamic>;
        return (item['properties'] as Map).keys.cast<String>().toList();
      }

      expect(itemFields(without), isNot(contains('summary')));
      expect(itemFields(withSum), contains('summary'));
    });
  });
}
