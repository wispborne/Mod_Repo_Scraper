import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:mod_repo_scraper/site/site_changelog.dart';
import 'package:mod_repo_scraper/viewer/live_reload.dart';
import 'package:mod_repo_scraper/viewer/site_version.dart';

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
///
/// It reloads an open page whenever a file in the website's folder changes
/// (`--no-reload` turns that off). See [LiveReload].
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', defaultsTo: '8099', help: 'Port to listen on.')
    ..addOption('site-dir',
        defaultsTo: 'site', help: "The website's own files.")
    ..addOption('data-dir',
        defaultsTo: p.join('outputs', 'site'),
        help: 'mods.json, updates.json and mods/, as a run built them.')
    ..addFlag('reload',
        defaultsTo: true,
        help: "Reload open pages when a file in the website's folder changes.")
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

  // The build line in the footer reads `version.json`, which only the release
  // workflow writes. Run from the repo there is none, so the footer would show
  // no build at all; this answers it from git instead, the same way the
  // results viewer does (`SiteVersion`). A real `site/version.json` is served
  // by the static handler above and wins.
  handlers.add(_buildVersion(p.dirname(p.absolute(siteDir))));
  // The changelog page reads `changelog.json`, which only the release workflow
  // writes, so it is answered from git here in the same way.
  handlers.add(_changelog(p.dirname(p.absolute(siteDir))));

  // Last of all: a missing file gets the built not-found page with status 404,
  // the way the real host answers it, so the page can be checked here.
  final notFoundPage = File(p.join(dataDir, '404.html'));
  handlers.add((request) async {
    if (!notFoundPage.existsSync()) return Response.notFound('Not found');
    return Response.notFound(await notFoundPage.readAsString(),
        headers: {'content-type': 'text/html; charset=utf-8'});
  });

  final liveReload =
      opts['reload'] as bool ? LiveReload.watch(Directory(siteDir)) : null;

  var cascade = Cascade();
  for (final handler in handlers) {
    cascade = cascade.add(handler);
  }

  var pipeline = const Pipeline().addMiddleware(logRequests());
  if (liveReload != null) {
    pipeline = pipeline.addMiddleware(liveReload.middleware);
  }

  final HttpServer server;
  try {
    server = await shelf_io.serve(
      pipeline.addHandler(cascade.handler),
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
  if (liveReload != null) {
    stdout.writeln('Open pages reload when a file in $siteDir changes.');
  }
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

/// Answers `version.json` with the build number, commit and day, read by
/// [SiteVersion] from the release file or from git. Nothing else.
Handler _buildVersion(String rootDir) => (request) {
      if (request.url.path != 'version.json') return Response.notFound('');
      final version = SiteVersion(rootDir).read();
      if (version == null) return Response.notFound('');
      return Response.ok(jsonEncode(version),
          headers: {'content-type': 'application/json'});
    };

/// Answers `changelog.json` with the website's changelog, read by
/// [SiteChangelog] from the release file or from git. Nothing else.
Handler _changelog(String rootDir) => (request) {
      if (request.url.path != 'changelog.json') return Response.notFound('');
      final entries = SiteChangelog(rootDir).read();
      if (entries == null) return Response.notFound('');
      return Response.ok(jsonEncode(entries),
          headers: {'content-type': 'application/json'});
    };
