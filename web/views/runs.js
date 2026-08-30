// #/runs — what is running now, what is waiting, what has already run, and the
// form for starting a whole-store job.

import {
  api, el, clear, pager, pageSizePreference, go, errorPanel,
  askDialog, noticeDialog, breadcrumbs,
} from '../lib.js';
import * as manager from '../manager.js';

const state = { page: 0, pageSize: pageSizePreference() };

export async function render(root) {
  clear(root);
  root.append(breadcrumbs([{ label: 'Runs and queue' }]));
  root.append(el('h1', { text: 'Runs' }));

  const live = el('div', { class: 'run-section' });
  const starter = el('div', { class: 'run-section' });
  const history = el('div', { class: 'run-section' });
  root.append(live, starter, history);

  // One subscription for this view; dropped as soon as the hash changes, so
  // leaving the page stops the fast polling. The history list reloads on the
  // first answer and whenever the running job changes — which is when a run has
  // just joined the history.
  let lastCurrentId = null;
  let firstDraw = true;
  let starterDrawnFor = null;
  const unsubscribe = manager.subscribe((s) => {
    drawLive(live, s);
    // The form is only redrawn when the manager goes on or off. Rebuilding it
    // on every beat would throw away whatever the user had just chosen.
    if (starterDrawnFor !== s.on) {
      starterDrawnFor = s.on;
      drawStarter(starter, s);
    }
    const id = s.current && s.current.record ? s.current.record.id : null;
    if (s.on && (firstDraw || id !== lastCurrentId)) {
      firstDraw = false;
      lastCurrentId = id;
      loadHistory(history);
    }
  });
  const stop = () => {
    unsubscribe();
    window.removeEventListener('hashchange', stop);
  };
  window.addEventListener('hashchange', stop);

  await manager.refresh();
}

// --- What is running now, and what is waiting ---

function drawLive(node, s) {
  clear(node);
  if (!s.on) {
    node.append(managerOffPanel(s));
    return;
  }

  const panel = el('div', { class: 'panel' });
  panel.append(el('h2', { text: 'Running now' }));
  const current = s.current;
  if (!current) {
    panel.append(el('p', { class: 'loading', text: 'Nothing is running.' }));
  } else {
    const record = current.record || {};
    const done = current.itemsDone || 0;
    const total = current.itemsTotal || 0;
    panel.append(
      el('div', { class: 'run-head' }, [
        el('a', {
          class: 'run-title',
          href: `#/runs/${encodeURIComponent(record.id)}`,
          text: manager.kindLabel(record.request && record.request.kind),
        }),
        el('span', { class: 'badge badge-primary', text: 'running' }),
        el('span', {
          class: 'run-when',
          text: `started ${manager.fmtTime(record.startedAt)} · `
            + `${manager.fmtDuration(record.startedAt, null)} so far`,
        }),
      ])
    );
    panel.append(progressBar(done, total));
    panel.append(
      el('ul', { class: 'field-list' }, [
        field('Phase', current.phase || '—'),
        field('Doing now', current.item || '—'),
        field('Done', total > 0 ? `${done} of ${total}` : String(done)),
        field('Errors', String((record.counters && record.counters.errors) || 0)),
        field('LLM calls', String((record.counters && record.counters.llmCalls) || 0)),
      ])
    );
    panel.append(stopRunButton(record.id));
  }

  const queued = s.queued || [];
  if (queued.length) {
    panel.append(el('h3', { text: `Waiting (${queued.length})` }));
    const list = el('ol', { class: 'queue-list' });
    for (const r of queued) {
      list.append(el('li', {}, [
        el('a', {
          href: `#/runs/${encodeURIComponent(r.id)}`,
          text: manager.kindLabel(r.request && r.request.kind),
        }),
        ' ',
        el('span', { class: 'run-when', text: topicNote(r.request) }),
      ]));
    }
    panel.append(list);
  }
  node.append(panel);
}

/// The confirmed stop action shared by the Runs view and a live run's page.
export function stopRunButton(runId) {
  return el('button', {
    class: 'btn btn-danger',
    text: 'Stop this run',
    onclick: async (ev) => {
      const button = ev.currentTarget;
      const yes = await askDialog({
        title: 'Stop this run?',
        message: 'It stops between topics and keeps everything it has '
          + 'already saved.',
        confirmLabel: 'Stop it',
        danger: true,
      });
      if (!yes) return;
      button.disabled = true;
      try {
        const answer = await manager.cancelCurrent(runId);
        noticeDialog('Stopping', answer.message || 'Asked the run to stop.');
      } catch (err) {
        button.disabled = false;
        noticeDialog('That didn\'t work', err.message);
      }
    },
  });
}

