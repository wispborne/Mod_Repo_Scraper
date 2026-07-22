import 'dart:async';

import 'package:path/path.dart' as p;

import 'cancel_token.dart';
import 'data_lock.dart';
import 'job.dart';
import 'run_history_store.dart';
import 'run_reporter.dart';
import 'scraper_service.dart';

/// How the running job is getting on, right now.
///
/// This is the live view, not the record: phase and current item are only
/// interesting while a run is going, so they are kept in memory and never
/// written to disk. The record keeps what is worth keeping.
class RunStatusSnapshot {
  /// The run this is about.
  final String runId;

  /// The stretch of work it is in, e.g. "Scraping topics".
  final String? phase;

  /// What it is working on right now — usually a mod title.
  final String? item;

  /// How far the phase has got. [itemsTotal] of 0 means "not known yet".
  final int itemsDone;
  final int itemsTotal;

  const RunStatusSnapshot({
    required this.runId,
    this.phase,
    this.item,
    this.itemsDone = 0,
    this.itemsTotal = 0,
  });

  /// Set [clearItem] when the new phase means the old item no longer applies.
  RunStatusSnapshot copyWith({
    String? phase,
    String? item,
    bool clearItem = false,
    int? itemsDone,
    int? itemsTotal,
  }) =>
      RunStatusSnapshot(
        runId: runId,
        phase: phase ?? this.phase,
        item: clearItem ? null : (item ?? this.item),
        itemsDone: itemsDone ?? this.itemsDone,
        itemsTotal: itemsTotal ?? this.itemsTotal,
      );

  Map<String, dynamic> toMap() => {
        'runId': runId,
        'phase': phase,
        'item': item,
        'itemsDone': itemsDone,
        'itemsTotal': itemsTotal,
      };
}

/// Takes job requests, runs them one at a time, and keeps the run history up to
/// date.
///
/// One at a time on purpose: the files on disk assume a single writer, and
/// nothing about politely scraping a forum wants two runs at once. A request
/// made while something is running waits its turn. When a [DataLock] is given,
/// that promise reaches across processes too — a server and a standalone CLI
/// pointed at one folder take turns instead of trampling each other.
class JobManager {
  final JobRunner service;
  final RunHistoryStore history;

  /// Guards the data folder against other processes. Null means "this is the
  /// only writer", which is what tests usually want.
  final DataLock? lock;

  /// Builds the reporter for a job. The CLI hands back a console reporter; a
  /// test hands back one that just records.
  final RunReporter Function(JobRequest request) _makeReporter;

  final List<_QueuedJob> _queue = [];
  _QueuedJob? _current;
  RunStatusSnapshot? _liveStatus;
  bool _draining = false;

  JobManager({
    required this.service,
    required this.history,
    this.lock,
    RunReporter Function(JobRequest request)? makeReporter,
  }) : _makeReporter = makeReporter ?? ((_) => const SilentRunReporter());

  /// The run happening right now, or null when nothing is running.
  RunRecord? get currentRun => _current?.record;

  /// How the running job is getting on, or null when nothing is running.
  RunStatusSnapshot? get liveStatus => _liveStatus;

  /// The runs waiting their turn, in the order they will run.
  List<RunRecord> get queuedRuns =>
      List.unmodifiable(_queue.map((j) => j.record));

  /// Reads the run history and marks anything left over from a run that died
  /// as interrupted. Call once at startup.
  Future<void> load() => history.load();

  /// Adds a job to the queue and returns once it has finished. The returned
  /// record says how it went.
  Future<RunRecord> submit(JobRequest request) async =>
      (await _enqueue(request)).done.future;

  /// Adds a job to the queue and returns its record straight away, without
  /// waiting for the run. For callers that watch progress some other way — the
  /// HTTP API answers with this rather than holding the connection open for the
  /// length of a scrape.
  Future<RunRecord> enqueue(JobRequest request) async =>
      (await _enqueue(request)).record;

  /// Asks the running job to stop. It stops between topics, keeps everything it
  /// has already saved, and its record says it was cancelled.
  void cancelCurrent() => _current?.cancel.cancel();

