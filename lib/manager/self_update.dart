import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Runs a command and hands back what it said. Stands in for [Process.run] so
/// tests never start `systemctl`.
typedef RunCommand = Future<ProcessResult> Function(
    String executable, List<String> arguments);

/// Lets the viewer update the server to the newest release.
///
/// The work is done by `update-scraper-only.sh`, the same script cron runs, so
/// there is one way to update and one way back. The server cannot run it as
/// its own child: the script stops the service, and stopping a service kills
/// every process the service started. So it runs as its own fixed systemd
/// unit, `tool/starsector-scraper-update.service`, which outlives the server
/// it replaces. The server only starts that unit — a polkit rule allows that
/// one thing — so it holds no way to run anything as root.
///
/// The unit's output goes to [logFileName] in the program's folder. The new
/// server reads that file back, which is how the page learns how it went.
class SelfUpdate {
  static const scriptName = 'update-scraper-only.sh';
  static const logFileName = '.self-update.log';
  static const unitName = 'starsector-scraper-update.service';
  static const latestReleaseUrl =
      'https://git.wispborne.com/api/v1/repos/david/Mod_Repo_Scraper/releases/latest';

  /// Gitea only answers signed-in users, so asking it needs a token. It is
  /// kept in this file in the program's folder, the same file the update
  /// script reads.
  static const tokenFileName = '.gitea-token';

  /// The last line of the log once the script has ended, written by the unit
  /// rather than by the script, so it is there however the script ended. The
  /// unit file must write exactly this; a test holds the two together.
  static const finishedPrefix = 'Finished with exit code ';

  /// An unfinished update with nothing written for this long has died.
  static const staleAfter = Duration(minutes: 15);

  /// How long an answer from Gitea is reused. The page asks often; Gitea
  /// does not need to be asked every time.
  static const checkEvery = Duration(minutes: 10);

  /// How soon to ask Gitea again after it did not answer.
  static const retryCheckAfter = Duration(minutes: 2);

  static const _logLinesShown = 60;

  /// The folder the programs, the script and `site/version.json` sit in.
  final String rootDir;

  /// The build this server is, or null when nothing says.
  final int? Function() installedBuild;

  /// Whether a job is running or waiting. Updating restarts the server, which
  /// stops the one running and forgets the ones waiting.
  final bool Function() busy;

  final Future<int?> Function() fetchLatestBuild;
  final RunCommand runCommand;
  final bool isLinux;
  final DateTime Function() now;

  int? _latestBuild;
  DateTime? _checkedAt;
  bool _lastCheckFailed = false;
  Future<int?>? _checking;
  bool _starting = false;

  SelfUpdate({
    required String rootDir,
    required this.installedBuild,
    required this.busy,
    Future<int?> Function()? fetchLatestBuild,
    RunCommand? runCommand,
    bool? isLinux,
    DateTime Function()? now,
  })  : rootDir = p.normalize(p.absolute(rootDir)),
        fetchLatestBuild = fetchLatestBuild ??
            (() => latestReleaseBuild(token: readToken(rootDir))),
        runCommand = runCommand ?? Process.run,
        isLinux = isLinux ?? Platform.isLinux,
        now = now ?? DateTime.now;

  String get scriptPath => p.join(rootDir, scriptName);

  String get logPath => p.join(rootDir, logFileName);

  /// Whether an update started from here is still going.
  bool get isRunning => _starting || (lastUpdate()?.running ?? false);

  /// What the page needs to offer an update, or to say why it cannot.
  Future<Map<String, Object?>> status() async {
    final installed = installedBuild();
    final unsupported = await _unsupportedReason();
    // A machine that cannot update itself has no reason to ask Gitea.
    final latest = unsupported == null ? await _latest() : null;
    final last = lastUpdate();
    final available =
        installed != null && latest != null && latest > installed;
    final reason = unsupported ??
        _whyNotNow(installed: installed, latest: latest, last: last);
    return {
      'supported': unsupported == null,
      'installed': installed,
      'latest': latest,
      'available': available,
      'canUpdate': reason == null,
      'reason': reason,
      'lastUpdate': last?.toMap(),
    };
  }

