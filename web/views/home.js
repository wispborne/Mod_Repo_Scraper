// #/home — output files, search, jobs, latest run, and topic health.

import { api, el, clear, go, MissingFile, noticeDialog, breadcrumbs, fmtBytes } from '../lib.js';
import * as manager from '../manager.js';
import { addWhatChangedLink } from './run.js';

export async function render(root) {
  clear(root);
  root.append(breadcrumbs([]));

  const page = el('div', { class: 'stack' });
  const outputs = el('div', { class: 'output-cards' });
  page.append(heroBlock(outputs));
  page.append(searchBlock());

  const actions = el('div', {});
  const lastRun = el('div', {});
  const health = el('div', {});
  page.append(actions, lastRun, health);
  root.append(page);

  const status = manager.status() || await manager.refresh();
  drawActions(actions, status);
  loadOutputs(outputs);
  loadLastRun(lastRun);
  loadHealth(health);
}

// --- Output files ---

function heroBlock(outputs) {
  return el('div', { class: 'home-hero' }, [
    el('div', { class: 'home-hero-title' }, [
      el('h1', { text: 'Mod Repo Viewer' }),
      el('span', { class: 'home-hero-version', text: '2.0' }),
    ]),
    el('p', {
      class: 'home-hero-text',
      text: 'Browse mods from the forum, Discord, and Nexus in one catalog. '
        + 'Each mod has a permanent ID and a record of the posts or pages it came from.',
    }),
    outputs,
  ]);
}

const OUTPUTS = [
  {
    fileId: 'modrepo',
    file: 'mod-catalog.json',
    description: 'One entry per mod, with its ID and the posts or pages it came from.',
    href: '#/modrepo',
    loadCount: () => api('modrepo', { pageSize: 1 }),
    unit: 'mods',
  },
  {
    fileId: 'forum-data-bundle',
    file: 'mod-catalog-details.json',
    description: 'Forum topics with downloads and pictures, plus details from forum and Discord posts.',
    href: '#/bundle',
    loadCount: () => api('bundle/mods', { pageSize: 1 }),
    unit: 'topics',
  },
];

async function loadOutputs(node) {
  const [files, ...counts] = await Promise.all([
    api('files').catch(() => null),
    ...OUTPUTS.map((o) => o.loadCount().catch(() => null)),
  ]);
  const fileRows = (files && files.items) || [];
  clear(node);
  OUTPUTS.forEach((o, i) => {
    const file = fileRows.find((f) => f.id === o.fileId);
    const count = counts[i];
    const missing = !file || !file.exists || !count || count instanceof MissingFile;
    node.append(el('a', { class: 'output-card' + (missing ? ' missing-file' : ''), href: o.href }, [
      el('div', { class: 'output-card-file', text: o.file }),
      el('div', { class: 'output-card-description', text: o.description }),
      missing
        ? el('div', { class: 'output-card-count', text: 'Not written yet' })
        : el('div', { class: 'output-card-count' }, [
          String(count.total),
          el('small', { text: o.unit }),
        ]),
      file && file.exists
        ? el('div', {
          class: 'output-card-when',
          text: `Written ${manager.fmtTime(file.mtime)} · ${fmtBytes(file.size)}`,
        })
        : null,
    ]));
  });
}

// --- Search across topics, the bundle, and merged mods ---

function searchBlock() {
  const wrap = el('div', { class: 'home-search' });
  const input = el('input', {
    type: 'search',
    class: 'home-search-input',
    placeholder: 'Search topics, Mod Catalog and Mod Details…',
  });
  const results = el('div', { class: 'home-search-results' });
  let debounce;
  input.addEventListener('input', () => {
    clearTimeout(debounce);
    const q = input.value.trim();
    debounce = setTimeout(() => runSearch(results, q), 250);
  });
  wrap.append(input, results);
  return wrap;
}

// Ignore late responses from earlier searches.
let searchTicket = 0;

async function runSearch(node, q) {
  if (!q) {
    clear(node);
    return;
  }
  const ticket = ++searchTicket;
  clear(node).append(el('div', { class: 'loading', text: 'Searching…' }));
  const [topics, bundle, modrepo] = await Promise.all([
    api('topics', { q, pageSize: 6 }).catch(() => null),
    api('bundle/mods', { q, pageSize: 6 }).catch(() => null),
    api('modrepo', { q, pageSize: 6 }).catch(() => null),
  ]);
  if (ticket !== searchTicket) return;

  clear(node);
  const groups = [
    topicsGroup(topics),
    bundleGroup(bundle),
    modrepoGroup(modrepo),
  ].filter(Boolean);
  if (!groups.length) {
    node.append(el('p', { class: 'loading', text: `Nothing matches “${q}”.` }));
    return;
  }
  for (const g of groups) node.append(g);
}

function group(title, total, rows) {
  if (!rows.length) return null;
  const box = el('div', { class: 'home-result-group' });
  box.append(el('div', {
    class: 'home-result-head',
    text: total > rows.length ? `${title} (${rows.length} of ${total})` : `${title} (${total})`,
  }));
  for (const r of rows) box.append(r);
  return box;
}

function resultRow(href, title, sub) {
  return el('a', { class: 'home-result', href }, [
    el('span', { class: 'home-result-title', text: title || '(untitled)' }),
    sub ? el('span', { class: 'home-result-sub', text: sub }) : null,
  ]);
}

function topicsGroup(data) {
  if (!data || data instanceof MissingFile) return null;
  const rows = (data.items || []).map((it) =>
    resultRow(`#/topics/${it.topicId}`, it.title, `by ${it.author} · #${it.topicId}`));
  return group('Topics', data.total, rows);
}

