// What changed (#/changes): the output of two saved runs, side by side.
// Two tabs share one picker. Mods compares the catalog each run saved
// (`/api/merge/compare`); Facts compares the mod details (`/api/bundle/compare`),
// where the newer side can also be the data on disk right now. That side
// changes while a run is going, and is worked out again only when Refresh is
// pressed: a redraw on a timer would lose the reader's place and every row
// they opened.
//
// The tab, both sides, the search, the filter, the page and the open rows are
// kept in the address.

import { el, clear, api, pager, pageSizePreference, infoButton, foldArrow } from '../lib.js';
import { pageLayout } from '../frame.js';
import { hashQuery, buildHash } from '../routes.js';
import { icon } from '../icons.js';
import { badge, when } from '../post_parts.js';
import {
  diffTable, changedFieldsLine, changedFieldsTitle, expandAllButton, jobWord, isImported,
} from '../diff_parts.js';
import {
  WORKING, TABS, tabFrom, settleSides, openFrom, openParam, postForMod, modsToLink,
} from '../change_sides.js';

const TAB = {
  mods: {
    label: 'Mods',
    compare: 'merge/compare',
    thing: 'mods',
    one: 'mod',
    search: 'Search mod name or author…',
  },
  facts: {
    label: 'Facts',
    compare: 'bundle/compare',
    thing: 'topics',
    one: 'topic',
    search: 'Search topic title or author…',
  },
};

/// The count boxes, which are also the filters: [kind, label, tone].
const KINDS = [
  ['added', 'Added', 'good'],
  ['gone', 'Removed', 'bad'],
  ['changed', 'Changed', 'warn'],
];
const KIND_KEYS = new Set(KINDS.map(([k]) => k));

