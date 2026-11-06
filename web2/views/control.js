// The Control page: job buttons in the toolbar, the running (or last) run in
// the centre, and Needs attention, Queue and Recent runs at the side.

import { el, clear, api, shortTime } from '../lib.js';
import { icon } from '../icons.js';
import { subscribe } from '../status.js';
import { kindLabel, percent, oldViewerAddress } from '../routes.js';
import { pageLayout, sidePanel, statusMark, progressBar } from '../frame.js';
import {
  SCOPES, BOARDS, SOURCES, defaultFetchOptions, fetchHasWork, fetchRequest, llmRequest,
  rebuildRequest, publishRequest, scanImagesRequest, matchNamesRequest, describeJob, duration,
} from '../jobs.js';
import { confirmAndStart, confirmAndStop } from '../actions.js';

const MARK_FOR_STATE = {
  running: 'running',
  queued: 'idle',
  completed: 'done',
  failed: 'failed',
  cancelled: 'warning',
  interrupted: 'warning',
};

const STATE_WORDS = {
  running: 'Running',
  queued: 'Waiting',
  completed: 'Done',
  failed: 'Failed',
  cancelled: 'Stopped',
  interrupted: 'Interrupted',
};

const LOG_TAIL = 200;

// Job options last for the current visit.
const fetchOptions = defaultFetchOptions();
let llmAll = false;
let openTab = 'log';

export function render({ content, toolbar, onLeave }) {
  const main = el('div', { class: 'run-panel' });
  const attention = el('div');
  const queuePanel = el('div');
  const runsBody = el('div', { class: 'rows' }, [el('p', { class: 'empty', text: 'Loading…' })]);
  const runsPanel = sidePanel({
    name: 'Recent runs',
    body: el('div', {}, [
      runsBody,
      el('p', { class: 'side-more' }, [el('a', { href: '#/runs', text: 'View all runs' })]),
    ]),
  });
  content.append(pageLayout(main, [attention, queuePanel, runsPanel]));

  const run = runView(main);
  let lastOn = null;
  let lastQueueKey = null;
  let lastCurrent;
  let finishedRuns = [];
  let closeMenus = () => {};

  const loadRuns = async () => {
    try {
      const page = await api('manager/runs', { pageSize: 12 });
      const runs = (page && page.items) || [];
      finishedRuns = runs.filter((r) => r.state !== 'running' && r.state !== 'queued');
      clear(runsBody).append(...(runs.length
        ? runs.map(runRow)
        : [el('p', { class: 'empty', text: 'No runs yet.' })]));
    } catch (err) {
      finishedRuns = [];
      clear(runsBody).append(el('p', { class: 'empty', text: err.message }));
    }
  };

  onLeave(() => closeMenus());
  onLeave(subscribe(async (s) => {
    if (s.on !== lastOn) {
      lastOn = s.on;
      toolbar.actions.replaceChildren();
      closeMenus();
      closeMenus = s.on ? drawJobButtons(toolbar.actions) : () => {};
    }
    if (!s.on) run.off(s);

    const current = s.on && s.current ? s.current : null;
    const currentId = current ? current.record.id : null;
    if (currentId !== lastCurrent) {
      lastCurrent = currentId;
      await loadRuns();
      loadAttention(attention, finishedRuns[0] || null);
    }
    if (s.on) {
      if (current) run.show(current.record, current);
      else run.show(finishedRuns[0] || null, null);
    }

    const queued = s.on ? s.queued || [] : [];
    const key = queued.map((r) => r.id).join(',') + (s.on ? '' : ':off');
    if (key === lastQueueKey) return;
    lastQueueKey = key;
    const queueBody = el('div', { class: 'rows' }, queued.length
      ? queued.map(runRow)
      : [el('p', { class: 'empty', text: s.on ? 'Queue is empty.' : 'Jobs are off.' })]);
    queuePanel.replaceChildren(sidePanel({ name: 'Queue', count: queued.length, body: queueBody }));
  }));
}

// --- Toolbar job buttons ---