function bundleGroup(data) {
  if (!data || data instanceof MissingFile) return null;
  const rows = (data.items || []).map((it) => {
    const row = it.index || {};
    return resultRow(`#/bundle/${row.topicId}`, row.title, `by ${row.author}`);
  });
  return group('Mod Details', data.total, rows);
}

function modrepoGroup(data) {
  if (!data || data instanceof MissingFile) return null;
  const rows = (data.items || []).map((it) =>
    resultRow(`#/modrepo/${it.index}`, it.name, `by ${(it.authorsList || []).join(', ')}`));
  return group('Mod Catalog', data.total, rows);
}

// --- Quick actions ---

function drawActions(node, status) {
  clear(node);
  const panel = el('div', { class: 'panel' });
  panel.append(el('h2', { text: 'Quick actions' }));

  if (!status || !status.on) {
    panel.append(el('p', {
      class: 'run-when',
      text: 'Viewing only. Job controls are disabled on this server. '
        + 'See Runs and queue for setup details.',
    }));
    node.append(panel);
    return;
  }

  const row = el('div', { class: 'job-buttons' });
  row.append(
    actionBtn('Start full run', 'Scrape new or changed topics on the main and libraries '
      + 'boards and run LLM extraction.',
      { kind: 'fullRun', scope: 'newData', boards: ['main', 'libraries'], runLlm: true, replayAllowed: false }, true),
    actionBtn('Merge saved sources', 'Merge saved sources into mod-catalog.json. No network requests.',
      { kind: 'mergeModRepo', collectMergeDebug: true }),
    actionBtn('Rebuild mod details', 'Rebuild mod-catalog-details.json from saved data.',
      { kind: 'rebuildBundle' }),
    actionBtn('LLM coverage pass', 'Extract missing or outdated LLM results from saved posts.',
      { kind: 'llmCoveragePass', runLlm: true }),
  );
  panel.append(row);
  panel.append(el('p', {
    class: 'run-when',
    text: 'For scope, board, and source options, open Runs and queue.',
  }));
  node.append(panel);
}

function actionBtn(label, title, request, primary) {
  return el('button', {
    class: 'btn' + (primary ? ' btn-primary' : ''),
    text: label,
    title: title || '',
    onclick: async () => {
      try {
        const record = await manager.confirmAndSubmit(request);
        if (record) go(`#/runs/${encodeURIComponent(record.id)}`);
      } catch (err) {
        noticeDialog('Could not start job', err.message);
      }
    },
  });
}

// --- Latest finished run ---

async function loadLastRun(node) {
  clear(node).append(el('div', { class: 'loading', text: 'Loading the last run…' }));
  let data;
  try {
    data = await api('manager/runs', { pageSize: 25 });
  } catch (_) {
    clear(node); // Manager off, or no history — nothing to show here.
    return;
  }
  const finished = (data.items || [])
    .filter((r) => r.state !== 'running' && r.state !== 'queued');
  if (!finished.length) {
    clear(node);
    return;
  }

  const r = finished[0];
  const c = r.counters || {};
  clear(node);
  const panel = el('div', { class: 'panel' });
  panel.append(el('h2', { text: 'Last run' }));

  const row = el('div', { class: 'run-head' }, [
    el('a', {
      class: 'run-title',
      href: `#/runs/${encodeURIComponent(r.id)}`,
      text: manager.kindLabel(r.request && r.request.kind),
    }),
    el('span', {
      class: 'badge ' + (manager.STATE_BADGES[r.state] || 'badge-dim'),
      text: r.state,
    }),
    el('span', {
      class: 'run-when',
      text: `${manager.fmtTime(r.startedAt)} · took `
        + `${manager.fmtDuration(r.startedAt, r.finishedAt)}`,
    }),
  ]);
  panel.append(row);

  const facts = [
    `${c.itemsDone || 0}${c.itemsTotal ? ' of ' + c.itemsTotal : ''} topics`,
  ];
  if (c.errors) facts.push(`${c.errors} errors`);
  if (c.llmCalls) facts.push(`${c.llmCalls} LLM calls`);
  panel.append(el('p', { class: 'run-when', text: facts.join(' · ') }));

  // Only runs with a bundle snapshot and a predecessor have a diff.
  addWhatChangedLink(row, r.id);

  node.append(panel);
}

// --- Topic health ---

async function loadHealth(node) {
  clear(node).append(el('div', { class: 'loading', text: 'Counting…' }));
  const [all, noDl, noLlm, placeholders] = await Promise.all([
    countTopics({}),
    countTopics({ filters: 'noDownload' }),
    countTopics({ filters: 'noLlmExtraction' }),
    countTopics({ filters: 'placeholderDetail' }),
  ]);
  if (all == null) {
    clear(node); // No topics index yet.
    return;
  }

  clear(node);
  node.append(el('h2', { text: 'At a glance' }));
  node.append(el('div', { class: 'stat-grid' }, [
    statCard('Topics saved', all, '#/topics'),
    statCard('No download found', noDl, '#/topics?filters=noDownload', 'warning'),
    statCard('No LLM results', noLlm, '#/topics?filters=noLlmExtraction'),
    statCard('Placeholders', placeholders, '#/topics?filters=placeholderDetail', 'error'),
  ]));
  node.append(el('p', {
    class: 'run-when',
    text: 'Select a count to view matching topics.',
  }));
}

async function countTopics(params) {
  try {
    const data = await api('topics', { ...params, pageSize: 1 });
    if (data instanceof MissingFile) return null;
    return data.total;
  } catch (_) {
    return null;
  }
}

function statCard(label, value, href, tone) {
  return el('a', { class: 'stat-card stat-card-link' + (tone ? ' ' + tone : ''), href }, [
    el('div', { class: 'label', text: label }),
    el('div', { class: 'value', text: value == null ? '—' : String(value) }),
  ]);
}
