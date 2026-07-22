import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'api.dart';

/// Where the management routes live.
const String managerPathPrefix = 'api/manager';

/// Puts the server's parts together: the manager routes, the read-only viewer
/// API, and the static frontend.
///
/// The manager subtree is picked off before anything else. That is on purpose
/// rather than a mounted route: a mounted handler that answers 404 — "no run by
/// that name" — would be read as "no such route" and fall through to the viewer
/// and then to the static files, so the caller would get a bare "Not Found"
/// instead of the reason. Handling the subtree here keeps every manager answer,
/// including its 404s, exactly as the manager wrote it.
///
/// [managerHandler] is either the real management API or the "the manager is
/// off" answer — the viewer works the same either way.
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
      // Hand on the path with the prefix taken off, so the manager's own routes
      // read as `/status`, `/runs/<id>`, and so on.
      return managerHandler(request.change(path: managerPathPrefix));
    }
    return rest(request);
  };
}
