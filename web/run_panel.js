// The run panel shared by the Control page and the run page: the run's
// state, progress and counters, Stop or Run again, and its Log, What it
// changed and Record tabs.

import { el, api, shortTime } from './lib.js';
import { icon } from './icons.js';
import { kindLabel, percent, buildHash } from './routes.js';
import { progressBar, setProgress, statusMark } from './frame.js';
import { describeJob, duration } from './jobs.js';
import { confirmAndStart, confirmAndStop, confirmAndRemove } from './actions.js';
import { queuedAt, startedAt, runTime } from './run_record.js';
import { WORKING } from './change_sides.js';
import { modCard, topicCard } from './views/changes.js';
import { logLevel, errorLines } from './log_lines.js';

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
  const moreButton = el('button', { type: 'button', class: 'button quiet', icon: 'more', text: 'Show more', hidden: true });
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
  // `tail` is how many lines the next read asks for. `shownTail` is how
  // many the last read that came back asked for.
  let tail = LOG_TAIL;
  let shownTail = LOG_TAIL;
  let changedFor = null;
  let shownLines = [];
  let followedOnce = false;
  let followedLive = false;
  let logAsking = false;
  // A read asked for while another was loading. It runs when that one ends.
  let readAgain = null;
  let laidOut = false;
  // Pressing the error count shows only the log's error lines. They can be
  // anywhere in the log, so the whole log is read while this is on.
  let errorsOnly = false;
  const errorChip = el('button', { type: 'button', class: 'chip bad', onclick: () => showErrorsOnly(!errorsOnly) });

  // How far from the bottom the reader was when the log was last on screen.
  // A hidden log box cannot be scrolled, so this is where it goes back to.
  let keptFromBottom = 0;
  const logOnScreen = () => logBox.getClientRects().length > 0;
  const fromBottomNow = () => Math.max(0, logBox.scrollHeight - logBox.scrollTop - logBox.clientHeight);

  const tabButton = (id, text) => {
    const b = el('button', { type: 'button', class: 'tab', role: 'tab', text });
    b.dataset.tab = id;
    b.addEventListener('click', () => {
      if (logOnScreen()) keptFromBottom = fromBottomNow();
      openTab = id;
      drawTabs();
      placeLog(shownLive, keptFromBottom);
    });
    return b;
  };
  const tabButtons = [tabButton('log', 'Log'), tabButton('changed', 'What changed'), tabButton('record', 'Record')];
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

  // Scrolls the log once it is on screen. A finished run opens at the top. A
  // running one opens at the bottom and follows new lines, even when it was
  // first drawn as not running. After that, the reader's distance from the
  // bottom is kept. Nothing counts as done while the log is hidden.
  function placeLog(live, fromBottom) {
    if (!shownLines.length || !logOnScreen()) return;
    if (!followedOnce || (live && !followedLive)) {
      logBox.scrollTop = live ? logBox.scrollHeight : 0;
      followedOnce = true;
      if (live) followedLive = true;
    } else {
      logBox.scrollTop = Math.max(0, logBox.scrollHeight - logBox.clientHeight - fromBottom);
    }
    keptFromBottom = fromBottomNow();
  }

  // More lines: 2,000 first, then five times as many each press. The next
  // size is worked out from what is shown, so a second press before the
  // read comes back does not skip a step.
  moreButton.addEventListener('click', () => {
    tail = shownTail === LOG_TAIL ? 2000 : shownTail * 5;
    if (shownRecord) readLog(shownRecord, shownLive);
  });

  function forgetLog() {
    shownLines = [];
    followedOnce = false;
    followedLive = false;
    keptFromBottom = 0;
    moreButton.hidden = true;
    logBox.replaceChildren();
  }

  function showErrorsOnly(on) {
    errorsOnly = on;
    forgetLog();
    logNote.textContent = 'Loading…';
    openTab = 'log';
    drawTabs();
    drawChips(chips, shownRecord, shownLive, errorChip, errorsOnly);
    readLog(shownRecord, shownLive);
  }

  const layOut = () => {
    if (laidOut) return;
    laidOut = true;
    node.replaceChildren(head, meter, chips, tabs, logPane, changedPane, recordPane);
  };

  async function readLog(record, live) {
    if (logAsking) {
      // Only the latest request is kept. It runs once this read ends.
      readAgain = { record, live };
      return;
    }
    logAsking = true;
    const onlyErrors = errorsOnly;
    // A tail of 0 asks for the whole log.
    const asked = onlyErrors ? 0 : tail;
    try {
      const log = await api(`manager/runs/${encodeURIComponent(record.id)}/log`, { tail: asked });
      if (record.id !== shownId || onlyErrors !== errorsOnly) return;
      if (!onlyErrors) shownTail = asked;
      if (!log || log.missing) {
        logNote.textContent = 'No log is available for this run.';
        moreButton.hidden = true;
        logBox.replaceChildren();
        shownLines = [];
        return;
      }
      moreButton.hidden = onlyErrors || !(log.total > (log.lines || []).length);
      updateLog(onlyErrors ? errorLines(log.lines || []) : log.lines || [], log.total || 0, live);
    } catch (err) {
      logNote.textContent = err.message;
    } finally {
      logAsking = false;
      const again = readAgain;
      readAgain = null;
      if (again && again.record.id === shownId) readLog(again.record, again.live);
    }
  }

  // Keeps the log box on the page and only adds and removes lines, so the
  // reader's scroll position and selection survive each update.
  function updateLog(lines, total, live) {
    if (errorsOnly) {
      logNote.textContent = lines.length
        ? `Showing ${lines.length} error ${lines.length === 1 ? 'line' : 'lines'} of ${total} lines.`
        : 'No lines in this log are marked as errors.';
    } else {
      logNote.textContent = lines.length
        ? `Showing the last ${lines.length} of ${total} lines.`
        : 'Nothing logged yet.';
    }
    const fromBottom = logOnScreen() ? fromBottomNow() : keptFromBottom;
    const dropped = linesDroppedFromTop(shownLines, lines);
    for (let i = 0; i < dropped && logBox.firstChild; i++) logBox.firstChild.remove();
    for (let i = shownLines.length - dropped; i < lines.length; i++) logBox.append(logLine(lines[i]));
    shownLines = lines;
    keptFromBottom = fromBottom;
    placeLog(live, fromBottom);
  }

  return {
    off(s) {
      laidOut = false;
      shownId = undefined;
      node.replaceChildren(el('div', { class: 'note' }, [
        el('h2', { class: 'panel-heading', text: 'Viewing only' }),
        el('p', {
          text: s.offline
            ? 'Unable to reach the server. Job controls are unavailable.'
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
        errorsOnly = false;
        forgetLog();
        tail = LOG_TAIL;
        shownTail = LOG_TAIL;
        readAgain = null;
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
      drawChips(chips, record, live, errorChip, errorsOnly);
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
      ? `Queued ${shortTime(queuedAt(record)) || 'at an unknown time'}`
      : `Finished ${shortTime(record.finishedAt) || 'at an unknown time'}`;
  const action = waiting
    ? el('button', { type: 'button', class: 'button', onclick: () => confirmAndRemove(record) }, [icon('remove'), 'Remove'])
    : live
    ? el('button', { type: 'button', class: 'button danger', onclick: () => confirmAndStop(record) }, [icon('stop'), 'Stop'])
    : el('button', {
      type: 'button',
      class: 'button',
      title: 'Start a new job with the same settings.',
      onclick: () => confirmAndStart({ ...(record.request || {}), replayAllowed: false }),
    }, [icon('run-again'), 'Run again']);
  node.replaceChildren(
    el('span', { class: `tag tag-${MARK_FOR_STATE[state] || 'idle'}`, text: STATE_WORDS[state] || state }),
    el('div', { class: 'run-title' }, [
      el('h2', { class: 'run-name', text: kind }),
      el('p', { class: 'run-sub', text: sub }),
    ]),
    ...(action ? [action] : []),
  );
}

/// The progress bar, count and percentage of a running job. They are made
/// once and changed in place, so the bar keeps moving while the run reports.
function drawMeter(node, live) {
  node.hidden = !live;
  if (!live) return;
  if (!node.firstChild) {
    node.append(progressBar(null), el('span', { class: 'run-count' }), el('span', { class: 'run-pct' }));
  }
  const [bar, count, pctText] = node.children;
  const pct = percent(live.itemsDone, live.itemsTotal);
  setProgress(bar, pct);
  count.textContent = live.itemsTotal ? `${live.itemsDone} / ${live.itemsTotal}` : `${live.itemsDone || 0} done`;
  pctText.textContent = pct == null ? '' : `${pct}%`;
}

function chip(label, value, kind = '') {
  return el('span', { class: `chip ${kind}` }, [el('b', { text: String(value) }), ` ${label}`]);
}

function drawChips(node, record, live, errorChip, errorsOnly) {
  const c = record.counters || {};
  const errorWord = c.errors === 1 ? 'error' : 'errors';
  errorChip.replaceChildren(el('b', { text: String(c.errors || 0) }), ` ${errorWord}`);
  errorChip.classList.toggle('on', errorsOnly);
  errorChip.setAttribute('aria-pressed', String(errorsOnly));
  errorChip.title = errorsOnly ? 'Show the whole log' : 'Show only error lines';
  // Redrawing the chips takes the button off the page for a moment.
  const hadFocus = document.activeElement === errorChip;
  const items = [
    live
      ? chip('elapsed', duration(record.startedAt, null) || '—')
      : el('span', { class: 'chip' }, ['Took ', el('b', { text: (startedAt(record) && duration(record.startedAt, record.finishedAt)) || '—' })]),
    chip(c.llmCalls === 1 ? 'LLM call' : 'LLM calls', c.llmCalls || 0),
    c.errors ? errorChip : chip(errorWord, 0),
  ];
  if (!live && c.itemsTotal) items.push(chip(`of ${c.itemsTotal} done`, c.itemsDone || 0));
  if (record.guardrailStop) {
    items.push(el('span', { class: 'chip warn', title: record.guardrailStop, text: 'Limit reached' }));
  }
  items.push(el('span', { class: 'chip id', text: record.id }));
  node.replaceChildren(...items);
  if (hadFocus) errorChip.focus();
}

/// How many changed mods or topics the What changed tab shows before
/// "View all" sends the reader to the What changed page.
const CHANGES_SHOWN = 25;

/// The What changed tab: the changes themselves, in the tab. A finished run
/// is compared with the snapshot before it: its catalog under Mods and its
/// mod details under Facts, whichever it saved. A running job compares the
/// newest snapshot with the data on disk, with Refresh to read it again.
/// `stillWanted()` is false once another run is shown.
async function drawChanged(node, record, live, stillWanted) {
  const message = (text) => node.replaceChildren(el('div', { class: 'note' }, [el('p', { text })]));
  if (record.state === 'queued') {
    message('Nothing has changed yet. The run is waiting in the queue.');
    return;
  }
  message('Loading…');
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
  const sections = [];
  if (live) {
    if (facts.length) sections.push({ tab: 'facts', a: facts[0], b: WORKING });
  } else {
    const modsPair = pair(mods);
    const factsPair = pair(facts);
    if (modsPair) sections.push({ tab: 'mods', ...modsPair });
    if (factsPair) sections.push({ tab: 'facts', ...factsPair });
  }
  if (!sections.length) {
    message('No earlier snapshot to compare with.');
    return;
  }

  const parts = await Promise.all(sections.map((s) => changeSection(s, sections.length > 1)));
  if (!stillWanted()) return;
  const refresh = live ? el('button', {
    type: 'button',
    class: 'button',
    icon: 'refresh',
    text: 'Refresh',
    onclick: () => drawChanged(node, record, live, stillWanted),
  }) : null;
  node.replaceChildren(el('div', { class: 'run-changed' }, [refresh, ...parts]));
}

/// One comparison drawn in the What changed tab: the counts, the first
/// changed mods or topics as the What changed page draws them, and
/// "View all" when there are more. `heading` names Mods or Facts when the run
/// saved both.
async function changeSection({ tab, a, b }, heading) {
  const name = tab === 'mods' ? 'Mods' : 'Facts';
  const all = buildHash(['changes'], { tab, a, b });
  let answer;
  try {
    answer = await api(tab === 'mods' ? 'merge/compare' : 'bundle/compare', { a, b, page: 0, pageSize: CHANGES_SHOWN });
  } catch (err) {
    return el('section', { class: 'run-changed-section' }, [
      heading ? el('h3', { class: 'run-changed-head', text: name }) : null,
      el('p', { class: 'error-text', text: err.message }),
    ]);
  }
  if (answer.missing) {
    return el('section', { class: 'run-changed-section' }, [
      heading ? el('h3', { class: 'run-changed-head', text: name }) : null,
      el('p', { class: 'dim', text: answer.hint || 'One of those snapshots is no longer kept.' }),
    ]);
  }
  const items = answer.items || [];
  const total = answer.total ?? items.length;
  const count = (n, word) => el('span', { class: 'chip' }, [el('b', { text: String(n ?? 0) }), ` ${word}`]);
  return el('section', { class: 'run-changed-section' }, [
    heading ? el('h3', { class: 'run-changed-head', text: name }) : null,
    el('div', { class: 'run-changed-counts' }, [
      count(answer.addedCount, 'added'),
      count(answer.goneCount, 'removed'),
      count(answer.changedCount, 'changed'),
      count(answer.sameCount, 'unchanged'),
    ]),
    items.length
      ? el('div', { class: 'ch-list' }, items.map((row) => (tab === 'mods' ? modCard(row) : topicCard(row))))
      : el('p', { class: 'dim', text: 'No differences found.' }),
    total > items.length ? el('a', { class: 'run-changed-all', href: all, text: `View all ${total} in What changed` }) : null,
  ]);
}

function drawRecord(node, record) {
  const c = record.counters || {};
  const rows = [
    ['Run', record.id],
    ['Job', describeJob(record.request || {})],
    ['Queued', shortTime(queuedAt(record))],
    ['Started', shortTime(startedAt(record))],
    ['Finished', record.finishedAt ? shortTime(record.finishedAt) : 'Not finished'],
    ['Took', startedAt(record) ? duration(record.startedAt, record.finishedAt) : ''],
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
  const level = logLevel(text);
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
    el('span', { class: 'row-time', text: shortTime(runTime(record)) }),
  ]);
}