function topicNote(request) {
  const n = (request && request.topicIds ? request.topicIds.length : 0);
  if (!n) return '';
  return n === 1 ? '1 topic' : `${n} topics`;
}

export function progressBar(done, total) {
  const pct = total > 0 ? Math.min(100, (done / total) * 100) : 0;
  return el('div', { class: 'timing-bar-container' }, [
    el('div', { class: 'timing-bar-label' }, [
      el('span', { text: total > 0 ? `${done} / ${total}` : `${done} done` }),
      el('span', { text: total > 0 ? `${pct.toFixed(0)}%` : '' }),
    ]),
    el('div', { class: 'timing-bar' }, [
      el('div', { class: 'timing-bar-fill', style: `width: ${pct}%` }),
    ]),
  ]);
}

function field(label, value) {
  return el('li', {}, [
    el('span', { class: 'field-label', text: label }),
    el('span', { class: 'field-value', text: value }),
  ]);
}

/// The manager is off: say so calmly and say how to turn it on. No buttons —
/// there is nothing here to press.
export function managerOffPanel(s) {
  return el('div', { class: 'missing' }, [
    el('h3', { text: 'Viewing only' }),
    el('p', {
      text: s && s.offline
        ? 'The server could not be reached, so there is nothing to manage right now.'
        : 'This server was started without a config file, so it can show results '
          + 'but not run jobs. Start the viewer where config.properties lives '
          + '(or point it there with --config) to run jobs from here.',
    }),
  ]);
}

// --- Starting a whole-store job ---

const SCOPES = [
  ['newData', 'New data only — topics that changed since last time'],
  ['all', 'Everything — every topic on the chosen boards'],
  ['librariesOnly', 'Libraries board only'],
];

const BOARDS = [
  ['main', 'Main mods board', true],
  ['libraries', 'Libraries board', true],
  ['lesser', 'Lesser mods board', false],
];

function drawStarter(node, s) {
  clear(node);
  if (!s.on) return; // Nothing to start.

  const panel = el('div', { class: 'panel' });
  panel.append(el('h2', { text: 'Start a job' }));
  panel.append(el('p', {
    class: 'run-when',
    text: 'What a job will do is written out in full before it runs — nothing is '
      + 'taken from the config file behind your back. Jobs started here always '
      + 'fetch fresh pages; replaying saved pages stays a command-line option.',
  }));

  panel.append(el('div', { class: 'job-columns' }, [
    scrapeCard(), mergeCard(), publishCard(),
  ]));
  node.append(panel);
}

/// The whole-store scrape and extract jobs, in one card.
function scrapeCard() {
  const scopeSelect = el('select', { class: 'field-input' });
  for (const [value, label] of SCOPES) {
    scopeSelect.append(el('option', { value, text: label }));
  }
  const boardBoxes = BOARDS.map(([value, label, on]) => {
    const box = el('input', { type: 'checkbox', value });
    box.checked = on;
    return { value, box, label };
  });
  const llmBox = el('input', { type: 'checkbox' });
  llmBox.checked = true;

  const card = el('div', { class: 'job-card' });
  card.append(el('h3', { text: 'Scrape and extract' }));
  card.append(el('label', { class: 'job-field' }, [
    el('span', { class: 'field-label', text: 'Scope' }),
    scopeSelect,
  ]));
  const boardRow = el('div', { class: 'job-field' }, [
    el('span', { class: 'field-label', text: 'Boards' }),
  ]);
  for (const b of boardBoxes) {
    boardRow.append(el('label', { class: 'job-check' }, [b.box, ' ' + b.label]));
  }
  card.append(boardRow);
  card.append(el('div', { class: 'job-field' }, [
    el('span', { class: 'field-label', text: 'LLM' }),
    el('label', { class: 'job-check' }, [llmBox, ' Ask the LLM about each topic']),
  ]));
  card.append(el('button', {
    class: 'btn btn-primary',
    text: 'Start full run',
    onclick: () => start({
      kind: 'fullRun',
      scope: scopeSelect.value,
      boards: boardBoxes.filter((b) => b.box.checked).map((b) => b.value),
      runLlm: llmBox.checked,
      replayAllowed: false,
    }),
  }));

  // The two whole-store jobs that need no choices and touch no network.
  card.append(el('div', { class: 'job-subhead', text: 'Without scraping' }));
  card.append(el('div', { class: 'job-buttons' }, [
    el('button', {
      class: 'btn',
      text: 'LLM coverage pass',
      title: 'Ask the LLM about every stored topic that has no answers yet.',
      onclick: () => start({ kind: 'llmCoveragePass', runLlm: true }),
    }),
    el('button', {
      class: 'btn',
      text: 'Rebuild bundle',
      title: 'Build forum-data-bundle.json again from what is already saved.',
      onclick: () => start({ kind: 'rebuildBundle' }),
    }),
  ]));
  return card;
}

