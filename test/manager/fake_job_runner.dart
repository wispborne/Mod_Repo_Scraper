import 'dart:async';

import 'package:mod_repo_scraper/manager/cancel_token.dart';
import 'package:mod_repo_scraper/manager/job.dart';
import 'package:mod_repo_scraper/manager/run_reporter.dart';
import 'package:mod_repo_scraper/manager/scraper_service.dart';

/// A job that does whatever the test tells it to.
///
/// It reports a phase and some progress so the live view has something to show,
/// then waits for [release] (or finishes at once when nothing is holding it).
class FakeJobRunner implements JobRunner {
  /// Requests it was asked to run, in order.
  final List<JobRequest> ran = [];

  /// When set, the job throws this instead of finishing.
  Object? throwThis;

  /// The phase name it announces.
  String phaseName = 'Working';

  /// What it says it is working on.
  String itemName = 'Some mod';

  /// How many items it claims there are.
  int itemsTotal = 3;

  /// What it says its running totals are, when it reports progress. Null means
  /// it says nothing about them, as a job that cannot count them would.
  int? reportErrors;
  int? reportLlmCalls;

  /// Completed by the job once it has reported its first progress, so a test
  /// can look at the live view at a moment it knows the job has reached.
  final Completer<void> started = Completer<void>();

  Completer<void>? _gate;

  /// Makes the next job wait until [release] is called.
  void holdUntilReleased() => _gate = Completer<void>();

  void release() {
    final gate = _gate;
    _gate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<JobOutcome> runJob(
    JobRequest request, {
    RunReporter reporter = const SilentRunReporter(),
    CancelToken? cancel,
    String? runId,
  }) async {
    ran.add(request);
    reporter.phase(phaseName);
    reporter.progress(1, itemsTotal,
        item: itemName, errors: reportErrors, llmCalls: reportLlmCalls);
    if (!started.isCompleted) started.complete();

    final gate = _gate;
    if (gate != null) await gate.future;

    final error = throwThis;
    if (error != null) throw error;

    return JobOutcome(
      itemsDone: itemsTotal,
      itemsTotal: itemsTotal,
      cancelled: cancel?.isCancelled ?? false,
    );
  }
}
