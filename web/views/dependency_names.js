// Dependency matching: every way posts spell a mod they require, use or
// conflict with, and which of our mods each spelling means. The page only
// reads. Matching a spelling to one or more mods, marking it as not in the
// catalog, or resetting its saved answer adds a pending change; nothing is
// written until the pending changes are saved.
//
// The list is the server's answer as it is. A row with a pending change is
// marked, but the page never guesses what the save will change.

import { el, clear, api, shortTime, pager, pageSizePreference, infoButton } from '../lib.js';
import { pageLayout, sidePanel, statusMark } from '../frame.js';
import { icon } from '../icons.js';
import { subscribe, status } from '../status.js';
import { hashQuery, buildHash } from '../routes.js';
import { addPending, onPendingChange, pendingItems, removePending } from '../pending.js';
import { pendingPanel } from '../pending_view.js';
import { looseKey, modChooser, suggestMods } from '../mod_picker.js';
import { matchLabel, matchCorrection } from '../mod_words.js';

const PAGE_ID = 'dependency-matching';

/// How a spelling was matched, as the report names it.
const SOURCE_LABELS = {
  unmatched: 'Not matched',
  llm: 'LLM',
  hand: 'Hand entry',
  rule: 'Rules',
};

/// The filters above the list. `unused` is the saved answers no mod used in
/// the last build.
const FILTERS = [
  ['all', 'All', null],
  ['unmatched', SOURCE_LABELS.unmatched, null],
  ['llm', SOURCE_LABELS.llm, null],
  ['hand', SOURCE_LABELS.hand, null],
  ['rule', SOURCE_LABELS.rule, null],
  ['unused', 'Not used', 'Saved answers that no mod used in the last build.'],
];
const FILTER_KEYS = new Set(FILTERS.map(([key]) => key));

/// Dependency list headings used on the mod page.
const USE_LABELS = [
  ['needs', 'Requires'],
  ['optional', 'Optional'],
  ['conflict', 'Conflicts'],
];

/// The sentence the other pages use when jobs are off.
function managerOffText(s) {
  if (s && s.offline) return 'Unable to reach the server. Editing is disabled.';
  return `${(s && s.reason) || 'Job management is disabled on this server.'} Start the viewer with a readable `
    + 'config.properties file (or specify it with --config) and omit --no-manager to enable jobs.';
}

