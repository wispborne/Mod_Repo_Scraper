// PROTOTYPE — throwaway. Data and helpers shared by the Control page design
// variants. Real run history comes from the manager API; the live run, the
// queue, "Needs attention" and pending changes are made up so every state can
// be looked at.

export const KIND_LABELS = {
  fetchAndUpdate: 'Fetch and update',
  rebuildFromSaved: 'Rebuild from saved',
  publishOutputs: 'Publish',
  llmCoveragePass: 'LLM catch-up',
  describePictures: 'Scan images',
  matchRequirements: 'Match dependency names',
  rescrapeTopics: 'Re-scrape topics',
  extractLlm: 'Re-run LLM',
  resolveDownloads: 'Resolve downloads',
  mergeModRepo: 'Merge',
  scrapeAndMerge: 'Scrape and merge',
  rebuildBundle: 'Rebuild bundle',
  fullRun: 'Full run',
  takeDown: 'Take down',
  restoreTakedown: 'Restore takedown',
  setAuthorAliases: 'Save author aliases',
  setRequirementNames: 'Save dependency names',
  llmTest: 'LLM test',
};

export const kindLabel = (k) => KIND_LABELS[k] || k;

export const NAV = [
  { title: 'Operate', items: [
    { label: 'Control', icon: 'gauge', active: true },
    { label: 'Run history', icon: 'history' },
    { label: 'Settings', icon: 'settings' },
  ] },
  { title: 'Correct', items: [
    { label: 'Takedowns', icon: 'eye-off' },
    { label: 'Author aliases', icon: 'users' },
    { label: 'Dependency names', icon: 'link' },
  ] },
  { title: 'Investigate', items: [
    { label: 'Mods', icon: 'box' },
    { label: 'Source posts', icon: 'list' },
    { label: 'What changed', icon: 'compare' },
    { label: 'Catalog explorer', icon: 'merge' },
    { label: 'LLM test report', icon: 'flask' },
    { label: 'Files', icon: 'files' },
  ] },
];

export const START_JOBS = [
  { kind: 'fetchAndUpdate', label: 'Fetch and update', icon: 'download',
    detail: 'Forum (all boards), Discord · LLM on',
    options: ['Forum scope: new and changed', 'Boards: Mods, Lesser, Libraries', 'Also fetch: Discord', 'LLM: on'] },
  { kind: 'runLlm', label: 'Run LLM', icon: 'sparkles',
    detail: 'Only changed posts · no fetching',
    options: ['Only changed (default): posts with no answer, or whose post or prompt changed', 'All: read every post again (the LLM call cap still applies)'] },
  { kind: 'rebuildFromSaved', label: 'Rebuild from saved', icon: 'refresh',
    detail: 'No network, no LLM',
    options: ['Merge, catalog, details and website from saved files'] },
  { kind: 'publishOutputs', label: 'Publish', icon: 'upload',
    detail: 'Push outputs and the website to GitHub',
    options: ['Checks the takedown list first'] },
];

export const MORE_JOBS = [
  { kind: 'describePictures', label: 'Scan images' },
  { kind: 'matchRequirements', label: 'Match dependency names' },
];

const ATTENTION = [
  { label: 'Dependency names not matched', count: 7, where: 'Dependency names' },
  { label: 'Suggested author pairs to decide', count: 3, where: 'Author aliases' },
  { label: 'Takedown entries that excluded nothing', count: 1, where: 'Takedowns', warn: true },
  { label: 'Posts with no LLM answer yet', count: 58, where: 'Source posts' },
  { label: 'Mods with a missing or broken download', count: 24, where: 'Mods' },
];

const PENDING = [
  { kind: 'Takedown', text: 'Take down "Tidal Diable Avionics"' },
  { kind: 'Author alias', text: 'Histidine = histidine_my' },
];

const DEMO_LOG = [
  '23:07:41 INFO  Topic 34150 saved (Arma Armatura) — 0 changes',
  '23:07:42 INFO  Topic 34152 saved (Kadur Remnant) — post edited',
  '23:07:42 INFO  LLM: reading topic 34152 (4,812 prompt tokens)',
  '23:07:44 WARN  Topic 34155: download host answered 503, will try again next run',
  '23:07:45 INFO  Topic 34158 saved (Ship and Weapon Pack) — 0 changes',
  '23:07:47 INFO  LLM: topic 34152 answered in 4.9 s (2 mods, 3 downloads)',
  '23:07:48 INFO  Topic 34159 saved (Hullmods - Renewed) — new reply only',
  '23:07:50 ERROR Topic 34160: page did not load (timed out after 30 s)',
  '23:07:51 INFO  Topic 34161 saved (Hartley\'s Mods) — post edited',
  '23:07:51 INFO  LLM: reading topic 34161 (9,204 prompt tokens)',
];

