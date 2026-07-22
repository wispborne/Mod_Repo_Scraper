// #/topics — searchable, sortable, filterable topic index (2.3).

import { api, el, clear, missingPanel, MissingFile, pager, go } from '../lib.js';
import * as manager from '../manager.js';

// True only when the server can actually run jobs. When it can't, none of the
// picking-and-acting parts are drawn at all — the page reads exactly as the
// read-only viewer always has.
let canAct = false;

// One source of truth for the eight topic flags. Each entry drives three
// things: the filter chip (label), the badge in the Flags column (cls + badge),
// and the plain-English meaning (desc) shown in the legend and as a hover
// tooltip on both the chip and the badge.
const FLAGS = [
  { key: 'noDownload', cls: 'badge-error', badge: 'no dl', label: 'No download',
    desc: 'Nothing found, by rules or LLM.' },
  { key: 'lowConfidenceOnly', cls: 'badge-warning', badge: 'low conf', label: 'Low-confidence only',
    desc: 'Every link found is a guess.' },
  { key: 'llmOnlyDownloads', cls: 'badge-llm', badge: 'llm found', label: 'LLM found (rules missed)',
    desc: 'The LLM caught a link the rules missed.' },
  { key: 'multiMod', cls: 'badge-llm', badge: 'multi-mod', label: 'More than one mod',
    desc: 'One thread, several mods.' },
  { key: 'placeholderDetail', cls: 'badge-dim', badge: 'placeholder', label: 'Placeholder detail',
    desc: 'A stub only — never fully scraped.' },
  { key: 'missingGameVersion', cls: 'badge-warning', badge: 'no ver', label: 'Missing game version',
    desc: 'No game version found.' },
  { key: 'wip', cls: 'badge-secondary', badge: 'wip', label: 'WIP',
    desc: 'Marked work-in-progress.' },
  { key: 'noLlmExtraction', cls: 'badge-dim', badge: 'no llm', label: 'No LLM extraction',
    desc: 'The LLM has not seen it yet.' },
];

const COLUMNS = [
  ['topicId', 'ID', 'num'],
  ['title', 'Title', ''],
  ['author', 'Author', ''],
  ['gameVersion', 'Game ver', ''],
  ['replies', 'Replies', 'num'],
  ['views', 'Views', 'num'],
  ['lastPostDate', 'Last post', ''],
];

// View state lives here so search/filter/sort/paging survive re-renders.
const state = {
  q: '',
  filters: new Set(),
  sort: 'lastPostDate',
  dir: 'desc',
  page: 0,
  pageSize: 50,
};

export async function render(root) {
  clear(root);
  root.append(el('h1', { text: 'Topics' }));

  const status = manager.status() || await manager.refresh();
  canAct = !!(status && status.on);

  const toolbar = el('div', { class: 'toolbar' });
  const search = el('input', {
    type: 'search',
    placeholder: 'Search title, author or thread id…',
    value: state.q,
  });
  let debounce;
  search.addEventListener('input', () => {
    clearTimeout(debounce);
    debounce = setTimeout(() => {
      state.q = search.value.trim();
      state.page = 0;
      load();
    }, 250);
  });
  toolbar.append(search);

  root.append(toolbar);
  root.append(flagPicker(() => {
    state.page = 0;
    load();
  }));

  if (canAct) root.append(selectionBar());

  const results = el('div', {});
  root.append(results);

  async function load() {
    clear(results).append(el('div', { class: 'loading', text: 'Loading…' }));
    const data = await api('topics', {
      q: state.q,
      filters: [...state.filters].join(','),
      sort: state.sort,
      dir: state.dir,
      page: state.page,
      pageSize: state.pageSize,
    });
    clear(results);
    if (data instanceof MissingFile) {
      results.append(missingPanel(data));
      return;
    }
    results.append(buildTable(data, load), pager(data.page, data.pageSize, data.total, (p) => {
      state.page = p;
      load();
    }));
  }

  load();
}

// The bar above the table: how many are ticked, and what can be done with
// them. The ticked set lives in manager.js, so it survives paging, searching
// and moving between views.
function selectionBar() {
  const bar = el('div', { class: 'selection-bar' });
  const count = el('span', { class: 'selection-count' });
  const hint = el('span', {
    class: 'selection-hint',
    text: 'Tick topics to act on them. The tick marks stay as you page and search.',
  });

  const buttons = [
    ['Re-scrape', 'rescrapeTopics'],
    ['Re-resolve downloads', 'resolveDownloads'],
    ['Re-run LLM', 'extractLlm'],
  ].map(([label, kind]) =>
    el('button', {
      class: 'btn',
      text: label,
      onclick: () => act(kind),
    })
  );
  const clearBtn = el('button', {
    class: 'btn',
    text: 'Clear',
    onclick: () => manager.selection.clear(),
  });

  bar.append(count, ...buttons, clearBtn, hint);

  function draw(n) {
    count.textContent = n === 1 ? '1 topic selected' : `${n} topics selected`;
    for (const b of [...buttons, clearBtn]) {
      if (n) b.removeAttribute('disabled');
      else b.setAttribute('disabled', 'true');
    }
  }
  draw(manager.selection.count());

  const unsubscribe = manager.selection.subscribe((n) => {
    draw(n);
    // Keep the ticks on screen in step with the set (e.g. after Clear).
    for (const box of document.querySelectorAll('input[data-topic-id]')) {
      box.checked = manager.selection.has(box.dataset.topicId);
    }
  });
  const stop = () => {
    unsubscribe();
    window.removeEventListener('hashchange', stop);
  };
  window.addEventListener('hashchange', stop);

  return bar;
}

