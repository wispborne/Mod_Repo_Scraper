import 'dart:io';

import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:mod_repo_scraper/viewer/server_app.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:test/test.dart';

/// The viewer is served at `/`. Previously, two viewers were served at `/`
/// and at `/v1/` or `/v2/`. Those addresses now lead to the same page at `/`.
void main() {
  late Directory tmp;
  late Handler handler;

  Future<Response> get(String path) =>
      Future.sync(() => handler(Request('GET', Uri.parse('http://localhost$path'))));

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('former_addresses_');
    final web = Directory(p.join(tmp.path, 'web'))..createSync();
    File(p.join(web.path, 'index.html')).writeAsStringSync('viewer');
    File(p.join(web.path, 'style.css')).writeAsStringSync('css');
    handler = buildServerHandler(
      viewer: ViewerApi(DataAccess(
        dataDir: p.join(tmp.path, 'qb_data'),
        outputsDir: p.join(tmp.path, 'outputs'),
        rootDir: tmp.path,
      )),
      managerHandler: (_) => Response.ok('manager'),
      staticHandler: withFormerViewerAddresses(
          createStaticHandler(web.path, defaultDocument: 'index.html')),
    );
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('the viewer is at /', () async {
    expect(await (await get('/')).readAsString(), 'viewer');
    expect(await (await get('/style.css')).readAsString(), 'css');
  });

  test('/v1/ and /v2/ addresses lead to the same address at /', () async {
    for (final (from, to) in [
      ('/v2/', '/'),
      ('/v2', '/'),
      ('/v1/', '/'),
      ('/v1', '/'),
      ('/v2/style.css', '/style.css'),
      ('/v2/?x=1', '/?x=1'),
      ('/v1?x=1', '/?x=1'),
    ]) {
      final res = await get(from);
      expect(res.statusCode, 302, reason: from);
      expect(res.headers['location'], to, reason: from);
    }
  });

  test('a name that only starts with v2 is not sent anywhere', () async {
    expect((await get('/v2x/style.css')).statusCode, 404);
  });

  test('the API and manager routes still come first', () async {
    expect(await (await get('/api/manager/status')).readAsString(), 'manager');
    final version = await get('/api/version');
    expect(version.statusCode, 200);
    expect(version.headers['content-type'], contains('json'));
  });
}
