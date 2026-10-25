// Shared management API client: status polling, job actions and topic selection.
// Views subscribe to this poller rather than starting their own.

import { el, clear, askDialog } from './lib.js';

const STATUS_URL = '/api/manager/status';
const BASE = '/api/manager';

// Poll faster while jobs are active.
const BUSY_MS = 1000;
const IDLE_MS = 5000;

export const KIND_LABELS = {
  fetchAndUpdate: 'Fetch and update',
  rebuildFromSaved: 'Rebuild from saved files',
  fullRun: 'Full run',
  rescrapeTopics: 'Re-scrape topics',
  resolveDownloads: 'Recheck downloads',
  extractLlm: 'Re-run LLM extraction',
  llmCoveragePass: 'LLM catch-up',
  describePictures: 'Scan images',
  matchRequirements: 'Match dependency names',
  setRequirementNames: 'Change dependency names',
  llmTest: 'LLM test',
  rebuildBundle: 'Rebuild mod details',
  mergeModRepo: 'Merge from saved files',
  scrapeAndMerge: 'Scrape then merge',
  publishOutputs: 'Publish to GitHub',
  takeDown: 'Take down',
  restoreTakedown: 'Restore',
};

export function kindLabel(kind) {
  return KIND_LABELS[kind] || kind || 'Job';
}

export const STATE_BADGES = {
  queued: 'badge-dim',
  running: 'badge-primary',
  completed: 'badge-success',
  failed: 'badge-error',
  cancelled: 'badge-warning',
  interrupted: 'badge-warning',
};

// --- Status subscriptions ---

// New subscribers receive the cached status immediately. Null before first poll.
let lastStatus = null;
const listeners = new Set();
let timer = null;
// Concurrent refreshes share the same request and wait for its result.
let inFlight = null;

/// Cached status: { on, reason, dataPath, current, queued }.
/// `on: false` includes read-only mode and connection failures.
export function status() {
  return lastStatus;
}

/// Emits cached status immediately, then each update. Returns an unsubscribe.
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

/// Refresh status after a job starts or stops.
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
        reason: body.error || 'Job management is disabled on this server.',
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
  if (document.hidden) return; // Resume when the tab becomes visible.
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

/// Posts to a manager route, preserving the server's error message on failure.
async function post(path, body) {
  const res = await fetch(BASE + path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body || {}),
  });
  const answer = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(answer.error || `Server returned ${res.status} ${res.statusText}.`);
  }
  return answer;
}

/// Starts a job. `request` is a JobRequest as the API expects it.
export async function submitJob(request) {
  const record = await post('/jobs', request);
  refresh();
  return record;
}

/// A run id prevents an outdated page from stopping a different run.
export async function cancelCurrent(runId = null) {
  const answer = await post('/jobs/cancel', runId ? { runId } : {});
  refresh();
  return answer;
}

// --- Job confirmations ---

/// Describes the job and its network and LLM costs before submission.
export function describeJob(request) {
  const count = (request.topicIds || []).length;
  const topics = count === 1 ? '1 topic' : `${count} topics`;
  switch (request.kind) {
    case 'fetchAndUpdate':
      return describeFetchAndUpdate(request);
    case 'rebuildFromSaved':
      return 'Rebuild mod-catalog.json, mod-catalog-details.json, the old ModRepo.json '
        + 'and the website from saved files. No network or LLM calls.';
    case 'rescrapeTopics':
      return `Fetch ${topics} from the forum again, resolve downloads, and `
        + 're-run LLM extraction. This makes network requests. LLM calls may cost money.';
    case 'resolveDownloads':
      return `Recheck downloads for ${topics} using saved posts. `
        + 'This makes network requests to check the links.';
    case 'extractLlm':
      return `Re-run LLM extraction for ${topics} from saved posts. Discord `
        + 'threads joined to the same mods are read again only if their saved '
        + 'answers are out of date. LLM calls may cost money.';
    case 'fullRun': {
      const boards = listBoards(request.boards);
      const llm = request.runLlm ? ' and run LLM extraction' : '';
      return `Scrape ${describeScope(request.scope)} on ${boards}${llm}. `
        + `This makes network requests.${request.runLlm ? ' LLM calls may cost money.' : ''}`;
    }
    case 'describePictures':
      return count
        ? `Rescan all images in ${topics} and in the Discord threads `
          + 'joined to the same mods. No post is read again. Then rebuild the catalog, '
          + 'mod details, and website. LLM calls may cost money.'
        : 'Scan images in saved forum topics and Discord threads. Scan only images '
          + 'not yet scanned, or scanned with an older prompt. Stop at the per-run call '
          + 'limit. No post is read again. Then rebuild the catalog, mod details, and '
          + 'website. LLM calls may cost money.';
    case 'setRequirementNames': {
      const n = (request.requirementChanges || []).length;
      return `Save ${n} dependency ${n === 1 ? 'change' : 'changes'}. `
        + 'Rebuild the website from saved files. No network or LLM calls.';
    }
    case 'matchRequirements':
      return 'Ask the LLM to match unmatched dependency names, such as '
        + '"Graphic Lib", to mods. No post is read again. Then rebuild the catalog, mod details, '
        + 'and website. LLM calls may cost money.';
    case 'llmCoveragePass':
      return 'Update missing or outdated LLM results using saved forum topics and Discord '
        + 'threads, up to the per-run call limit. Then rebuild the catalog, mod details, '
        + 'and website. LLM calls may cost money.';
    case 'rebuildBundle':
      return 'Rebuild mod-catalog-details.json, mod-catalog.json and the website from saved '
        + 'data. No network or LLM calls.';
    case 'llmTest':
      return 'Test the LLM prompt on a few topics and save a report. '
        + 'Other data stays unchanged. LLM calls may cost money.';
    case 'mergeModRepo':
      return 'Merge saved sources into the old ModRepo.json, and rebuild mod-catalog.json '
        + 'and the website. No network or LLM calls.';
    case 'scrapeAndMerge':
      return `Fetch ${listSources(request.modSources)}, then merge into the old ModRepo.json `
        + 'and rebuild mod-catalog.json and the website. This makes network requests. '
        + 'No LLM calls.';
    case 'publishOutputs':
      return 'Publish the current outputs and website to the GitHub repo TriOS reads. '
        + 'If nothing changed, nothing is pushed.';
    case 'takeDown': {
      const what = request.takedownModId
        ? `"${request.takedownModId}"`
        : `every mod credited to ${(request.takedownAuthors || []).join(', ')}`;
      return `Add ${what} to the takedown list. Rebuild every output from saved files using the updated list`
        + `${request.publishAfter ? '. Then publish' : ''}. No network or LLM calls.`;
    }
    case 'restoreTakedown':
      return `Remove "${request.takedownEntry}" from the takedown list. Rebuild every output from saved files`
        + `${request.publishAfter ? '. Then publish' : ''}. No network or LLM calls.`;
    default:
      return `Run a "${request.kind}" job.`;
  }
}

