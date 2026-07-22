import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'job.dart';
import 'run_reporter.dart';

/// Why the command line is doing the work itself instead of handing it to a
/// server, in words meant for whoever is watching the console.
typedef FallbackReason = String;

/// Hands the QB job to a manager server and watches it from the command line.
///
/// The point is that a run started here and a run started from a browser share
/// one queue and one history, instead of two processes writing the same folder.
/// When that can't be arranged — nothing answers, the server has no manager, or
/// it is working on a different folder — this says so plainly and hands the job
/// back, and the command line runs it as it always did. A delegation problem
/// never means the job is quietly skipped.
class ManagerDelegate {
  /// Where the server is, e.g. `http://127.0.0.1:8085`.
  final Uri baseUrl;

  /// The folder this command line means, as an absolute path.
  final String dataPath;

  /// Where progress and messages go. The same console reporter a local run
  /// uses, so a delegated run looks the same.
  final RunReporter reporter;

  final http.Client _client;

  /// How often to ask the server how it is getting on.
  final Duration pollInterval;

  /// How long to wait for one answer from the server.
  final Duration requestTimeout;

  /// How many lines of the run's log to print when it fails.
  final int failureLogTail;

  ManagerDelegate({
    required String managerUrl,
    required String dataPath,
    required this.reporter,
    http.Client? client,
    this.pollInterval = const Duration(seconds: 1),
    this.requestTimeout = const Duration(seconds: 15),
    this.failureLogTail = 50,
  })  : baseUrl = Uri.parse(
          managerUrl.endsWith('/')
              ? managerUrl.substring(0, managerUrl.length - 1)
              : managerUrl,
        ),
        dataPath = p.normalize(p.absolute(dataPath)),
        _client = client ?? http.Client();

  Uri _url(String path) => Uri.parse('$baseUrl/api/manager$path');

  /// Checks the server can take this job. Returns null when it can, or the
  /// reason to run the job here instead.
  Future<FallbackReason?> check() async {
    final Map<String, dynamic> status;
    try {
      final res = await _client.get(_url('/status')).timeout(requestTimeout);
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        return 'the manager at $baseUrl answered with something unexpected';
      }
      status = decoded;
    } catch (e) {
      return 'the manager at $baseUrl could not be reached ($e)';
    }

    if (status['managerOn'] != true) {
      final why = status['error'] as String?;
      return 'the server at $baseUrl has its manager switched off'
          '${why == null ? '' : ' ($why)'}';
    }

