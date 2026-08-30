// The one place the frontend talks to the management API.
//
// Three jobs, all shared by every view:
//   1. Ask the server what is happening, on a sensible beat, and tell whoever
//      is listening.
//   2. Send jobs, and turn the server's answer into words a person can read.
//   3. Remember which topics are ticked, so the selection survives paging,
//      searching, and moving between views.
//
// Nothing here knows about any particular view, and no view polls on its own.

import { el, clear, askDialog } from './lib.js';

const STATUS_URL = '/api/manager/status';
const BASE = '/api/manager';

// How often to ask. Fast while there is something to watch, slow otherwise.
const BUSY_MS = 1000;
const IDLE_MS = 5000;

/// What each kind of job is called in the interface.
export const KIND_LABELS = {
  fullRun: 'Full run',
  rescrapeTopics: 'Re-scrape topics',
  resolveDownloads: 'Re-resolve downloads',
  extractLlm: 'Re-run LLM extraction',
  llmCoveragePass: 'LLM coverage pass',
  llmTest: 'LLM test',
  rebuildBundle: 'Rebuild bundle',
  mergeModRepo: 'Merge from saved files',
  scrapeAndMerge: 'Scrape then merge',
  publishOutputs: 'Publish to GitHub',
};

export function kindLabel(kind) {
  return KIND_LABELS[kind] || kind || 'Job';
}

/// What each run state is called, and which badge colour suits it.
export const STATE_BADGES = {
  queued: 'badge-dim',
  running: 'badge-primary',
  completed: 'badge-success',
  failed: 'badge-error',
  cancelled: 'badge-warning',
  interrupted: 'badge-warning',
};

// --- Status, and who is listening ---

// The last answer we got, so a view that starts up mid-beat has something to
// draw straight away. `null` means "we have not asked yet".
let lastStatus = null;
const listeners = new Set();
let timer = null;
// The ask that is on its way, if there is one. Anyone asking for a refresh
// while it is in flight waits for that same answer rather than sending a second
// request or, worse, getting back "we don't know yet".
let inFlight = null;

/// The last thing the server said. Shape:
///   { on, reason, dataPath, current, queued }
/// `on: false` means the server has no manager (no config file) — that is a
/// way to run the viewer, not a fault.
export function status() {
  return lastStatus;
}

/// Listen for status. The callback fires right away with whatever we already
/// know (if anything), then on every fresh answer. Returns a function that
/// stops the listening.
export function subscribe(fn) {
  listeners.add(fn);
  if (lastStatus) {
    try {
      fn(lastStatus);
    } catch (err) {
      console.error(err);
    }
  }
  start();
  return () => {
    listeners.delete(fn);
    if (listeners.size === 0) stop();
  };
}

/// Ask now, without waiting for the next beat. Used after starting or
/// cancelling a job so the interface catches up at once.
export function refresh() {
  return poll();
}

function isBusy(s) {
  return !!(s && s.on && (s.current || (s.queued && s.queued.length)));
}

function announce(s) {
  lastStatus = s;
  for (const fn of [...listeners]) {
    try {
      fn(s);
    } catch (err) {
      console.error(err);
    }
  }
}

function poll() {
  if (!inFlight) inFlight = askOnce();
  return inFlight;
}

async function askOnce() {
  try {
    const res = await fetch(STATUS_URL, { headers: { accept: 'application/json' } });
    const body = await res.json().catch(() => ({}));
    if (res.status === 503 || body.managerOn === false) {
      announce({
        on: false,
        reason: body.error || 'The manager is off on this server.',
        current: null,
        queued: [],
      });
    } else if (!res.ok) {
      announce({
        on: false,
        reason: `The server answered ${res.status} ${res.statusText}.`,
        current: null,
        queued: [],
      });
    } else {
      announce({
        on: true,
        dataPath: body.dataPath,
        current: body.current || null,
        queued: body.queued || [],
      });
    }
  } catch (err) {
    announce({
      on: false,
      reason: 'The server could not be reached.',
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
  if (listeners.size === 0) return;
  if (document.hidden) return; // Nothing to see; pick up again on show.
  timer = setTimeout(poll, isBusy(lastStatus) ? BUSY_MS : IDLE_MS);
}

function start() {
  if (timer || inFlight) return;
  poll();
}

function stop() {
  clearTimeout(timer);
  timer = null;
}

document.addEventListener('visibilitychange', () => {
  if (document.hidden) stop();
  else if (listeners.size) start();
});

// --- Sending jobs ---

/// POSTs to a management route and returns the answer. On a refusal, throws an
/// Error carrying the server's own message — those are already written for
/// people to read, so we never invent our own wording on top.
async function post(path, body) {
  const res = await fetch(BASE + path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body || {}),
  });
  const answer = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(answer.error || `The server answered ${res.status} ${res.statusText}.`);
  }
  return answer;
}

