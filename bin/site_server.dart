import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

/// Serves the public website against the data a real run built.
///
/// The two halves live in different folders. The website's own files are in
/// `site/`; the data is in `outputs/site/`, where the builder writes it. A
/// publish copies both into one folder, and the site expects to find its data
/// sitting next to its pages — so neither folder can be served on its own.
/// This serves them as though they had already been copied together, without
/// copying anything.
///
/// The website's files come first, so a page is always the one just edited
/// rather than a stale copy left in the outputs folder by an earlier publish.
///
/// Read-only, and bound to `127.0.0.1`. There is no manager behind it and no
/// way to change anything — in production the public site has no server at all,
/// and neither does this.
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', defaultsTo: '8099', help: 'Port to listen on.')
    ..addOption('site-dir',
        defaultsTo: 'site', help: "The website's own files.")
    ..addOption('data-dir',
        defaultsTo: p.join('outputs', 'site'),
        help: 'mods.json, updates.json and mods/, as a run built them.')
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
    stdout.writeln('Serves the public website with the real published data.\n');
    stdout.writeln(parser.usage);
    return;
  }

  final port = int.tryParse(opts['port'] as String) ?? 8099;
  final siteDir = opts['site-dir'] as String;
  final dataDir = opts['data-dir'] as String;

  if (!Directory(siteDir).existsSync()) {
    stderr.writeln("There is no $siteDir folder to serve the website from.");
    exitCode = 66;
    return;
  }

  final handlers = <Handler>[
    createStaticHandler(siteDir,
        defaultDocument: 'index.html', listDirectories: false),
  ];

  final hasData = Directory(dataDir).existsSync();
  if (hasData) {
    // The same `index.html` rule as the site's own files. The per-mod pages the
    // builder writes sit at `mods/<id>/index.html`, and a shared link points at
    // the folder — so a server that does not serve the index for a folder shows
    // a reader a 404 where a real host would show the mod.
    handlers.add(createStaticHandler(dataDir,
        defaultDocument: 'index.html', listDirectories: false));
  }

  var cascade = Cascade();
  for (final handler in handlers) {
    cascade = cascade.add(handler);
  }

  final HttpServer server;
  try {
    server = await shelf_io.serve(
      const Pipeline().addMiddleware(logRequests()).addHandler(cascade.handler),
      InternetAddress.loopbackIPv4,
      port,
    );
  } on SocketException catch (e) {
    // Almost always another copy of this already running. A stack trace says
    // none of that.
    stderr.writeln('Port $port is already in use, so the website cannot start '
        'on it. Stop whatever is using it, or start this with '
        '--port <another one>.');
    stderr.writeln('(${e.osError?.message ?? e.message})');
    exitCode = 69;
    return;
  }
  server.autoCompress = true;

  stdout.writeln('Public website running at http://127.0.0.1:${server.port}/');
  stdout.writeln('  site-dir  $siteDir');
  stdout.writeln('  data-dir  $dataDir');
  if (!hasData) {
    // Not a failure. The site opens against the hand-written examples without
    // any data at all, which is how it is worked on before a run has built
    // anything.
    stdout.writeln('');
    stdout.writeln('There is no $dataDir folder yet, so no real data will '
        'load. Run the scraper to build it, or open');
    stdout.writeln('  http://127.0.0.1:${server.port}/?data=sample');
    stdout.writeln('to look at the site against the hand-written examples.');
  }
  stdout.writeln('Press Ctrl+C to stop.');
}
