import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'api.dart';

const String managerPathPrefix = 'api/manager';
const String apiPathPrefix = 'api';

/// Combines the manager, read-only viewer API and static frontend.
///
/// Requests under `/api` never reach the static files. A cascade would pass
/// the API's own 404 answers ("Unknown file id", "No group 3") on to the
/// static handler, and the browser would only see "Not Found". For the same
/// reason the manager routes are dispatched directly rather than mounted.
///
/// [managerHandler] may serve jobs or report that the manager is off.
Handler buildServerHandler({
  required ViewerApi viewer,
  required Handler managerHandler,
  Handler? staticHandler,
}) {
  final apiRouter = Router(notFoundHandler: _noApiRoute)
    ..mount('/$apiPathPrefix', viewer.router);

  return (Request request) {
    final path = request.url.path;
    if (_isUnder(path, managerPathPrefix)) {
      // The manager routes are relative to this prefix.
      return managerHandler(request.change(path: managerPathPrefix));
    }
    if (_isUnder(path, apiPathPrefix) || staticHandler == null) {
      return apiRouter.call(request);
    }
    return staticHandler(request);
  };
}

bool _isUnder(String path, String prefix) =>
    path == prefix || path.startsWith('$prefix/');

/// The answer for an address under `/api` that names no route, as JSON so
/// the page can show the reason like any other API error.
Response _noApiRoute(Request request) => Response.notFound(
      jsonEncode({'error': 'Page not found: /${request.url.path}.'}),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// The folders the old and new viewers were served from while both existed.
const formerViewerPrefixes = ['v1', 'v2'];

/// Serves [viewer] at `/`. Redirects `/v1/...` and `/v2/...` to the same
/// address without the prefix. Bookmarks from when both viewers were served
/// still work because the browser keeps the `#/...` part through a redirect.
Handler withFormerViewerAddresses(Handler viewer) {
  return (Request request) {
    final path = request.url.path;
    for (final prefix in formerViewerPrefixes) {
      if (path == prefix || path.startsWith('$prefix/')) {
        final rest = path == prefix ? '' : path.substring(prefix.length + 1);
        final query = request.url.hasQuery ? '?${request.url.query}' : '';
        return Response.found('/$rest$query');
      }
    }
    return viewer(request);
  };
}
