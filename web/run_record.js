// Facts about a run record and the status, with no DOM, so Node can test
// them (test/web/run_record_test.mjs).

/// When the run was queued. A run's id starts with the time it was queued
/// (`20260721T153000Z-rescrapeTopics`). `startedAt` holds the same time
/// until the run starts, so it is used when the id has no time.
export function queuedAt(record) {
  const m = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z/.exec((record && record.id) || '');
  if (m) return `${m[1]}-${m[2]}-${m[3]}T${m[4]}:${m[5]}:${m[6]}Z`;
  return record && record.state === 'queued' ? record.startedAt || null : null;
}

/// When the run began running, or null while it waits in the queue.
export function startedAt(record) {
  if (!record || record.state === 'queued') return null;
  return record.startedAt || null;
}

/// The one time a list shows for a run: when it started, else when it was queued.
export function runTime(record) {
  return startedAt(record) || queuedAt(record);
}

/// The record's state when it says the run has ended, else null.
export function endedState(record) {
  const state = record && record.state;
  return state && state !== 'queued' && state !== 'running' ? state : null;
}

/// The id of the run the status says is running, or null.
export function currentRunId(s) {
  return s && s.current && s.current.record ? s.current.record.id : null;
}

/// Returns the next run to watch and the id of the run that just ended.
/// Keeps watching the same run if the server cannot be reached or jobs are off.
export function nextWatch(watchedId, s) {
  if (!s || !s.on) return { watchedId, endedId: null };
  const currentId = currentRunId(s);
  return { watchedId: currentId, endedId: watchedId && watchedId !== currentId ? watchedId : null };
}
