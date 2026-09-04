import 'package:logging/logging.dart';

import 'llm_client.dart';

/// An [LlmClient] that tries a primary provider first and falls to a second
/// when the primary fails.
///
/// Built for an opportunistic setup: the primary is a local model on a PC that
/// is often asleep, and the fallback is a cloud endpoint that quietly takes over
/// when the PC is off.
///
/// **What decides the switch is cost, not which failure happened.** Any
/// [LlmException] from the primary switches to the fallback and **latches for
/// the rest of the run** — a refused connection, a timeout, a non-success
/// status, an answer envelope that can't be read. Once the primary has failed
/// once it isn't knocked on again this run, so a sleeping or broken server
/// doesn't cost a connection attempt (or a full timeout) per topic. A fresh run
/// builds a new instance and tries the primary again.
///
/// The one thing that stops the switch is money. When [switchAllowed] is false —
/// the primary is free and the fallback is paid, and `llm_fallback_free_to_paid`
/// says not to — the fallback is **never** called: every primary failure is
/// rethrown and the caller's retry-then-rule-based path runs, exactly as it
/// would with no fallback configured. Whether an endpoint is free or paid is
/// worked out in `endpoint_cost.dart`; the comparison happens where the clients
/// are built, and this class is handed the answer.
///
/// The extraction JSON is parsed **above** this client, in `PostExtractor`, so
/// a model that answers with unusable JSON never reaches this rule — that keeps
/// its retry-at-a-higher-temperature path. What arrives here is only what
/// `OpenAiCompatibleClient` itself throws.
///
/// No retry logic lives here: [PostExtractor] already retries above the client.
class FallbackLlmClient implements LlmClient {
  final LlmClient _primary;
  final LlmClient _fallback;
  final Logger _log;

  /// False when switching would start spending money the primary wasn't. The
  /// fallback is then never called; failures are rethrown.
  final bool _switchAllowed;

  /// A one-way, per-run latch. Once the primary has failed it stays false for
  /// the life of this instance, so later calls skip it entirely.
  bool _primaryUsable = true;

  /// Describes the two providers for the one-time switch log line.
  final String _primaryLabel;
  final String _fallbackLabel;

  FallbackLlmClient({
    required LlmClient primary,
    required LlmClient fallback,
    String primaryLabel = 'primary',
    String fallbackLabel = 'fallback',
    bool switchAllowed = true,
    Logger? logger,
  })  : _primary = primary,
        _fallback = fallback,
        _primaryLabel = primaryLabel,
        _fallbackLabel = fallbackLabel,
        _switchAllowed = switchAllowed,
        _log = logger ?? Logger('FallbackLlmClient') {
    if (!_switchAllowed) {
      // Said now rather than on the first failure, so it shows up even on a run
      // where the primary never fails. A fallback that can never fire is worth
      // knowing about before the moment it would have been needed.
      _log.warning(
          'Fallback LLM ($_fallbackLabel) is configured but will not be used: '
          'it charges per token and the primary ($_primaryLabel) does not, so '
          'switching would turn a free run into a paid one. Set '
          'llm_fallback_free_to_paid = true to allow it.');
    }
  }

  @override
  Future<LlmResponse> complete(LlmRequest request) async {
    if (!_switchAllowed) return _primary.complete(request);

    // Primary already known to have failed this run: go straight to the
    // fallback.
    if (!_primaryUsable) return _fallback.complete(request);

    try {
      return await _primary.complete(request);
    } on LlmException catch (e) {
      // Log only on the flip. Several calls can be in flight at once (the
      // pipeline overlaps a few topics), so they all reach here in the first
      // batch. Reading and setting the latch is synchronous — no `await`
      // between — so on the event loop the first call flips it and logs, and
      // the rest see it already closed and stay quiet.
      if (_primaryUsable) {
        _primaryUsable = false;
        _log.warning('Primary LLM ($_primaryLabel) failed ($e); switching to '
            'the fallback ($_fallbackLabel) for the rest of this run.');
      }
      return _fallback.complete(request);
    }
  }
}