async function act(kind) {
  const ids = manager.selection.ids();
  if (!ids.length) return;
  try {
    const record = await manager.confirmAndSubmit({
      kind,
      topicIds: ids,
      runLlm: true,
    });
    if (!record) return;
    // The job owns these topics now, so the ticks have done their work.
    manager.selection.clear();
    go('#/runs');
  } catch (err) {
    window.alert(err.message);
  }
}

function buildTable(data, reload) {
  const wrap = el('div', { class: 'table-wrapper' });
  const table = el('table');
  const thead = el('thead');
  const htr = el('tr');
  if (canAct) htr.append(el('th', { class: 'pick', text: '' }));
  for (const [key, label, cls] of COLUMNS) {
    const active = state.sort === key;
    const arrow = active ? (state.dir === 'asc' ? ' ▲' : ' ▼') : '';
    htr.append(
      el('th', {
        class: 'sortable ' + (cls || ''),
        text: label + arrow,
        onclick: () => {
          if (state.sort === key) state.dir = state.dir === 'asc' ? 'desc' : 'asc';
          else {
            state.sort = key;
            state.dir = 'asc';
          }
          reload();
        },
      })
    );
  }
  htr.append(el('th', { text: 'Downloads' }), el('th', { text: 'Flags' }));
  thead.append(htr);
  table.append(thead);

  const tbody = el('tbody');
  for (const row of data.items) {
    const tr = el('tr', {
      class: 'clickable',
      onclick: () => go(`#/topics/${row.topicId}`),
    });
    if (canAct) {
      const box = el('input', { type: 'checkbox', 'data-topic-id': String(row.topicId) });
      box.checked = manager.selection.has(row.topicId);
      box.addEventListener('click', (ev) => ev.stopPropagation()); // Don't open the topic.
      box.addEventListener('change', () => manager.selection.toggle(row.topicId, box.checked));
      tr.append(el('td', { class: 'pick' }, box));
    }
    for (const [key, , cls] of COLUMNS) {
      tr.append(el('td', { class: cls || '', text: row[key] ?? '—' }));
    }
    const dc = row.downloadCounts || {};
    const dlCell = [
      el('span', { class: 'badge badge-secondary', text: `rules ${dc.rules ?? 0}` }),
      ' ',
      el('span', { class: 'badge badge-llm', text: `llm ${dc.llm ?? 0}` }),
    ];
    if ((dc.mods ?? 0) > 1) {
      dlCell.push(' ', el('span', { class: 'badge badge-llm', text: `${dc.mods} mods` }));
    }
    tr.append(el('td', {}, dlCell));
    tr.append(el('td', {}, flagBadges(row.filters || {})));
    tbody.append(tr);
  }
  if (data.items.length === 0) {
    const width = COLUMNS.length + 2 + (canAct ? 1 : 0);
    tbody.append(el('tr', {}, el('td', { colspan: String(width), class: 'loading', text: 'No topics match.' })));
  }
  table.append(tbody);
  wrap.append(table);
  return wrap;
}

function flagBadges(flags) {
  const out = [];
  for (const f of FLAGS) {
    if (flags[f.key]) {
      out.push(el('span', { class: 'badge ' + f.cls, text: f.badge, title: f.desc }), ' ');
    }
  }
  return out;
}

// The filters and the key to the badges are one thing, not two: each flag is a
// button carrying the same badge you see in the Flags column, its name, and
// what it means. Tight by default, so the eight fit on a line or two; "explain
// these" opens them out into a row each with the meaning spelled out.
function flagPicker(onChange) {
  const wrap = el('div', { class: 'flag-picker' });

  for (const f of FLAGS) {
    const chip = el('button', {
      class: 'flag-chip' + (state.filters.has(f.key) ? ' on' : ''),
      title: f.desc,
      onclick: () => {
        if (state.filters.has(f.key)) state.filters.delete(f.key);
        else state.filters.add(f.key);
        chip.classList.toggle('on');
        onChange();
      },
    }, [
      el('span', { class: 'badge ' + f.cls, text: f.badge }),
      el('span', { class: 'flag-chip-name', text: f.label }),
      el('span', { class: 'flag-chip-desc', text: f.desc }),
    ]);
    wrap.append(chip);
  }

  const explain = el('button', {
    class: 'flag-explain',
    text: 'Explain these',
    onclick: () => {
      const open = wrap.classList.toggle('explained');
      explain.textContent = open ? 'Hide the meanings' : 'Explain these';
    },
  });

  return el('div', { class: 'flag-picker-wrap' }, [wrap, explain]);
}
