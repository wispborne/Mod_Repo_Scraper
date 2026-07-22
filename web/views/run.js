// #/runs/<id> — one run in full: what was asked for, how it went, and its log.

import { api, el, clear, go, errorPanel, MissingFile } from '../lib.js';
import * as manager from '../manager.js';
import { progressBar, managerOffPanel } from './runs.js';
import { compareRuns } from './bundle_compare.js';

const DEFAULT_TAIL = 200;
const MORE_TAIL = 2000;

export async function render(root, parts) {
  const id = parts[0];
  clear(root);
  root.append(el('a', { class: 'back-link', href: '#/runs', text: '‹ Back to runs' }));

  const body = el('div', {});
  root.append(body);

  let tail = DEFAULT_TAIL;
  let live = false;
  let drawing = false;

  async function draw() {
    if (drawing) return; // A redraw is already on its way; let it finish.
    drawing = true;
    try {
      await drawOnce();
    } finally {
      drawing = false;
    }
  }

  async function drawOnce() {
    let record;
    try {
      record = await api(`manager/runs/${encodeURIComponent(id)}`);
    } catch (err) {
      clear(body).append(errorPanel(err));
      return;
    }
    if (record.error) {
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

    clear(body);
    body.append(header(record));
    body.append(recordPanel(record));
    body.append(logPanel(log, tail, () => {
      tail = tail === DEFAULT_TAIL ? MORE_TAIL : tail * 5;
      draw();
    }));
  }

  await draw();

  // While this run is still going, follow it on the shared poller's beat.
  const unsubscribe = manager.subscribe((s) => {
    if (!s.on) {
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
          window.alert(err.message);
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
async function addWhatChangedLink(row, runId) {
  const saved = await api('bundle/runs');
  if (saved instanceof MissingFile) return;
  const ids = (saved.items || []).map((r) => r.id);
  const at = ids.indexOf(runId);
  if (at < 0 || at + 1 >= ids.length) return;

  row.append(el('a', {
    class: 'btn',
    href: '#/bundle/changes',
    text: 'What this run changed',
    title: 'Compare the bundle this run published with the one before it.',
    onclick: () => compareRuns(ids[at + 1], runId),
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

function logPanel(log, tail, onMore) {
  const panel = el('div', { class: 'panel' });
  panel.append(el('h2', { text: 'Log' }));
  const lines = log.lines || [];
  if (log.missing) {
    panel.append(el('p', { class: 'loading', text: 'This run has no log file on disk.' }));
    return panel;
  }
  if (!lines.length) {
    panel.append(el('p', { class: 'loading', text: 'Nothing logged yet.' }));
    return panel;
  }
  panel.append(el('p', {
    class: 'run-when',
    text: `Showing the last ${lines.length} of ${log.total} lines.`,
  }));
  if (log.total > lines.length) {
    panel.append(el('button', { class: 'btn', text: 'Show more', onclick: onMore }));
  }
  const box = el('pre', { class: 'raw' });
  for (const line of lines) {
    box.append(el('div', { class: 'log-line', text: line }));
  }
  panel.append(box);
  return panel;
}
