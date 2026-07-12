// #/topics — searchable, sortable, filterable topic index (2.3).

import { api, el, clear, missingPanel, MissingFile, pager, go } from '../lib.js';

const FILTERS = [
  ['noDownload', 'No download'],
  ['lowConfidenceOnly', 'Low-confidence only'],
  ['llmOnlyDownloads', 'LLM found (rules missed)'],
  ['multiMod', 'More than one mod'],
  ['placeholderDetail', 'Placeholder detail'],
  ['missingGameVersion', 'Missing game version'],
  ['wip', 'WIP'],
  ['noLlmExtraction', 'No LLM extraction'],
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

  const toolbar = el('div', { class: 'toolbar' });
  const search = el('input', {
    type: 'search',
    placeholder: 'Search title or author…',
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

  const filterBar = el('div', { class: 'filters' });
  for (const [key, label] of FILTERS) {
    const chip = el('span', {
      class: 'chip' + (state.filters.has(key) ? ' on' : ''),
      text: label,
      onclick: () => {
        if (state.filters.has(key)) state.filters.delete(key);
        else state.filters.add(key);
        chip.classList.toggle('on');
        state.page = 0;
        load();
      },
    });
    filterBar.append(chip);
  }
  toolbar.append(filterBar);
  root.append(toolbar);

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

function buildTable(data, reload) {
  const wrap = el('div', { class: 'table-wrapper' });
  const table = el('table');
  const thead = el('thead');
  const htr = el('tr');
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
    tbody.append(el('tr', {}, el('td', { colspan: String(COLUMNS.length + 2), class: 'loading', text: 'No topics match.' })));
  }
  table.append(tbody);
  wrap.append(table);
  return wrap;
}

function flagBadges(flags) {
  const map = {
    noDownload: ['badge-error', 'no dl'],
    lowConfidenceOnly: ['badge-warning', 'low conf'],
    llmOnlyDownloads: ['badge-llm', 'llm found'],
    multiMod: ['badge-llm', 'multi-mod'],
    placeholderDetail: ['badge-dim', 'placeholder'],
    missingGameVersion: ['badge-warning', 'no ver'],
    wip: ['badge-secondary', 'wip'],
    noLlmExtraction: ['badge-dim', 'no llm'],
  };
  const out = [];
  for (const [key, [cls, label]] of Object.entries(map)) {
    if (flags[key]) {
      out.push(el('span', { class: 'badge ' + cls, text: label }), ' ');
    }
  }
  return out;
}
