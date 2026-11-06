// Source posts: every saved forum topic and Discord thread in one list, with
// what the last build made of each. Search, filters, sort and page are kept in
// the address. While the manager is on, posts can be ticked across pages and
// searches, and the per-post jobs run on the ticked posts.

import { el, clear, api, pager, pageSizePreference } from '../lib.js';
import { pageLayout, sidePanel } from '../frame.js';
import { subscribe, status } from '../status.js';
import { hashQuery, buildHash } from '../routes.js';
import { POST_JOBS, postJobCount, postJobRequest } from '../jobs.js';
import { confirmAndStart } from '../actions.js';

const PAGE_ID = 'posts';

/// The data quality numbers at the top. Each opens the list with its filter.
const NUMBERS = [
  ['noDownload', 'No download found'],
  ['noLlmAnswer', 'No LLM answer'],
  ['placeholder', 'Placeholder posts'],
];

/// The filters the server knows, with what each means.
const FILTERS = [
  ['noDownload', 'No download found', 'No downloads found by rules or LLM.'],
  ['noLlmAnswer', 'No LLM answer', 'No LLM answer is saved. Placeholders and topics with no saved post are not counted: they are never sent to the LLM.'],
  ['placeholder', 'Placeholder posts', 'Only a placeholder is saved; the full post is missing.'],
  ['leftOut', 'Left out', 'The last build made no mod from it.'],
  ['takenDown', 'Taken down', 'Every mod from it was taken down in the last build.'],
  ['collection', 'Collection', 'The last build made a Collection page from it.'],
];
const FILTER_KEYS = new Set(FILTERS.map(([key]) => key));

const KINDS = [
  ['all', 'All'],
  ['topic', 'Forum topics'],
  ['discord', 'Discord threads'],
];
const KIND_KEYS = new Set(KINDS.map(([key]) => key));

/// Sortable columns: the server's sort name and the direction used on the
/// first click.
const SORTS = { lastPost: 'desc', title: 'asc', mods: 'desc' };

// --- Ticked posts, kept for the tab ---

const TICKED_KEY = 'viewer2SelectedPosts';

function readTicked() {
  try {
    const list = JSON.parse(sessionStorage.getItem(TICKED_KEY) || '[]');
    return new Set(Array.isArray(list) ? list.map(String) : []);
  } catch {
    return new Set();
  }
}

function saveTicked(ticked) {
  try {
    sessionStorage.setItem(TICKED_KEY, JSON.stringify([...ticked]));
  } catch {
    // Storage blocked: the ticks last until the page is left.
  }
}

/// The sentence the other pages use when jobs are off.
function managerOffText(s) {
  if (s && s.offline) return 'The server could not be reached. Jobs cannot be started.';
  return `${(s && s.reason) || 'Job management is disabled on this server.'} Start the viewer with a readable `
    + 'config.properties file (or specify it with --config) and omit --no-manager to enable jobs.';
}

