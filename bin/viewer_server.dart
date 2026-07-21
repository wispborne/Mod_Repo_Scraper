import 'dart:io';

import 'package:args/args.dart';
import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

/// Local, read-only viewer for the scraper's output files. Serves the static
/// frontend in `web/` and a JSON API over the files on disk. Binds to
/// `127.0.0.1` only, never reads `config.properties`, and never writes data.
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', defaultsTo: '8085', help: 'Port to listen on.')
    ..addOption('data-dir',
        defaultsTo: 'qb_data',
        help: 'QB data dir: mods-index.json, mods/, the caches.')
    ..addOption('outputs-dir',
        defaultsTo: 'outputs',
        help: 'ModRepo.json and forum-data-bundle.json.')
    ..addOption('root-dir',
        defaultsTo: '.', help: 'merge-debug.json and ModRepo.log.')
    ..addOption('web-dir',
        defaultsTo: 'web', help: 'Static frontend directory.')
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show usage and exit.');

  final ArgResults opts;
  try {
    opts = parser.parse(args);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(parser.usage);
    exitCode = 64;
    return;
  }

  if (opts['help'] as bool) {
    stdout.writeln('Starsector mod repo results viewer.\n');
    stdout.writeln(parser.usage);
    return;
  }

  final port = int.tryParse(opts['port'] as String) ?? 8085;

  final data = DataAccess(
    dataDir: opts['data-dir'] as String,
    outputsDir: opts['outputs-dir'] as String,
    rootDir: opts['root-dir'] as String,
  );
  final api = ViewerApi(data);

  final webDir = opts['web-dir'] as String;
  final staticHandler = createStaticHandler(
    webDir,
    defaultDocument: 'index.html',
    listDirectories: false,
  );

  // /api/* goes to the JSON API; everything else falls through to static files.
  final apiRouter = Router()..mount('/api', api.router);
  final cascade = Cascade().add(apiRouter.call).add(staticHandler);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(cascade.handler);

  final server =
      await shelf_io.serve(handler, InternetAddress.loopbackIPv4, port);
  server.autoCompress = true;

  stdout.writeln('Results viewer running at http://127.0.0.1:${server.port}/');
  stdout.writeln('  data-dir    ${data.dataDir}');
  stdout.writeln('  outputs-dir ${data.outputsDir}');
  stdout.writeln('  root-dir    ${data.rootDir}');
  stdout.writeln('Press Ctrl+C to stop.');
}
