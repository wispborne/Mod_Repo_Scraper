// #/runs — active job, queue, history, and job forms.

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

  // Unsubscribe on navigation. Reload history when the active run changes.
  let lastCurrentId = null;
  let firstDraw = true;
  let starterDrawnFor = null;
  const unsubscribe = manager.subscribe((s) => {
    drawLive(live, s);
    // Redraw forms only when manager availability changes to preserve inputs.
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

// --- Active job and queue ---

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
        field('Current item', current.item || '—'),
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
    text: 'Stop run',
    onclick: async (ev) => {
      const button = ev.currentTarget;
      const yes = await askDialog({
        title: 'Stop run?',
        message: 'The run stops between topics. Data already saved is kept.',
        confirmLabel: 'Stop run',
        danger: true,
      });
      if (!yes) return;
      button.disabled = true;
      try {
        const answer = await manager.cancelCurrent(runId);
        noticeDialog('Stopping run', answer.message || 'Stop requested.');
      } catch (err) {
        button.disabled = false;
        noticeDialog('Could not stop run', err.message);
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

/// Explains why job controls are unavailable and how to enable them.
export function managerOffPanel(s) {
  return el('div', { class: 'missing' }, [
    el('h3', { text: 'Viewing only' }),
    el('p', {
      text: s && s.offline
        ? 'The server could not be reached. Job controls are unavailable.'
        : (s && s.reason ? s.reason : 'Job management is disabled on this server.')
          + ' Start the viewer with a readable config.properties file '
          + '(or specify it with --config) and omit --no-manager to enable jobs.',
    }),
  ]);
}

// --- Job forms ---

const SCOPES = [
  ['newData', 'New or changed topics'],
  ['all', 'All topics on selected boards'],
  ['librariesOnly', 'Libraries board only'],
];

const BOARDS = [
  ['main', 'Main mods board', true],
  ['libraries', 'Libraries board', true],
  ['lesser', 'Lesser mods board', false],
];

function drawStarter(node, s) {
  clear(node);
  if (!s.on) return;

  const panel = el('div', { class: 'panel' });
  panel.append(el('h2', { text: 'Start a job' }));
  panel.append(el('p', {
    class: 'run-when',
    text: 'Scrape jobs fetch current pages. Use the command line to replay cached pages.',
  }));

  panel.append(el('div', { class: 'job-columns' }, [
    scrapeCard(), mergeCard(), publishCard(),
  ]));
  node.append(panel);
}

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
    el('label', { class: 'job-check' }, [llmBox, ' Run LLM extraction']),
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

  // These jobs use saved posts rather than scraping the forum.
  card.append(el('div', { class: 'job-subhead', text: 'Without scraping' }));
  card.append(el('div', { class: 'job-buttons' }, [
    el('button', {
      class: 'btn',
      text: 'LLM coverage pass',
      title: 'Extract missing or outdated LLM results from saved posts.',
      onclick: () => start({ kind: 'llmCoveragePass', runLlm: true }),
    }),
    el('button', {
      class: 'btn',
      text: 'Rebuild mod details',
      title: 'Rebuild mod-catalog-details.json from saved data.',
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

function mergeCard() {
  const sourceBoxes = MOD_SOURCES.map(([value, label, on]) => {
    const box = el('input', { type: 'checkbox', value });
    box.checked = on;
    return { value, box, label };
  });
  const keepVersionsBox = el('input', { type: 'checkbox' });

  const card = el('div', { class: 'job-card' });
  card.append(el('h3', { text: 'Merge into mod-catalog.json' }));
  card.append(el('p', {
    class: 'run-when',
    text: 'Each merge saves a snapshot for comparison in Catalog diff.',
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
      ' Keep all game versions listed by a source',
    ]),
  ]));

  card.append(el('div', { class: 'job-buttons' }, [
    el('button', {
      class: 'btn btn-primary',
      text: 'Merge from saved files',
      title: 'Merge saved sources. No network requests.',
      onclick: () => start({
        kind: 'mergeModRepo',
        keepAllGameVersions: keepVersionsBox.checked,
        collectMergeDebug: true,
      }),
    }),
    el('button', {
      class: 'btn',
      text: 'Scrape then merge',
      title: 'Fetch selected sources, then merge into mod-catalog.json.',
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

/// Publishes current outputs without additional job settings.
function publishCard() {
  const card = el('div', { class: 'job-card' });
  card.append(el('h3', { text: 'Publish to GitHub' }));
  card.append(el('p', {
    class: 'run-when',
    text: 'Publish current outputs and the website to the GitHub repo TriOS reads. '
      + 'If nothing changed, nothing is pushed.',
  }));
  card.append(el('div', { class: 'job-buttons' }, [
    el('button', {
      class: 'btn btn-primary',
      text: 'Publish to GitHub',
      title: 'Publish current outputs and the website to GitHub.',
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
    noticeDialog('Could not start job', err.message);
  }
}

// --- History ---

// Initial loads and run-start refreshes can overlap. Tickets prevent an older
// response from replacing newer history results.
let historyTicket = 0;

async function loadHistory(node) {
  const ticket = ++historyTicket;
  // Keep existing results visible until their replacement arrives.
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

  // Active runs appear above with live counters; stored counters can lag.
  // They occupy the first page, so subtract the omitted rows from the total.
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
  // Align count headings with their numeric cells.
  const columns = [
    ['Job', ''], ['Started', ''], ['Duration', ''], ['State', ''],
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
      text: 'limit reached',
      title: r.guardrailStop,
    }), ' ');
  }
  if (r.errorMessage) {
    out.push(el('span', { class: 'badge badge-error', text: 'error', title: r.errorMessage }));
  }
  return out;
}
