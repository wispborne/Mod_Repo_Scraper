import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';

/// An HTTP client wrapper that records all responses to disk on first run,
/// then replays them on subsequent runs. Useful for development/debugging
/// to avoid hitting API rate limits.
///
/// Recording writes each response to the file as it arrives (one JSON object
/// per line), rather than holding the whole run in memory and writing at the
/// end. A run that is interrupted or crashes therefore keeps the responses it
/// had already fetched, and a long run doesn't hold every response body in
/// memory.
///
/// Files written by the older "one big JSON list" format are still read.
class CachingClient extends BaseClient {
  final Client? _inner;

  /// Recorded responses, in order. Only populated when replaying, or when
  /// recording without a [_recordPath] (in which case they are held until
  /// [saveToFile]).
  final List<Map<String, dynamic>> _cache;
  final bool isReplaying;
  int _replayIndex = 0;

  /// Where responses are streamed as they arrive, when recording.
  final String? _recordPath;
  IOSink? _sink;
  int _recordedCount = 0;

  /// Creates a recording client that delegates to [inner] and records responses.
  ///
  /// When [recordPath] is given, each response is appended to that file as it
  /// arrives. Any file already there is replaced when the first response is
  /// recorded, so a run always writes a fresh cache.
  CachingClient(Client inner, {String? recordPath})
      : _inner = inner,
        _cache = [],
        _recordPath = recordPath,
        isReplaying = false;

  CachingClient._replaying(this._cache)
      : _inner = null,
        _recordPath = null,
        isReplaying = true;

  /// Creates a replaying client from a cache file.
  static Future<CachingClient> fromFile(String path) async {
    final json = await File(path).readAsString();
    return CachingClient._replaying(_parseCacheFile(json));
  }

  /// Reads either format: one JSON object per line (written as a run goes), or
  /// a single JSON list (the older end-of-run format).
  ///
  /// A run killed mid-write can leave a half-finished last line; unparseable
  /// lines are skipped rather than failing the whole cache.
  static List<Map<String, dynamic>> _parseCacheFile(String contents) {
    final trimmed = contents.trimLeft();
    if (trimmed.startsWith('[')) {
      return (jsonDecode(trimmed) as List).cast<Map<String, dynamic>>();
    }

    final entries = <Map<String, dynamic>>[];
    for (final line in const LineSplitter().convert(contents)) {
      if (line.trim().isEmpty) continue;
      try {
        entries.add(jsonDecode(line) as Map<String, dynamic>);
      } catch (_) {
        // Truncated final line from an interrupted run; the rest is still good.
      }
    }
    return entries;
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

    final entry = {
      'method': request.method,
      'url': request.url.toString(),
      'statusCode': response.statusCode,
      'body': body,
      'headers': response.headers,
    };
    await _record(entry);

    // Return a new StreamedResponse with the same body bytes.
    return StreamedResponse(
      ByteStream.fromBytes(bytes),
      response.statusCode,
      headers: response.headers,
      request: request,
      contentLength: bytes.length,
    );
  }

  /// Writes one response to the file, or holds it in memory when no record path
  /// was given.
  Future<void> _record(Map<String, dynamic> entry) async {
    final path = _recordPath;
    if (path == null) {
      _cache.add(entry);
      return;
    }

    // The first response of the run replaces whatever was there before; a later
    // one adds to it. Opening for writing truncates, so a response arriving
    // after a save must reopen in append mode or it would wipe the run's cache.
    final sink = _sink ??= File(path)
        .openWrite(mode: _recordedCount == 0 ? FileMode.write : FileMode.append);
    sink.writeln(jsonEncode(entry));
    // Flush per response so an interrupted run keeps what it fetched. The wait
    // is nothing next to the network call that produced this response.
    await sink.flush();
    _recordedCount++;
  }

  /// Finishes the recording: flushes and closes the file being written as the
  /// run went along. When no record path was given, writes everything held in
  /// memory to [path] instead (the older behaviour).
  Future<void> saveToFile(String path) async {
    final sink = _sink;
    if (sink != null) {
      await sink.flush();
      await sink.close();
      _sink = null;
      return;
    }

    if (_recordPath != null) {
      // Recording was on but nothing was fetched (e.g. everything was skipped).
      // Leave any existing file alone rather than replacing it with an empty one.
      return;
    }

    const encoder = JsonEncoder.withIndent('  ');
    await File(path).writeAsString(encoder.convert(_cache));
  }

  /// How many responses have been recorded this run.
  int get recordedCount => _recordPath == null ? _cache.length : _recordedCount;

  /// Releases the cache file if [saveToFile] wasn't called. Every response was
  /// already flushed as it arrived, so nothing is lost here.
  @override
  void close() {
    final sink = _sink;
    _sink = null;
    unawaited(sink?.close());
    super.close();
  }
}