export function render({ content, onLeave }) {
  const query = hashQuery(location.hash);
  // The list's state, kept in the address. Pages count from 1 there.
  const view = {
    match: FILTER_KEYS.has(query.get('match')) ? query.get('match') : 'all',
    search: query.get('q') || '',
    page: Math.max(0, (parseInt(query.get('page'), 10) || 1) - 1),
    pageSize: pageSizePreference(),
  };
  // `rows` is null until the first server response.
  // `open` contains the keys of expanded rows.
  // `editing` is the row being matched: its key and its mod chooser.
  // `suggestions` holds each row's suggested mods by key, worked out once per
  // load, since the mod list only changes when the page loads again.
  const state = {
    rows: null, report: null, error: null, loadError: null, mods: [], modNames: new Map(), on: null, open: new Set(),
    editing: null, suggestions: new Map(),
  };

  const main = el('div', { class: 'dn-page' }, [el('p', { class: 'empty', text: 'Loading…' })]);
  const sideSlot = el('div');
  content.append(pageLayout(main, [pendingPanel(), sideSlot]));

  // Built once, so typing in it is never interrupted by a redraw.
  const search = el('input', {
    type: 'search',
    class: 'input dn-search',
    placeholder: 'Search dependencies',
    'aria-label': 'Search dependencies',
    autocomplete: 'off',
    spellcheck: 'false',
    value: view.search,
  });
  search.addEventListener('input', () => {
    view.search = search.value;
    view.page = 0;
    drawList();
  });
  const filterBar = el('div', { class: 'tabs dn-filters', role: 'group', 'aria-label': 'Match source' });
  const listSlot = el('div', { class: 'dn-list' });

  const load = async () => {
    let body;
    try {
      body = await api('requirement-names');
    } catch (err) {
      state.loadError = err.message;
      state.rows = [];
      return;
    }
    state.loadError = null;
    state.error = body.error || null;
    state.report = body.report || null;
    state.mods = (state.report && state.report.mods) || [];
    state.modNames = new Map(state.mods.map((m) => [m.id, m.name]));
    state.suggestions = new Map();
    state.rows = rowsOf(state.report, body.saved || []);
  };

  const saveAddress = () => {
    // Leave the address alone once the reader has moved to another page.
    if (!location.hash.startsWith(`#/${PAGE_ID}`)) return;
    history.replaceState(null, '', buildHash([PAGE_ID], {
      match: view.match === 'all' ? null : view.match,
      q: view.search.trim() || null,
      page: view.page > 0 ? view.page + 1 : null,
    }));
  };

  const drawFilters = () => {
    const counts = countRows(state.rows);
    clear(filterBar);
    for (const [key, label, title] of FILTERS) {
      const on = view.match === key;
      filterBar.append(el('button', {
        type: 'button',
        class: `tab${on ? ' on' : ''}`,
        'aria-pressed': String(on),
        title,
        onclick: () => {
          view.match = key;
          view.page = 0;
          drawFilters();
          drawList();
        },
      }, [label, el('span', { class: 'dn-filter-count', text: String(counts[key]) })]));
    }
  };

  const drawList = () => {
    if (!state.rows) return;
    const shown = filterRows(state.rows, view);
    const pageSize = view.pageSize;
    // With every row on one page, a page number left in the address is dropped.
    if (!pageSize) view.page = 0;
    if (pageSize && view.page * pageSize >= shown.length) view.page = Math.max(0, Math.ceil(shown.length / pageSize) - 1);
    const slice = pageSize ? shown.slice(view.page * pageSize, (view.page + 1) * pageSize) : shown;
    saveAddress();

    clear(listSlot);
    if (!shown.length) {
      listSlot.append(el('p', { class: 'empty dn-empty', text: 'No dependencies match these filters.' }));
      return;
    }
    listSlot.append(
      rowTable(slice, state, drawList),
      pager(view.page, pageSize, shown.length, (p) => {
        view.page = p;
        drawList();
        // Start the new page at its first row, not at the pager.
        filterBar.scrollIntoView({ block: 'nearest' });
      }, (size) => {
        view.pageSize = size;
        view.page = 0;
        drawList();
      }),
    );
  };

  const drawMain = () => {
    if (!state.rows) return;
    clear(main).append(...headParts(state));
    if (state.loadError) return;
    drawFilters();
    main.append(
      el('div', { class: 'dn-toolbar' }, [search]),
      filterBar,
      listSlot,
    );
    drawList();
  };

  const drawSide = () => {
    const parts = [];
    if (state.on === false) {
      parts.push(sidePanel({
        name: 'Viewing only',
        body: el('p', { class: 'dn-side-note', text: managerOffText(status()) }),
      }));
    }
    sideSlot.replaceChildren(...parts);
  };

  // Every action redraws through here: the pending list changed.
  onLeave(onPendingChange(drawList));

  let lastRunId;
  onLeave(subscribe(async (s) => {
    if (s.on !== state.on) {
      state.on = s.on;
      drawSide();
      drawList();
    }
    // A job that just ended may have changed the answers: read them again.
    const runId = s.current ? s.current.record.id : null;
    if (lastRunId !== undefined && runId !== lastRunId && lastRunId !== null) {
      await load();
      drawMain();
    }
    lastRunId = runId;
  }));

  drawSide();
  load().then(() => {
    state.on = status() ? status().on : state.on;
    drawSide();
    drawMain();
  });
}

// --- The rows ---

/// The report's spellings, each with its saved answer, then the saved answers
/// no mod used in the last build. Those are labelled by who saved the answer,
/// hand or LLM, even when the answer is "not in catalog": "Not matched" means
/// a name the last build showed as written, and no mod used these. Needs
/// attention counts only the report's unmatched spellings, the same set.
function rowsOf(report, saved) {
  const rows = ((report && report.names) || []).map((n) => ({ ...n, used: true }));
  const keys = new Set(rows.map((r) => r.key));
  const savedByKey = new Map(saved.map((s) => [s.key, s]));
  for (const row of rows) row.saved = savedByKey.get(row.key) || null;
  for (const entry of saved) {
    if (keys.has(entry.key)) continue;
    rows.push({
      key: entry.key,
      written: entry.written,
      count: 0,
      id: entry.id,
      ids: entry.ids,
      anyOne: entry.anyOne,
      by: entry.by === 'hand' ? 'hand' : 'llm',
      saved: entry,
      used: false,
    });
  }
  return rows;
}

function countRows(rows) {
  const counts = Object.fromEntries(FILTERS.map(([key]) => [key, 0]));
  for (const row of rows || []) {
    counts.all++;
    if (row.by in counts) counts[row.by]++;
    if (!row.used) counts.unused++;
  }
  return counts;
}

