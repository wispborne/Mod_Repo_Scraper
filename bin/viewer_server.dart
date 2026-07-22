import 'dart:io';

import 'package:args/args.dart';
import 'package:mod_repo_scraper/bot/common.dart';
import 'package:mod_repo_scraper/manager/data_lock.dart';
import 'package:mod_repo_scraper/manager/job_manager.dart';
import 'package:mod_repo_scraper/manager/manager_api.dart';
import 'package:mod_repo_scraper/manager/modrepo_service.dart';
import 'package:mod_repo_scraper/manager/run_history_store.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:mod_repo_scraper/manager/scraper_service.dart';
import 'package:mod_repo_scraper/manager/scraper_settings.dart';
import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:mod_repo_scraper/viewer/server_app.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

/// Local viewer and manager for the scraper. Serves the static frontend in
/// `web/`, a read-only JSON API over the files on disk, and — when a config file
/// is there to read — the management API that runs jobs.
///
/// Binds to `127.0.0.1` only. The config file is read for where the data lives
/// and which services may be called; none of its values are ever sent over HTTP.
/// Viewer endpoints never write; the only writes are jobs asked for on the
/// management API.
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
    ..addOption('config',
        defaultsTo: 'config.properties',
        help: 'Config file. Read only to set up the manager; if it is not '
            'there, the viewer still runs and the manager is off.')
    ..addFlag('no-manager',
        negatable: false,
        help: 'Run as the read-only viewer, even if a config file is there.')
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

  final webDir = opts['web-dir'] as String;
  final staticHandler = createStaticHandler(
    webDir,
    defaultDocument: 'index.html',
    listDirectories: false,
  );

  final manager = await _buildManager(
    configPath: opts['config'] as String,
    wanted: !(opts['no-manager'] as bool),
    viewerDataDir: data.dataDir,
    viewerRootDir: data.rootDir,
    viewerOutputsDir: data.outputsDir,
  );

  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(
        buildServerHandler(
          viewer: ViewerApi(data),
          managerHandler: manager.handler,
          staticHandler: staticHandler,
        ),
      );

  final server =
      await shelf_io.serve(handler, InternetAddress.loopbackIPv4, port);
  server.autoCompress = true;

  stdout.writeln('Results viewer running at http://127.0.0.1:${server.port}/');
  stdout.writeln('  data-dir    ${data.dataDir}');
  stdout.writeln('  outputs-dir ${data.outputsDir}');
  stdout.writeln('  root-dir    ${data.rootDir}');
  stdout.writeln('  manager     ${manager.description}');
  stdout.writeln('Press Ctrl+C to stop.');
}

/// What the server ended up with: either a live management API or the answer
/// that says the manager is off.
class _ManagerSetup {
  final Handler handler;
  final String description;

  _ManagerSetup(this.handler, this.description);
}

/// Builds the manager core from the config file, or reports why it can't.
Future<_ManagerSetup> _buildManager({
  required String configPath,
  required bool wanted,
  required String viewerDataDir,
  required String viewerRootDir,
  required String viewerOutputsDir,
}) async {
  if (!wanted) {
    const reason = 'The manager is off: the server was started with '
        '--no-manager.';
    return _ManagerSetup(ManagerApi.offHandler(reason), reason);
  }

  if (!File(configPath).existsSync()) {
    final reason = 'The manager is off: there is no $configPath to read.';
    return _ManagerSetup(ManagerApi.offHandler(reason), reason);
  }

  final config = Common.readConfig(configFilePath: configPath);
  if (config == null) {
    final reason = 'The manager is off: $configPath could not be read.';
    return _ManagerSetup(ManagerApi.offHandler(reason), reason);
  }

  // The manager works on the folder the config names. If the viewer was pointed
  // somewhere else, the pages would show one folder while jobs wrote another,
  // so say so plainly rather than letting it confuse someone later.
  final managerDataPath = p.normalize(p.absolute(config.qbDataPath));
  final viewerDataPath = p.normalize(p.absolute(viewerDataDir));
  if (managerDataPath != viewerDataPath) {
    stderr.writeln('Warning: the viewer is showing $viewerDataPath but the '
        'manager writes to $managerDataPath (qb_data_path in $configPath). '
        'Start the server with --data-dir ${config.qbDataPath} to see the '
        'folder the manager is working on.');
  }

  // Logging goes to the console here — the server has no log file of its own —
  // and, while a job runs, into that run's own log file.
  Common.initTimberForConsole(config);
  Common.bridgeLoggingToTimber();

  final service = ScraperService(
    environment: ScraperEnvironment.fromConfig(config),
    guardrails: ScraperGuardrails.fromConfig(config),
  );
  await service.load();

  final jobManager = JobManager(
    // One queue, two pipelines: QB jobs go to the scraper service, merge jobs
    // to the ModRepo one.
    service: JobRouter(
      qb: service,
      modRepo: ModRepoService(
        // A merge started here writes where this server reads, so the pages
        // show what the job just did.
        environment: ModRepoEnvironment.fromConfig(
          config,
          workingPath: viewerRootDir,
          outputPath: viewerOutputsDir,
        ),
        guardrails: ModRepoGuardrails.fromConfig(config),
      ),
    ),
    history: RunHistoryStore(config.qbDataPath,
        runsToKeep: config.qbRunsToKeep),
    lock: DataLock(dataPath: config.qbDataPath, label: 'server'),
    // Nobody is watching a console here, but a job's own words still have to
    // reach its log file — that is all anyone browsing the run will have.
    makeReporter: (_) => const LogRunReporter(),
  );
  await jobManager.load();

  final api = ManagerApi(manager: jobManager, dataPath: config.qbDataPath);
  return _ManagerSetup(api.router, 'on, working on $managerDataPath');
}
