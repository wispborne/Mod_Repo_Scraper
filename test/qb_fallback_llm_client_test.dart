import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:mod_repo_scraper/bot/common.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/fallback_llm_client.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/llm_client.dart';
import 'package:test/test.dart';

/// A scripted [LlmClient] that records how many times it was called. Each call
/// returns (or throws) the next behavior; the last behavior repeats.
class _FakeLlmClient implements LlmClient {
  final List<Object> behaviors; // LlmResponse to return, or Object to throw
  int callCount = 0;

  _FakeLlmClient(this.behaviors);

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    final i = callCount < behaviors.length ? callCount : behaviors.length - 1;
    callCount++;
    final behavior = behaviors[i];
    if (behavior is LlmResponse) return behavior;
    throw behavior;
  }
}

LlmResponse _ok(String content) => LlmResponse(content: content, totalTokens: 1);

LlmRequest _req() =>
    const LlmRequest(systemPrompt: 'sys', userPrompt: 'user');

/// A connection failure: [OpenAiCompatibleClient] wraps a [SocketException] in
/// [LlmException.cause] when the server can't be reached.
LlmException _connectionFailure() => LlmException(
    'Request failed', const SocketException('Connection refused'));

void main() {
  group('FallbackLlmClient', () {
    test('primary succeeds: fallback is never called (4.1)', () async {
      final primary = _FakeLlmClient([_ok('primary')]);
      final fallback = _FakeLlmClient([_ok('fallback')]);
      final client = FallbackLlmClient(primary: primary, fallback: fallback);

      final res = await client.complete(_req());

      expect(res.content, 'primary');
      expect(primary.callCount, 1);
      expect(fallback.callCount, 0);
    });

    test('connection failure: falls back and returns the fallback answer (4.2)',
        () async {
      final primary = _FakeLlmClient([_connectionFailure()]);
      final fallback = _FakeLlmClient([_ok('fallback')]);
      final client = FallbackLlmClient(primary: primary, fallback: fallback);

      final res = await client.complete(_req());

      expect(res.content, 'fallback');
      expect(primary.callCount, 1);
      expect(fallback.callCount, 1);
    });

    test('after a connection failure, later calls skip the primary (4.3)',
        () async {
      // Primary would succeed on a second call, but the latch must stop us from
      // ever calling it again this run.
      final primary = _FakeLlmClient([_connectionFailure(), _ok('primary-2')]);
      final fallback = _FakeLlmClient([_ok('fb-1'), _ok('fb-2')]);
      final client = FallbackLlmClient(primary: primary, fallback: fallback);

      final first = await client.complete(_req());
      final second = await client.complete(_req());

      expect(first.content, 'fb-1');
      expect(second.content, 'fb-2');
      expect(primary.callCount, 1); // never called again after the latch closed
      expect(fallback.callCount, 2);
    });

    test('concurrent first batch logs the switch exactly once', () async {
      // Several topics are in flight at once, all hitting a dead primary before
      // any failure comes back. The latch must still log only once.
      final primary = _FakeLlmClient([_connectionFailure()]);
      final fallback = _FakeLlmClient([_ok('fb')]);
      final log = Logger('FallbackLlmClientTest.concurrent');
      var switches = 0;
      final sub = log.onRecord.listen((r) {
        if (r.level == Level.WARNING && r.message.contains('switching')) {
          switches++;
        }
      });
      final client = FallbackLlmClient(
          primary: primary, fallback: fallback, logger: log);

      // Fire 4 calls concurrently: all pass the reachable-gate before the first
      // failure resumes into the catch block.
      await Future.wait([
        client.complete(_req()),
        client.complete(_req()),
        client.complete(_req()),
        client.complete(_req()),
      ]);
      await sub.cancel();

      expect(switches, 1, reason: 'the switch should be logged exactly once');
      // All four still hit the primary once each (they were already in flight),
      // then fell to the fallback.
      expect(primary.callCount, 4);
      expect(fallback.callCount, 4);
    });

    test('timeout is NOT a connection failure: rethrows, no fallback (4.4)',
        () async {
      final primary = _FakeLlmClient(
          [LlmException('Request failed', TimeoutException('slow'))]);
      final fallback = _FakeLlmClient([_ok('fallback')]);
      final client = FallbackLlmClient(primary: primary, fallback: fallback);

      await expectLater(client.complete(_req()), throwsA(isA<LlmException>()));
      expect(fallback.callCount, 0);

      // The latch is still open: a later reachable call still tries the primary.
      final primary2 = _FakeLlmClient([_ok('primary')]);
      final fallback2 = _FakeLlmClient([_ok('fallback')]);
      final client2 =
          FallbackLlmClient(primary: primary2, fallback: fallback2);
      await client2.complete(_req());
      expect(primary2.callCount, 1);
      expect(fallback2.callCount, 0);
    });

    test('status-code error (no cause): rethrows, no fallback (4.5)', () async {
      final primary = _FakeLlmClient([LlmException('Error response (status 500)')]);
      final fallback = _FakeLlmClient([_ok('fallback')]);
      final client = FallbackLlmClient(primary: primary, fallback: fallback);

      await expectLater(client.complete(_req()), throwsA(isA<LlmException>()));
      expect(fallback.callCount, 0);
    });
  });

  group('BotConfig.llmFallbackEnabled (4.6)', () {
    BotConfig cfg({String? url, String? model}) => BotConfig(
          lessScraping: false,
          enableForums: false,
          enableDiscord: false,
          enableNexus: false,
          logLevel: 'INFO',
          llmFallbackBaseUrl: url,
          llmFallbackModel: model,
        );

    test('false when both blank', () {
      expect(cfg().llmFallbackEnabled, isFalse);
    });
    test('false when only the URL is set', () {
      expect(cfg(url: 'https://x/v1/chat/completions').llmFallbackEnabled,
          isFalse);
    });
    test('false when only the model is set', () {
      expect(cfg(model: 'deepseek/deepseek-chat').llmFallbackEnabled, isFalse);
    });
    test('false when a field is whitespace only', () {
      expect(cfg(url: '   ', model: 'm').llmFallbackEnabled, isFalse);
    });
    test('true when both are set', () {
      expect(
          cfg(url: 'https://x/v1/chat/completions', model: 'deepseek/deepseek-chat')
              .llmFallbackEnabled,
          isTrue);
    });
  });
}