async function getJson(url) {
  try {
    const res = await fetch(url);
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

/** state: 'running' | 'idle' | 'off'. */
export async function loadData(state) {
  const [status, runsPage, version] = await Promise.all([
    getJson('/api/manager/status'),
    getJson('/api/manager/runs?pageSize=40'),
    getJson('/api/version'),
  ]);
  const runs = (runsPage?.items || []).filter((r) => r.state !== 'queued' && r.state !== 'running');
  const lastRun = runs.find((r) => r.finishedAt) || null;

  let current = status?.current || null;
  let queued = status?.queued || [];
  let log = [];

  if (state === 'running') {
    const started = new Date(Date.now() - 7 * 60 * 1000 - 23 * 1000);
    current = {
      record: {
        id: '20261105T230000Z-fetchAndUpdate',
        request: { kind: 'fetchAndUpdate', runLlm: true },
        state: 'running',
        startedAt: started.toISOString(),
        counters: { itemsDone: 412, itemsTotal: 1031, errors: 2, llmCalls: 37 },
      },
      phase: 'Reading forum topics',
      item: 'Topic 34161 — Hartley\'s Mods',
      itemsDone: 412,
      itemsTotal: 1031,
    };
    queued = [
      { id: '20261105T230812Z-publishOutputs', request: { kind: 'publishOutputs' }, state: 'queued' },
    ];
    log = DEMO_LOG;
  } else if (lastRun) {
    const tail = await getJson(`/api/manager/runs/${encodeURIComponent(lastRun.id)}/log?tail=10`);
    log = tail?.lines || [];
  }
  if (state !== 'running' && state !== 'off') current = status?.current || null;

  const attention = [...ATTENTION];
  if (lastRun?.counters?.errors) {
    attention.unshift({ label: 'Errors in the last run', count: lastRun.counters.errors, where: 'Run', bad: true });
  }

  return {
    state,
    managerOn: state !== 'off',
    current: state === 'off' ? null : current,
    queued: state === 'off' ? [] : queued,
    runs,
    lastRun,
    log,
    attention: attention.filter((a) => a.count > 0),
    pending: state === 'off' ? [] : PENDING,
    version: version?.build ? version : { build: 48, commit: '28cbe0f', date: '2026-11-05' },
    update: state === 'off' ? null : { available: `v${Number(version?.build || 48) + 1}` },
    realHistory: runs.length > 0,
  };
}

// ---- Formatting -------------------------------------------------------------

export function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

export function duration(ms) {
  if (ms == null || Number.isNaN(ms)) return '—';
  const s = Math.round(ms / 1000);
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ${String(s % 60).padStart(2, '0')}s`;
  return `${Math.floor(m / 60)}h ${String(m % 60).padStart(2, '0')}m`;
}

export function runDuration(r) {
  if (!r?.startedAt) return null;
  const end = r.finishedAt ? new Date(r.finishedAt) : new Date();
  return end - new Date(r.startedAt);
}

export function ago(iso) {
  if (!iso) return '—';
  const s = (Date.now() - new Date(iso)) / 1000;
  if (s < 60) return 'just now';
  if (s < 3600) return `${Math.round(s / 60)} min ago`;
  if (s < 86400) return `${Math.round(s / 3600)} h ago`;
  return `${Math.round(s / 86400)} days ago`;
}

export function clock(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  return d.toLocaleString(undefined, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false });
}

export function pct(done, total) {
  return total ? Math.round((done / total) * 100) : 0;
}

export const STATE_WORDS = {
  running: 'Running', queued: 'Waiting', completed: 'Done', failed: 'Failed',
  cancelled: 'Stopped', interrupted: 'Interrupted',
};

export function logLevel(line) {
  if (/\bERROR\b|\bSEVERE\b/.test(line)) return 'error';
  if (/\bWARN(ING)?\b/.test(line)) return 'warn';
  return 'info';
}

// ---- Icons (Tabler Icons, MIT, path data copied in) ---------------------------

const PATHS = {
  gauge: ['M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0', 'M12 12l3.5 -3.5', 'M7 12h.01', 'M12 7h.01'],
  history: ['M12 8l0 4l2 2', 'M3.05 11a9 9 0 1 1 .5 4m-.5 5v-5h5'],
  settings: ['M14 6m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M4 6l8 0', 'M16 6l4 0', 'M8 12m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M4 12l2 0', 'M10 12l10 0', 'M17 18m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M4 18l11 0', 'M19 18l1 0'],
  'eye-off': ['M10.585 10.587a2 2 0 0 0 2.829 2.828', 'M16.681 16.673a8.717 8.717 0 0 1 -4.681 1.327c-3.6 0 -6.6 -2 -9 -6c1.272 -2.12 2.712 -3.678 4.32 -4.674m2.86 -1.146a9.055 9.055 0 0 1 1.82 -.18c3.6 0 6.6 2 9 6c-.666 1.11 -1.379 2.067 -2.138 2.87', 'M3 3l18 18'],
  users: ['M9 7m-4 0a4 4 0 1 0 8 0a4 4 0 1 0 -8 0', 'M3 21v-2a4 4 0 0 1 4 -4h4a4 4 0 0 1 4 4v2', 'M16 3.13a4 4 0 0 1 0 7.75', 'M21 21v-2a4 4 0 0 0 -3 -3.85'],
  link: ['M9 15l6 -6', 'M11 6l.463 -.536a5 5 0 0 1 7.071 7.072l-.534 .464', 'M13 18l-.397 .534a5.068 5.068 0 0 1 -7.127 0a4.972 4.972 0 0 1 0 -7.071l.524 -.463'],
  box: ['M12 3l8 4.5v9l-8 4.5l-8 -4.5v-9z', 'M12 12l8 -4.5', 'M12 12v9', 'M12 12l-8 -4.5'],
  list: ['M9 6h11', 'M9 12h11', 'M9 18h11', 'M5 6v.01', 'M5 12v.01', 'M5 18v.01'],
  compare: ['M6 6m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M18 18m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M11 6h5a2 2 0 0 1 2 2v8', 'M14 9l-3 -3l3 -3', 'M13 18h-5a2 2 0 0 1 -2 -2v-8', 'M10 15l3 3l-3 3'],
  merge: ['M7 18m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M7 6m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M17 12m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M7 8l0 8', 'M7 8a4 4 0 0 0 4 4h4'],
  flask: ['M9 3l6 0', 'M10 9l4 0', 'M10 3v6l-4 11a.7 .7 0 0 0 .5 1h11a.7 .7 0 0 0 .5 -1l-4 -11v-6'],
  files: ['M15 3v4a1 1 0 0 0 1 1h4', 'M18 17h-7a2 2 0 0 1 -2 -2v-10a2 2 0 0 1 2 -2h4l5 5v7a2 2 0 0 1 -2 2z', 'M16 17v2a2 2 0 0 1 -2 2h-7a2 2 0 0 1 -2 -2v-10a2 2 0 0 1 2 -2h2'],
  search: ['M10 10m-7 0a7 7 0 1 0 14 0a7 7 0 1 0 -14 0', 'M21 21l-6 -6'],
  download: ['M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2 -2v-2', 'M7 11l5 5l5 -5', 'M12 4l0 12'],
  upload: ['M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2 -2v-2', 'M7 9l5 -5l5 5', 'M12 4l0 12'],
  refresh: ['M20 11a8.1 8.1 0 0 0 -15.5 -2m-.5 -4v4h4', 'M4 13a8.1 8.1 0 0 0 15.5 2m.5 4v-4h-4'],
  stop: ['M6 6h12v12h-12z'],
  alert: ['M12 9v4', 'M10.363 3.591l-8.106 13.534a1.914 1.914 0 0 0 1.636 2.871h16.214a1.914 1.914 0 0 0 1.636 -2.87l-8.106 -13.536a1.914 1.914 0 0 0 -3.274 0z', 'M12 16h.01'],
  chevron: ['M9 6l6 6l-6 6'],
  'chevron-down': ['M6 9l6 6l6 -6'],
  check: ['M5 12l5 5l10 -10'],
  x: ['M18 6l-12 12', 'M6 6l12 12'],
  clock: ['M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0', 'M12 7v5l3 3'],
  play: ['M7 4v16l13 -8z'],
  sparkles: ['M16 18a2 2 0 0 1 2 2a2 2 0 0 1 2 -2a2 2 0 0 1 -2 -2a2 2 0 0 1 -2 2zm0 -12a2 2 0 0 1 2 2a2 2 0 0 1 2 -2a2 2 0 0 1 -2 -2a2 2 0 0 1 -2 2zm-7 12a6 6 0 0 1 6 -6a6 6 0 0 1 -6 -6a6 6 0 0 1 -6 6a6 6 0 0 1 6 6z'],
  inbox: ['M4 4m0 2a2 2 0 0 1 2 -2h12a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2h-12a2 2 0 0 1 -2 -2z', 'M4 13h3l3 3h4l3 -3h3'],
};

export function ico(name, size = 16, sw = 2) {
  const paths = (PATHS[name] || []).map((d) => `<path d="${d}"/>`).join('');
  return `<svg class="ico" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${paths}</svg>`;
}