  /// Starts the update. Returns null once it is under way, or the reason it
  /// was not started.
  Future<String?> start() async {
    if (_starting) return 'An update is already starting.';
    _starting = true;
    try {
      final installed = installedBuild();
      final latest = await _latest();
      final reason = await _unsupportedReason() ??
          _whyNotNow(installed: installed, latest: latest, last: lastUpdate());
      if (reason != null) return reason;

      final log = File(logPath);
      log.writeAsStringSync(
          'Started from the viewer at ${now().toUtc().toIso8601String()}: '
          'v$installed to v$latest.\n');

      // --no-block, or systemctl would wait for the update to finish, and the
      // update stops this server before it does.
      final ProcessResult result;
      try {
        result = await runCommand(
            'systemctl', ['start', '--no-block', unitName]);
      } on ProcessException catch (e) {
        return _couldNotStart(log, e.message);
      }
      if (result.exitCode != 0) {
        final said = '${result.stderr}'.trim();
        return _couldNotStart(log,
            said.isEmpty ? 'systemctl exited with ${result.exitCode}' : said);
      }
      return null;
    } finally {
      _starting = false;
    }
  }

  String _couldNotStart(File log, String said) {
    log.writeAsStringSync('Could not start the update: $said\n${finishedPrefix}1\n',
        mode: FileMode.append);
    return 'The update could not be started: $said. The server\'s user must '
        'be allowed to start $unitName. See '
        'tool/starsector-scraper-update.rules.';
  }

  /// What the log says about the last update started from here, or null when
  /// none ever was.
  LastUpdate? lastUpdate() {
    final file = File(logPath);
    final List<String> lines;
    final DateTime written;
    try {
      if (!file.existsSync()) return null;
      lines = file.readAsLinesSync();
      written = file.lastModifiedSync();
    } on FileSystemException {
      return null;
    }

    int? exitCode;
    for (final line in lines.reversed) {
      if (line.startsWith(finishedPrefix)) {
        exitCode = int.tryParse(line.substring(finishedPrefix.length).trim());
        break;
      }
    }
    final finished = exitCode != null;
    final died = !finished && now().difference(written) > staleAfter;
    final shown = lines.length > _logLinesShown
        ? lines.sublist(lines.length - _logLinesShown)
        : lines;
    return LastUpdate(
      running: !finished && !died,
      exitCode: exitCode,
      died: died,
      lastWritten: written,
      lines: [for (final l in shown) if (!l.startsWith(finishedPrefix)) l],
    );
  }

  Future<String?> _unsupportedReason() async {
    if (!isLinux) {
      return 'Updating from the viewer only works on the Linux server it is '
          'installed on.';
    }
    final script = File(scriptPath);
    if (!script.existsSync()) {
      return 'There is no $scriptName next to the server, so it cannot update '
          'itself.';
    }
    // Any of the three "can run" bits. The wrapper runs the script directly.
    // Windows has no such bits, and only the tests get this far there.
    if (Platform.isLinux && script.statSync().mode & 0x49 == 0) {
      return '$scriptName is not allowed to run. Fix it with: '
          'chmod +x $scriptName';
    }
    return _unitProblem();
  }

