import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:synchronized/synchronized.dart';

import '../timber/log_level.dart';
import '../timber/timber.dart';
import 'job.dart';

/// Keeps a record of every job the manager runs, in `<data path>/runs/`.
///
/// The index is written when a run starts, whenever its state changes, and
/// every so often while it is going — so a run killed part-way still leaves an
/// honest record of how far it got, and the next start can mark it as
/// interrupted.
class RunHistoryStore {
  static const String indexFileName = 'runs-index.json';

  /// Save the index after this many progress reports. Progress arrives once per
  /// topic, so this is roughly "every ten topics", matching the other stores.
  static const int _saveEveryProgressReports = 10;

  final String _dataPath;
  final Lock _writeLock = Lock();

  /// How many runs to keep. Older ones are dropped, and their log files with
  /// them — the logs are what actually fill the folder up. 0 or less keeps
  /// everything.
  final int runsToKeep;

  /// Newest first, which is the order the file is written in.
  final List<RunRecord> _records = [];

  /// Runs this copy started, so it knows which records it is the authority on.
  /// Everything else is somebody else's, and their file is the truth.
  final Set<String> _ourRunIds = {};

  /// What the index file looked like when we last read or wrote it, so a look
  /// at the history costs one question to the file system unless something has
  /// actually changed.
  DateTime? _seenChangedAt;
  int? _seenSize;

  int _sinceLastSave = 0;

  RunHistoryStore(this._dataPath, {this.runsToKeep = 100});

  /// The folder holding the index and the per-run log files.
  String get runsPath => p.join(_dataPath, 'runs');

  String get indexPath => p.join(runsPath, indexFileName);

  /// Every record, newest first.
  List<RunRecord> get records {
    _readAgainIfChanged();
    return List.unmodifiable(_records);
  }

