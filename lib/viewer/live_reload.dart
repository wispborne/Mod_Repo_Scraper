import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';

/// Reloads open pages when a server's own files change, or when the server
/// itself was restarted.
///
/// Every HTML page the server sends gets a few lines of script added before
/// `</body>`. That script asks [_path] whether anything has changed, and the
/// server holds the question open until something does or [_wait] runs out.
/// When the answer is a new value, the page reloads itself. Only a local
/// server started with reloading on adds the script — the files on disk are
/// never touched, so it can never be published.
///
/// The value starts with the moment this server started, so a page open
/// across a restart (`bin/dev_servers.dart` restarts both servers when Dart
/// code changes) reloads once the new server answers.
///
/// Every answer also tells the browser not to keep a copy. Both sites are
/// plain ES modules, and a browser holding on to an old `lib.js` while loading
/// a new view that imports something from it fails to draw the page at all.
class LiveReload {
  LiveReload._();

  static const _path = '__reload';
  static const _wait = Duration(seconds: 25);

  /// Saving one file in an editor can fire several changes in a row. They
  /// are counted as one once this long has passed with nothing new.
  static const _settle = Duration(milliseconds: 150);

  final _started = DateTime.now().microsecondsSinceEpoch;
  var _changes = 0;
  final _changed = StreamController<void>.broadcast();
  Timer? _pending;

  String get _current => '$_started.$_changes';

  /// Watches [dir] and everything under it.
  static LiveReload watch(Directory dir) {
    final reload = LiveReload._();
    dir.watch(recursive: true).listen((_) {
      reload._pending?.cancel();
      reload._pending = Timer(_settle, () {
        reload._changes++;
        reload._changed.add(null);
      });
    });
    return reload;
  }

  /// Answers `/__reload?since=X` and adds the script to every HTML page.
  Middleware get middleware => (Handler inner) => (Request request) async {
        if (request.url.path == _path) return _answer(request);
        final response = await inner(request);
        final type = response.headers['content-type'] ?? '';
        if (response.statusCode != 200 || !type.startsWith('text/html')) {
          return response.change(headers: _noStore);
        }
        final html = await response.readAsString();
        final at = html.lastIndexOf('</body>');
        final withScript = at < 0
            ? '$html$_script'
            : '${html.substring(0, at)}$_script${html.substring(at)}';
        return Response.ok(withScript,
            headers: {'content-type': type, ..._noStore});
      };

  /// The current value: at once when it is not X, otherwise when a file
  /// changes or [_wait] runs out.
  Future<Response> _answer(Request request) async {
    if (request.url.queryParameters['since'] == _current) {
      await _changed.stream.first.timeout(_wait, onTimeout: () {});
    }
    return Response.ok(_current, headers: _noStore);
  }

  static const _noStore = {'cache-control': 'no-store'};

  /// Waits on the server, reloads when the value moves, and tries again a
  /// few seconds later when the server is not there (stopped or restarting).
  static const _script = '''
<script>
(async () => {
  let seen = null;
  for (;;) {
    try {
      const res = await fetch('/$_path?since=' + encodeURIComponent(seen ?? ''), { cache: 'no-store' });
      if (!res.ok) throw new Error(res.status);
      const now = await res.text();
      if (seen !== null && now !== seen) { location.reload(); return; }
      seen = now;
    } catch (_) {
      await new Promise((done) => setTimeout(done, 1000));
    }
  }
})();
</script>
''';
}