const MOD_SOURCES = [
  ['forum', 'Forum', true],
  ['discord', 'Discord', true],
  ['nexus', 'Nexus', true],
];

/// The merge into ModRepo.json, in one card. Merging from saved files costs
/// nothing, so it gets the plain button; scraping first is spelt out and
/// confirmed.
function mergeCard() {
  const sourceBoxes = MOD_SOURCES.map(([value, label, on]) => {
    const box = el('input', { type: 'checkbox', value });
    box.checked = on;
    return { value, box, label };
  });
  const keepVersionsBox = el('input', { type: 'checkbox' });

  const card = el('div', { class: 'job-card' });
  card.append(el('h3', { text: 'Merge into ModRepo.json' }));
  card.append(el('p', {
    class: 'run-when',
    text: 'Merging saves its own copy of the workings, so you can look at this '
      + 'merge next to an older one in the ModRepo explorer.',
  }));

  const sourceRow = el('div', { class: 'job-field' }, [
    el('span', { class: 'field-label', text: 'Sources' }),
  ]);
  for (const s of sourceBoxes) {
    sourceRow.append(el('label', { class: 'job-check' }, [s.box, ' ' + s.label]));
  }
  card.append(sourceRow);
  card.append(el('div', { class: 'job-field' }, [
    el('span', { class: 'field-label', text: 'Versions' }),
    el('label', { class: 'job-check' }, [
      keepVersionsBox,
      ' Keep every game version one source lists',
    ]),
  ]));

  card.append(el('div', { class: 'job-buttons' }, [
    el('button', {
      class: 'btn btn-primary',
      text: 'Merge from saved files',
      title: 'Merge what is already on disk. No network requests.',
      onclick: () => start({
        kind: 'mergeModRepo',
        keepAllGameVersions: keepVersionsBox.checked,
        collectMergeDebug: true,
      }),
    }),
    el('button', {
      class: 'btn',
      text: 'Scrape then merge',
      title: 'Fetch the ticked sources fresh, then merge. Takes a few minutes.',
      onclick: () => start({
        kind: 'scrapeAndMerge',
        modSources: sourceBoxes.filter((s) => s.box.checked).map((s) => s.value),
        keepAllGameVersions: keepVersionsBox.checked,
        collectMergeDebug: true,
        replayAllowed: false,
      }),
    }),
  ]));
  return card;
}

/// Publishing the current outputs to GitHub, in one card. It needs no choices —
/// it pushes whatever is in outputs/ right now — so it is just the one button,
/// with the confirm dialog spelling out what will happen.
function publishCard() {
  const card = el('div', { class: 'job-card' });
  card.append(el('h3', { text: 'Publish to GitHub' }));
  card.append(el('p', {
    class: 'run-when',
    text: 'Push the current ModRepo.json and forum-data-bundle.json to the '
      + 'GitHub repo TriOS reads. If nothing changed since last time, nothing '
      + 'is pushed.',
  }));
  card.append(el('div', { class: 'job-buttons' }, [
    el('button', {
      class: 'btn btn-primary',
      text: 'Publish to GitHub',
      title: 'Push the current outputs to the GitHub repo TriOS reads.',
      onclick: () => start({ kind: 'publishOutputs' }),
    }),
  ]));
  return card;
}

async function start(request) {
  try {
    const record = await manager.confirmAndSubmit(request);
    if (record) go(`#/runs/${encodeURIComponent(record.id)}`);
  } catch (err) {
    noticeDialog('The job was not started', err.message);
  }
}

