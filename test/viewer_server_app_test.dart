import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:mod_repo_scraper/viewer/server_app.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:test/test.dart';

/// Requests under `/api` are answered by the API alone. The API's own "not
/// found" answers carry a reason, and the static files must not replace it
/// with a plain "Not Found".
void main() {
  late Directory tmp;
  late Handler handler;

  Future<Response> get(String path) =>
      Future.sync(() => handler(Request('GET', Uri.parse('http://localhost$path'))));

  Future<Map<String, dynamic>> jsonOf(Response res) async =>
      jsonDecode(await res.readAsString()) as Map<String, dynamic>;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('server_app_');
    final web = Directory(p.join(tmp.path, 'web'))..createSync();
    File(p.join(web.path, 'index.html')).writeAsStringSync('viewer');
    handler = buildServerHandler(
      viewer: ViewerApi(DataAccess(
        dataDir: p.join(tmp.path, 'qb_data'),
        outputsDir: p.join(tmp.path, 'outputs'),
        rootDir: tmp.path,
      )),
      managerHandler: (_) => Response.ok('manager'),
      staticHandler: createStaticHandler(web.path, defaultDocument: 'index.html'),
    );
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test("an API route's 404 keeps its reason", () async {
    final res = await get('/api/files/no-such-file');
    expect(res.statusCode, 404);
    expect(res.headers['content-type'], contains('json'));
    expect((await jsonOf(res))['error'], 'Unknown file id "no-such-file".');
  });

  test('an address under /api that names no route is a JSON 404', () async {
    for (final path in ['/api/no-such-route', '/api', '/api/index.html']) {
      final res = await get(path);
      expect(res.statusCode, 404, reason: path);
      expect(res.headers['content-type'], contains('json'), reason: path);
      expect((await jsonOf(res))['error'], contains('Page not found'),
          reason: path);
    }
  });

  test('other addresses still reach the static files', () async {
    expect(await (await get('/')).readAsString(), 'viewer');
    expect((await get('/apix/index.html')).statusCode, 404);
  });

  test('the manager routes are still dispatched first', () async {
    expect(await (await get('/api/manager/status')).readAsString(), 'manager');
  });
}