function filterRows(rows, view) {
  const q = view.search.trim().toLowerCase();
  return rows.filter((row) => {
    if (view.match === 'unused' ? row.used : (view.match !== 'all' && row.by !== view.match)) return false;
    if (!q) return true;
    return [row.written, row.name, row.id, ...(row.ids || []), ...(row.names || [])]
      .some((v) => v && String(v).toLowerCase().includes(q));
  });
}

/// The heading, counts, notes and any error above the list.
function headParts(state) {
  const { report } = state;
  const parts = [
    el('div', { class: 'dn-head' }, [
      el('h2', { class: 'panel-heading', text: 'Dependency matching' }),
      infoButton('About dependency matching', 'Dependency matching', aboutDependencyMatching),
      report && report.builtAt
        ? el('span', { class: 'dn-built', title: report.builtAt, text: `Last build ${shortTime(report.builtAt)}` })
        : null,
    ]),
  ];
  if (state.loadError) {
    parts.push(el('p', { class: 'dn-banner bad', text: state.loadError }));
    return parts;
  }
  if (state.error) parts.push(el('p', { class: 'dn-banner bad', text: state.error }));
  if (!report) {
    parts.push(el('div', { class: 'dn-banner' }, [
      el('strong', { text: 'No dependency report yet.' }),
      el('p', { text: 'Run “Rebuild from saved” on the Control page.' }),
    ]));
  }
  return parts;
}

/// The info dialog: what the page is for, and the legend for the match sources.
function aboutDependencyMatching() {
  const item = (label, text) => el('div', {}, [el('dt', { text: label }), el('dd', { text })]);
  return [
    el('p', { text: 'Match names in Requires, Optional, and Conflicts to catalog mods.' }),
    el('dl', {}, [
      item(SOURCE_LABELS.hand, 'Your saved answer is used before rules and LLM answers.'),
      item(SOURCE_LABELS.rule, 'Matches a mod name or a nickname used by only one mod.'),
      item(SOURCE_LABELS.llm, 'A saved LLM answer.'),
      item(SOURCE_LABELS.unmatched, 'Shown as written in the post.'),
    ]),
  ];
}

/// The mods a row is matched to, as { id, name }: one (`id`, `name`) or
/// several (`ids`, `names`).
function matchedMods(row, modNames) {
  const ids = row.ids && row.ids.length ? row.ids : (row.id ? [row.id] : []);
  return ids.map((id, i) => ({
    id,
    name: (row.names && row.names[i]) || (ids.length === 1 ? row.name : null) || modNames.get(id) || null,
  }));
}

/// Several mod names joined by "and", or by "or" when any one is enough.
function joinNames(names, anyOne) {
  return names.join(anyOne ? ' or ' : ' and ');
}

// --- Pending changes for a row ---

/// The pending changes for this spelling, oldest first. A change carries the
/// key the server saves its answer under, the same key each row has; a change
/// without one is matched on letters and digits.
function pendingFor(row) {
  const loose = looseKey(row.written);
  return pendingItems().filter((i) => i.correction.kind === 'matchRequirement'
    && (i.key && row.key ? i.key === row.key : looseKey(i.correction.written) === loose));
}

/// The ids a pending match names: `modIds`, or `modId` alone.
function pendingIds(c) {
  return c.modIds && c.modIds.length ? c.modIds : (c.modId ? [c.modId] : []);
}

/// The mark on a row with a pending change, from the newest one.
function pendingTag(item, modNames) {
  const c = item.correction;
  const ids = pendingIds(c);
  let text;
  if (c.forget) text = 'Unsaved: reset';
  else if (!ids.length) text = 'Unsaved: not in catalog';
  else text = `Unsaved: ${joinNames(ids.map((id) => modNames.get(id) || id), c.anyOne)}`;
  return el('span', { class: 'tag dn-tag-pending', title: item.label, text });
}

function noneLabel(written) {
  return `Mark "${written}" as not in catalog`;
}

function forgetLabel(written) {
  return `Reset the saved answer for "${written}"`;
}

/// Adds a pending match of the row's name to one or more mods.
function addMatch(row, mods, anyOne = false) {
  addPending({
    kind: 'matchRequirement',
    label: matchLabel(row.written, mods.map((mod) => mod.name), anyOne),
    key: row.key,
    correction: matchCorrection(row.written, mods.map((mod) => mod.id), anyOne),
  });
}

function addNone(row) {
  addPending({
    kind: 'matchRequirement',
    label: noneLabel(row.written),
    key: row.key,
    correction: { kind: 'matchRequirement', written: row.written, modId: null },
  });
}

