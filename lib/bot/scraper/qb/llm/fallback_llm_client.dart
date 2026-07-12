import 'dart:io';

import 'package:logging/logging.dart';

import 'llm_client.dart';

/// An [LlmClient] that tries a primary provider first and falls to a second
/// only when the primary can't be reached.
///
/// Built for an opportunistic setup: the primary is a local model on a PC that
/// is often asleep, and the fallback is a cloud endpoint (OpenRouter) that
/// quietly takes over when the PC is off.
///
/// The rule is narrow on purpose:
/// - A **connection failure** on the primary (the server isn't there —
///   connection refused, host unreachable, DNS failure) switches to the
///   fallback. The switch **latches for the rest of the run**: once the primary
///   is found unreachable, every following call goes straight to the fallback,
///   so a sleeping PC isn't knocked on for every post. A fresh run (a new
///   instance) tries the primary again.
/// - Anything else — a timeout, a non-success status, an unparseable answer —
///   is **rethrown** so the caller's existing retry-then-rule-based path runs.
///   A timeout counts as "reachable but slow", not a connection failure.
///
/// No retry logic lives here: [PostExtractor] already retries above the client.
class FallbackLlmClient implements LlmClient {
  final LlmClient _primary;
  final LlmClient _fallback;
  final Logger _log;

  /// A one-way, per-run latch. Once the primary is found unreachable it stays
  /// false for the life of this instance, so later calls skip it entirely.
  bool _primaryReachable = true;

  /// Describes the two providers for the one-time switch log line.
  final String _primaryLabel;
  final String _fallbackLabel;

  FallbackLlmClient({
    required LlmClient primary,
    required LlmClient fallback,
    String primaryLabel = 'primary',
    String fallbackLabel = 'fallback',
    Logger? logger,
  })  : _primary = primary,
        _fallback = fallback,
        _primaryLabel = primaryLabel,
        _fallbackLabel = fallbackLabel,
        _log = logger ?? Logger('FallbackLlmClient');

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    // Primary already known to be down this run: go straight to the fallback.
    if (!_primaryReachable) {
      return _fallback.complete(request);
    }

    try {
      return await _primary.complete(request);
    } on LlmException catch (e) {
      if (_isConnectionFailure(e)) {
        // Log only on the flip. Several calls can be in flight at once (the
        // pipeline overlaps a few topics), so they all reach here in the first
        // batch. Reading and setting the latch is synchronous — no `await`
        // between — so on the event loop the first call flips it and logs, and
        // the rest see it already closed and stay quiet.
        if (_primaryReachable) {
          _primaryReachable = false;
          _log.warning(
              'Primary LLM ($_primaryLabel) not reachable ($e); switching to '
              'the fallback ($_fallbackLabel) for the rest of this run.');
        }
        return _fallback.complete(request);
      }
      // Reachable but this call failed (timeout, bad status, bad JSON): let the
      // caller's retry-then-rule-based path handle it. Do not use the fallback.
      rethrow;
    }
  }

  /// True only for "the server isn't there" errors. [OpenAiCompatibleClient]
  /// wraps network errors as `LlmException('Request failed', cause)`, so a
  /// connection refused / host unreachable / DNS failure arrives as a
  /// [SocketException] in [LlmException.cause]. (package:http throws a
  /// `_ClientSocketException` for a refused connection, which is itself a
  /// [SocketException], so this catches it.) A [TimeoutException] arrives the
  /// same way but is deliberately NOT treated as a connection failure — the
  /// server answered the socket, it is just slow. A non-success HTTP status has
  /// no cause at all (a different [LlmException]), so it is not caught here.
  static bool _isConnectionFailure(LlmException e) => e.cause is SocketException;
}
