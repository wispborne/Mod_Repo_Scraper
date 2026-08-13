// #/runs/<id> — one run in full: what was asked for, how it went, and its log.

import { api, el, clear, go, errorPanel, MissingFile, noticeDialog, rawJson, breadcrumbs, buildHash } from '../lib.js';
import * as manager from '../manager.js';
import { progressBar, managerOffPanel } from './runs.js';

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

  // The log panel is made once and then only added to. A live run redraws every
  // second, and rebuilding the log would throw away where the reader had
  // scrolled to and anything they had selected — which makes a running log
  // impossible to read. Everything else on the page is cheap to redraw.
  const logView = newLogView();

  // The three blocks that are replaced on each draw. They are held by name so
  // they can be swapped in place, leaving the log panel where it is: taking it
  // out of the page, even for a moment, is what loses the scroll position.
  let headEl = null;
  let recordEl = null;
  let rawEl = null;

  async function draw() {
    if (drawing) return; // A redraw is already on its way; let it finish.
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

    // The log route says "missing" when the run wrote no file. The shared
    // fetch helper turns that envelope into a MissingFile, so read it back as
    // the plain "no log" case rather than an empty one.
    let log = { lines: [], total: 0, missing: true };
    try {
      const answer = await api(`manager/runs/${encodeURIComponent(id)}/log`, { tail });
      log = answer instanceof MissingFile ? { lines: [], total: 0, missing: true } : answer;
    } catch (_) {
      // A log we cannot read is not worth an error page; the panel says so.
    }

    if (!headEl) layOutBlocks();
    headEl = swap(headEl, header(record));
    recordEl = swap(recordEl, recordPanel(record));
    rawEl = swap(rawEl, rawJson(record, 'Show this run’s raw record (JSON)'));
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

function header(record) {
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
      text: 'Run this again',
      title: 'Start a new job asking for exactly the same thing.',
      onclick: async () => {
        try {
          const again = await manager.confirmAndSubmit(record.request);
          if (again) go(`#/runs/${encodeURIComponent(again.id)}`);
        } catch (err) {
          noticeDialog('The job was not started', err.message);
        }
      },
    }),
  ]);
  head.append(row);
  addWhatChangedLink(row, record.id);
  return head;
}

/// A link to what this run changed, but only when it saved a bundle and there
/// is an older one to compare it against. A link that leads to "nothing to
/// compare" is worse than no link.
export async function addWhatChangedLink(row, runId) {
  const saved = await api('bundle/runs');
  if (saved instanceof MissingFile) return;
  const ids = (saved.items || []).map((r) => r.id);
  const at = ids.indexOf(runId);
  if (at < 0 || at + 1 >= ids.length) return;

  // The two runs ride in the link itself, so it also works opened in a new tab.
  row.append(el('a', {
    class: 'btn',
    href: buildHash(['bundle', 'changes'], { a: ids[at + 1], b: runId }),
    text: 'What this run changed',
    title: 'Compare the bundle this run published with the one before it.',
  }));
}

function recordPanel(record) {
  const panel = el('div', { class: 'panel' });
  panel.append(el('h2', { text: 'What happened' }));

  const c = record.counters || {};
  const total = c.itemsTotal || 0;
  panel.append(progressBar(c.itemsDone || 0, total));

  const list = el('ul', { class: 'field-list' });
  const rows = [
    ['Started', manager.fmtTime(record.startedAt)],
    ['Finished', record.finishedAt ? manager.fmtTime(record.finishedAt) : 'still going'],
    ['Took', manager.fmtDuration(record.startedAt, record.finishedAt)],
    ['Topics done', total ? `${c.itemsDone || 0} of ${total}` : String(c.itemsDone || 0)],
    ['Errors', String(c.errors || 0)],
    ['LLM calls', String(c.llmCalls || 0)],
    ['Stopped at a cap', record.guardrailStop],
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

  panel.append(el('h3', { text: 'What was asked for' }));
  panel.append(el('p', { class: 'run-when', text: manager.describeJob(record.request || {}) }));
  panel.append(requestFields(record.request || {}));
  return panel;
}

/// The stored request, spelled out — this is what "run this again" will send.
function requestFields(request) {
  const list = el('ul', { class: 'field-list' });
  const topics = request.topicIds || [];
  const rows = [
    ['Kind', manager.kindLabel(request.kind)],
    ['Topics', topics.length ? topics.join(', ') : null],
    ['Scope', request.kind === 'fullRun' ? request.scope : null],
    ['Boards', request.kind === 'fullRun' ? (request.boards || []).join(', ') : null],
    ['Ask the LLM', request.runLlm ? 'yes' : 'no'],
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

// --- The log panel ---
//
// The panel and its scrolling box are made once and kept for the life of the
// page. Each draw only changes what has actually changed: the count line, the
// Show more button, and the lines themselves. That is what lets a reader scroll
// through a log while the run it belongs to is still writing to it.

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
    ? 'This run has no log file on disk.'
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

  // Anything that belongs above the box has to be put there by hand: the box
  // is made first and stays put, so a plain append would land under it.
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

  // How far the reader is sitting from the bottom. New lines arrive at the
  // bottom and old ones fall off the top, so keeping that distance keeps the
  // same lines under their eyes — and someone sitting at the bottom is left
  // there, so the log follows itself.
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

/// How many of the lines now on the page have fallen off the top of the log
/// window since the last look. The window holds the last N lines, so as a run
/// writes, new lines arrive at the bottom and the oldest drop off the top;
/// lining the two windows up is what lets the lines they share stay in the page
/// untouched. When they share nothing — the tail was made longer, or the file
/// was written over — the answer is "all of them", which rebuilds the box.
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