  RunRecord? byId(String id) {
    _readAgainIfChanged();
    for (final r in _records) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Reads the index and marks anything still saying `running` as
  /// `interrupted` — a run can only still say `running` if the program stopped
  /// before it ended.
  Future<void> load() async {
    _records.clear();
    final file = File(indexPath);
    if (file.existsSync()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is Map<String, dynamic>) {
              _records.add(RunRecordMapper.fromMap(entry));
            }
          }
        }
      } catch (e) {
        stderr.writeln('Could not read the run history at $indexPath: $e');
      }
    }

    var changed = false;
    for (var i = 0; i < _records.length; i++) {
      final record = _records[i];
      if (record.state == RunState.running || record.state == RunState.queued) {
        _records[i] = record.copyWith(state: RunState.interrupted);
        changed = true;
      }
    }
    if (changed) {
      await save();
    } else {
      _noteFileAsSeen();
    }
  }

  /// Starts a record for [request] and writes it straight away, so a run that
  /// dies in its first second is still on record.
  Future<RunRecord> startRun(JobRequest request, {DateTime? now}) async {
    final startedAt = (now ?? DateTime.now()).toUtc();
    final id = _makeId(request.kind, startedAt);
    final record = RunRecord(
      id: id,
      request: request,
      state: RunState.running,
      startedAt: startedAt,
      logFileName: '$id.log',
    );
    _records.insert(0, record);
    // Ours from here on: what we hold for this run beats what the file says,
    // because we are the one writing it.
    _ourRunIds.add(id);
    _sinceLastSave = 0;
    await save();
    return record;
  }

  /// Replaces the record with the same id (or adds it) and writes the index.
  /// Use for anything that changes a run's state or its ending.
  Future<RunRecord> update(RunRecord record) async {
    _put(record);
    _sinceLastSave = 0;
    await save();
    return record;
  }

  /// Saves new counters for a run, writing the index every so often rather than
  /// on every single update.
  Future<RunRecord> reportProgress(RunRecord record, RunCounters counters,
      {bool force = false}) async {
    final updated = record.copyWith(counters: counters);
    _put(updated);
    _sinceLastSave++;
    if (force || _sinceLastSave >= _saveEveryProgressReports) {
      _sinceLastSave = 0;
      await save();
    }
    return updated;
  }

  /// Writes the index. Safe to call from several places at once.
  ///
  /// Anything on disk that this copy has never heard of is picked up first. Two
  /// programs can share one folder — a server and a command line taking turns —
  /// and each keeps its own list in memory, so writing the list as-is would
  /// throw away runs the other one recorded.
  Future<void> save() async {
    await _writeLock.synchronized(() async {
      await Directory(runsPath).create(recursive: true);
      _takeInRunsFromDisk();
      // Trimming happens after taking in the other program's runs and before
      // writing. The other way round, a run we had just dropped would be read
      // straight back off the disk as one we had never heard of.
      _dropOldRuns();
      final json = const JsonEncoder.withIndent('  ')
          .convert(_records.map((r) => r.toMap()).toList());
      await File(indexPath).writeAsString(json);
      _noteFileAsSeen();
    });
  }

  /// Picks up what another program has written since we last looked.
  ///
  /// A server sitting there for weeks would otherwise show the history exactly
  /// as it was the moment it started: a run somebody kicked off from the command
  /// line would be missing from the page until the next restart, which is the
  /// worst possible moment to be missing it. So every look at the history checks
  /// the file first, and re-reads it when it has changed.
  ///
  /// Runs we started ourselves are kept as we have them. Ours are saved every
  /// tenth report, so what is in memory is newer than what is on disk, and
  /// taking the file's word for it would wind our own live run backwards.
  void _readAgainIfChanged() {
    final file = File(indexPath);
    final FileStat stat;
    try {
      stat = file.statSync();
      if (stat.type == FileSystemEntityType.notFound) return;
      if (_seenChangedAt != null &&
          stat.modified == _seenChangedAt &&
          stat.size == _seenSize) {
        return;
      }
    } on FileSystemException {
      return;
    }

    final fromDisk = <RunRecord>[];
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! List) return;
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) fromDisk.add(RunRecordMapper.fromMap(entry));
      }
    } catch (_) {
      // Caught it half-written. Leave the stamps alone so we try again next
      // time rather than settling for what we managed to read.
      return;
    }

    final ours = {
      for (final r in _records)
        if (_ourRunIds.contains(r.id)) r.id: r,
    };
    final merged = <RunRecord>[
      for (final r in fromDisk) ours.remove(r.id) ?? r,
      // Ours that haven't reached the file yet.
      ...ours.values,
    ]..sort((a, b) => b.id.compareTo(a.id));

    _records
      ..clear()
      ..addAll(merged);
    _seenChangedAt = stat.modified;
    _seenSize = stat.size;
  }

  /// Notes what the file looks like now, so our own writing doesn't read as
  /// somebody else's change.
  void _noteFileAsSeen() {
    try {
      final stat = File(indexPath).statSync();
      if (stat.type == FileSystemEntityType.notFound) return;
      _seenChangedAt = stat.modified;
      _seenSize = stat.size;
    } on FileSystemException {
      // Nothing worth doing; the next look just re-reads.
    }
  }

  /// Adds any run in the file that this copy doesn't know about. Runs we do
  /// know about keep what we have, because we are the one running them.
  void _takeInRunsFromDisk() {
    final file = File(indexPath);
    if (!file.existsSync()) return;

    final known = {for (final r in _records) r.id};
    final extras = <RunRecord>[];
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! List) return;
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        final record = RunRecordMapper.fromMap(entry);
        if (!known.contains(record.id)) extras.add(record);
      }
    } catch (_) {
      // A half-written or damaged file must not stop this run being recorded.
      return;
    }
    if (extras.isEmpty) return;

    // Ids start with the run's UTC timestamp, so newest first is a plain
    // reverse sort.
    _records
      ..addAll(extras)
      ..sort((a, b) => b.id.compareTo(a.id));
  }

  /// Keeps the newest [runsToKeep] runs and throws the rest away, log files
  /// included.
  ///
  /// What goes is the record of a run and the run's own log — the story of what
  /// happened. What a run actually fetched is never touched: the mods index, the
  /// per-topic detail files, every cache, and the published bundle all live
  /// outside the `runs/` folder and are left exactly as they are. Losing old
  /// paperwork is fine; re-scraping the forum because we deleted its results is
  /// not.
  ///
  /// A run that has not ended is never dropped, however old it looks — the
  /// oldest thing in the folder should not disappear while it is still being
  /// written to. In practice a live run is the newest anyway; this is here so
  /// that stays true if it ever isn't.
  void _dropOldRuns() {
    if (runsToKeep <= 0 || _records.length <= runsToKeep) return;

    final kept = <RunRecord>[];
    final dropped = <RunRecord>[];
    for (final record in _records) {
      final live =
          record.state == RunState.running || record.state == RunState.queued;
      if (live || kept.length < runsToKeep) {
        kept.add(record);
      } else {
        dropped.add(record);
      }
    }
    if (dropped.isEmpty) return;

    _records
      ..clear()
      ..addAll(kept);

    for (final record in dropped) {
      _ourRunIds.remove(record.id);
      final log = _logFileToDelete(record);
      if (log == null) continue;
      try {
        if (log.existsSync()) log.deleteSync();
      } on FileSystemException {
        // A log we can't delete is untidy, not broken. The record is gone
        // either way.
      }
    }
  }

  /// The run's log file, but only if it really is a log file sitting directly
  /// in the `runs/` folder. Anything else gets left alone.
  ///
  /// We write these names ourselves, so in normal life this always says yes.
  /// The check is here because the name is read back from a file on disk, and
  /// this is the one place that deletes things: a hand-edited or damaged index
  /// naming `../mods-index.json` must not be able to talk us into deleting
  /// scraped data.
  File? _logFileToDelete(RunRecord record) {
    final name = record.logFileName;
    if (name.isEmpty || !name.endsWith('.log')) return null;

    final full = p.canonicalize(p.join(runsPath, name));
    if (!p.equals(p.dirname(full), p.canonicalize(runsPath))) return null;
    return File(full);
  }

  void _put(RunRecord record) {
    for (var i = 0; i < _records.length; i++) {
      if (_records[i].id == record.id) {
        _records[i] = record;
        return;
      }
    }
    _records.insert(0, record);
  }

  /// `20260721T153000Z-rescrapeTopics`, with a counter added if two runs of the
  /// same kind start in the same second.
  String _makeId(JobKind kind, DateTime startedAt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${startedAt.year}${two(startedAt.month)}'
        '${two(startedAt.day)}T${two(startedAt.hour)}'
        '${two(startedAt.minute)}${two(startedAt.second)}Z';
    final base = '$stamp-${kind.name}';
    if (byId(base) == null) return base;
    var n = 2;
    while (byId('$base-$n') != null) {
      n++;
    }
    return '$base-$n';
  }
}