/// Starts a job. `request` is a JobRequest as the API expects it.
export async function submitJob(request) {
  const record = await post('/jobs', request);
  refresh();
  return record;
}

/// Asks the running job to stop. When a run id is supplied, the server checks
/// it before stopping anything. This keeps an old page from stopping the next
/// run if the one it was showing finished just before the click arrived.
export async function cancelCurrent(runId = null) {
  const answer = await post('/jobs/cancel', runId ? { runId } : {});
  refresh();
  return answer;
}

// --- Saying what a job will do, and asking first ---

/// One plain sentence describing a job, including what it costs.
export function describeJob(request) {
  const count = (request.topicIds || []).length;
  const topics = count === 1 ? '1 topic' : `${count} topics`;
  switch (request.kind) {
    case 'rescrapeTopics':
      return `Re-scrape ${topics} fresh from the forum, then work out their `
        + 'downloads again and ask the LLM again. This makes network requests '
        + 'and may spend LLM budget.';
    case 'resolveDownloads':
      return `Work out the downloads for ${topics} again, from the posts `
        + 'already saved. This makes network requests to check the links.';
    case 'extractLlm':
      return `Ask the LLM about ${topics} again, from the posts already saved. `
        + 'This may spend LLM budget.';
    case 'fullRun': {
      const boards = listBoards(request.boards);
      const llm = request.runLlm ? ', and ask the LLM about each one' : '';
      return `Go through ${describeScope(request.scope)} on ${boards}, save what `
        + `it finds${llm}. This one takes a while: it makes a lot of network `
        + `requests${request.runLlm ? ' and may spend LLM budget' : ''}.`;
    }
    case 'llmCoveragePass':
      return 'Go through every stored topic and ask the LLM about any that have '
        + 'no answers yet. No scraping. This may spend LLM budget, up to the '
        + 'run cap the server was started with.';
    case 'rebuildBundle':
      return 'Build forum-data-bundle.json again from what is already saved. '
        + 'No network requests, no LLM spending.';
    case 'llmTest':
      return 'Try the LLM prompt on a few topics and write a report. Nothing '
        + 'else is saved. This spends a little LLM budget.';
    case 'mergeModRepo':
      return 'Merge the mod sources already saved on disk into ModRepo.json. '
        + 'No network requests, no LLM spending. Safe to run again and again.';
    case 'scrapeAndMerge':
      return `Fetch ${listSources(request.modSources)} fresh, then merge them `
        + 'into ModRepo.json. This one goes out to the mod sites and can take a '
        + 'few minutes. No LLM spending.';
    case 'publishOutputs':
      return 'Push the current ModRepo.json and forum-data-bundle.json to the '
        + 'GitHub repo TriOS reads. Publishes whatever is in outputs/ right now. '
        + 'If nothing changed since last time, nothing is pushed.';
    default:
      return `Run a "${request.kind}" job.`;
  }
}

/// The boards as you would say them: "the main and libraries boards".
function listBoards(boards) {
  const names = { main: 'main', lesser: 'lesser mods', libraries: 'libraries' };
  const picked = (boards || []).map((b) => names[b] || b);
  if (!picked.length) return 'no boards at all';
  if (picked.length === 1) return `the ${picked[0]} board`;
  const last = picked.pop();
  return `the ${picked.join(', ')} and ${last} boards`;
}

/// The mod sources as you would say them: "the forum and Nexus".
function listSources(sources) {
  const names = { forum: 'the forum', discord: 'Discord', nexus: 'Nexus' };
  const picked = (sources || []).map((s) => names[s] || s);
  if (!picked.length) return 'no sources at all';
  if (picked.length === 1) return picked[0];
  const last = picked.pop();
  return `${picked.join(', ')} and ${last}`;
}

/// What a scope means, in words rather than in its config-file spelling.
function describeScope(scope) {
  switch (scope) {
    case 'all':
      return 'every topic';
    case 'pages':
      return 'the first few pages';
    case 'librariesOnly':
      return 'the libraries board';
    case 'topics':
      return 'the named topics';
    default:
      return 'anything new or changed';
  }
}

/// Describes the job, asks, and sends it if the answer is yes. Returns the new
/// run record, or null when the user said no.
export async function confirmAndSubmit(request) {
  const yes = await askDialog({
    title: kindLabel(request.kind),
    message: describeJob(request),
    confirmLabel: 'Start it',
  });
  if (!yes) return null;
  return submitJob(request);
}

