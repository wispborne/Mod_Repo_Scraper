import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'api.dart';

const String managerPathPrefix = 'api/manager';

/// Combines the manager, read-only viewer API and static frontend.
///
/// Dispatch manager requests directly: a mounted handler's 404 would fall
/// through the cascade and lose the manager's error message.
///
/// [managerHandler] may serve jobs or report that the manager is off.
Handler buildServerHandler({
  required ViewerApi viewer,
  required Handler managerHandler,
  Handler? staticHandler,
}) {
  final apiRouter = Router()..mount('/api', viewer.router);
  final rest = staticHandler == null
      ? Cascade().add(apiRouter.call).handler
      : Cascade().add(apiRouter.call).add(staticHandler).handler;

  return (Request request) {
    final path = request.url.path;
    if (path == managerPathPrefix || path.startsWith('$managerPathPrefix/')) {
      // The manager routes are relative to this prefix.
      return managerHandler(request.change(path: managerPathPrefix));
    }
    return rest(request);
  };
}

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
