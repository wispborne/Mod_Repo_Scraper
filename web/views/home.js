// #/home — the front door. One search across everything, the common jobs a
// click away, the last run at a glance, and a few numbers worth watching. Built
// entirely on endpoints the other pages already use.

import { api, el, clear, go, MissingFile, noticeDialog, breadcrumbs } from '../lib.js';
import * as manager from '../manager.js';
import { addWhatChangedLink } from './run.js';

export async function render(root) {
  clear(root);
  root.append(breadcrumbs([]));

  // One column with even spacing, so the panels below never touch. The last-run
  // and health blocks empty themselves when there is nothing to show, and an
  // empty block leaves no gap.
  const page = el('div', { class: 'stack' });
  page.append(el('h1', { text: 'Mod Repo Viewer' }));
  page.append(searchBlock());

  const actions = el('div', {});
  const lastRun = el('div', {});
  const health = el('div', {});
  page.append(actions, lastRun, health);
  root.append(page);

  const status = manager.status() || await manager.refresh();
  drawActions(actions, status);
  loadLastRun(lastRun);
  loadHealth(health);
}

// --- Search across topics, the bundle, and merged mods ---

function searchBlock() {
  const wrap = el('div', { class: 'home-search' });
  const input = el('input', {
    type: 'search',
    class: 'home-search-input',
    placeholder: 'Find a mod or topic — searches Topics, the Forum Data Bundle and ModRepo',
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

// Only the newest search is allowed to draw. A slower earlier answer that lands
// late is thrown away, so the results always match what is in the box.
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
  return group('Forum Data Bundle', data.total, rows);
}

function modrepoGroup(data) {
  if (!data || data instanceof MissingFile) return null;
  const rows = (data.items || []).map((it) =>
    resultRow(`#/modrepo/${it.index}`, it.name, `by ${(it.authorsList || []).join(', ')}`));
  return group('ModRepo', data.total, rows);
}

// --- The common jobs, one click away ---

function drawActions(node, status) {
  clear(node);
  const panel = el('div', { class: 'panel' });
  panel.append(el('h2', { text: 'Quick actions' }));

  if (!status || !status.on) {
    panel.append(el('p', {
      class: 'run-when',
      text: 'Viewing only — this server can show results but not run jobs. Start '
        + 'the viewer where config.properties lives to run jobs from here.',
    }));
    node.append(panel);
    return;
  }

  const row = el('div', { class: 'job-buttons' });
  row.append(
    actionBtn('Start full run', 'Go through anything new on the main and libraries '
      + 'boards, save it, and ask the LLM about each one.',
      { kind: 'fullRun', scope: 'newData', boards: ['main', 'libraries'], runLlm: true, replayAllowed: false }, true),
    actionBtn('Merge saved sources', 'Merge what is already on disk into ModRepo.json. No network.',
      { kind: 'mergeModRepo', collectMergeDebug: true }),
    actionBtn('Rebuild bundle', 'Build forum-data-bundle.json again from what is saved.',
      { kind: 'rebuildBundle' }),
    actionBtn('LLM coverage pass', 'Ask the LLM about every stored topic with no answers yet.',
      { kind: 'llmCoveragePass', runLlm: true }),
  );
  panel.append(row);
  panel.append(el('p', {
    class: 'run-when',
    text: 'Each one asks before it runs and says exactly what it will do. For full '
      + 'control over scope, boards and sources, use Runs and queue.',
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
        noticeDialog('The job was not started', err.message);
      }
    },
  });
}

// --- The last run, at a glance ---

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

  // The same conditional link the run's own page shows: only when this run
  // published a bundle and there is an older one to compare against.
  addWhatChangedLink(row, r.id);

  node.append(panel);
}

// --- A few numbers worth watching, each a way into the filtered topics list ---

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
    statCard('No LLM answers', noLlm, '#/topics?filters=noLlmExtraction'),
    statCard('Placeholders', placeholders, '#/topics?filters=placeholderDetail', 'error'),
  ]));
  node.append(el('p', {
    class: 'run-when',
    text: 'Each number opens the topics list already filtered to those rows.',
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
