// The new viewer's only manager status poller. Pages and the status bar
// subscribe to it. Copied from web/manager.js, which will be removed
// when the new viewer replaces the old one.

const STATUS_URL = '/api/manager/status';
const BUSY_MS = 1000;
const IDLE_MS = 5000;

// Null before the first answer.
let lastStatus = null;
const listeners = new Set();
let timer = null;
// Concurrent requests share the pending response.
let inFlight = null;

/// The last answer: { on, reason, current, queued, offline }.
export function status() {
  return lastStatus;
}

/// Calls `fn` immediately with the last response, if available, then with
/// each new response. Returns a function to unsubscribe.
export function subscribe(fn) {
  listeners.add(fn);
  if (lastStatus) safely(fn, lastStatus);
  start();
  return () => {
    listeners.delete(fn);
    if (listeners.size === 0) stop();
  };
}

/// Fetches status now, for example after a job starts or stops.
export function refresh() {
  if (!inFlight) inFlight = askOnce();
  return inFlight;
}

export function isBusy(s) {
  return !!(s && s.on && (s.current || (s.queued && s.queued.length)));
}

function safely(fn, value) {
  try {
    fn(value);
  } catch (err) {
    console.error(err);
  }
}

function announce(s) {
  lastStatus = s;
  for (const fn of [...listeners]) safely(fn, s);
}

async function askOnce() {
  try {
    const res = await fetch(STATUS_URL, { headers: { accept: 'application/json' } });
    const body = await res.json().catch(() => ({}));
    if (res.status === 503 || body.managerOn === false) {
      announce({
        on: false,
        reason: body.error || 'Jobs are turned off on this server.',
        current: null,
        queued: [],
      });
    } else if (!res.ok) {
      announce({
        on: false,
        reason: `Server returned ${res.status} ${res.statusText}.`,
        current: null,
        queued: [],
      });
    } else {
      announce({ on: true, current: body.current || null, queued: body.queued || [] });
    }
  } catch {
    announce({
      on: false,
      reason: 'Cannot reach the server.',
      current: null,
      queued: [],
      offline: true,
    });
  } finally {
    inFlight = null;
    reschedule();
  }
  return lastStatus;
}

function reschedule() {
  clearTimeout(timer);
  timer = null;
  if (listeners.size === 0 || document.hidden) return;
  timer = setTimeout(refresh, isBusy(lastStatus) ? BUSY_MS : IDLE_MS);
}

function start() {
  if (timer || inFlight) return;
  refresh();
}

function stop() {
  clearTimeout(timer);
  timer = null;
}

document.addEventListener('visibilitychange', () => {
  if (document.hidden) stop();
  else if (listeners.size) start();
});

/// How the last run this page saw running ended: 'completed', 'failed',
/// another state, or null. Cleared when a new run starts or the page changes.
let watchedRunId = null;
let ended = null;

export function endedRun() {
  return ended;
}

export function forgetEndedRun() {
  ended = null;
}

/// Notices a run ending. When the run this page saw is no longer current,
/// its record is fetched to learn how it ended. `onChange` is called after.
export function watchRunEnds(onChange) {
  return subscribe(async (s) => {
    const current = s.current && s.current.record;
    if (current) {
      if (current.id !== watchedRunId) ended = null;
      watchedRunId = current.id;
      onChange();
      return;
    }
    if (watchedRunId) {
      const id = watchedRunId;
      watchedRunId = null;
      try {
        const res = await fetch(`/api/manager/runs/${encodeURIComponent(id)}`);
        const record = res.ok ? await res.json() : null;
        ended = record && record.state ? record.state : null;
      } catch {
        ended = null;
      }
    }
    onChange();
  });
}
