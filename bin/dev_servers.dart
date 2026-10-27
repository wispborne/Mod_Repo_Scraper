import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

/// Runs the public website and the results viewer together, for working on
/// them. Started by `tool/run-sites-dev.bat`.
///
/// Each server reloads its own open pages when a file in `site/` or `web/`
/// changes. This adds the other half: when a Dart file in `lib/` or `bin/`
/// changes, or `pubspec.lock` does, both servers are stopped and started
/// again on the new code, and their open pages reload once the new server
/// answers.
///
/// The viewer is not restarted while it is running or holding a job, because
/// that would stop the job. It is restarted once the job ends.
Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('site-port', defaultsTo: '8099')
    ..addOption('viewer-port', defaultsTo: '8085')
    ..addFlag('help', abbr: 'h', negatable: false);
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
    stdout
        .writeln('Runs both sites and restarts them when Dart code changes.\n');
    stdout.writeln(parser.usage);
    return;
  }

  final viewerPort = opts['viewer-port'] as String;
  final site = _Server('site', [
    p.join('bin', 'site_server.dart'),
    '--port',
    opts['site-port'] as String,
  ]);
  final viewer = _Server('viewer', [
    p.join('bin', 'viewer_server.dart'),
    '--reload',
    '--port',
    viewerPort,
  ]);
  final servers = [site, viewer];

  await Future.wait(servers.map((s) => s.start()));
  stdout.writeln('[dev] Restarting both servers when a Dart file in lib/ or '
      'bin/ changes. Press Ctrl+C to stop.');

  var restarting = false;
  var again = false;
  Timer? settle;

  Future<void> restart() async {
    if (restarting) {
      again = true;
      return;
    }
    restarting = true;
    do {
      again = false;
      await _waitForViewerJobs(viewerPort);
      stdout.writeln('[dev] Dart code changed. Restarting both servers.');
      await Future.wait(servers.map((s) => s.restart()));
    } while (again);
    restarting = false;
  }

  void changed(FileSystemEvent event) {
    final name = p.basename(event.path);
    if (!name.endsWith('.dart') && name != 'pubspec.lock') return;
    // Editors write a file in several steps. Wait for them to finish.
    settle?.cancel();
    settle = Timer(const Duration(milliseconds: 300), restart);
  }

  for (final dir in ['lib', 'bin']) {
    Directory(dir).watch(recursive: true).listen(changed);
  }
  Directory('.').watch().listen(changed);

  late final StreamSubscription<ProcessSignal> onStop;
  onStop = ProcessSignal.sigint.watch().listen((_) async {
    await onStop.cancel();
    stdout.writeln('[dev] Stopping both servers.');
    await Future.wait(servers.map((s) => s.stop()));
    exit(0);
  });
}

/// Waits while the viewer's manager has a job running or waiting.
Future<void> _waitForViewerJobs(String port) async {
  var said = false;
  while (await _viewerBusy(port)) {
    if (!said) {
      stdout.writeln('[dev] The viewer has a job running. It will restart '
          'once the job ends.');
      said = true;
    }
    await Future<void>.delayed(const Duration(seconds: 5));
  }
}

Future<bool> _viewerBusy(String port) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final request = await client
        .getUrl(Uri.parse('http://127.0.0.1:$port/api/manager/status'));
    final response = await request.close().timeout(const Duration(seconds: 2));
    final body = await response.transform(utf8.decoder).join();
    final status = jsonDecode(body);
    if (status is! Map || status['managerOn'] != true) return false;
    return status['current'] != null ||
        ((status['queued'] as List?)?.isNotEmpty ?? false);
  } catch (_) {
    // No viewer answering means no job to protect.
    return false;
  } finally {
    client.close(force: true);
  }
}

/// One server, run as `dart <args>`, with each line of its output marked with
/// its name.
class _Server {
  _Server(this.name, this.args);

  final String name;
  final List<String> args;
  Process? _process;

  Future<void> start() async {
    final process = await Process.start(Platform.resolvedExecutable, args);
    _process = process;
    _pipe(process.stdout, stdout);
    _pipe(process.stderr, stderr);
    unawaited(process.exitCode.then((code) {
      // A stop asked for here clears `_process` first, so only an exit
      // nobody asked for gets a line. The usual cause is a compile error;
      // the next save starts it again.
      if (identical(_process, process)) {
        stdout.writeln('[$name] Stopped with exit code $code. It will start '
            'again on the next change to the Dart code.');
        _process = null;
      }
    }));
  }

  Future<void> stop() async {
    final process = _process;
    _process = null;
    if (process == null) return;
    process.kill();
    await process.exitCode;
  }

  Future<void> restart() async {
    await stop();
    await start();
  }

  void _pipe(Stream<List<int>> from, IOSink to) {
    from
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => to.writeln('[$name] $line'));
  }
}
