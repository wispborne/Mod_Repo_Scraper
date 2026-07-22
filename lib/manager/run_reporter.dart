import 'package:mod_repo_scraper/timber/ktx/timber_kt.dart' as timber;
import 'package:mod_repo_scraper/utilities/console_progress_bar.dart';

/// Where a job says how it is getting on.
///
/// The service only ever talks to this, so it doesn't know or care whether a
/// console, a test, or (later) a web page is listening.
abstract class RunReporter {
  /// Start of a new stretch of work, e.g. "Scraping topics". Progress reported
  /// after this belongs to the new phase.
  void phase(String name);

  /// How far the current phase has got. [total] of 0 means "not known yet".
  ///
  /// [errors] and [llmCalls] are the run's totals so far, for the jobs that
  /// know them as they go. Leaving one out means "no news", not zero — so a
  /// caller that can't count something never wipes out what is already known.
  /// They ride along with progress on purpose: the count of what a run has
  /// spent is saved as the run goes, so a run that dies still says what it
  /// cost.
  void progress(int done, int total,
      {String? item, int? errors, int? llmCalls});

  /// A line worth showing to whoever is watching.
  void log(String line);
}

/// Draws progress as a console bar and sends log lines to the normal log.
///
/// A bar is started on the first progress report of a phase, so it gets the
/// real total rather than a guess, and finished when the phase changes or the
/// job ends.
class ConsoleRunReporter implements RunReporter {
  String _phaseName = 'Working';
  ConsoleProgressBar? _bar;

  @override
  void phase(String name) {
    _bar?.finish();
    _bar = null;
    _phaseName = name;
  }

  @override
  void progress(int done, int total,
      {String? item, int? errors, int? llmCalls}) {
    _bar ??= ConsoleProgressBar.start(_phaseName, total);
    _bar!.update(done, total: total, item: item);
  }

  @override
  void log(String line) => timber.i(message: () => line);

  /// Takes the bar off the console. Call when the job ends.
  void finish() {
    _bar?.finish();
    _bar = null;
  }
}

/// Sends log lines to the normal log and draws nothing.
///
/// This is what the server uses. A job it runs has nobody watching a console,
/// but its lines still have to reach the run's own log file — that capture
/// listens to the normal log, so a reporter that drops its lines (as the silent
/// one does) leaves a run with counters and no reasons: "1 error" and no word of
/// what went wrong. Progress needs no help here; the manager already keeps the
/// counters and the live view up to date on the way past.
class LogRunReporter implements RunReporter {
  const LogRunReporter();

  @override
  void phase(String name) => timber.i(message: () => name);

  @override
  void progress(int done, int total,
      {String? item, int? errors, int? llmCalls}) {}

  @override
  void log(String line) => timber.i(message: () => line);
}

/// Keeps everything it is told, for tests.
class RecordingRunReporter implements RunReporter {
  final List<String> phases = [];
  final List<String> logs = [];
  final List<({int done, int total, String? item, int? errors, int? llmCalls})>
      updates = [];

  @override
  void phase(String name) => phases.add(name);

  @override
  void progress(int done, int total,
          {String? item, int? errors, int? llmCalls}) =>
      updates.add((
        done: done,
        total: total,
        item: item,
        errors: errors,
        llmCalls: llmCalls,
      ));

  @override
  void log(String line) => logs.add(line);
}

/// Throws everything away. Handy when a caller doesn't want to watch.
class SilentRunReporter implements RunReporter {
  const SilentRunReporter();

  @override
  void phase(String name) {}

  @override
  void progress(int done, int total,
      {String? item, int? errors, int? llmCalls}) {}

  @override
  void log(String line) {}
}
