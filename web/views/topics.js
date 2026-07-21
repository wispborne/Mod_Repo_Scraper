// #/topics — searchable, sortable, filterable topic index (2.3).

import { api, el, clear, missingPanel, MissingFile, pager, go } from '../lib.js';

// One source of truth for the eight topic flags. Each entry drives three
// things: the filter chip (label), the badge in the Flags column (cls + badge),
// and the plain-English meaning (desc) shown in the legend and as a hover
// tooltip on both the chip and the badge.
const FLAGS = [
  { key: 'noDownload', cls: 'badge-error', badge: 'no dl', label: 'No download',
    desc: 'No download link was found — not by the rules and not by the LLM.' },
  { key: 'lowConfidenceOnly', cls: 'badge-warning', badge: 'low conf', label: 'Low-confidence only',
    desc: 'Every download link found is a low-confidence guess.' },
  { key: 'llmOnlyDownloads', cls: 'badge-llm', badge: 'llm found', label: 'LLM found (rules missed)',
    desc: 'The LLM found a download link that the rules missed.' },
  { key: 'multiMod', cls: 'badge-llm', badge: 'multi-mod', label: 'More than one mod',
    desc: 'The LLM split this one thread into more than one mod.' },
  { key: 'placeholderDetail', cls: 'badge-dim', badge: 'placeholder', label: 'Placeholder detail',
    desc: 'Only a stub was saved — this topic was not fully scraped.' },
  { key: 'missingGameVersion', cls: 'badge-warning', badge: 'no ver', label: 'Missing game version',
    desc: 'No Starsector game version was found for this mod.' },
  { key: 'wip', cls: 'badge-secondary', badge: 'wip', label: 'WIP',
    desc: 'The thread is marked work-in-progress.' },
  { key: 'noLlmExtraction', cls: 'badge-dim', badge: 'no llm', label: 'No LLM extraction',
    desc: 'The LLM has not processed this topic yet.' },
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
  for (const f of FLAGS) {
    const chip = el('span', {
      class: 'chip' + (state.filters.has(f.key) ? ' on' : ''),
      text: f.label,
      title: f.desc,
      onclick: () => {
        if (state.filters.has(f.key)) state.filters.delete(f.key);
        else state.filters.add(f.key);
        chip.classList.toggle('on');
        state.page = 0;
        load();
      },
    });
    filterBar.append(chip);
  }
  toolbar.append(filterBar);
  root.append(toolbar);
  root.append(flagLegend());

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
  const out = [];
  for (const f of FLAGS) {
    if (flags[f.key]) {
      out.push(el('span', { class: 'badge ' + f.cls, text: f.badge, title: f.desc }), ' ');
    }
  }
  return out;
}

// A collapsible key that maps each badge to what it means, so the Flags column
// reads on its own without hunting through the code.
function flagLegend() {
  const details = el('details', { class: 'legend', open: '' });
  details.append(el('summary', { text: 'What do the flags mean?' }));
  const grid = el('div', { class: 'legend-grid' });
  for (const f of FLAGS) {
    grid.append(
      el('span', { class: 'badge ' + f.cls, text: f.badge, title: f.desc }),
      el('span', { class: 'legend-desc', text: f.desc }),
    );
  }
  details.append(grid);
  return details;
}
