// #/runs/<id> — request, result, and log for one run.

import { api, el, clear, go, errorPanel, MissingFile, noticeDialog, rawJson, breadcrumbs, buildHash } from '../lib.js';
import * as manager from '../manager.js';
import { progressBar, managerOffPanel, stopRunButton } from './runs.js';

const DEFAULT_TAIL = 200;
const MORE_TAIL = 2000;

export async function render(root, parts) {
  const id = parts[0];
  clear(root);
  root.append(breadcrumbs([{ label: 'Runs and queue', href: '#/runs' }, { label: `Run ${id}` }]));

  const body = el('div', { class: 'stack' });
  root.append(body);

  let tail = DEFAULT_TAIL;
  let live = false;
  let drawing = false;

  // Keep the log panel mounted across live redraws to preserve scrolling and
  // text selection. Update its lines in place.
  const logView = newLogView();

  // Replace other blocks individually; detaching the log would lose its scroll.
  let headEl = null;
  let recordEl = null;
  let rawEl = null;

  async function draw() {
    if (drawing) return;
    drawing = true;
    try {
      await drawOnce();
    } finally {
      drawing = false;
    }
  }

  /// Puts the page back to its four blocks after an error or a manager-off
  /// notice replaced them.
  function layOutBlocks() {
    clear(body);
    headEl = el('div', {});
    recordEl = el('div', {});
    rawEl = el('div', {});
    body.append(headEl, recordEl, logView.panel, rawEl);
  }

  /// Swaps one of the redrawn blocks for its new version, keeping its place.
  function swap(oldEl, newEl) {
    body.replaceChild(newEl, oldEl);
    return newEl;
  }

  async function drawOnce() {
    let record;
    try {
      record = await api(`manager/runs/${encodeURIComponent(id)}`);
    } catch (err) {
      headEl = null;
      clear(body).append(errorPanel(err));
      return;
    }
    if (record.error) {
      headEl = null;
      clear(body).append(errorPanel(new Error(record.error)));
      return;
    }
    live = record.state === 'running' || record.state === 'queued';

    // MissingFile means no log file, rather than an empty log.
    let log = { lines: [], total: 0, missing: true };
    try {
      const answer = await api(`manager/runs/${encodeURIComponent(id)}/log`, { tail });
      log = answer instanceof MissingFile ? { lines: [], total: 0, missing: true } : answer;
    } catch (_) {
      // Keep the record visible when the log is unavailable.
    }

    if (!headEl) layOutBlocks();
    headEl = swap(headEl, header(record, live));
    recordEl = swap(recordEl, recordPanel(record));
    rawEl = swap(rawEl, rawJson(record, 'Raw run record (JSON)'));
    updateLog(logView, log, () => {
      tail = tail === DEFAULT_TAIL ? MORE_TAIL : tail * 5;
      draw();
    }, live);
  }

  await draw();

  // While this run is still going, follow it on the shared poller's beat.
  const unsubscribe = manager.subscribe((s) => {
    if (!s.on) {
      headEl = null;
      clear(body).append(managerOffPanel(s));
      return;
    }
    if (live) draw();
  });
  const stop = () => {
    unsubscribe();
    window.removeEventListener('hashchange', stop);
  };
  window.addEventListener('hashchange', stop);
}

function header(record, live) {
  const head = el('div', {});
  head.append(el('h1', { text: manager.kindLabel(record.request && record.request.kind) }));
  const row = el('div', { class: 'run-head' }, [
    el('span', {
      class: 'badge ' + (manager.STATE_BADGES[record.state] || 'badge-dim'),
      text: record.state,
    }),
    el('span', { class: 'run-when', text: record.id }),
    el('button', {
      class: 'btn',
      text: 'Run again',
      title: 'Start a new job with the same settings.',
      onclick: async () => {
        try {
          const again = await manager.confirmAndSubmit(record.request);
          if (again) go(`#/runs/${encodeURIComponent(again.id)}`);
        } catch (err) {
          noticeDialog('Could not start job', err.message);
        }
      },
    }),
  ]);
  if (record.state === 'running') row.append(stopRunButton(record.id));
  head.append(row);
  addWhatChangedLink(row, record.id, { live });
  return head;
}

/// Links to this run's bundle diff, or to working-data changes while it runs.
/// Finished runs need their own snapshot and a saved predecessor. Live runs
/// need no extra request during the page's one-second redraws.
export async function addWhatChangedLink(row, runId, { live = false } = {}) {
  if (live) {
    row.append(el('a', {
      class: 'btn',
      href: buildHash(['bundle', 'changes'], { b: 'working' }),
      text: 'Changes so far',
      title: 'Compare current saved data with the latest published bundle.',
    }));
    return;
  }

  const saved = await api('bundle/runs');
  if (saved instanceof MissingFile) return;
  const ids = (saved.items || []).map((r) => r.id);
  const at = ids.indexOf(runId);
  if (at < 0 || at + 1 >= ids.length) return;

  // The two runs ride in the link itself, so it also works opened in a new tab.
  row.append(el('a', {
    class: 'btn',
    href: buildHash(['bundle', 'changes'], { a: ids[at + 1], b: runId }),
    text: 'View changes',
    title: 'Compare the bundle this run published with the one before it.',
  }));
}