/// Draws the job buttons. Returns a function that closes any open menu and
/// stops listening.
function drawJobButtons(node) {
  const menus = [];
  const closeAll = (except) => {
    for (const m of menus) if (m !== except) m.close();
  };
  const onOutside = (e) => {
    if (!menus.some((m) => m.root.contains(e.target))) closeAll();
  };
  const onKey = (e) => {
    if (e.key === 'Escape') closeAll();
  };
  document.addEventListener('mousedown', onOutside);
  document.addEventListener('keydown', onKey);

  const fetchMain = el('button', {
    type: 'button',
    class: 'button primary split-main',
    onclick: () => confirmAndStart(fetchRequest(fetchOptions)),
  }, [icon('download', 14), 'Fetch and update']);
  const updateFetch = () => {
    const ok = fetchHasWork(fetchOptions);
    fetchMain.disabled = !ok;
    fetchMain.title = ok ? describeJob(fetchRequest(fetchOptions))
      : 'Select at least one board or source. To use saved data, choose Rebuild from saved.';
  };
  const fetchMenu = menuButton({
    label: 'Fetch and update options',
    main: fetchMain,
    primary: true,
    body: () => fetchOptionsPanel(updateFetch),
    onOpen: (m) => closeAll(m),
  });
  updateFetch();

  const llmMain = el('button', {
    type: 'button',
    class: 'button split-main',
    onclick: () => confirmAndStart(llmRequest(llmAll)),
  });
  const updateLlm = () => {
    llmMain.replaceChildren(icon('sparkles', 14), 'Run LLM', el('span', {
      class: llmAll ? 'choice warn-text' : 'choice',
      text: llmAll ? '· All' : '· Only changed',
    }));
    llmMain.title = describeJob(llmRequest(llmAll));
  };
  updateLlm();
  const llmMenu = menuButton({
    label: 'Run LLM options',
    main: llmMain,
    body: () => llmOptionsPanel(updateLlm),
    onOpen: (m) => closeAll(m),
  });

  const rebuild = el('button', {
    type: 'button',
    class: 'button',
    title: describeJob(rebuildRequest()),
    onclick: () => confirmAndStart(rebuildRequest()),
  }, [icon('refresh', 14), 'Rebuild from saved']);
  const publish = el('button', {
    type: 'button',
    class: 'button',
    title: describeJob(publishRequest()),
    onclick: () => confirmAndStart(publishRequest()),
  }, [icon('upload', 14), 'Publish']);

  const more = menuButton({
    label: 'More jobs',
    text: 'More',
    quiet: true,
    body: (close) => el('div', { class: 'menu-list', role: 'menu' }, [
      menuItem('Scan images', describeJob(scanImagesRequest()), () => { close(); confirmAndStart(scanImagesRequest()); }),
      menuItem('Match dependency names', describeJob(matchNamesRequest()), () => { close(); confirmAndStart(matchNamesRequest()); }),
    ]),
    onOpen: (m) => closeAll(m),
  });

  menus.push(fetchMenu, llmMenu, more);
  node.append(fetchMenu.root, llmMenu.root, rebuild, publish, more.root);

  return () => {
    closeAll();
    document.removeEventListener('mousedown', onOutside);
    document.removeEventListener('keydown', onKey);
  };
}

/// A button with a drop-down. With `main`, it is a split button: `main` does
/// the job and the arrow opens the menu. Without it, the whole button opens
/// the menu.
function menuButton({ label, main = null, text = null, primary = false, quiet = false, body, onOpen }) {
  const root = el('div', { class: 'menu-host' });
  const classes = ['button', main ? 'split-arrow' : '', primary ? 'primary' : '', quiet ? 'quiet' : '']
    .filter(Boolean).join(' ');
  const toggle = el('button', {
    type: 'button',
    class: classes,
    'aria-haspopup': 'true',
    'aria-expanded': 'false',
    'aria-label': label,
    title: label,
  }, [text ? el('span', { text }) : null, icon('chevron-down', 14)]);
  const panel = el('div', { class: 'menu', hidden: true });

  const menu = {
    root,
    close() {
      panel.hidden = true;
      toggle.setAttribute('aria-expanded', 'false');
    },
    open() {
      onOpen(menu);
      panel.replaceChildren(body(() => menu.close()));
      panel.hidden = false;
      toggle.setAttribute('aria-expanded', 'true');
      const first = panel.querySelector('input, select, button');
      if (first) first.focus();
    },
  };
  toggle.addEventListener('click', () => (panel.hidden ? menu.open() : menu.close()));
  if (main) root.append(el('div', { class: 'split' }, [main, toggle]));
  else root.append(toggle);
  root.append(panel);
  return menu;
}