// --- History ---

// Two asks can be in the air at once — the first draw and the "a run just
// started" one land within a second of each other. Each ask takes a ticket, and
// only the newest one is allowed to put anything on the page; an older answer
// arriving late is thrown away. Without this, the slower ask cleared the box
// while the quicker one was still fetching, and the list was drawn twice.
let historyTicket = 0;

async function loadHistory(node) {
  const ticket = ++historyTicket;
  // Only say "Loading…" when there is nothing to look at yet. A reload over an
  // existing list swaps it in place, with no blink.
  if (!node.firstChild) {
    node.append(historyPanel([el('div', { class: 'loading', text: 'Loading…' })]));
  }
  let data;
  try {
    data = await api('manager/runs', { page: state.page, pageSize: state.pageSize });
  } catch (err) {
    if (ticket !== historyTicket) return;
    clear(node).append(historyPanel([errorPanel(err)]));
    return;
  }
  if (ticket !== historyTicket) return;

  // A run that hasn't finished is shown in full at the top of the page, and its
  // record on disk lags behind (counters are saved every tenth report), so a row
  // for it here would only ever be a staler copy of what is already on screen.
  // They are always the newest, so they are only ever on the first page — which
  // is why taking them off the count stays exact.
  const all = data.items || [];
  const items = all.filter((r) => r.state !== 'running' && r.state !== 'queued');
  const total = data.total - (all.length - items.length);

  const inside = [];
  if (!items.length) {
    inside.push(el('p', { class: 'loading', text: 'No finished runs yet.' }));
  } else {
    inside.push(runTable(items));
    inside.push(pager(data.page, data.pageSize, total, (p) => {
      state.page = p;
      loadHistory(node);
    }, (size) => {
      state.pageSize = size;
      state.page = 0;
      loadHistory(node);
    }));
  }
  clear(node).append(historyPanel(inside));
}

function historyPanel(children) {
  return el('div', { class: 'panel' }, [
    el('h2', { text: 'Past runs' }),
    ...children,
  ]);
}

function runTable(items) {
  const wrap = el('div', { class: 'table-wrapper' });
  const table = el('table');
  const head = el('tr');
  // The counts are right-aligned in their cells, so their headings have to be
  // too — otherwise every number reads as sitting under the next heading along.
  const columns = [
    ['Kind', ''], ['Started', ''], ['Took', ''], ['State', ''],
    ['Done', 'num'], ['Errors', 'num'], ['LLM calls', 'num'], ['Notes', ''],
  ];
  for (const [label, cls] of columns) {
    head.append(el('th', { class: cls, text: label }));
  }
  table.append(el('thead', {}, head));

  const body = el('tbody');
  for (const r of items) {
    const c = r.counters || {};
    const tr = el('tr', {
      class: 'clickable',
      onclick: () => go(`#/runs/${encodeURIComponent(r.id)}`),
    });
    tr.append(
      el('td', {}, [
        el('span', { text: manager.kindLabel(r.request && r.request.kind) }),
        ' ',
        el('span', { class: 'run-when', text: topicNote(r.request) }),
      ]),
      el('td', { text: manager.fmtTime(r.startedAt) }),
      el('td', { text: manager.fmtDuration(r.startedAt, r.finishedAt) }),
      el('td', {}, el('span', {
        class: 'badge ' + (manager.STATE_BADGES[r.state] || 'badge-dim'),
        text: r.state,
      })),
      el('td', { class: 'num', text: c.itemsTotal ? `${c.itemsDone}/${c.itemsTotal}` : String(c.itemsDone || 0) }),
      el('td', { class: 'num', text: String(c.errors || 0) }),
      el('td', { class: 'num', text: String(c.llmCalls || 0) }),
      el('td', {}, notes(r)),
    );
    body.append(tr);
  }
  table.append(body);
  wrap.append(table);
  return wrap;
}

function notes(r) {
  const out = [];
  if (r.guardrailStop) {
    out.push(el('span', {
      class: 'badge badge-warning',
      text: 'stopped at a cap',
      title: r.guardrailStop,
    }), ' ');
  }
  if (r.errorMessage) {
    out.push(el('span', { class: 'badge badge-error', text: 'error', title: r.errorMessage }));
  }
  return out;
}
