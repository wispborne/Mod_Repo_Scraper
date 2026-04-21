import 'dart:async';

import 'package:http/http.dart' as http;

/// Synchronous, cheap classifier: returns `true` when the URL's extension or
/// host is an obvious indicator of a mod archive download.
bool isLikelyModDownloadUrl(String url) {
  if (url.isEmpty) return false;
  return url.contains('drive.google.com') ||
      url.contains('mega.nz') ||
      url.contains('mediafire') ||
      url.contains('.zip') ||
      url.contains('.rar') ||
      url.contains('.7z');
}

/// Runs [isLikelyModDownloadUrl] first; if that returns `true`, short-circuits
/// without any I/O. Otherwise issues a HEAD (falling back to GET when HEAD is
/// unsupported) and inspects `Content-Disposition` and `Content-Type`. Any
/// error or timeout yields `false`.
Future<bool> isDownloadableUrl(
  String url, {
  Duration timeout = const Duration(seconds: 10),
  http.Client? client,
}) async {
  if (isLikelyModDownloadUrl(url)) return true;

  final uri = Uri.tryParse(url);
  if (uri == null) return false;

  final ownsClient = client == null;
  final c = client ?? http.Client();
  try {
    return await _probe(c, uri).timeout(timeout, onTimeout: () => false);
  } catch (_) {
    return false;
  } finally {
    if (ownsClient) c.close();
  }
}

Future<bool> _probe(http.Client client, Uri uri) async {
  // Try HEAD first.
  try {
    final headResp = await client.head(uri);
    if (headResp.statusCode >= 200 && headResp.statusCode < 400) {
      final result = _classifyHeaders(
        headResp.headers['content-disposition'],
        headResp.headers['content-type'],
      );
      if (result != null) return result;
      // If headers are inconclusive on HEAD, fall through to GET.
    } else if (headResp.statusCode == 405 || headResp.statusCode == 501) {
      // HEAD not allowed — fall back to GET.
    } else {
      return false;
    }
  } catch (_) {
    // Fall through to GET.
  }

  // GET fallback. We only need headers; the `http` package reads the body
  // eagerly, so to avoid pulling a large archive we use a streamed request
  // and cancel after headers arrive.
  final req = http.Request('GET', uri);
  final streamed = await client.send(req);
  try {
    return _classifyHeaders(
          streamed.headers['content-disposition'],
          streamed.headers['content-type'],
        ) ??
        false;
  } finally {
    // Drop the body without buffering it.
    unawaited(streamed.stream.drain<void>().catchError((_) {}));
  }
}

bool? _classifyHeaders(String? contentDisposition, String? contentType) {
  final cd = contentDisposition?.toLowerCase();
  if (cd != null && cd.trimLeft().startsWith('attachment')) return true;

  final ct = contentType?.toLowerCase();
  if (ct != null) {
    // MIME can include charset etc.; compare the type/subtype prefix.
    final mime = ct.split(';').first.trim();
    if (mime == 'application/octet-stream' || mime == 'application/zip') {
      return true;
    }
    if (mime.startsWith('text/') || mime == 'application/xhtml+xml') {
      return false;
    }
  }
  return null;
}