export async function render({ content, onLeave }) {
  const query = hashQuery(location.hash);
  const view = {
    tab: tabFrom(query.get('tab')),
    // What the reader or a link asked for. A tab with no snapshot for one of
    // them shows a stand-in, and going back to the other tab restores these.
    picked: { a: query.get('a') || '', b: query.get('b') || '' },
    a: '',
    b: '',
    moved: [],
    q: (query.get('q') || '').trim(),
    kind: KIND_KEYS.has(query.get('kind')) ? query.get('kind') : '',
    page: Math.max(0, (parseInt(query.get('page'), 10) || 1) - 1),
    pageSize: pageSizePreference(),
    open: openFrom(query.get('open')),
  };

  const tabBar = el('div', { class: 'tabs ch-tabs', role: 'tablist', 'aria-label': 'What to compare' });
  const pickerSlot = el('div', { class: 'ch-picker' });
  const notes = el('div', { class: 'ch-notes', 'aria-live': 'polite' });
  const search = el('input', {
    type: 'search',
    class: 'input ch-search',
    autocomplete: 'off',
    spellcheck: 'false',
    value: view.q,
  });
  const counts = el('div', { class: 'ch-counts' });
  const results = el('div', { class: 'ch-list' }, [el('p', { class: 'empty ch-message', text: 'Loading…' })]);
  const pagerSlot = el('div');
  const foldAll = expandAllButton(results, 'details.ch-card');
  // Expand all only when there are rows to open.
  const syncFoldAll = () => {
    foldAll.hidden = !results.querySelector('details.ch-card');
    foldAll.refresh();
  };
  // Hidden until the saved runs have loaded, so no empty box shows meanwhile.
  const searchRow = el('div', { class: 'ch-search-row', hidden: true }, [
    search, infoButton('About What changed', 'What changed', legend), el('span', { class: 'gap' }), foldAll,
  ]);
  const body = el('div', { class: 'ch-body' }, [pickerSlot, notes, searchRow, counts, results, pagerSlot]);
  const main = el('div', { class: 'list-page ch-page' }, [tabBar, body]);
  content.append(pageLayout(main));
  syncFoldAll();

  // Both lists of saved runs: the picker needs both to say which snapshots a
  // run has, and to find a stand-in when one tab has none for it.
  const [mergeList, bundleList] = await Promise.all([
    api('merge/runs').catch(() => ({ items: [] })),
    api('bundle/runs').catch(() => ({ items: [] })),
  ]);
  if (!main.isConnected) return;
  const lists = {
    mods: (mergeList && mergeList.items) || [],
    facts: (bundleList && bundleList.items) || [],
  };
  const working = (bundleList && bundleList.working) || null;
  const ids = { mods: new Set(lists.mods.map((r) => r.id)), facts: new Set(lists.facts.map((r) => r.id)) };
  const other = (tab) => (tab === 'mods' ? 'facts' : 'mods');
  const findRun = (id) => lists.facts.find((r) => r.id === id) || lists.mods.find((r) => r.id === id) || null;

  // --- The address ---

  const saveAddress = () => {
    // Leave the address alone once the reader has moved to another page.
    if (!/^#\/changes(\?|$)/.test(location.hash)) return;
    const open = view.open === 'all' ? 'all' : openParam(view.open, shownKeys());
    history.replaceState(null, '', buildHash(['changes'], {
      tab: view.tab,
      a: view.a,
      b: view.b,
      q: view.q,
      kind: view.kind,
      page: view.page > 0 ? view.page + 1 : null,
      open,
    }));
  };

  const shownKeys = () => [...results.querySelectorAll('details.ch-card')].map((c) => c.dataset.key).filter(Boolean);
  const openKeys = () => new Set([...results.querySelectorAll('details.ch-card[open]')]
    .map((c) => c.dataset.key).filter(Boolean));

  // The address records which rows are open. Toggle does not bubble,
  // so listen during the capture phase.
  results.addEventListener('toggle', () => {
    view.open = openKeys();
    saveAddress();
  }, true);

  // --- Tabs ---

  const drawTabs = () => {
    clear(tabBar);
    for (const t of TABS) {
      const on = t === view.tab;
      tabBar.append(el('button', {
        type: 'button',
        class: `tab${on ? ' on' : ''}`,
        role: 'tab',
        'aria-selected': String(on),
        text: TAB[t].label,
        onclick: () => {
          if (t === view.tab) return;
          view.tab = t;
          view.page = 0;
          view.open = new Set();
          drawTab();
        },
      }));
    }
  };

  // --- The picker ---

  const refresh = el('button', {
    type: 'button',
    class: 'button',
    icon: 'refresh',
    text: 'Refresh',
    title: 'Reload current data and update the comparison.',
    onclick: () => load({ keepPlace: true }),
  });
  // When the data on disk was last written, beside Refresh.
  const updated = el('span', { class: 'ch-updated' });

  /// "5 Nov 2026, 07:40:02 — full run — 1094 topics (Mods and Facts)".
  const runLabel = (run) => {
    const size = view.tab === 'mods'
      ? (run.finalCount != null ? `${run.finalCount} mods` : '')
      : (run.indexCount != null ? `${run.indexCount} topics` : '');
    const both = ids[other(view.tab)].has(run.id) ? ' (Mods and Facts)' : '';
    return [when(run.savedAt) || run.id, jobWord(run.id), size].filter(Boolean).join(' — ') + both;
  };

  /// A run as a note names it: "5 Nov 2026, 07:40:02 (full run)".
  const runName = (id) => {
    if (id === WORKING) return 'Current local data';
    const run = findRun(id);
    return run ? `${when(run.savedAt) || id} (${jobWord(id)})` : id;
  };

  const settle = () => {
    const s = settleSides({
      runs: lists[view.tab],
      working: view.tab === 'facts' ? working : null,
      a: view.picked.a,
      b: view.picked.b,
      otherRuns: lists[other(view.tab)],
    });
    view.a = s.a;
    view.b = s.b;
    view.moved = s.moved;
    return s;
  };

  const pick = (next) => {
    view.picked = next;
    view.page = 0;
    view.open = new Set();
    drawPicker();
    load();
  };

  const drawPicker = () => {
    settle();
    const runs = lists[view.tab];
    const select = (which) => {
      const box = el('select', { class: 'select ch-select', id: `ch-side-${which}` });
      // The data on disk is only ever the newer side.
      if (which === 'b' && view.tab === 'facts' && working) {
        box.append(el('option', { value: WORKING, text: workingLabel(working) }));
      }
      for (const run of runs) box.append(el('option', { value: run.id, text: runLabel(run) }));
      box.value = view[which];
      box.addEventListener('change', () => {
        const next = { a: view.a, b: view.b };
        const leaving = next[which];
        next[which] = box.value;
        if (next.a === next.b) {
          // Picking the run already on the other side swaps the two, rather
          // than comparing a run with itself. The data on disk cannot become
          // the older side, so then the run before is used.
          const otherSide = which === 'a' ? 'b' : 'a';
          next[otherSide] = leaving === WORKING ? '' : leaving;
        }
        pick(next);
      });
      return box;
    };
    const live = view.b === WORKING;
    const swap = el('button', {
      type: 'button',
      class: 'button',
      icon: 'swap',
      text: 'Swap',
      disabled: live,
      title: live ? 'Current local data can only be the newer side.' : 'Swap older and newer snapshots.',
      onclick: () => pick({ a: view.b, b: view.a }),
    });
    refresh.hidden = !live;
    updated.hidden = !live;

    // The data on disk and an imported snapshot have no run to open.
    const runLink = (id) => (id === WORKING || isImported(id)
      ? null
      : el('a', { class: 'ch-run-link', href: `#/runs/${encodeURIComponent(id)}`, text: 'Open run' }));
    const side = (label, which) => el('div', { class: 'ch-side' }, [
      el('div', { class: 'ch-side-head' }, [
        el('label', { class: 'field-label', for: `ch-side-${which}`, text: label }),
        runLink(view[which]),
      ]),
      select(which),
    ]);

    pickerSlot.replaceChildren(el('div', { class: 'ch-sides' }, [
      side('Older', 'a'), swap, side('Newer', 'b'), refresh, updated,
    ]));
    drawMoved();
  };

  /// Says which picked run could not be shown on this tab, and what is shown.
  const drawMoved = () => {
    const tab = TAB[view.tab].label;
    clear(notes);
    for (const m of view.moved) {
      let text;
      if (m.why === 'working') {
        text = `Current local data is only on the Facts tab. Showing ${runName(m.to)}.`;
      } else if (m.why === 'otherTab' && m.nearest && m.nearest !== m.to) {
        const otherSide = m.side === 'a' ? 'newer' : 'older';
        text = `${runName(m.from)} has no ${tab} snapshot, and the nearest one is already the ${otherSide} side. `
          + `Showing ${runName(m.to)}.`;
      } else if (m.why === 'otherTab') {
        text = `${runName(m.from)} has no ${tab} snapshot. Showing the nearest: ${runName(m.to)}.`;
      } else if (m.why === 'oldest') {
        text = `Nothing is older than ${runName(m.from)}, so it is shown as the older side.`;
      } else {
        text = `${m.from} is no longer kept. Showing ${runName(m.to)}.`;
      }
      notes.append(el('p', { class: 'ch-note', text }));
    }
  };

  // --- Search ---

  let typing;
  search.addEventListener('input', () => {
    clearTimeout(typing);
    typing = setTimeout(() => {
      view.q = search.value.trim();
      view.page = 0;
      view.open = new Set();
      load();
    }, 250);
  });
  onLeave(() => clearTimeout(typing));

  // --- The comparison ---

  const drawCounts = (answer) => {
    const t = TAB[view.tab];
    clear(counts);
    for (const [kind, label, tone] of KINDS) {
      const value = answer[`${kind}Count`];
      const on = view.kind === kind;
      counts.append(el('button', {
        type: 'button',
        class: `ch-count ${value ? tone : 'zero'}${on ? ' on' : ''}`,
        'aria-pressed': String(on),
        title: `Show ${kindWord(kind)} ${t.thing}.`,
        onclick: () => {
          view.kind = on ? '' : kind;
          view.page = 0;
          view.open = new Set();
          load();
        },
      }, [
        el('span', { class: 'ch-count-value', text: String(value ?? '—') }),
        el('span', { class: 'ch-count-label', text: label }),
      ]));
    }
    counts.append(el('div', { class: 'ch-count zero still' }, [
      el('span', { class: 'ch-count-value', text: String(answer.sameCount ?? '—') }),
      el('span', { class: 'ch-count-label', text: 'Unchanged' }),
    ]));
  };

  const drawUpdated = (answer) => {
    const asOf = answer.b === WORKING ? when(answer.workingUpdatedAt) : '';
    updated.textContent = asOf ? `Last updated ${asOf}` : '';
  };

  // Answers to older requests are dropped once a newer one starts.
  let ticket = 0;
  /// `keepPlace` (Refresh) keeps the rows that are open and where the reader
  /// had scrolled to, and leaves the old rows up until the new ones arrive.
  const load = async ({ keepPlace = false } = {}) => {
    const mine = ++ticket;
    const t = TAB[view.tab];
    const wasOpen = keepPlace ? openKeys() : view.open;
    const wasAt = keepPlace ? content.scrollTop : null;
    saveAddress();
    if (keepPlace) {
      refresh.disabled = true;
      refresh.replaceChildren(icon('refresh'), 'Refreshing…');
    } else {
      clear(counts);
      clear(pagerSlot);
      results.replaceChildren(el('p', { class: 'empty ch-message', text: 'Loading…' }));
      syncFoldAll();
    }

    let answer;
    try {
      answer = await api(t.compare, {
        a: view.a,
        b: view.b,
        q: view.q,
        kind: view.kind,
        page: view.page,
        pageSize: view.pageSize,
      });
    } catch (err) {
      if (mine !== ticket) return;
      refresh.disabled = false;
      refresh.replaceChildren(icon('refresh'), 'Refresh');
      clear(counts);
      clear(pagerSlot);
      results.replaceChildren(el('p', { class: 'error-text ch-message', text: err.message }));
      syncFoldAll();
      return;
    }
    if (mine !== ticket) return;
    refresh.disabled = false;
    refresh.replaceChildren(icon('refresh'), 'Refresh');

    // Show the server's error when a snapshot cannot be read.
    if (answer.missing) {
      clear(counts);
      clear(pagerSlot);
      results.replaceChildren(el('div', { class: 'pp-missing ch-message' }, [
        el('p', { text: answer.hint || 'One of those snapshots is no longer kept. Pick another.' }),
      ]));
      syncFoldAll();
      return;
    }

    const items = answer.items || [];
    // A page past the end is answered with the last page. Keep the page the
    // server sent, so the address names it too.
    if (Number.isInteger(answer.page)) view.page = answer.page;

    drawUpdated(answer);
    drawCounts(answer);
    const rows = [];
    if (view.kind) {
      rows.push(el('p', { class: 'ch-filter-note' }, [
        `Showing only ${kindWord(view.kind)} ${t.thing}. `,
        el('button', {
          type: 'button',
          class: 'link-button',
          icon: 'clear',
          text: 'Clear filter',
          onclick: () => {
            view.kind = '';
            view.page = 0;
            view.open = new Set();
            load();
          },
        }),
      ]));
    }
    for (const row of items) {
      const card = view.tab === 'mods' ? modCard(row) : topicCard(row);
      if (wasOpen === 'all' || wasOpen.has(row.key)) card.open = true;
      rows.push(card);
    }
    if (!items.length) {
      rows.push(el('p', {
        class: 'empty ch-message',
        text: view.q || view.kind ? 'Nothing matches this search or filter.' : 'No differences found.',
      }));
    }
    results.replaceChildren(...rows);
    view.open = openKeys();
    syncFoldAll();
    saveAddress();
    pagerSlot.replaceChildren(pager(answer.page, answer.pageSize, answer.total, (p) => {
      view.page = p;
      view.open = new Set();
      load();
      main.scrollIntoView({ block: 'start' });
    }, (size) => {
      view.pageSize = size;
      view.page = 0;
      view.open = new Set();
      load();
    }));

    if (wasAt != null) content.scrollTop = wasAt;
  };

  /// Draws everything that depends on the tab, then loads the comparison.
  const drawTab = () => {
    const t = TAB[view.tab];
    drawTabs();
    search.placeholder = t.search;
    search.setAttribute('aria-label', t.search.replace('…', ''));
    const runs = lists[view.tab];
    if (settle().nothing) {
      clear(notes);
      pickerSlot.replaceChildren(nothingYet(view.tab, runs.length));
      searchRow.hidden = true;
      clear(counts);
      clear(pagerSlot);
      results.replaceChildren();
      saveAddress();
      return;
    }
    searchRow.hidden = false;
    drawPicker();
    load();
  };

  drawTab();
}

// --- Rows ---

/// The closed row: what happened, the name, who made it, and which fields
/// changed, at the right end of the same line.
function cardSummary(row, fallbackName) {
  const changes = row.changes || [];
  const [, , tone] = KINDS.find(([k]) => k === row.kind) || [];
  return el('summary', {}, [
    foldArrow(),
    badge(kindWord(row.kind), tone || ''),
    el('span', { class: 'ph-name ch-name', text: row.name || fallbackName }),
    el('span', { class: 'ch-author', text: row.authors || '' }),
    // Added and removed rows name no fields.
    changes.length ? el('span', { class: 'ch-fields', text: changedFieldsLine(changes), title: changedFieldsTitle(changes) }) : null,
  ]);
}

/// A few facts about an added or removed row, so it can be told apart
/// without opening its page. Empty values are left out.
function factList(pairs) {
  const shown = pairs.filter(([, value]) => value != null && value !== '' && !(Array.isArray(value) && !value.length));
  if (!shown.length) return null;
  return el('dl', { class: 'ch-facts' }, shown.flatMap(([name, value]) => [
    el('dt', { text: name }),
    el('dd', {}, [value]),
  ]));
}

/// A link that opens outside the viewer, or the plain text when it is not
/// a web address.
function outsideLink(url) {
  const text = String(url);
  return /^https?:\/\//i.test(text)
    ? el('a', { href: text, target: '_blank', rel: 'noopener', text })
    : text;
}

/// The plain names for a catalog mod's kinds of link.
const LINK_NAMES = {
  Forum: 'Forum',
  Discord: 'Discord',
  NexusMods: 'Nexus Mods',
  DirectDownload: 'Download',
  DownloadPage: 'Download page',
};

const cut = (text, max = 200) => {
  const s = String(text || '').trim();
  return s.length > max ? `${s.slice(0, max - 1)}…` : s;
};

/// One mod from the Mods tab. Opening it finds the mod's page through the
/// post it came from, since a saved catalog does not keep permanent ids.
export function modCard(row) {
  const mod = row.mod || {};
  const urls = mod.urls || {};
  const changes = row.changes || [];
  const card = el('details', { class: 'ph-card ch-card', 'data-key': row.key || '' });
  card.append(cardSummary(row, '(no name)'));

  // A forum link that is not one of the mod's own sources is not its post.
  const post = postForMod(mod);

  const modSlot = el('span', { class: 'ch-mod-links' });
  const links = el('div', { class: 'ph-actions' }, [modSlot]);
  if (post && post.own) {
    links.append(el('a', {
      href: `#/posts/${post.kind}/${encodeURIComponent(post.id)}`,
      text: 'Open source post',
    }));
  }
  const inner = el('div', { class: 'ph-card-body' }, [links]);
  if (row.note) inner.append(el('p', { class: 'pp-source-line', text: row.note }));
  if (changes.length) inner.append(diffTable(changes));
  // An added or removed mod has no field changes; a few facts say which mod it is.
  if (!changes.length) {
    const facts = factList([
      ['Summary', cut(mod.summary)],
      ['Mod version', mod.modVersion],
      ['Game version', mod.gameVersionReq],
      ['Categories', (mod.categories || []).join(', ')],
      ...Object.entries(urls).map(([kind, url]) => [LINK_NAMES[kind] || kind, outsideLink(url)]),
    ]);
    if (facts) inner.append(facts);
  }
  card.append(inner);

  let asked = false;
  card.addEventListener('toggle', () => {
    if (!card.open || asked) return;
    asked = true;
    fillModLinks(modSlot, post, row.name || mod.name || '');
  });
  return card;
}

/// The mod page for a row, from what its post became in the last build.
async function fillModLinks(slot, post, name) {
  const findInMods = () => el('a', { href: buildHash(['mods'], { q: name }), text: 'Find in Mods' });
  if (!post) {
    slot.replaceChildren(findInMods());
    return;
  }
  slot.replaceChildren(el('span', { class: 'dim', text: 'Finding the mod page…' }));
  let outcome;
  try {
    outcome = await api('posts/outcome', { kind: post.kind, id: post.id });
  } catch {
    slot.replaceChildren(findInMods());
    return;
  }
  const mods = (outcome && outcome.mods) || [];
  if (!mods.length && post.own) {
    // The server's own words, such as "Not in last build."
    slot.replaceChildren(el('span', { class: 'dim', text: (outcome && outcome.line) || '' }));
    return;
  }
  const shown = modsToLink(mods, name, post.own);
  if (!shown.length) {
    // The post is only linked from this mod, and none of its mods has this name.
    slot.replaceChildren(findInMods());
    return;
  }
  slot.replaceChildren(...shown.map((m) => el('a', {
    href: `#/mods/${encodeURIComponent(m.id)}`,
    text: shown.length === 1 ? 'Open mod page' : `Mod page: ${m.name || m.id}`,
  })));
}

/// One forum topic from the Facts tab.
export function topicCard(row) {
  const topic = row.topic || {};
  const changes = row.changes || [];
  const card = el('details', { class: 'ph-card ch-card', 'data-key': row.key || '' });
  card.append(cardSummary(row, '(no title)'));
  const inner = el('div', { class: 'ph-card-body' });
  if (topic.topicId != null) {
    const id = encodeURIComponent(topic.topicId);
    inner.append(el('div', { class: 'ph-actions' }, [
      el('a', { href: `#/posts/topic/${id}`, text: 'Open source post' }),
      el('a', { href: `#/posts/topic/${id}/history`, text: 'History' }),
    ]));
  }
  if (row.note) inner.append(el('p', { class: 'pp-source-line', text: row.note }));
  if (changes.length) inner.append(diffTable(changes));
  // An added or removed topic: what the LLM found on it, and where it sits.
  if (!changes.length) {
    const mods = ((topic.llm && topic.llm.mods) || []).map((m) => {
      const version = m.extras && m.extras.version;
      return version ? `${m.name} ${version}` : m.name;
    }).filter(Boolean);
    const facts = factList([
      ['Mods found', mods.join(', ')],
      ['Category', topic.category],
      ['In mod index', topic.inModIndex == null ? null : (topic.inModIndex ? 'Yes' : 'No')],
    ]);
    if (facts) inner.append(facts);
  }
  card.append(inner);
  return card;
}

// --- Words ---

function kindWord(kind) {
  return { added: 'added', gone: 'removed', changed: 'changed' }[kind] || kind;
}

/// How the data on disk reads in the picker. Its time is beside Refresh,
/// where it is kept up to date.
function workingLabel(working) {
  const size = working.indexCount != null ? `${working.indexCount} topics` : '';
  return ['Current local data', size].filter(Boolean).join(' — ');
}

/// What a tab says when there are not two things to compare.
function nothingYet(tab, saved) {
  if (tab === 'mods') {
    return el('div', { class: 'note ch-nothing' }, [
      el('h2', { class: 'panel-heading', text: 'Two saved merges needed' }),
      el('p', {
        text: saved === 1
          ? 'Only one merge is saved. Run another to compare changes.'
          : 'No merges have been saved yet. Run one from the Control page.',
      }),
    ]);
  }
  return el('div', { class: 'note ch-nothing' }, [
    el('h2', { class: 'panel-heading', text: 'Nothing to compare yet' }),
    el('p', {
      text: saved === 1
        ? 'Only one snapshot is saved, and there is no local data to compare. '
          + 'Run the scraper to create another snapshot.'
        : 'No snapshots have been saved yet. Run the scraper to save one.',
    }),
  ]);
}

function legend() {
  const item = (label, text) => el('div', {}, [el('dt', { text: label }), el('dd', { text })]);
  return el('dl', { class: 'pl-legend' }, [
    item('Mods', 'The catalog each run built: which mods there are, with their names, authors, versions, links and categories.'),
    item('Facts', 'The mod details each run published, one row per forum topic: the post, its links, downloads and the LLM’s facts. Discord threads are not compared here.'),
    item('Current local data', 'What is saved on disk now but not published yet. It can only be the newer side, on the Facts tab. It changes while a run is going; press Refresh to see the latest.'),
    item('Rows', 'A closed row names the fields that changed. Open it to see only what changed.'),
  ]);
}