/// Copies log lines into one run's own log file while that run is going.
///
/// Logging is set up once for the whole program, so this hooks into it rather
/// than reworking it. Only one job runs at a time, so every line that arrives
/// while a run is active belongs to that run.
class RunLogCapture {
  final String _path;
  IOSink? _out;
  void Function(LogLevel, String)? _appender;

  RunLogCapture(this._path);

  /// The log file this capture writes to.
  String get path => _path;

  /// Starts copying lines into the file, replacing anything already there.
  Future<void> start() async {
    if (_out != null) return;
    final file = File(_path);
    await file.parent.create(recursive: true);
    final out = file.openWrite(mode: FileMode.write);
    _out = out;

    void copyLine(LogLevel level, String line) {
      try {
        out.writeln(line);
      } catch (_) {
        // The file is closing or gone. Losing a log line must never take the
        // run down with it.
      }
    }

    // One reference, held onto, so the very same function can be taken off the
    // list again when the run ends.
    final void Function(LogLevel, String) appender = copyLine;
    _appender = appender;
    DebugTree.extraAppenders.add(appender);
  }

  /// Stops copying and closes the file.
  Future<void> stop() async {
    final appender = _appender;
    if (appender != null) DebugTree.extraAppenders.remove(appender);
    _appender = null;
    final out = _out;
    _out = null;
    if (out != null) {
      try {
        await out.flush();
      } catch (_) {
        // Nothing useful to do; the run is already over.
      }
      await out.close();
    }
  }
}