function addForget(row) {
  addPending({
    kind: 'matchRequirement',
    label: forgetLabel(row.written),
    key: row.key,
    correction: { kind: 'matchRequirement', written: row.written, forget: true },
  });
}

// --- The table ---

function rowTable(rows, state, redraw) {
  const withPending = rows.map((row) => ({ row, pending: pendingFor(row) }));
  // With jobs off there is nothing to change, but a pending change can still be undone.
  const actions = state.on || withPending.some((r) => r.pending.length);
  return el('div', { class: 'table-wrap' }, [
    el('table', { class: 'table dn-table' }, [
      el('thead', {}, [el('tr', {}, [
        el('th', { text: 'Name in post' }),
        el('th', { class: 'num', text: 'Used by' }),
        el('th', { text: 'Matched mod' }),
        el('th', { text: 'Match source' }),
        actions ? el('th', { text: 'Actions' }) : null,
      ])]),
      el('tbody', {}, withPending.flatMap(({ row, pending }) => {
        const open = state.open.has(row.key) && row.uses && row.uses.length;
        return [
          rowView(row, pending, state, actions, redraw),
          open ? el('tr', { class: 'dn-uses-row' }, [
            el('td', { colspan: actions ? 5 : 4 }, [usesList(row.uses, state.modNames)]),
          ]) : null,
        ];
      })),
    ]),
  ]);
}

function rowView(row, pending, state, actions, redraw) {
  const { modNames } = state;
  let count;
  if (!row.count) {
    count = el('span', { class: 'dim', text: '0', title: 'No mod used this spelling in the last build.' });
  } else if (row.uses && row.uses.length) {
    const open = state.open.has(row.key);
    count = el('button', {
      type: 'button',
      class: 'dn-count',
      'aria-expanded': String(open),
      title: open ? 'Hide mods' : 'Show mods',
      onclick: () => {
        if (open) state.open.delete(row.key);
        else state.open.add(row.key);
        redraw();
      },
    }, [String(row.count), icon(open ? 'chevron-down' : 'chevron-right')]);
  } else {
    count = el('span', { text: String(row.count) });
  }

  const editing = state.editing && state.editing.key === row.key ? state.editing : null;
  return el('tr', { class: pending.length ? 'is-pending' : null }, [
    el('td', { class: 'dn-written', 'data-label': 'Name in post' }, [el('strong', { text: row.written })]),
    el('td', { class: 'num mono', 'data-label': 'Used by' }, [count]),
    el('td', { class: 'dn-match', 'data-label': 'Matched mod' }, [
      matchView(row, modNames),
      pending.length ? pendingTag(pending[pending.length - 1], modNames) : null,
      // Matching happens here, in the row, not in a dialog.
      editing ? editing.chooser.element : (pending.length ? null : suggestionView(row, state, redraw)),
    ]),
    el('td', { class: 'dn-source', 'data-label': 'Match source' }, [sourceView(row, modNames)]),
    actions ? el('td', { class: 'dn-actions' }, [editing ? null : actionsView(row, pending, state, redraw)]) : null,
  ]);
}

/// The mods a spelling matched, each with its id, or why there are none.
/// Several are joined by "and", or by "or" when any one is enough.
function matchView(row, modNames) {
  const mods = matchedMods(row, modNames);
  if (mods.length) {
    return el('div', { class: 'dn-mods' }, mods.flatMap((mod, i) => [
      i ? el('span', { class: 'dn-join', text: row.anyOne ? 'or' : 'and' }) : null,
      el('span', { class: 'dn-mod' }, [
        el('a', { href: `#/mods/${encodeURIComponent(mod.id)}`, text: mod.name || mod.id }),
        el('code', { class: 'dn-id', text: mod.name ? mod.id : `${mod.id} · Not in catalog` }),
      ]),
    ]));
  }
  if (row.saved && !(row.saved.id || (row.saved.ids && row.saved.ids.length))) {
    return el('span', { class: 'dim', text: 'Not in catalog' });
  }
  return el('span', { class: 'dim', text: '—' });
}