  /// Why the update unit cannot be used, or null when it is installed and
  /// works in this server's folder.
  Future<String?> _unitProblem() async {
    const notInstalled = 'The update unit, $unitName, is not installed. See '
        'tool/starsector-scraper-update.service.';
    final ProcessResult result;
    try {
      result = await runCommand('systemctl',
          ['show', '--property=LoadState,WorkingDirectory', unitName]);
    } on ProcessException {
      return notInstalled;
    }
    if (result.exitCode != 0) return notInstalled;

    final said = <String, String>{};
    for (final line in '${result.stdout}'.split('\n')) {
      final i = line.indexOf('=');
      if (i > 0) said[line.substring(0, i)] = line.substring(i + 1).trim();
    }
    if (said['LoadState'] != 'loaded') return notInstalled;

    // The unit writes its log in its own folder, and this server reads it from
    // its own. If they differ, the page would never hear how the update went.
    final unitDir = said['WorkingDirectory'] ?? '';
    if (unitDir.isEmpty || !p.equals(p.normalize(unitDir), rootDir)) {
      return 'The update unit works in "${unitDir.isEmpty ? 'no folder' : unitDir}", '
          'but this server runs in "$rootDir". Set WorkingDirectory= in '
          '$unitName to this server\'s folder.';
    }
    return null;
  }

  String? _whyNotNow({
    required int? installed,
    required int? latest,
    required LastUpdate? last,
  }) {
    if (last != null && last.running) return 'An update is already going.';
    if (latest == null) {
      return 'Gitea could not be asked which release is the newest. It needs '
          'a Gitea token in $tokenFileName, in the server\'s folder.';
    }
    if (installed != null && latest <= installed) {
      return 'This server is already on the newest release, v$installed.';
    }
    if (busy()) {
      return 'A job is running or waiting. Updating restarts the server, '
          'which would stop it. Wait for it to finish.';
    }
    return null;
  }

  /// The newest release's build, reusing a recent answer.
  Future<int?> _latest() {
    final checked = _checkedAt;
    if (checked != null) {
      final wait = _lastCheckFailed ? retryCheckAfter : checkEvery;
      if (now().difference(checked) < wait) return Future.value(_latestBuild);
    }
    return _checking ??= () async {
      try {
        final build = await fetchLatestBuild();
        _lastCheckFailed = build == null;
        // A failed check keeps the last answer rather than forgetting it.
        if (build != null) _latestBuild = build;
        _checkedAt = now();
        return _latestBuild;
      } finally {
        _checking = null;
      }
    }();
  }

  /// The token in [tokenFileName] in [rootDir], or null when there is none.
  static String? readToken(String rootDir) {
    try {
      final token =
          File(p.join(rootDir, tokenFileName)).readAsStringSync().trim();
      return token.isEmpty ? null : token;
    } on FileSystemException {
      return null;
    }
  }

  /// The newest release's build number, or null when Gitea does not say.
  ///
  /// Gitea's API names the newest published release, whose tag is `v<N>`.
  /// Without a token Gitea answers nobody, so there is no point asking.
  static Future<int?> latestReleaseBuild(
      {required String? token, http.Client? client}) async {
    if (token == null) return null;
    final c = client ?? http.Client();
    try {
      final response = await c.get(Uri.parse(latestReleaseUrl), headers: {
        'Authorization': 'token $token',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      return body is Map ? buildFromTag(body['tag_name']) : null;
    } on Exception {
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  /// Reads `52` out of the tag `v52`.
  static int? buildFromTag(Object? tag) {
    final match = RegExp(r'^v(\d+)$').firstMatch(tag is String ? tag : '');
    return match == null ? null : int.parse(match.group(1)!);
  }
}

/// What the log says about the last update started from the viewer.
class LastUpdate {
  final bool running;

  /// The script's exit code, or null while it runs or when it died silently.
  final int? exitCode;

  /// Nothing was written for [SelfUpdate.staleAfter] and it never finished.
  final bool died;

  final DateTime lastWritten;
  final List<String> lines;

  const LastUpdate({
    required this.running,
    required this.exitCode,
    required this.died,
    required this.lastWritten,
    required this.lines,
  });

  Map<String, Object?> toMap() => {
        'running': running,
        'exitCode': exitCode,
        'died': died,
        'lastWritten': lastWritten.toUtc().toIso8601String(),
        'lines': lines,
      };
}
