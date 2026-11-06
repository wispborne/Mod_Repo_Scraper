// Mods: every mod in the last build, from `GET /api/mods`. Search, filters,
// sort and page are kept in the address. Each row opens the mod's page.

import { el, clear, api, pager, pageSizePreference } from '../lib.js';
import { pageLayout, sidePanel } from '../frame.js';
import { hashQuery, buildHash } from '../routes.js';
import { modHref } from '../mod_words.js';

const PAGE_ID = 'mods';

/// The filters the server knows, with what each means.
const FILTERS = [
  ['noDownload', 'No download', 'Starmodder has no download for it.'],
  ['takenDown', 'Taken down', 'On the takedown list. It is left out of everything we publish.'],
  ['conflicts', 'Has conflicts', 'Its post names a mod it conflicts with.'],
  ['aiStated', 'AI use stated', 'The author says whether AI was used.'],
];
const FILTER_KEYS = new Set(FILTERS.map(([key]) => key));

/// Sortable columns: the server's sort name and the direction used on the
/// first click.
const SORTS = { name: 'asc', authors: 'asc', gameVersion: 'desc', conflicts: 'desc' };

const SOURCE_WORDS = { forum: 'Forum', discord: 'Discord', nexus: 'Nexus' };

export function render({ content, onLeave }) {
  const query = hashQuery(location.hash);
  // The list's state, kept in the address. Pages count from 1 there.
  const view = {
    q: query.get('q') || '',
    filters: new Set((query.get('filters') || '').split(',').map((s) => s.trim()).filter((s) => FILTER_KEYS.has(s))),
    sort: query.get('sort') in SORTS ? query.get('sort') : 'name',
    dir: null,
    page: Math.max(0, (parseInt(query.get('page'), 10) || 1) - 1),
    pageSize: pageSizePreference(),
  };
  view.dir = query.get('dir') === 'asc' || query.get('dir') === 'desc' ? query.get('dir') : SORTS[view.sort];
  // All on one page: an old page number in the address means nothing.
  if (!view.pageSize) view.page = 0;

  const state = { data: null, error: null };

  const search = el('input', {
    type: 'search',
    class: 'input ml-search',
    placeholder: 'Search name, nickname, author or id…',
    'aria-label': 'Search mods',
    autocomplete: 'off',
    spellcheck: 'false',
    value: view.q,
  });
  const filterBar = el('div', { class: 'pl-filters', role: 'group', 'aria-label': 'Filters' });
  const countLine = el('p', { class: 'ml-count', 'aria-live': 'polite' });
  const listSlot = el('div', { class: 'ml-list' }, [el('p', { class: 'empty pl-message', text: 'Loading…' })]);
  const main = el('div', { class: 'list-page ml-page' }, [
    el('div', { class: 'pl-toolbar ml-toolbar' }, [search, countLine]),
    filterBar,
    listSlot,
  ]);
  content.append(pageLayout(main, [sidePanel({ name: 'What the columns mean', body: legend() })]));

  let debounce;
  search.addEventListener('input', () => {
    clearTimeout(debounce);
    debounce = setTimeout(() => {
      view.q = search.value.trim();
      view.page = 0;
      load();
    }, 250);
  });
  onLeave(() => clearTimeout(debounce));

  const saveAddress = () => {
    // Leave the address alone once the reader has moved to another page.
    if (!/^#\/mods(\?|$)/.test(location.hash)) return;
    history.replaceState(null, '', buildHash([PAGE_ID], {
      q: view.q,
      filters: [...view.filters].join(','),
      sort: view.sort === 'name' ? null : view.sort,
      dir: view.dir === SORTS[view.sort] ? null : view.dir,
      page: view.pageSize && view.page > 0 ? view.page + 1 : null,
    }));
  };

  const drawFilters = () => {
    clear(filterBar);
    const counts = (state.data && state.data.counts) || {};
    for (const [key, label, desc] of FILTERS) {
      const on = view.filters.has(key);
      filterBar.append(el('button', {
        type: 'button',
        class: `pl-filter${on ? ' on' : ''}`,
        'aria-pressed': String(on),
        title: desc,
        onclick: () => {
          if (on) view.filters.delete(key);
          else view.filters.add(key);
          view.page = 0;
          load();
        },
      }, [label, counts[key] == null ? null : el('span', { class: 'ml-filter-count', text: ` ${counts[key]}` })]));
    }
    if (view.filters.size) {
      filterBar.append(el('button', {
        type: 'button',
        class: 'link-button pl-clear',
        text: 'Clear filters',
        onclick: () => {
          view.filters = new Set();
          view.page = 0;
          load();
        },
      }));
    }
  };

  const sortBy = (key) => {
    if (view.sort === key) view.dir = view.dir === 'asc' ? 'desc' : 'asc';
    else {
      view.sort = key;
      view.dir = SORTS[key];
    }
    view.page = 0;
    load();
  };

  const drawList = () => {
    clear(listSlot);
    countLine.textContent = '';
    if (state.error) {
      listSlot.append(el('p', { class: 'error-text pl-message', text: state.error }));
      return;
    }
    const data = state.data;
    if (!data) return;
    if (data.missing) {
      listSlot.append(el('p', { class: 'empty pl-message', text: `No catalog yet. ${data.hint || ''}`.trim() }));
      return;
    }
    const items = data.items || [];
    countLine.textContent = data.total === 1 ? '1 mod' : `${data.total} mods`;
    listSlot.append(
      items.length
        ? modTable(items, view, sortBy)
        : el('p', { class: 'empty pl-message', text: 'No mods match.' }),
      pager(data.page, data.pageSize, data.total, (p) => {
        view.page = p;
        load();
        filterBar.scrollIntoView({ block: 'nearest' });
      }, (size) => {
        view.pageSize = size;
        view.page = 0;
        load();
      }),
    );
  };

  // Answers to older requests are dropped once a newer one starts.
  let ticket = 0;
  const load = async () => {
    const mine = ++ticket;
    saveAddress();
    drawFilters();
    let data;
    try {
      data = await api('mods', {
        q: view.q,
        filters: [...view.filters].join(','),
        sort: view.sort,
        dir: view.dir,
        page: view.page,
        pageSize: view.pageSize,
      });
    } catch (err) {
      if (mine !== ticket) return;
      state.error = err.message;
      drawList();
      return;
    }
    if (mine !== ticket) return;
    state.error = null;
    // Go back to the last page when this one is past the end.
    if (data && !data.missing && !(data.items || []).length && view.page > 0 && data.total > 0) {
      view.page = view.pageSize ? Math.max(0, Math.ceil(data.total / view.pageSize) - 1) : 0;
      load();
      return;
    }
    // A page past the end comes back as the last page: keep its number.
    if (data && !data.missing && Number.isInteger(data.page) && data.pageSize && data.page !== view.page) {
      view.page = data.page;
      saveAddress();
    }
    state.data = data;
    drawFilters();
    drawList();
  };

  load();
}

// --- The table ---

function modTable(items, view, onSort) {
  const sortHead = (key, label, cls = '') => {
    const active = view.sort === key;
    const arrow = active ? (view.dir === 'asc' ? ' ▲' : ' ▼') : '';
    return el('th', { class: cls, 'aria-sort': active ? (view.dir === 'asc' ? 'ascending' : 'descending') : null }, [
      el('button', { type: 'button', class: 'pl-sort', onclick: () => onSort(key) }, [label + arrow]),
    ]);
  };
  const head = el('tr', {}, [
    sortHead('name', 'Name'),
    sortHead('authors', 'Authors'),
    sortHead('gameVersion', 'Game version'),
    el('th', { text: 'Mod version' }),
    el('th', { text: 'Sources' }),
    el('th', { text: 'Download' }),
    sortHead('conflicts', 'Notes'),
  ]);

  const rows = items.map((row) => {
    const href = modHref(row.id);
    const name = row.displayName || row.name || row.id;
    const notes = [];
    if (row.takenDown) notes.push(el('span', { class: 'tag tag-failed', text: 'Taken down' }));
    const conflicts = Number(row.conflicts) || (Array.isArray(row.conflicts) ? row.conflicts.length : 0);
    if (conflicts) {
      notes.push(el('span', { class: 'tag tag-warning', text: conflicts === 1 ? '1 conflict' : `${conflicts} conflicts` }));
    }
    if (row.usesAi === true) notes.push(el('span', { class: 'tag tag-idle', text: 'Uses AI' }));
    else if (row.usesAi === false) notes.push(el('span', { class: 'tag tag-idle', text: 'No AI' }));

    const tr = el('tr', { class: `clickable${row.takenDown ? ' ml-gone' : ''}` }, [
      el('td', { class: 'ml-name' }, [
        el('a', { href, text: name }),
        el('code', { class: 'ml-id', text: row.id }),
      ]),
      el('td', { class: 'ml-authors', text: (row.authors || []).join(', ') }),
      el('td', { class: 'ml-game mono', text: row.gameVersion || '' }),
      el('td', { class: 'ml-version mono', text: row.modVersion || '' }),
      el('td', { class: 'ml-sources', text: (row.sources || []).map((s) => SOURCE_WORDS[String(s).toLowerCase()] || s).join(', ') }),
      el('td', {
        class: `ml-download${row.hasDownload ? '' : ' warn-text'}`,
        text: row.hasDownload ? 'Yes' : 'None',
      }),
      el('td', { class: 'ml-notes' }, notes),
    ]);
    // Clicking anywhere in the row opens the mod. The name link works by keyboard.
    tr.addEventListener('click', (e) => {
      if (e.target.closest('a, button')) return;
      location.hash = href;
    });
    return tr;
  });

  return el('div', { class: 'table-wrap' }, [
    el('table', { class: 'table pl-table ml-table' }, [el('thead', {}, [head]), el('tbody', {}, rows)]),
  ]);
}

function legend() {
  const item = (label, text) => el('div', {}, [el('dt', { text: label }), el('dd', { text })]);
  return el('dl', { class: 'pl-legend' }, [
    item('Name', 'The name Starmodder shows, with the mod’s permanent id under it.'),
    item('Sources', 'Where the mod was found: the forum, Discord or Nexus.'),
    item('Download', 'Whether Starmodder offers a download for it.'),
    item('Notes', 'Taken down, the conflicts its post names, and what the author says about AI use. This column sorts by the number of conflicts.'),
  ]);
}