// --- The ticked topics ---

// The ticked topics survive a reload by riding in sessionStorage — a half-built
// selection shouldn't vanish just because the page was refreshed. It is cleared
// when a job is started with it, or by the Clear button.
const SELECTION_KEY = 'viewerSelectedTopics';

function loadSelection() {
  try {
    const raw = sessionStorage.getItem(SELECTION_KEY);
    if (raw) return new Set(JSON.parse(raw).map(Number));
  } catch (_) {
    // A bad or blocked store just means we start with nothing ticked.
  }
  return new Set();
}

function saveSelection() {
  try {
    sessionStorage.setItem(SELECTION_KEY, JSON.stringify([...selected]));
  } catch (_) {
    // Not being able to save is not worth bothering the user about.
  }
}

const selected = loadSelection();
const selectionListeners = new Set();

export const selection = {
  has: (id) => selected.has(Number(id)),
  count: () => selected.size,
  ids: () => [...selected].sort((a, b) => a - b),
  add(id) {
    selected.add(Number(id));
    announceSelection();
  },
  remove(id) {
    selected.delete(Number(id));
    announceSelection();
  },
  toggle(id, on) {
    if (on) selected.add(Number(id));
    else selected.delete(Number(id));
    announceSelection();
  },
  clear() {
    selected.clear();
    announceSelection();
  },
  /// Listen for changes. Returns a function that stops the listening.
  subscribe(fn) {
    selectionListeners.add(fn);
    return () => selectionListeners.delete(fn);
  },
};

function announceSelection() {
  saveSelection();
  for (const fn of [...selectionListeners]) {
    try {
      fn(selection.count());
    } catch (err) {
      console.error(err);
    }
  }
}

// --- The header chip ---

/// Draws the little "what's happening" chip in the top bar and keeps it up to
/// date. It is on every page, so you never have to wonder whether something is
/// running. Clicking it opens the Runs view.
export function mountHeaderChip(node) {
  if (!node) return;
  node.setAttribute('href', '#/runs');
  subscribe((s) => drawChip(node, s));
  drawChip(node, status());
}

/// The chip is a status dot, a short word or two, and — while a job runs — a
/// progress bar. The dot colour carries the state at a glance: grey when off,
/// green when ready, amber when jobs wait, cyan and pulsing while one runs.
function drawChip(node, s) {
  clear(node);

  const row = (stateClass, dotClass, text) => {
    node.className = 'status-chip ' + stateClass;
    node.append(el('div', { class: 'status-chip-row' }, [
      el('span', { class: 'status-dot ' + dotClass }),
      el('span', { class: 'status-chip-text', text }),
    ]));
  };

  if (!s) {
    row('loading-chip', 'pulse', 'Checking…');
    return;
  }
  if (!s.on) {
    row('off', '', 'Viewing only');
    node.title = s.reason || 'The manager is off on this server.';
    return;
  }
  const current = s.current;
  if (!current) {
    const waiting = (s.queued || []).length;
    if (waiting) {
      row('waiting', '', `${waiting} waiting`);
      node.title = 'Jobs are queued but nothing is running yet. Click to see them.';
    } else {
      row('ready', '', 'Ready');
      node.title = 'Nothing is running. Click to start a job.';
    }
    return;
  }

  const record = current.record || {};
  const done = current.itemsDone || 0;
  const total = current.itemsTotal || 0;
  const label = kindLabel(record.request && record.request.kind);
  const counts = total > 0 ? ` ${done}/${total}` : '';
  row('running', 'pulse', label + counts);
  node.append(el('div', { class: 'status-chip-bar' }, [
    el('div', {
      class: 'status-chip-bar-fill',
      style: `width: ${total > 0 ? Math.min(100, (done / total) * 100) : 0}%`,
    }),
  ]));
  node.title = [current.phase, current.item].filter(Boolean).join(' — ')
    || 'A job is running. Click to watch it.';
}

// --- Small shared formatting ---

export function fmtTime(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return String(iso);
  return d.toLocaleString();
}

/// How long a run took, or how long it has been going.
export function fmtDuration(startedAt, finishedAt) {
  if (!startedAt) return '—';
  const start = new Date(startedAt).getTime();
  const end = finishedAt ? new Date(finishedAt).getTime() : Date.now();
  if (Number.isNaN(start) || Number.isNaN(end)) return '—';
  let s = Math.max(0, Math.round((end - start) / 1000));
  const h = Math.floor(s / 3600);
  s -= h * 3600;
  const m = Math.floor(s / 60);
  s -= m * 60;
  if (h) return `${h}h ${m}m`;
  if (m) return `${m}m ${s}s`;
  return `${s}s`;
}