export function render({ content, onLeave }) {
  const query = hashQuery(location.hash);
  // The list's state, kept in the address. Pages count from 1 there.
  const view = {
    q: query.get('q') || '',
    kind: KIND_KEYS.has(query.get('kind')) ? query.get('kind') : 'all',
    filters: new Set((query.get('filters') || '').split(',').map((s) => s.trim()).filter((s) => FILTER_KEYS.has(s))),
    sort: query.get('sort') in SORTS ? query.get('sort') : 'lastPost',
    dir: null,
    page: Math.max(0, (parseInt(query.get('page'), 10) || 1) - 1),
    pageSize: pageSizePreference(),
  };
  view.dir = query.get('dir') === 'asc' || query.get('dir') === 'desc' ? query.get('dir') : SORTS[view.sort];

  const state = { data: null, error: null, on: null };
  const ticked = readTicked();

  const numbers = el('div', { class: 'pl-numbers' });
  const search = el('input', {
    type: 'search',
    class: 'input pl-search',
    placeholder: 'Search title, author, thread id or mod name…',
    'aria-label': 'Search source posts',
    autocomplete: 'off',
    spellcheck: 'false',
    value: view.q,
  });
  const kindTabs = el('div', { class: 'tabs pl-kinds', role: 'group', 'aria-label': 'Kind of post' });
  const filterBar = el('div', { class: 'pl-filters', role: 'group', 'aria-label': 'Filters' });
  const selectionSlot = el('div');
  const listSlot = el('div', { class: 'pl-list' }, [el('p', { class: 'empty', text: 'Loading…' })]);
  const main = el('div', { class: 'list-page pl-page' }, [
    numbers,
    el('div', { class: 'pl-toolbar' }, [search]),
    kindTabs,
    filterBar,
    selectionSlot,
    listSlot,
  ]);
  const sideSlot = el('div');
  content.append(pageLayout(main, [sideSlot]));

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
    if (!/^#\/posts(\?|$)/.test(location.hash)) return;
    history.replaceState(null, '', buildHash([PAGE_ID], {
      q: view.q,
      kind: view.kind === 'all' ? null : view.kind,
      filters: [...view.filters].join(','),
      sort: view.sort === 'lastPost' ? null : view.sort,
      dir: view.dir === SORTS[view.sort] ? null : view.dir,
      page: view.page > 0 ? view.page + 1 : null,
    }));
  };

  // --- Drawing ---

  const drawNumbers = () => {
    const counts = (state.data && state.data.counts) || null;
    clear(numbers);
    if (!counts) return;
    for (const [key, label] of NUMBERS) {
      const on = view.filters.size === 1 && view.filters.has(key);
      numbers.append(el('button', {
        type: 'button',
        class: `pl-number${on ? ' on' : ''}${counts[key] ? '' : ' zero'}`,
        'aria-pressed': String(on),
        title: `Show only posts with ${label.toLowerCase()}.`,
        onclick: () => {
          view.filters = new Set([key]);
          view.page = 0;
          load();
        },
      }, [
        el('span', { class: 'pl-number-count', text: String(counts[key] ?? 0) }),
        el('span', { class: 'pl-number-label', text: label }),
      ]));
    }
  };

  const drawControls = () => {
    clear(kindTabs);
    for (const [key, label] of KINDS) {
      const on = view.kind === key;
      kindTabs.append(el('button', {
        type: 'button',
        class: `tab${on ? ' on' : ''}`,
        'aria-pressed': String(on),
        onclick: () => {
          view.kind = key;
          view.page = 0;
          load();
        },
      }, [label]));
    }
    clear(filterBar);
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
      }, [label]));
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

  const drawSelection = () => {
    clear(selectionSlot);
    if (!state.on) return;
    const keys = [...ticked];
    const topics = keys.filter((k) => k.startsWith('topic:')).length;
    const buttons = POST_JOBS.map((job) => {
      const n = postJobCount(job.kind, keys);
      // Say how many a topics-only job acts on when threads are ticked too.
      const partial = job.topicsOnly && n > 0 && n < keys.length;
      return el('button', {
        type: 'button',
        class: 'button',
        disabled: n === 0,
        title: job.topicsOnly && keys.length && !topics ? 'Works on forum topics only.' : null,
        onclick: () => start(job.kind),
      }, [job.label, partial ? el('span', { class: 'choice', text: ` ${n} of ${keys.length}` }) : null]);
    });
    selectionSlot.append(el('div', { class: 'pl-selection' }, [
      el('span', {
        class: 'pl-selection-count',
        text: keys.length === 1 ? '1 post selected' : `${keys.length} posts selected`,
      }),
      ...buttons,
      el('button', {
        type: 'button',
        class: 'button quiet',
        text: 'Clear selection',
        disabled: !keys.length,
        onclick: () => {
          ticked.clear();
          saveTicked(ticked);
          drawSelection();
          drawList();
        },
      }),
      keys.length ? null : el('span', {
        class: 'pl-selection-hint',
        text: 'Select posts to run a job. Selection is kept across searches and pages.',
      }),
    ]));
  };

  const start = async (kind) => {
    const request = postJobRequest(kind, [...ticked]);
    const record = await confirmAndStart(request);
    if (!record) return;
    // Clear ticks only after the server accepts the job, and only the ones it
    // was sent: a forum-only job leaves the ticked Discord threads ticked.
    for (const topicId of request.topicIds || []) ticked.delete(`topic:${topicId}`);
    for (const threadId of request.discordThreadIds || []) ticked.delete(`discord:${threadId}`);
    saveTicked(ticked);
    drawSelection();
    drawList();
  };

  const toggle = (key, on) => {
    if (on) ticked.add(key);
    else ticked.delete(key);
    saveTicked(ticked);
    drawSelection();
  };

  const drawList = () => {
    clear(listSlot);
    if (state.error) {
      listSlot.append(el('p', { class: 'error-text pl-message', text: state.error }));
      return;
    }
    const data = state.data;
    if (!data) return;
    if (data.missing) {
      listSlot.append(el('p', { class: 'empty pl-message', text: `No saved posts yet. ${data.hint || ''}`.trim() }));
      return;
    }
    const items = data.items || [];
    listSlot.append(
      items.length
        ? postTable(items, { view, canTick: !!state.on, ticked, toggle, onSort: sortBy })
        : el('p', { class: 'empty pl-message', text: 'No posts match.' }),
      pager(data.page, data.pageSize, data.total, (p) => {
        view.page = p;
        load();
        kindTabs.scrollIntoView({ block: 'nearest' });
      }, (size) => {
        view.pageSize = size;
        view.page = 0;
        load();
      }),
    );
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

  const drawSide = () => {
    const parts = [];
    if (state.on === false) {
      parts.push(sidePanel({
        name: 'Viewing only',
        body: el('p', { class: 'pl-side-note', text: managerOffText(status()) }),
      }));
    }
    parts.push(sidePanel({ name: 'What happened to each post', body: outcomeLegend() }));
    sideSlot.replaceChildren(...parts);
  };

  // Answers to older requests are dropped once a newer one starts.
  let ticket = 0;
  const load = async () => {
    const mine = ++ticket;
    saveAddress();
    drawControls();
    drawNumbers();
    let data;
    try {
      data = await api('posts', {
        q: view.q,
        kind: view.kind === 'all' ? null : view.kind,
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
    drawNumbers();
    drawList();
  };

  let lastRunId;
  onLeave(subscribe((s) => {
    if (s.on !== state.on) {
      state.on = s.on;
      drawSide();
      drawSelection();
      drawList();
    }
    // A job that just ended may have changed the posts: read them again.
    const runId = s.current ? s.current.record.id : null;
    if (lastRunId !== undefined && runId !== lastRunId && lastRunId !== null) load();
    lastRunId = runId;
  }));

  state.on = status() ? status().on : null;
  drawSide();
  drawSelection();
  load();
}

// --- The table ---

const OUTCOME_CLASS = {
  leftOut: 'pl-dim',
  notInBuild: 'pl-dim',
  takenDown: 'warn-text',
};

/// What became of a post, in a few words. The server's whole sentence is the
/// hover text.
function outcomeWords(row) {
  const mods = row.modCount === 1 ? '1 mod' : `${row.modCount} mods`;
  switch (row.outcome) {
    case 'mods': return mods;
    case 'collection': return `Collection of ${mods}`;
    case 'leftOut': return 'Left out';
    case 'pointsTo': return 'Points to another topic';
    case 'takenDown': return 'Taken down';
    case 'notInBuild': return 'Not in the last build';
    default: return row.outcome || '';
  }
}

function postHref(row) {
  return `#/posts/${row.kind}/${encodeURIComponent(row.id)}`;
}

/// A post's last post day as written in the answer: the date part only.
function lastPostDay(text) {
  return text ? String(text).slice(0, 10) : '';
}

function postTable(items, { view, canTick, ticked, toggle, onSort }) {
  const sortHead = (key, label, cls = '') => {
    const active = view.sort === key;
    const arrow = active ? (view.dir === 'asc' ? ' ▲' : ' ▼') : '';
    return el('th', { class: cls, 'aria-sort': active ? (view.dir === 'asc' ? 'ascending' : 'descending') : null }, [
      el('button', { type: 'button', class: 'pl-sort', onclick: () => onSort(key) }, [label + arrow]),
    ]);
  };

  const boxes = [];
  let all = null;
  if (canTick) {
    all = el('input', { type: 'checkbox', 'aria-label': 'Select every post on this page' });
    all.addEventListener('change', () => {
      for (const box of boxes) {
        box.checked = all.checked;
        toggle(box.dataset.key, all.checked);
      }
    });
  }
  const syncAll = () => {
    if (!all) return;
    const on = boxes.filter((b) => b.checked).length;
    all.checked = on > 0 && on === boxes.length;
    all.indeterminate = on > 0 && on < boxes.length;
  };

  const head = el('tr', {}, [
    canTick ? el('th', { class: 'pl-pick' }, [all]) : null,
    el('th', { text: 'Kind' }),
    sortHead('title', 'Title'),
    el('th', { text: 'Author' }),
    sortHead('lastPost', 'Last post'),
    el('th', { class: 'num', text: 'Downloads' }),
    el('th', { text: 'LLM answer' }),
    sortHead('mods', 'What it became'),
  ]);

  const rows = items.map((row) => {
    const key = `${row.kind}:${row.id}`;
    const href = postHref(row);
    const counts = row.downloadCounts || {};
    let pick = null;
    if (canTick) {
      const box = el('input', { type: 'checkbox', 'data-key': key, 'aria-label': `Select ${row.title || key}` });
      box.checked = ticked.has(key);
      box.addEventListener('change', () => {
        toggle(key, box.checked);
        syncAll();
      });
      boxes.push(box);
      pick = el('td', { class: 'pl-pick' }, [box]);
    }
    const tr = el('tr', { class: 'clickable' }, [
      pick,
      el('td', { class: 'pl-kind mono', text: row.kind === 'discord' ? 'Discord' : 'Forum' }),
      el('td', { class: 'pl-title' }, [
        el('a', { href, text: row.title || (row.kind === 'discord' ? `Discord thread ${row.id}` : `Topic ${row.id}`) }),
        row.isPlaceholder ? el('span', { class: 'tag tag-idle pl-tag', text: 'Placeholder' }) : null,
      ]),
      el('td', { class: 'pl-author', text: row.author || '' }),
      el('td', { class: 'pl-date mono', text: lastPostDay(row.lastPostDate) }),
      el('td', {
        class: `num mono pl-downloads${row.downloads ? '' : ' warn-text'}`,
        title: `Rules found ${counts.rules ?? 0}. The LLM found ${counts.llm ?? 0}.`,
        text: row.downloads ? String(row.downloads) : 'None',
      }),
      el('td', {
        class: `pl-llm${row.hasLlmAnswer ? '' : ' pl-dim'}`,
        text: row.hasLlmAnswer ? 'Yes' : 'No',
      }),
      el('td', { class: `pl-outcome ${OUTCOME_CLASS[row.outcome] || ''}`, title: row.line || null, text: outcomeWords(row) }),
    ]);
    // Clicking anywhere in the row opens the post. The title link works by keyboard.
    tr.addEventListener('click', (e) => {
      if (e.target.closest('a, input, button, label')) return;
      if (e.target.closest('.pl-pick')) return;
      location.hash = href;
    });
    return tr;
  });
  syncAll();

  return el('div', { class: 'table-wrap' }, [
    el('table', { class: 'table pl-table' }, [el('thead', {}, [head]), el('tbody', {}, rows)]),
  ]);
}

/// What the words in the last column mean.
function outcomeLegend() {
  const item = (label, text) => el('div', {}, [el('dt', { text: label }), el('dd', { text })]);
  return el('dl', { class: 'pl-legend' }, [
    item('Mods', 'The mods the last build made from the post. A post can give several.'),
    item('Collection', 'The post lists mods that each have their own page, and it keeps a page that lists them.'),
    item('Left out', 'The last build made no mod from it. Its page says why, when the build saved a reason.'),
    item('Points to another topic', 'Each mod on it has a forum topic of its own, where the mod is published.'),
    item('Taken down', 'Every mod from it is on the takedown list.'),
    item('Not in the last build', 'It was saved after the last build, or the build did not read it.'),
  ]);
}
