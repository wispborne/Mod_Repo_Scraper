import 'package:http/http.dart' as http;

class ThrottledClient {
  final http.Client _inner;
  final int delayMs;
  DateTime? _lastRequestTime;
  Future<void>? _gate;

  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  final Duration timeout;

  ThrottledClient({http.Client? client, this.delayMs = 1500, this.timeout = const Duration(seconds: 60)})
      : _inner = client ?? http.Client();

  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    await _enforceDelay();
    final merged = {
      'User-Agent': _userAgent,
      ...?headers,
    };
    return _inner.get(url, headers: merged).timeout(timeout);
  }

  Future<http.Response> post(Uri url,
      {Map<String, String>? headers, Object? body}) async {
    await _enforceDelay();
    final merged = {
      'User-Agent': _userAgent,
      ...?headers,
    };
    return _inner.post(url, headers: merged, body: body).timeout(timeout);
  }

  /// Chains each caller off the previous one so concurrent `get()` calls can't
  /// observe the same `_lastRequestTime` and fire simultaneously.
  Future<void> _enforceDelay() {
    final prev = _gate ?? Future.value();
    final next = prev.then((_) async {
      if (_lastRequestTime != null) {
        final elapsed =
            DateTime.now().difference(_lastRequestTime!).inMilliseconds;
        if (elapsed < delayMs) {
          await Future.delayed(Duration(milliseconds: delayMs - elapsed));
        }
      }
      _lastRequestTime = DateTime.now();
    });
    _gate = next;
    return next;
  }

  void close() => _inner.close();
}
