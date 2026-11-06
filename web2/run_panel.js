// The run panel shared by the Control page and the run page: the run's
// state, progress and counters, Stop or Run again, and its Log, What it
// changed and Record tabs.

import { el, api, shortTime } from './lib.js';
import { icon } from './icons.js';
import { kindLabel, percent, buildHash } from './routes.js';
import { progressBar, statusMark } from './frame.js';
import { describeJob, duration } from './jobs.js';
import { confirmAndStart, confirmAndStop } from './actions.js';

export const MARK_FOR_STATE = {
  running: 'running',
  queued: 'idle',
  completed: 'done',
  failed: 'failed',
  cancelled: 'warning',
  interrupted: 'warning',
};

export const STATE_WORDS = {
  running: 'Running',
  queued: 'Waiting',
  completed: 'Done',
  failed: 'Failed',
  cancelled: 'Stopped',
  interrupted: 'Interrupted',
};

const LOG_TAIL = 200;

// Remember the last selected tab while the viewer is open.
let openTab = 'log';

/// The centre panel. `show(record, live)` draws a run: `live` is the status's
/// current entry while it runs, or null for a finished run.
export function runPanel(node) {
  const head = el('div', { class: 'run-head' });
  const meter = el('div', { class: 'run-meter' });
  const chips = el('div', { class: 'chips' });
  const tabs = el('div', { class: 'tabs', role: 'tablist' });
  const logBox = el('div', { class: 'log-box', tabindex: '0', 'aria-label': 'Run log' });
  const logNote = el('span', { class: 'log-note' });
  const moreButton = el('button', { type: 'button', class: 'button quiet', text: 'Show more', hidden: true });
  const logPane = el('div', { class: 'tab-pane log-pane' }, [
    el('div', { class: 'log-bar' }, [logNote, moreButton]),
    logBox,
  ]);
  const changedPane = el('div', { class: 'tab-pane' });
  const recordPane = el('div', { class: 'tab-pane' });
  const panes = { log: logPane, changed: changedPane, record: recordPane };

  let shownId;
  let shownRecord = null;
  let shownLive = false;
  let tail = LOG_TAIL;
  let changedFor = null;
  let shownLines = [];
  let followedOnce = false;
  let logAsking = false;
  let laidOut = false;

  const tabButton = (id, text) => {
    const b = el('button', { type: 'button', class: 'tab', role: 'tab', text });
    b.dataset.tab = id;
    b.addEventListener('click', () => {
      openTab = id;
      drawTabs();
    });
    return b;
  };
  const tabButtons = [tabButton('log', 'Log'), tabButton('changed', 'What it changed'), tabButton('record', 'Record')];
  tabs.append(...tabButtons);
  const drawTabs = () => {
    for (const b of tabButtons) {
      const on = b.dataset.tab === openTab;
      b.classList.toggle('on', on);
      b.setAttribute('aria-selected', String(on));
    }
    for (const [id, pane] of Object.entries(panes)) pane.hidden = id !== openTab;
  };
  drawTabs();

  // More lines: 2,000 first, then five times as many each press.
  moreButton.addEventListener('click', () => {
    tail = tail === LOG_TAIL ? 2000 : tail * 5;
    if (shownRecord) readLog(shownRecord, shownLive);
  });

  const layOut = () => {
    if (laidOut) return;
    laidOut = true;
    node.replaceChildren(head, meter, chips, tabs, logPane, changedPane, recordPane);
  };

  async function readLog(record, live) {
    if (logAsking) return;
    logAsking = true;
    try {
      const log = await api(`manager/runs/${encodeURIComponent(record.id)}/log`, { tail });
      if (record.id !== shownId) return;
      if (!log || log.missing) {
        logNote.textContent = 'No log is available for this run.';
        moreButton.hidden = true;
        logBox.replaceChildren();
        shownLines = [];
        return;
      }
      moreButton.hidden = !(log.total > (log.lines || []).length);
      updateLog(log.lines || [], log.total || 0, live);
    } catch (err) {
      logNote.textContent = err.message;
    } finally {
      logAsking = false;
    }
  }

  // Keeps the log box on the page and only adds and removes lines, so the
  // reader's scroll position and selection survive each update.
  function updateLog(lines, total, live) {
    logNote.textContent = lines.length
      ? `Showing the last ${lines.length} of ${total} lines.`
      : 'Nothing logged yet.';
    const fromBottom = Math.max(0, logBox.scrollHeight - logBox.scrollTop - logBox.clientHeight);
    const dropped = linesDroppedFromTop(shownLines, lines);
    for (let i = 0; i < dropped && logBox.firstChild; i++) logBox.firstChild.remove();
    for (let i = shownLines.length - dropped; i < lines.length; i++) logBox.append(logLine(lines[i]));
    shownLines = lines;
    if (!followedOnce) {
      followedOnce = true;
      logBox.scrollTop = live ? logBox.scrollHeight : 0;
    } else {
      logBox.scrollTop = Math.max(0, logBox.scrollHeight - logBox.clientHeight - fromBottom);
    }
  }

  return {
    off(s) {
      laidOut = false;
      shownId = undefined;
      node.replaceChildren(el('div', { class: 'note' }, [
        el('h2', { class: 'panel-heading', text: 'Viewing only' }),
        el('p', {
          text: s.offline
            ? 'The server could not be reached. Job controls are unavailable.'
            : `${s.reason || 'Job management is disabled on this server.'} Start the viewer with a readable config.properties file (or specify it with --config) and omit --no-manager to enable jobs.`,
        }),
      ]));
    },
    show(record, live) {
      if (!record) {
        if (shownId !== null) {
          laidOut = false;
          node.replaceChildren(el('div', { class: 'note' }, [
            el('h2', { class: 'panel-heading', text: 'No runs yet' }),
            el('p', { text: 'Start a job with the buttons above.' }),
          ]));
        }
        shownId = null;
        return;
      }
      layOut();
      const waiting = !live && record.state === 'queued';
      if (record.id !== shownId) {
        shownId = record.id;
        shownLines = [];
        followedOnce = false;
        tail = LOG_TAIL;
        moreButton.hidden = true;
        logBox.replaceChildren();
        logNote.textContent = waiting ? 'Waiting in the queue. Nothing logged yet.' : 'Loading…';
        if (!waiting) readLog(record, !!live);
      } else if (waiting) {
        // Nothing to read until it starts.
      } else if (live || shownLive) {
        // Read once after the run ends to include its final log lines.
        readLog(record, !!live);
      }
      shownLive = !!live;
      shownRecord = record;
      drawHead(head, record, live);
      drawMeter(meter, live);
      drawChips(chips, record, live);
      const changedKey = `${record.id}:${!!live}:${record.state}`;
      if (changedKey !== changedFor) {
        changedFor = changedKey;
        drawChanged(changedPane, record, live, () => changedFor === changedKey);
      }
      drawRecord(recordPane, record);
    },
  };
}

