import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Who is holding the lock right now, as written in the lock file.
class LockHolder {
  /// The process id of whoever took the lock.
  final int pid;

  /// A short word for what took it: "server" or "cli".
  final String label;

  /// When it was taken.
  final DateTime startedAt;

  const LockHolder({
    required this.pid,
    required this.label,
    required this.startedAt,
  });

  Map<String, dynamic> toMap() => {
        'pid': pid,
        'label': label,
        'startedAt': startedAt.toUtc().toIso8601String(),
      };

  /// Reads a holder back, or null when the text isn't a lock file we understand.
  static LockHolder? fromJson(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final pid = decoded['pid'];
      if (pid is! int) return null;
      return LockHolder(
        pid: pid,
        label: (decoded['label'] as String?) ?? 'unknown',
        startedAt: DateTime.tryParse((decoded['startedAt'] as String?) ?? '')
                ?.toUtc() ??
            DateTime.now().toUtc(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => '$label (pid $pid)';
}

/// Keeps two processes from writing one QB data folder at the same time.
///
/// The lock is a small file, `<data path>/scraper.lock`, holding whoever has it:
/// their process id, a short label, and when they started. It exists only while
/// a job is running.
///
/// Waiting is the normal outcome, not an error: a job that finds the folder busy
/// says so once and keeps trying. A lock left behind by a process that has since
/// died is thrown away, because nobody is actually writing.
class DataLock {
  static const String fileName = 'scraper.lock';

  /// The folder being guarded.
  final String dataPath;

  /// What to call ourselves in the file: "server" or "cli".
  final String label;

  /// How long to wait between tries while somebody else holds the lock.
  final Duration retryDelay;

  /// Our own process id. Tests pass their own.
  final int ownPid;

  /// Says whether a process id belongs to something still running. Tests pass
  /// their own; the default asks the operating system.
  final bool Function(int pid) isProcessAlive;

  bool _held = false;

  DataLock({
    required this.dataPath,
    required this.label,
    this.retryDelay = const Duration(seconds: 3),
    int? ownPid,
    bool Function(int pid)? isProcessAlive,
  })  : ownPid = ownPid ?? pid,
        isProcessAlive = isProcessAlive ?? processIsAlive;

  /// The lock file itself.
  String get path => p.join(dataPath, fileName);

  /// True while we are the ones holding the lock.
  bool get isHeld => _held;

  /// Who holds the lock right now, or null when nobody does.
  LockHolder? currentHolder() {
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      return LockHolder.fromJson(file.readAsStringSync());
    } on FileSystemException {
      // Somebody deleted it between the check and the read. Nobody holds it.
      return null;
    }
  }

  /// Takes the lock, waiting for as long as it takes.
  ///
  /// [log] gets one line when we start waiting for somebody else, and one line
  /// when a lock left by a dead process is cleared away.
  Future<void> acquire({void Function(String line)? log}) async {
    if (_held) return;
    await Directory(dataPath).create(recursive: true);

    var saidWeAreWaiting = false;
    while (true) {
      final holder = currentHolder();

      if (holder == null) {
        if (_tryWrite()) {
          _held = true;
          return;
        }
        // Somebody else got there in the same instant. Round again.
        continue;
      }

      if (!isProcessAlive(holder.pid)) {
        log?.call('Clearing a lock left behind by $holder, which is no longer '
            'running.');
        _deleteFile();
        continue;
      }

      if (!saidWeAreWaiting) {
        log?.call('Waiting for the lock held by $holder.');
        saidWeAreWaiting = true;
      }
      await Future<void>.delayed(retryDelay);
    }
  }

  /// Gives the lock up. Safe to call when we never had it.
  Future<void> release() async {
    if (!_held) return;
    _held = false;
    // Only ours to delete. If somebody cleared it as stale and took it over,
    // leave theirs alone.
    final holder = currentHolder();
    if (holder == null || holder.pid == ownPid) _deleteFile();
  }

  /// Writes our claim and checks it stuck. Returns false when another process
  /// wrote its own claim at the same moment.
  bool _tryWrite() {
    final holder =
        LockHolder(pid: ownPid, label: label, startedAt: DateTime.now().toUtc());
    try {
      File(path).writeAsStringSync(jsonEncode(holder.toMap()), flush: true);
    } on FileSystemException {
      return false;
    }
    final readBack = currentHolder();
    return readBack != null && readBack.pid == ownPid;
  }

  void _deleteFile() {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // Already gone, or held open by somebody else. Either way there is
      // nothing useful to do here.
    }
  }

  /// Asks the operating system whether [processId] is still running.
  ///
  /// Windows has no cheap signal check, so it asks `tasklist`. Everywhere else,
  /// `kill -0` reports whether the process exists without disturbing it. When
  /// the check itself fails we say "alive", because waiting is much cheaper than
  /// wrongly clearing a live process's lock.
  static bool processIsAlive(int processId) {
    if (processId <= 0) return false;
    try {
      if (Platform.isWindows) {
        final result = Process.runSync(
            'tasklist', ['/FI', 'PID eq $processId', '/NH', '/FO', 'CSV']);
        final out = (result.stdout as String? ?? '');
        return out.contains('"$processId"');
      }
      return Process.runSync('kill', ['-0', '$processId']).exitCode == 0;
    } catch (_) {
      return true;
    }
  }
}