function menuItem(text, hint, onclick) {
  return el('button', { type: 'button', class: 'menu-item', role: 'menuitem', onclick }, [
    el('span', { class: 'menu-item-name', text }),
    el('span', { class: 'menu-hint', text: hint }),
  ]);
}

function check(label, checked, onchange) {
  const box = el('input', { type: 'checkbox' });
  box.checked = checked;
  box.addEventListener('change', () => onchange(box.checked));
  return el('label', { class: 'check' }, [box, label]);
}

function toggleIn(list, value, on) {
  const i = list.indexOf(value);
  if (on && i < 0) list.push(value);
  if (!on && i >= 0) list.splice(i, 1);
}

function fetchOptionsPanel(changed) {
  const scope = el('select', { class: 'select' });
  for (const [value, label] of SCOPES) {
    const option = el('option', { value, text: label });
    if (value === fetchOptions.scope) option.selected = true;
    scope.append(option);
  }
  const note = el('p', {
    class: 'menu-note warn-text',
    text: 'Select at least one board or source. To use saved data, choose Rebuild from saved.',
  });
  const update = () => {
    scope.disabled = fetchOptions.boards.length === 0;
    note.hidden = fetchHasWork(fetchOptions);
    changed();
  };
  scope.addEventListener('change', () => { fetchOptions.scope = scope.value; update(); });

  const panel = el('div', { class: 'menu-form' }, [
    el('label', { class: 'field' }, [el('span', { class: 'field-label', text: 'Forum scope' }), scope]),
    el('div', { class: 'field' }, [
      el('span', { class: 'field-label', text: 'Boards' }),
      ...BOARDS.map(([value, label]) => check(label, fetchOptions.boards.includes(value), (on) => {
        toggleIn(fetchOptions.boards, value, on);
        update();
      })),
    ]),
    el('div', { class: 'field' }, [
      el('span', { class: 'field-label', text: 'Also fetch' }),
      ...SOURCES.map(([value, label]) => check(label, fetchOptions.sources.includes(value), (on) => {
        toggleIn(fetchOptions.sources, value, on);
        update();
      })),
    ]),
    el('div', { class: 'field' }, [
      el('span', { class: 'field-label', text: 'LLM' }),
      check('Extract mod details from new and changed posts', fetchOptions.runLlm, (on) => {
        fetchOptions.runLlm = on;
        update();
      }),
    ]),
    note,
  ]);
  update();
  return panel;
}

function llmOptionsPanel(changed) {
  const choice = (value, label, hint) => {
    const radio = el('input', { type: 'radio', name: 'llm-scope' });
    radio.checked = llmAll === value;
    radio.addEventListener('change', () => {
      if (radio.checked) llmAll = value;
      changed();
    });
    return el('label', { class: 'radio' }, [radio, el('span', { class: 'radio-text' }, [
      el('span', { text: label }),
      el('span', { class: 'menu-hint', text: hint }),
    ])]);
  };
  return el('div', { class: 'menu-form' }, [
    choice(false, 'Only changed', 'Posts with no answer, or whose post or prompt changed.'),
    choice(true, 'All', 'Every post again, oldest answer first. The per-run call limit still applies.'),
  ]);
}

// --- Run panel ---

/// The centre panel. `show(record, live)` draws a run: `live` is the status's
/// current entry while it runs, or null for a finished run.
function runView(node) {
  const head = el('div', { class: 'run-head' });
  const meter = el('div', { class: 'run-meter' });
  const chips = el('div', { class: 'chips' });
  const tabs = el('div', { class: 'tabs', role: 'tablist' });
  const logBox = el('div', { class: 'log-box', tabindex: '0', 'aria-label': 'Run log' });
  const logNote = el('p', { class: 'log-note' });
  const logPane = el('div', { class: 'tab-pane log-pane' }, [logNote, logBox]);
  const changedPane = el('div', { class: 'tab-pane' });
  const recordPane = el('div', { class: 'tab-pane' });
  const panes = { log: logPane, changed: changedPane, record: recordPane };

  let shownId;
  let shownLive = false;
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

  const layOut = () => {
    if (laidOut) return;
    laidOut = true;
    node.replaceChildren(head, meter, chips, tabs, logPane, changedPane, recordPane);
  };

  async function readLog(record, live) {
    if (logAsking) return;
    logAsking = true;
    try {
      const log = await api(`manager/runs/${encodeURIComponent(record.id)}/log`, { tail: LOG_TAIL });
      if (record.id !== shownId) return;
      if (!log || log.missing) {
        logNote.textContent = 'No log is available for this run.';
        logBox.replaceChildren();
        shownLines = [];
        return;
      }
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
      if (record.id !== shownId) {
        shownId = record.id;
        shownLines = [];
        followedOnce = false;
        logBox.replaceChildren();
        logNote.textContent = 'Loading…';
        readLog(record, !!live);
      } else if (live || shownLive) {
        // One last read after a run ends picks up its final lines.
        readLog(record, !!live);
      }
      shownLive = !!live;
      drawHead(head, record, live);
      drawMeter(meter, live);
      drawChips(chips, record, live);
      drawChanged(changedPane, record, live);
      drawRecord(recordPane, record);
    },
  };
}