function drawHead(node, record, live) {
  const kind = kindLabel(record.request && record.request.kind);
  const state = live ? 'running' : record.state;
  const waiting = !live && state === 'queued';
  const sub = live
    ? [live.phase, live.item].filter(Boolean).join(' · ') || 'Starting…'
    : waiting
      ? `Queued ${shortTime(record.queuedAt)}`
      : `Finished ${shortTime(record.finishedAt) || 'at an unknown time'}`;
  const action = waiting ? null : live
    ? el('button', { type: 'button', class: 'button danger', onclick: () => confirmAndStop(record) }, [icon('stop', 12), 'Stop'])
    : el('button', {
      type: 'button',
      class: 'button',
      title: 'Start a new job with the same settings.',
      onclick: () => confirmAndStart({ ...(record.request || {}), replayAllowed: false }),
    }, [icon('refresh', 14), 'Run again']);
  node.replaceChildren(
    el('span', { class: `tag tag-${MARK_FOR_STATE[state] || 'idle'}`, text: STATE_WORDS[state] || state }),
    el('div', { class: 'run-title' }, [
      el('h2', { class: 'run-name', text: kind }),
      el('p', { class: 'run-sub', text: sub }),
    ]),
    ...(action ? [action] : []),
  );
}

function drawMeter(node, live) {
  node.hidden = !live;
  if (!live) {
    node.replaceChildren();
    return;
  }
  const pct = percent(live.itemsDone, live.itemsTotal);
  node.replaceChildren(
    progressBar(pct),
    el('span', { class: 'run-count', text: live.itemsTotal ? `${live.itemsDone} / ${live.itemsTotal}` : `${live.itemsDone || 0} done` }),
    el('span', { class: 'run-pct', text: pct == null ? '' : `${pct}%` }),
  );
}

function chip(label, value, kind = '') {
  return el('span', { class: `chip ${kind}` }, [el('b', { text: String(value) }), ` ${label}`]);
}

function drawChips(node, record, live) {
  const c = record.counters || {};
  const items = [
    live
      ? chip('elapsed', duration(record.startedAt, null) || '—')
      : el('span', { class: 'chip' }, ['Took ', el('b', { text: duration(record.startedAt, record.finishedAt) || '—' })]),
    chip(c.llmCalls === 1 ? 'LLM call' : 'LLM calls', c.llmCalls || 0),
    chip(c.errors === 1 ? 'error' : 'errors', c.errors || 0, c.errors ? 'bad' : ''),
  ];
  if (!live && c.itemsTotal) items.push(chip(`of ${c.itemsTotal} done`, c.itemsDone || 0));
  if (record.guardrailStop) {
    items.push(el('span', { class: 'chip warn', title: record.guardrailStop, text: 'Limit reached' }));
  }
  items.push(el('span', { class: 'chip id', text: record.id }));
  node.replaceChildren(...items);
}

