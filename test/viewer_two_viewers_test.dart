import 'dart:io';

import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:mod_repo_scraper/viewer/server_app.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:test/test.dart';

/// The server serves both the old viewer (`web/`) and new viewer (`web2/`).
/// `--ui` selects which viewer is at `/`.
void main() {
  late Directory tmp;
  late Handler oldViewer;
  late Handler newViewer;
  late ViewerApi api;

  Handler serve(Handler root, String prefix, Handler other) =>
      buildServerHandler(
        viewer: api,
        managerHandler: (_) => Response.ok('manager'),
        staticHandler:
            twoViewers(root: root, otherPrefix: prefix, other: other),
      );

  Future<Response> get(Handler handler, String path) =>
      Future.sync(() => handler(Request('GET', Uri.parse('http://localhost$path'))));

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('two_viewers_');
    for (final (name, text) in [('web', 'old'), ('web2', 'new')]) {
      final dir = Directory(p.join(tmp.path, name))..createSync();
      File(p.join(dir.path, 'index.html')).writeAsStringSync(text);
      File(p.join(dir.path, 'style.css')).writeAsStringSync('$text css');
    }
    oldViewer = createStaticHandler(p.join(tmp.path, 'web'),
        defaultDocument: 'index.html');
    newViewer = createStaticHandler(p.join(tmp.path, 'web2'),
        defaultDocument: 'index.html');
    api = ViewerApi(DataAccess(
      dataDir: p.join(tmp.path, 'qb_data'),
      outputsDir: p.join(tmp.path, 'outputs'),
      rootDir: tmp.path,
    ));
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('by default the old viewer is at / and the new one at /v2/', () async {
    final handler = serve(oldViewer, 'v2', newViewer);
    expect(await (await get(handler, '/')).readAsString(), 'old');
    expect(await (await get(handler, '/v2/')).readAsString(), 'new');
    expect(await (await get(handler, '/v2/style.css')).readAsString(),
        'new css');
    expect(await (await get(handler, '/style.css')).readAsString(), 'old css');
  });

  test('with --ui v2 the new viewer is at / and the old one at /v1/',
      () async {
    final handler = serve(newViewer, 'v1', oldViewer);
    expect(await (await get(handler, '/')).readAsString(), 'new');
    expect(await (await get(handler, '/v1/')).readAsString(), 'old');
    expect(await (await get(handler, '/v1/style.css')).readAsString(),
        'old css');
  });

  test('the address without a slash is sent to the one with it', () async {
    final handler = serve(oldViewer, 'v2', newViewer);
    final res = await get(handler, '/v2');
    expect(res.statusCode, 302);
    expect(res.headers['location'], '/v2/');

    final withQuery = await get(handler, '/v2?x=1');
    expect(withQuery.headers['location'], '/v2/?x=1');
  });

  test('a name that only starts with the prefix is not the other viewer',
      () async {
    final handler = serve(oldViewer, 'v2', newViewer);
    final res = await get(handler, '/v2x/style.css');
    expect(res.statusCode, 404);
  });

  test('the API and manager routes still come first', () async {
    final handler = serve(oldViewer, 'v2', newViewer);
    final manager = await get(handler, '/api/manager/status');
    expect(await manager.readAsString(), 'manager');
    final version = await get(handler, '/api/version');
    expect(version.statusCode, 200);
    expect(version.headers['content-type'], contains('json'));
  });
}
