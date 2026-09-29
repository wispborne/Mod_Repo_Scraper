import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/openai_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/throttled_client.dart';
import 'package:test/test.dart';

const _request = LlmRequest(systemPrompt: 'sys', userPrompt: 'user');

/// One server-sent event carrying [json].
String _event(Map<String, dynamic> json) => 'data: ${jsonEncode(json)}\n\n';

String _piece(String text) => _event({
      'choices': [
        {
          'delta': {'content': text},
          'finish_reason': null,
        }
      ],
    });

final _finish = _event({
  'choices': [
    {'delta': <String, dynamic>{}, 'finish_reason': 'stop'}
  ],
});

const _done = 'data: [DONE]\n\n';

/// A fake server that answers with [events], each sent after [gap], and keeps
/// what it was sent. [onCancel] runs if the client stops listening early.
class _StreamingServer {
  final List<String> events;
  final Duration gap;
  final Duration headerDelay;
  Map<String, dynamic>? lastBody;
  var cancelled = false;

  _StreamingServer(this.events,
      {this.gap = Duration.zero, this.headerDelay = Duration.zero});

  OpenAiCompatibleClient client({
    Duration idle = const Duration(seconds: 5),
    Duration total = const Duration(seconds: 30),
  }) =>
      OpenAiCompatibleClient(
        client: ThrottledClient(
          client: MockClient.streaming((request, body) async {
            lastBody =
                jsonDecode(await body.bytesToString()) as Map<String, dynamic>;
            await Future<void>.delayed(headerDelay);
            final controller = StreamController<List<int>>(
                onCancel: () => cancelled = true);
            unawaited(() async {
              for (final e in events) {
                if (gap > Duration.zero) await Future<void>.delayed(gap);
                if (controller.isClosed || cancelled) return;
                controller.add(utf8.encode(e));
              }
              if (!cancelled) await controller.close();
            }());
            return http.StreamedResponse(controller.stream, 200,
                headers: {'content-type': 'text/event-stream'});
          }),
          delayMs: 0,
        ),
        baseUrl: 'http://127.0.0.1:8080/v1/chat/completions',
        model: 'm',
        idleTimeout: idle,
        totalTimeout: total,
      );
}

/// Runs [call] and returns the [TimeoutException] it failed with.
Future<TimeoutException> _timeoutOf(Future<LlmResponse> call) async {
  try {
    await call;
  } on LlmException catch (e) {
    expect(e.cause, isA<TimeoutException>(), reason: '$e');
    return e.cause! as TimeoutException;
  }
  fail('expected a timeout');
}

void main() {
  group('OpenAiCompatibleClient streaming', () {
    test('asks for a stream with token counts', () async {
      final server = _StreamingServer([_piece('{}'), _finish, _done]);
      await server.client().complete(_request);

      expect(server.lastBody!['stream'], isTrue);
      expect(server.lastBody!['stream_options'], {'include_usage': true});
    });

    test('joins the pieces and reads the finish, counts and timings', () async {
      final server = _StreamingServer([
        ': keep-alive comment\n\n',
        _piece('{"isMod":'),
        _piece('true}'),
        _finish,
        _event({
          'choices': <Object>[],
          'usage': {
            'prompt_tokens': 10,
            'completion_tokens': 4,
            'total_tokens': 14,
          },
          'timings': {'prompt_per_second': 500.0, 'predicted_per_second': 30.0},
        }),
        _done,
      ]);

      final res = await server.client().complete(_request);

      expect(res.content, '{"isMod":true}');
      expect(res.finishReason, 'stop');
      expect(res.promptTokens, 10);
      expect(res.completionTokens, 4);
      expect(res.totalTokens, 14);
      expect(res.promptTokensPerSecond, 500.0);
      expect(res.completionTokensPerSecond, 30.0);
    });

    test('a slow but steady answer outlasts the idle limit', () async {
      final server = _StreamingServer(
        [for (var i = 0; i < 6; i++) _piece('x'), _finish, _done],
        gap: const Duration(milliseconds: 60),
      );

      final res = await server
          .client(idle: const Duration(milliseconds: 200))
          .complete(_request);

      expect(res.content, 'xxxxxx');
    });

    test('an answer that goes quiet times out and closes the connection',
        () async {
      final server = _StreamingServer(
        [_piece('x'), _finish, _done],
        gap: const Duration(milliseconds: 400),
      );

      final timeout = await _timeoutOf(server
          .client(idle: const Duration(milliseconds: 100))
          .complete(_request));

      expect(timeout.message, contains('Nothing new'));
      expect(server.cancelled, isTrue);
    });

    test('waiting too long for the first words times out', () async {
      final server = _StreamingServer([_piece('x'), _finish, _done],
          headerDelay: const Duration(milliseconds: 400));

      final timeout = await _timeoutOf(server
          .client(idle: const Duration(milliseconds: 100))
          .complete(_request));

      expect(timeout.message, contains('Nothing new'));
    });

    test('an answer that never ends hits the total limit', () async {
      final server = _StreamingServer(
        [for (var i = 0; i < 100; i++) _piece('x')],
        gap: const Duration(milliseconds: 20),
      );

      final timeout = await _timeoutOf(server
          .client(
            idle: const Duration(milliseconds: 200),
            total: const Duration(milliseconds: 300),
          )
          .complete(_request));

      expect(timeout.message, contains('No complete answer'));
      expect(server.cancelled, isTrue);
    });

    test('a stream that stops before the finish is a failure', () async {
      final server = _StreamingServer([_piece('{"isMod":')]);

      await expectLater(
        server.client().complete(_request),
        throwsA(isA<LlmException>().having(
            (e) => e.message, 'message', contains('before it was finished'))),
      );
    });

    test('an error sent part-way through is a failure', () async {
      final server = _StreamingServer([
        _piece('{"isMod":'),
        _event({
          'error': {'message': 'provider overloaded'},
        }),
      ]);

      await expectLater(
        server.client().complete(_request),
        throwsA(isA<LlmException>().having(
            (e) => e.message, 'message', contains('provider overloaded'))),
      );
    });

    test('a finish at the token limit with no text says so', () async {
      final server = _StreamingServer([
        _event({
          'choices': [
            {'delta': <String, dynamic>{}, 'finish_reason': 'length'}
          ],
        }),
        _done,
      ]);

      await expectLater(
        server.client().complete(_request),
        throwsA(isA<LlmException>()
            .having((e) => e.message, 'message', contains('token limit'))),
      );
    });
  });
}