function drawHead(node, record, live) {
  const kind = kindLabel(record.request && record.request.kind);
  const state = live ? 'running' : record.state;
  const sub = live
    ? [live.phase, live.item].filter(Boolean).join(' · ') || 'Starting…'
    : `Finished ${shortTime(record.finishedAt) || 'at an unknown time'}`;
  const action = live
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
    action,
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

function drawChanged(node, record, live) {
  const link = live
    ? oldViewerAddress(location.pathname, 'bundle/changes?b=working')
    : oldViewerAddress(location.pathname, `runs/${encodeURIComponent(record.id)}`);
  node.replaceChildren(el('div', { class: 'note' }, [
    el('p', {
      text: live
        ? 'Compare current local data with the latest snapshot.'
        : 'Compare these mod details with the previous snapshot.',
    }),
    el('p', { class: 'dim', text: 'The What changed page is coming soon. Until then, this opens the old viewer.' }),
    el('p', {}, [el('a', { class: 'out-link', href: link }, [
      live ? 'Changes so far' : 'View changes',
      icon('external-link', 14),
    ])]),
  ]));
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

// --- Side panels ---

function runRow(record) {
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

/// The Needs attention items, in order. `where` is the old viewer page that
/// fixes each one, until the new page is built.
const ATTENTION = [
  { key: 'unmatchedDependencyNames', label: 'Dependency names not matched', where: 'dependency-names' },
  { key: 'authorPairsToDecide', label: 'Author pairs to decide', where: 'author-aliases' },
  { key: 'takedownsExcludedNothing', label: 'Takedowns that excluded nothing', where: 'takedowns', warn: true },
  { key: 'takedownsReturned', label: 'Taken-down mods back under a new id', where: 'takedowns', warn: true },
  { key: 'postsWithoutLlmAnswer', label: 'Posts with no LLM answer', where: 'topics?filters=noLlmExtraction' },
  {
    key: 'modsWithoutDownload',
    label: 'Mods with no download',
    where: 'topics?filters=noDownload',
    hint: 'The old viewer has no list of these mods. This opens its topics with no download found.',
  },
];

async function loadAttention(node, lastRun) {
  let counts = {};
  try {
    counts = (await api('attention')) || {};
  } catch {
    counts = {};
  }
  const items = [];
  const errors = lastRun && lastRun.counters && lastRun.counters.errors;
  if (errors) {
    items.push({
      label: 'Errors in the last run',
      count: errors,
      bad: true,
      href: oldViewerAddress(location.pathname, `runs/${encodeURIComponent(lastRun.id)}`),
    });
  }
  for (const a of ATTENTION) {
    const n = counts[a.key];
    if (typeof n === 'number' && n > 0) {
      items.push({ label: a.label, count: n, warn: a.warn, hint: a.hint, href: oldViewerAddress(location.pathname, a.where) });
    }
  }
  if (!items.length) {
    node.replaceChildren();
    return;
  }
  node.replaceChildren(sidePanel({
    name: 'Needs attention',
    count: items.length,
    body: el('div', { class: 'rows' }, items.map((item) => el('a', {
      class: ['row', 'attention', item.bad ? 'bad' : '', item.warn ? 'warn' : ''].filter(Boolean).join(' '),
      href: item.href,
      title: item.hint || null,
    }, [
      el('span', { class: 'attention-count', text: String(item.count) }),
      el('span', { class: 'row-main', text: item.label }),
      icon('chevron-right', 14),
    ]))),
  }));
}