  Future<_QueuedJob> _enqueue(JobRequest request) async {
    final record = await history.startRun(request);
    final job = _QueuedJob(request, record.copyWith(state: RunState.queued));
    await history.update(job.record);
    _queue.add(job);
    unawaited(_drain());
    return job;
  }

  /// Runs queued jobs until the queue is empty. Only ever one at a time.
  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final job = _queue.removeAt(0);
        _current = job;
        _liveStatus = RunStatusSnapshot(runId: job.record.id);
        try {
          await _runOne(job);
        } finally {
          _current = null;
          _liveStatus = null;
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _runOne(_QueuedJob job) async {
    final reporter = _makeReporter(job.request);
    final capture =
        RunLogCapture(p.join(history.runsPath, job.record.logFileName));
    await capture.start();

    // Waiting for another process happens before the run counts as started, so
    // "how long did it take" doesn't include time spent queuing behind someone
    // else. The wait is logged into this run's own log.
    await lock?.acquire(log: reporter.log);

    job.record = await history.update(job.record.copyWith(
      state: RunState.running,
      startedAt: DateTime.now().toUtc(),
    ));

    try {
      final outcome = await service.runJob(
        job.request,
        reporter: _HistoryReporter(reporter, history, job, this),
        cancel: job.cancel,
      );
      job.record = await history.update(job.record.copyWith(
        state: outcome.cancelled ? RunState.cancelled : RunState.completed,
        finishedAt: DateTime.now().toUtc(),
        counters: outcome.toCounters(),
        guardrailStop: outcome.guardrailStop,
      ));
    } catch (e, stackTrace) {
      job.record = await history.update(job.record.copyWith(
        state: RunState.failed,
        finishedAt: DateTime.now().toUtc(),
        errorMessage: '$e',
      ));
      reporter.log('Job ${job.record.id} failed: $e\n$stackTrace');
    } finally {
      if (reporter is ConsoleRunReporter) reporter.finish();
      await lock?.release();
      await capture.stop();
      job.done.complete(job.record);
    }
  }

  /// Keeps the live view in step with what the reporter is being told.
  void _noteStatus({
    String? phase,
    String? item,
    bool clearItem = false,
    int? done,
    int? total,
  }) {
    final current = _liveStatus;
    if (current == null) return;
    _liveStatus = current.copyWith(
      phase: phase,
      item: item,
      clearItem: clearItem,
      itemsDone: done,
      itemsTotal: total,
    );
  }
}

/// A job waiting its turn, or running.
class _QueuedJob {
  final JobRequest request;
  RunRecord record;
  final CancelToken cancel = CancelToken();
  final Completer<RunRecord> done = Completer<RunRecord>();

  _QueuedJob(this.request, this.record);
}

/// Passes everything on to the real reporter, and keeps the run's counters and
/// the manager's live view up to date on the way past. The history store decides
/// how often that reaches the disk.
class _HistoryReporter implements RunReporter {
  final RunReporter _inner;
  final RunHistoryStore _history;
  final _QueuedJob _job;
  final JobManager _manager;

  _HistoryReporter(this._inner, this._history, this._job, this._manager);

  @override
  void phase(String name) {
    _inner.phase(name);
    // A new phase starts its counts again, and the old item no longer applies.
    _manager._noteStatus(phase: name, clearItem: true, done: 0, total: 0);
  }

  @override
  void progress(int done, int total,
      {String? item, int? errors, int? llmCalls}) {
    _inner.progress(done, total, item: item, errors: errors, llmCalls: llmCalls);
    _manager._noteStatus(item: item, done: done, total: total);
    // Errors and LLM calls are only copied when the job actually said something
    // about them. A job that can't count them as it goes leaves them alone, and
    // the job's own answer fills them in at the end.
    final counters = _job.record.counters.copyWith(
      itemsDone: done,
      itemsTotal: total,
      errors: errors ?? _job.record.counters.errors,
      llmCalls: llmCalls ?? _job.record.counters.llmCalls,
    );
    unawaited(_history
        .reportProgress(_job.record, counters)
        .then((updated) => _job.record = updated));
  }

  @override
  void log(String line) => _inner.log(line);
}
