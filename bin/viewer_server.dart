import 'dart:io';

import 'package:args/args.dart';
import 'package:mod_repo_scraper/bot/common.dart';
import 'package:mod_repo_scraper/manager/author_alias_service.dart';
import 'package:mod_repo_scraper/manager/data_lock.dart';
import 'package:mod_repo_scraper/manager/job_manager.dart';
import 'package:mod_repo_scraper/manager/manager_api.dart';
import 'package:mod_repo_scraper/manager/modrepo_service.dart';
import 'package:mod_repo_scraper/manager/publish_service.dart';
import 'package:mod_repo_scraper/manager/run_history_store.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:mod_repo_scraper/manager/scraper_service.dart';
import 'package:mod_repo_scraper/manager/scraper_settings.dart';
import 'package:mod_repo_scraper/manager/self_update.dart';
import 'package:mod_repo_scraper/manager/takedown_service.dart';
import 'package:mod_repo_scraper/viewer/api.dart';
import 'package:mod_repo_scraper/viewer/data_access.dart';
import 'package:mod_repo_scraper/viewer/server_app.dart';
import 'package:mod_repo_scraper/viewer/site_version.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

/// Serves `web/`, the read-only viewer API and optional job management API.
///
/// Binds to `127.0.0.1`. Config supplies manager settings; only the data path
/// may be exposed over HTTP. Viewer endpoints never write; manager jobs may.
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', defaultsTo: '8085', help: 'Port to listen on.')
    ..addOption('data-dir',
        defaultsTo: 'qb_data',
        help: 'QB data dir: mods-index.json, mods/, the caches.')
    ..addOption('outputs-dir',
        defaultsTo: 'outputs', help: 'ModRepo.json and forum-data-bundle.json.')
    ..addOption('root-dir',
        defaultsTo: '.', help: 'merge-debug.json and ModRepo.log.')
    ..addOption('web-dir',
        defaultsTo: 'web', help: 'Static frontend directory.')
    ..addOption('config',
        defaultsTo: 'config.properties',
        help:
            'Manager config file. Without it, the viewer runs with jobs disabled.')
    ..addFlag('no-manager',
        negatable: false,
        help: 'Disable jobs even when a config file is available.')
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

/// Management handler and startup status, including the disabled mode.
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

  // Warn if the viewer reads a different data folder from the one jobs write.
  final managerDataPath = p.normalize(p.absolute(config.qbDataPath));
  final viewerDataPath = p.normalize(p.absolute(viewerDataDir));
  if (managerDataPath != viewerDataPath) {
    stderr.writeln('Warning: the viewer is showing $viewerDataPath but the '
        'manager writes to $managerDataPath (qb_data_path in $configPath). '
        'Start the server with --data-dir ${config.qbDataPath} to see the '
        'folder the manager is working on.');
  }

  // Console logging also feeds per-run log capture while a job runs.
  Common.initTimberForConsole(config);
  Common.bridgeLoggingToTimber();

  final service = ScraperService(
    environment:
        ScraperEnvironment.fromConfig(config, sourceCachePath: viewerRootDir),
    guardrails: ScraperGuardrails.fromConfig(config),
  );
  await service.load();

  final jobManager = JobManager(
    service: JobRouter(
      qb: service,
      modRepo: ModRepoService(
        // Merge output must go to the folders the viewer reads.
        environment: ModRepoEnvironment.fromConfig(
          config,
          workingPath: viewerRootDir,
          outputPath: viewerOutputsDir,
        ),
        guardrails: ModRepoGuardrails.fromConfig(config),
      ),
      // Publish the output files this viewer reads.
      publish: PublishService(
        environment: PublishEnvironment.fromConfig(
          config,
          outputPath: viewerOutputsDir,
        ),
      ),
      // A mod entry's posts come from the catalog this viewer shows.
      takedowns: TakedownService(
        dataPath: config.qbDataPath,
        outputPath: viewerOutputsDir,
      ),
      authorAliases: AuthorAliasService(dataPath: config.qbDataPath),
    ),
    history:
        RunHistoryStore(config.qbDataPath, runsToKeep: config.qbRunsToKeep),
    lock: DataLock(dataPath: config.qbDataPath, label: 'server'),
    // The reporter must log so server-started runs have browsable logs.
    makeReporter: (_) => const LogRunReporter(),
  );
  await jobManager.load();

  final api = ManagerApi(
    manager: jobManager,
    dataPath: config.qbDataPath,
    selfUpdate: SelfUpdate(
      rootDir: viewerRootDir,
      installedBuild: () => SiteVersion(viewerRootDir).read()?['build'] as int?,
      busy: () =>
          jobManager.currentRun != null || jobManager.queuedRuns.isNotEmpty,
    ),
  );
  return _ManagerSetup(api.router, 'on, working on $managerDataPath');
}
