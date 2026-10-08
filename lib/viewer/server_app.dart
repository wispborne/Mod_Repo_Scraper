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