    final theirPath = status['dataPath'] as String?;
    if (theirPath == null || !p.equals(theirPath, dataPath)) {
      return 'the manager at $baseUrl works on $theirPath but this run is '
          'about $dataPath';
    }
    return null;
  }

  /// Hands [request] to the server and watches it to the end.
  ///
  /// Returns the finished record, or null when the job was not delegated after
  /// all and should be run here (the reason has already been reported).
  /// [interrupts] is Ctrl-C: the first one asks the server to stop and keeps
  /// watching until the run settles; a second one gives up watching and returns
  /// the last known record.
  Future<RunRecord?> run(
    JobRequest request, {
    Stream<void>? interrupts,
  }) async {
    final reason = await check();
    if (reason != null) {
      reporter.log('Not using the manager server: $reason. Running the job '
          'here instead.');
      return null;
    }

    final RunRecord queued;
    try {
      queued = await _submit(request);
    } catch (e) {
      reporter.log('The manager at $baseUrl would not take the job ($e). '
          'Running the job here instead.');
      return null;
    }
    reporter.log('The manager at $baseUrl took the job as run ${queued.id}.');

    var interruptCount = 0;
    StreamSubscription<void>? interruptSub;
    var giveUpWatching = false;
    interruptSub = interrupts?.listen((_) {
      interruptCount++;
      if (interruptCount == 1) {
        reporter.log('Stopping... asking the manager to stop run ${queued.id}. '
            'It stops between topics and keeps what it has saved. Press Ctrl-C '
            'again to stop watching and leave it to finish.');
        unawaited(_cancel());
      } else {
        giveUpWatching = true;
      }
    });

    try {
      var record = queued;
      while (!giveUpWatching) {
        await Future<void>.delayed(pollInterval);
        record = await _pollOnce(record);
        if (_hasSettled(record.state)) break;
      }
      if (giveUpWatching) {
        reporter.log('Leaving run ${queued.id} to the manager. Its record and '
            'log are on the server.');
      }
      await _reportEnding(record);
      return record;
    } finally {
      await interruptSub?.cancel();
    }
  }

  /// True once the run is over, one way or another.
  static bool _hasSettled(RunState state) =>
      state != RunState.queued && state != RunState.running;

  Future<RunRecord> _submit(JobRequest request) async {
    final res = await _client
        .post(
          _url('/jobs'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode(request.toMap()),
        )
        .timeout(requestTimeout);
    final decoded = jsonDecode(res.body);
    if (res.statusCode != 200 || decoded is! Map<String, dynamic>) {
      final why = decoded is Map ? decoded['error'] : res.body;
      throw StateError('$why');
    }
    return RunRecordMapper.fromMap(decoded);
  }

  Future<void> _cancel() async {
    try {
      await _client.post(_url('/jobs/cancel')).timeout(requestTimeout);
    } catch (e) {
      reporter.log('Could not ask the manager to stop: $e');
    }
  }

  /// Asks once how the run is getting on, moves the progress bar, and hands
  /// back the newest record. A hiccup answering keeps the old record rather
  /// than ending the watch.
  Future<RunRecord> _pollOnce(RunRecord known) async {
    try {
      final res = await _client.get(_url('/status')).timeout(requestTimeout);
      final status = jsonDecode(res.body) as Map<String, dynamic>;
      final current = status['current'] as Map<String, dynamic>?;
      final record = current?['record'] as Map<String, dynamic>?;

      if (record != null && record['id'] == known.id) {
        _showProgress(current!);
        return RunRecordMapper.fromMap(record);
      }
      // Not the running job any more: either it finished, or it is still
      // waiting behind something else. Its own record says which.
      return await _fetchRecord(known.id) ?? known;
    } catch (e) {
      reporter.log('Could not read the manager\'s status: $e');
      return known;
    }
  }

  /// Turns one status answer into the same phases and bar a local run shows.
  String? _lastPhase;

  void _showProgress(Map<String, dynamic> current) {
    final phase = current['phase'] as String?;
    if (phase != null && phase != _lastPhase) {
      _lastPhase = phase;
      reporter.phase(phase);
    }
    final total = (current['itemsTotal'] as int?) ?? 0;
    final done = (current['itemsDone'] as int?) ?? 0;
    if (total > 0 || done > 0) {
      reporter.progress(done, total, item: current['item'] as String?);
    }
  }

  Future<RunRecord?> _fetchRecord(String id) async {
    final res = await _client.get(_url('/runs/$id')).timeout(requestTimeout);
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;
    return RunRecordMapper.fromMap(decoded);
  }

  /// The same summary a local run prints, plus the tail of the log when the run
  /// failed, so nobody has to go hunting for it.
  Future<void> _reportEnding(RunRecord record) async {
    final counters = record.counters;
    switch (record.state) {
      case RunState.completed:
        reporter.log('Run ${record.id} finished: ${counters.itemsDone} of '
            '${counters.itemsTotal} done, ${counters.errors} error(s), '
            '${counters.llmCalls} LLM call(s).');
        if (record.guardrailStop != null) {
          reporter.log('It stopped early because ${record.guardrailStop}');
        }
      case RunState.cancelled:
        reporter.log('Run ${record.id} was stopped on request; '
            '${counters.itemsDone} topic(s) kept.');
      case RunState.failed:
        reporter.log('Run ${record.id} failed: '
            '${record.errorMessage ?? 'no reason was recorded'}');
        await _printLogTail(record.id);
      case RunState.interrupted:
        reporter.log('Run ${record.id} was interrupted — the manager stopped '
            'before it ended.');
        await _printLogTail(record.id);
      case RunState.queued:
      case RunState.running:
        reporter.log('Run ${record.id} is still going on the manager.');
    }
  }

  Future<void> _printLogTail(String id) async {
    try {
      final res = await _client
          .get(_url('/runs/$id/log?tail=$failureLogTail'))
          .timeout(requestTimeout);
      final body = jsonDecode(res.body);
      final lines = body is Map ? (body['lines'] as List?) ?? const [] : const [];
      if (lines.isEmpty) return;
      reporter.log('The last ${lines.length} line(s) of run $id\'s log:');
      for (final line in lines) {
        reporter.log('  $line');
      }
    } catch (e) {
      reporter.log('Could not read run $id\'s log from the manager: $e');
    }
  }

  void close() => _client.close();
}
