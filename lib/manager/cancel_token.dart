/// A "please stop" flag a running job checks between topics.
///
/// Stopping is cooperative: the job finishes the topic it is on, then stops.
/// Everything is saved as the run goes, so nothing that was already done is
/// lost.
class CancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}