/// The What changed tab. A finished run links to What changed, comparing its
/// saved snapshot with the one before it: the Facts tab when the run saved
/// mod details, and the Mods tab when it saved a catalog. A running job links
/// to the changes so far. `stillWanted()` is false once another run is shown.
async function drawChanged(node, record, live, stillWanted) {
  const note = (paragraphs, links) => node.replaceChildren(el('div', { class: 'note' }, [
    ...paragraphs.map((p) => el('p', p)),
    links.length ? el('p', { class: 'run-changed-links' }, links.map((l) => el('a', { href: l.href, text: l.text }))) : null,
  ]));

  if (live) {
    note([{ text: 'Compare current local data with the latest snapshot.' }],
      [{ href: buildHash(['changes'], { tab: 'facts', b: 'working' }), text: 'Changes so far' }]);
    return;
  }
  if (record.state === 'queued') {
    node.replaceChildren(el('div', { class: 'note' }, [el('p', { text: 'Nothing has changed yet. The run is waiting in the queue.' })]));
    return;
  }
  node.replaceChildren(el('div', { class: 'note' }, [el('p', { text: 'Loading…' })]));
  const ids = async (path) => {
    try {
      const saved = await api(path);
      return ((saved && saved.items) || []).map((r) => r.id);
    } catch {
      return [];
    }
  };
  const [facts, mods] = await Promise.all([ids('bundle/runs'), ids('merge/runs')]);
  if (!stillWanted()) return;
  // Snapshots are newest first, so the previous snapshot is next in the list.
  const pair = (list) => {
    const at = list.indexOf(record.id);
    return at < 0 || at + 1 >= list.length ? null : { a: list[at + 1], b: record.id };
  };
  const factsPair = pair(facts);
  const modsPair = pair(mods);
  if (!factsPair && !modsPair) {
    node.replaceChildren(el('div', { class: 'note' }, [el('p', { text: 'No earlier snapshot to compare with.' })]));
    return;
  }
  const href = (tab, sides) => buildHash(['changes'], { tab, ...sides });
  if (factsPair) {
    note([{ text: 'Compare these mod details with the previous snapshot.' }], [
      { href: href('facts', factsPair), text: 'View changes' },
      modsPair ? { href: href('mods', modsPair), text: 'View changes to mods' } : null,
    ].filter(Boolean));
  } else {
    note([{ text: 'Compare this catalog with the previous snapshot.' }],
      [{ href: href('mods', modsPair), text: 'View changes' }]);
  }
}

function drawRecord(node, record) {
  const c = record.counters || {};
  const rows = [
    ['Run', record.id],
    ['Job', describeJob(record.request || {})],
    ['Queued', shortTime(record.queuedAt)],
    ['Started', shortTime(record.startedAt)],
    ['Finished', record.finishedAt ? shortTime(record.finishedAt) : 'Not finished'],
    ['Took', duration(record.startedAt, record.finishedAt)],
    ['Done', c.itemsTotal ? `${c.itemsDone || 0} of ${c.itemsTotal}` : String(c.itemsDone || 0)],
    ['Errors', String(c.errors || 0)],
    ['LLM calls', String(c.llmCalls || 0)],
    ['Limit reached', record.guardrailStop],
    ['Error', record.errorMessage],
  ];
  node.replaceChildren(el('dl', { class: 'fields' }, rows
    .filter(([, v]) => v != null && v !== '')
    .flatMap(([k, v]) => [el('dt', { text: k }), el('dd', { text: v })])));
}

function logLine(text) {
  const level = /\b(ERROR|SEVERE)\b/.test(text) ? 'error' : /\bWARN(ING)?\b/.test(text) ? 'warn' : '';
  return el('div', { class: level ? `log-line ${level}` : 'log-line', text });
}

/// Counts lines removed from the top between log updates so shared lines
/// stay on the page.
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


/// One run as a row in a list: a diamond in its state's colour, its job and
/// its start time.
export function runRow(record) {
  const kind = kindLabel(record.request && record.request.kind);
  const errors = record.counters && record.counters.errors;
  return el('a', {
    class: 'row',
    href: `#/runs/${encodeURIComponent(record.id)}`,
    title: `${STATE_WORDS[record.state] || record.state}${record.errorMessage ? `: ${record.errorMessage}` : ''}`,
  }, [
    statusMark(MARK_FOR_STATE[record.state] || 'idle'),
    el('span', { class: 'row-main' }, [
      kind,
      errors ? el('span', { class: 'failed-text', text: ` · ${errors} ${errors === 1 ? 'error' : 'errors'}` }) : null,
    ]),
    el('span', { class: 'row-time', text: shortTime(record.startedAt || record.queuedAt) }),
  ]);
}