function recordPanel(record) {
  const panel = el('div', { class: 'panel' });
  panel.append(el('h2', { text: 'Run details' }));

  const c = record.counters || {};
  const total = c.itemsTotal || 0;
  panel.append(progressBar(c.itemsDone || 0, total));

  const list = el('ul', { class: 'field-list' });
  const rows = [
    ['Started', manager.fmtTime(record.startedAt)],
    ['Finished', record.finishedAt ? manager.fmtTime(record.finishedAt) : 'Not finished'],
    ['Duration', manager.fmtDuration(record.startedAt, record.finishedAt)],
    ['Topics done', total ? `${c.itemsDone || 0} of ${total}` : String(c.itemsDone || 0)],
    ['Errors', String(c.errors || 0)],
    ['LLM calls', String(c.llmCalls || 0)],
    ['Limit reached', record.guardrailStop],
    ['Error', record.errorMessage],
  ];
  for (const [label, value] of rows) {
    if (value == null || value === '') continue;
    list.append(el('li', {}, [
      el('span', { class: 'field-label', text: label }),
      el('span', { class: 'field-value', text: String(value) }),
    ]));
  }
  panel.append(list);

  panel.append(el('h3', { text: 'Job settings' }));
  panel.append(el('p', { class: 'run-when', text: manager.describeJob(record.request || {}) }));
  panel.append(requestFields(record.request || {}));
  return panel;
}

/// Run again submits this stored request.
function requestFields(request) {
  const list = el('ul', { class: 'field-list' });
  const topics = request.topicIds || [];
  const rows = [
    ['Job', manager.kindLabel(request.kind)],
    ['Topics', topics.length ? topics.join(', ') : null],
    ['Scope', request.kind === 'fullRun' ? request.scope : null],
    ['Boards', request.kind === 'fullRun' ? (request.boards || []).join(', ') : null],
    ['LLM extraction', request.runLlm ? 'yes' : 'no'],
    ['Replay saved pages', request.replayAllowed ? 'yes' : 'no'],
  ];
  for (const [label, value] of rows) {
    if (value == null || value === '') continue;
    list.append(el('li', {}, [
      el('span', { class: 'field-label', text: label }),
      el('span', { class: 'field-value', text: String(value) }),
    ]));
  }
  return list;
}

// --- Log panel, updated in place ---

function newLogView() {
  const panel = el('div', { class: 'panel' });
  panel.append(el('h2', { text: 'Log' }));
  return {
    panel,
    box: null,     // the scrolling <pre>, once there are lines to put in it
    lines: [],     // the lines the box is showing
    note: null,    // "showing the last N of M lines"
    more: null,    // the Show more button
    message: null, // shown instead of the box when there is no log
    filled: false, // has the box been filled at least once?
  };
}

function updateLog(view, log, onMore, live) {
  const lines = log.lines || [];
  const nothingToShow = log.missing
    ? 'No log is available for this run.'
    : (lines.length ? null : 'Nothing logged yet.');

  if (nothingToShow) {
    for (const name of ['box', 'note', 'more']) {
      if (view[name]) { view[name].remove(); view[name] = null; }
    }
    view.lines = [];
    view.filled = false;
    if (!view.message) {
      view.message = el('p', { class: 'loading' });
      view.panel.append(view.message);
    }
    view.message.textContent = nothingToShow;
    return;
  }
  if (view.message) { view.message.remove(); view.message = null; }

  // Insert controls before the existing log box without detaching it.
  const putAboveBox = (node) =>
    view.box ? view.panel.insertBefore(node, view.box) : view.panel.append(node);

  if (!view.note) {
    view.note = el('p', { class: 'run-when' });
    putAboveBox(view.note);
  }
  view.note.textContent = `Showing the last ${lines.length} of ${log.total} lines.`;

  const hasMore = log.total > lines.length;
  if (hasMore && !view.more) {
    view.more = el('button', { class: 'btn', text: 'Show more', onclick: onMore });
    putAboveBox(view.more);
  } else if (!hasMore && view.more) {
    view.more.remove();
    view.more = null;
  }

  if (!view.box) {
    view.box = el('pre', { class: 'raw' });
    view.panel.append(view.box);
  }

  // Preserve distance from the bottom as the tail shifts. Readers at the
  // bottom continue following new lines.
  const box = view.box;
  const fromBottom = Math.max(0, box.scrollHeight - box.scrollTop - box.clientHeight);

  const dropped = linesDroppedFromTop(view.lines, lines);
  for (let i = 0; i < dropped && box.firstChild; i++) box.firstChild.remove();
  for (let i = view.lines.length - dropped; i < lines.length; i++) {
    box.append(logLine(lines[i]));
  }
  view.lines = lines;

  if (!view.filled) {
    // First look at this log: a run still going is read from its newest line,
    // a finished one from the top of what is shown.
    view.filled = true;
    box.scrollTop = live ? box.scrollHeight : 0;
  } else {
    box.scrollTop = Math.max(0, box.scrollHeight - box.clientHeight - fromBottom);
  }
}

function logLine(text) {
  return el('div', { class: 'log-line', text });
}

/// Aligns the old tail's suffix with the new tail's prefix so shared lines
/// remain mounted. Returns the old length when no overlap is found.
function linesDroppedFromTop(shown, next) {
  for (let dropped = 0; dropped < shown.length; dropped++) {
    const kept = shown.length - dropped;
    if (kept > next.length) continue;
    let same = true;
    for (let i = 0; i < kept; i++) {
      if (shown[dropped + i] !== next[i]) { same = false; break; }
    }
    if (same) return dropped;
  }
  return shown.length;
}