/// How the spelling was matched, with the saved answer on hover.
function sourceView(row, modNames) {
  const saved = row.saved;
  let title = null;
  if (saved) {
    const ids = saved.ids && saved.ids.length ? saved.ids : (saved.id ? [saved.id] : []);
    const what = ids.length
      ? joinNames(ids.map((id) => `"${modNames.get(id) || id}"`), saved.anyOne)
      : 'Not in catalog';
    const who = saved.by === 'hand' ? 'Hand entry' : 'LLM answer';
    title = `${who}${saved.on ? ` saved ${saved.on}` : ''}: ${what}.`;
  }
  return el('span', { class: 'dn-source-cell', title }, [
    statusMark(row.by === 'unmatched' ? 'warning' : 'idle'),
    SOURCE_LABELS[row.by] || row.by,
  ]);
}

function actionsView(row, pending, state, redraw) {
  if (pending.length) {
    return el('button', {
      type: 'button',
      class: 'button quiet dn-small',
      icon: 'undo',
      text: 'Undo',
      title: 'Undo this unsaved change.',
      onclick: () => { for (const item of pending) removePending(item.id); },
    });
  }
  if (!state.on) return null;
  const alreadyNone = row.by === 'hand' && !matchedMods(row, state.modNames).length;
  return el('div', { class: 'dn-buttons' }, [
    el('button', {
      type: 'button',
      class: 'button dn-small',
      icon: 'match',
      text: 'Match…',
      title: 'Select a matching mod.',
      onclick: () => startMatching(row, state, redraw),
    }),
    alreadyNone ? null : el('button', {
      type: 'button',
      class: 'button dn-small',
      icon: 'not-in-catalog',
      text: 'Not in catalog',
      title: 'Mark this name as not referring to a catalog mod.',
      onclick: () => addNone(row),
    }),
    row.saved ? el('button', {
      type: 'button',
      class: 'button quiet dn-small',
      icon: 'reset',
      text: 'Reset',
      title: 'Delete the saved answer. Rules apply after saving. A future dependency matching job may ask the LLM again.',
      onclick: () => addForget(row),
    }) : null,
  ]);
}

/// Lists the mods whose posts include this dependency name. Groups them
/// under Requires, Optional, or Conflicts. Each mod links to its page.
function usesList(uses, modNames) {
  const groups = USE_LABELS.map(([as, label]) => [label, uses.filter((u) => u.as === as)])
    .filter(([, list]) => list.length);
  return el('dl', { class: 'dn-uses' }, groups.flatMap(([label, list]) => [
    el('dt', { text: label }),
    el('dd', {}, list.flatMap((use, i) => [
      i ? ' · ' : null,
      el('a', {
        href: `#/mods/${encodeURIComponent(use.id)}`,
        text: modNames.get(use.id) || use.id,
      }),
    ])),
  ]));
}

/// Shows the best suggested match for an unmatched dependency name. The
/// Match button adds a pending change. Hidden when jobs are disabled.
function suggestionView(row, state, redraw) {
  if (row.by !== 'unmatched' || !state.on) return null;
  let found = state.suggestions.get(row.key);
  if (!found) {
    found = suggestMods(state.mods, row.written);
    state.suggestions.set(row.key, found);
  }
  if (!found.length) return null;
  const mod = found[0];
  return el('div', { class: 'dn-suggest' }, [
    el('span', {}, ['Did you mean ', el('a', { href: `#/mods/${encodeURIComponent(mod.id)}`, text: mod.name }), '?']),
    el('span', { class: 'dn-buttons' }, [
      el('button', {
        type: 'button',
        class: 'button dn-small',
        icon: 'match',
        text: 'Match',
        title: `Match this name to ${mod.name}.`,
        onclick: () => addMatch(row, [mod]),
      }),
      found.length > 1 ? el('button', {
        type: 'button',
        class: 'button quiet dn-small',
        icon: 'more',
        text: `${found.length - 1} more`,
        title: 'Choose another mod.',
        onclick: () => startMatching(row, state, redraw),
      }) : null,
    ]),
  ]);
}

// --- Matching in the row ---

/// Opens the mod chooser in the row's Matched mod cell. One row at a time:
/// opening another closes this one. A hand entry's mods start out chosen.
/// Match adds the pending change; Cancel or Escape closes it.
function startMatching(row, state, redraw) {
  const close = () => {
    state.editing = null;
    redraw();
  };
  const chooser = modChooser({
    written: row.written,
    mods: state.mods,
    selected: row.by === 'hand' ? matchedMods(row, state.modNames).map((mod) => mod.id) : [],
    anyOne: !!row.anyOne,
    onPick: (picked, { anyOne }) => {
      state.editing = null;
      // Adding the change redraws the list.
      addMatch(row, picked, anyOne);
    },
    onCancel: close,
  });
  state.editing = { key: row.key, chooser };
  redraw();
  chooser.focus();
}
