import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';

/// An HTTP client wrapper that records all responses to disk on first run,
/// then replays them on subsequent runs. Useful for development/debugging
/// to avoid hitting API rate limits.
class CachingClient extends BaseClient {
  final Client? _inner;
  final List<Map<String, dynamic>> _cache;
  final bool isReplaying;
  int _replayIndex = 0;

  /// Creates a recording client that delegates to [inner] and records responses.
  CachingClient(Client inner)
      : _inner = inner,
        _cache = [],
        isReplaying = false;

  CachingClient._replaying(this._cache)
      : _inner = null,
        isReplaying = true;

  /// Creates a replaying client from a cache file.
  static Future<CachingClient> fromFile(String path) async {
    final file = File(path);
    final json = await file.readAsString();
    final list = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    return CachingClient._replaying(list);
  }

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (isReplaying) {
      return _replay(request);
    } else {
      return _recordAndForward(request);
    }
  }

  Future<StreamedResponse> _replay(BaseRequest request) async {
    final key = '${request.method} ${request.url}';

    // Search from current index forward to handle repeated URLs in order.
    for (var i = _replayIndex; i < _cache.length; i++) {
      final entry = _cache[i];
      final cachedKey = '${entry['method']} ${entry['url']}';
      if (cachedKey == key) {
        _replayIndex = i + 1;
        return _entryToResponse(entry, request);
      }
    }

    // If not found from current index, search from beginning (shouldn't
    // normally happen, but handles out-of-order access gracefully).
    for (var i = 0; i < _replayIndex && i < _cache.length; i++) {
      final entry = _cache[i];
      final cachedKey = '${entry['method']} ${entry['url']}';
      if (cachedKey == key) {
        _replayIndex = i + 1;
        return _entryToResponse(entry, request);
      }
    }

    throw StateError('No cached response found for $key');
  }

  StreamedResponse _entryToResponse(
      Map<String, dynamic> entry, BaseRequest request) {
    final body = entry['body'] as String;
    final statusCode = entry['statusCode'] as int;
    final headers = (entry['headers'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v.toString())) ??
        {};

    final bytes = utf8.encode(body);
    return StreamedResponse(
      ByteStream.fromBytes(bytes),
      statusCode,
      headers: headers,
      request: request,
      contentLength: bytes.length,
    );
  }

  Future<StreamedResponse> _recordAndForward(BaseRequest request) async {
    final response = await _inner!.send(request);

    // Read the response body so we can cache it and still return it.
    final bytes = await response.stream.toBytes();
    final body = utf8.decode(bytes);

    _cache.add({
      'method': request.method,
      'url': request.url.toString(),
      'statusCode': response.statusCode,
      'body': body,
      'headers': response.headers,
    });

    // Return a new StreamedResponse with the same body bytes.
    return StreamedResponse(
      ByteStream.fromBytes(bytes),
      response.statusCode,
      headers: response.headers,
      request: request,
      contentLength: bytes.length,
    );
  }

  /// Saves the recorded cache to a JSON file.
  Future<void> saveToFile(String path) async {
    final file = File(path);
    final encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(_cache));
  }
}