// The confirmation must reflect unchecked sources and boards too.
function describeFetchAndUpdate(request) {
  const boards = request.boards || [];
  const others = (request.modSources || []).filter((s) => s !== 'forum');
  const kept = ['discord', 'nexus'].filter((s) => !others.includes(s));

  const steps = [];
  if (others.length) steps.push(`fetch ${listSources(others)}`);
  if (boards.length) {
    steps.push(`scrape ${describeScope(request.scope)} on ${listBoards(boards)}`);
  }
  const parts = [];
  if (steps.length) {
    const first = steps.join(', then ');
    parts.push(first.charAt(0).toUpperCase() + first.slice(1) + '.');
  } else {
    parts.push('Nothing is fetched.');
  }
  if (!boards.length) parts.push('The forum is not scraped.');
  if (kept.length) {
    parts.push(`${listSources(kept)} ${kept.length === 1 ? 'keeps its' : 'keep their'} `
      + 'saved results.');
  }
  if (request.runLlm) {
    parts.push('Update missing or outdated LLM results. LLM calls may cost money.');
  } else {
    parts.push('No LLM calls.');
  }
  parts.push('Then rebuild mod-catalog.json, mod-catalog-details.json, the old '
    + 'ModRepo.json and the website.');
  return parts.join(' ');
}

/// Formats selected boards for job confirmations.
function listBoards(boards) {
  const names = { main: 'main', lesser: 'lesser mods', libraries: 'libraries' };
  const picked = (boards || []).map((b) => names[b] || b);
  if (!picked.length) return 'no boards';
  if (picked.length === 1) return `the ${picked[0]} board`;
  const last = picked.pop();
  return `the ${picked.join(', ')} and ${last} boards`;
}

/// Formats selected sources for job confirmations.
function listSources(sources) {
  const names = { forum: 'the forum', discord: 'Discord', nexus: 'Nexus' };
  const picked = (sources || []).map((s) => names[s] || s);
  if (!picked.length) return 'no sources';
  if (picked.length === 1) return picked[0];
  const last = picked.pop();
  return `${picked.join(', ')} and ${last}`;
}

/// Formats a scope for job confirmations.
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
      return 'new or changed topics';
  }
}

/// Returns the submitted run, or null if the confirmation is cancelled.
export async function confirmAndSubmit(request) {
  const yes = await askDialog({
    title: kindLabel(request.kind),
    message: describeJob(request),
    confirmLabel: 'Start job',
  });
  if (!yes) return null;
  return submitJob(request);
}

// --- Topic selection ---

// Persist selection across reloads; clear after submission or via Clear.
const SELECTION_KEY = 'viewerSelectedTopics';

function loadSelection() {
  try {
    const raw = sessionStorage.getItem(SELECTION_KEY);
    if (raw) return new Set(JSON.parse(raw).map(Number));
  } catch (_) {
    // Invalid or blocked storage starts with an empty selection.
  }
  return new Set();
}

function saveSelection() {
  try {
    sessionStorage.setItem(SELECTION_KEY, JSON.stringify([...selected]));
  } catch (_) {
    // Selection still works in memory when storage is unavailable.
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
  /// Returns an unsubscribe function.
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

// --- Sidebar status chip ---

export function mountHeaderChip(node) {
  if (!node) return;
  node.setAttribute('href', '#/runs');
  subscribe((s) => drawChip(node, s));
  drawChip(node, status());
}

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
    node.title = s.reason || 'Job management is disabled on this server.';
    return;
  }
  const current = s.current;
  if (!current) {
    const waiting = (s.queued || []).length;
    if (waiting) {
      row('waiting', '', `${waiting} waiting`);
      node.title = 'View queued jobs.';
    } else {
      row('ready', '', 'Ready');
      node.title = 'No active job. Open Runs and queue to start one.';
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
    || 'View the active job.';
}

// --- Time formatting ---

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
