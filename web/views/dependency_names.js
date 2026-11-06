// Dependency names: every way posts spell a required mod, and which of our
// mods each spelling means. The page only reads. Matching a spelling, marking
// it as none of our mods, or forgetting its saved answer adds a pending change;
// nothing is written until the pending changes are saved.
//
// The list is the server's answer as it is. A row with a pending change is
// marked, but the page never guesses what the save will change.

import { el, clear, api, shortTime, pager, pageSizePreference } from '../lib.js';
import { pageLayout, sidePanel, statusMark } from '../frame.js';
import { subscribe, status } from '../status.js';
import { hashQuery, buildHash } from '../routes.js';
import { addPending, onPendingChange, pendingItems, removePending } from '../pending.js';
import { pendingPanel } from '../pending_view.js';
import { looseKey, openModPicker } from '../mod_picker.js';

const PAGE_ID = 'dependency-names';

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

/// The sentence the other pages use when jobs are off.
function managerOffText(s) {
  if (s && s.offline) return 'The server could not be reached. Dependency names cannot be changed.';
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
  const state = { rows: null, report: null, error: null, loadError: null, mods: [], modNames: new Map(), on: null };

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
      rowTable(slice, state),
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
    parts.push(sidePanel({ name: 'How names are matched', body: howMatched() }));
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
/// hand or LLM, even when the answer is "none of our mods": "Not matched" means
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
    return [row.written, row.name, row.id].some((v) => v && String(v).toLowerCase().includes(q));
  });
}

/// The heading, counts, notes and any error above the list.
function headParts(state) {
  const { report } = state;
  const parts = [
    el('div', { class: 'dn-head' }, [
      el('h2', { class: 'panel-heading', text: 'Dependency names' }),
      report && report.builtAt
        ? el('span', { class: 'dn-built', title: report.builtAt, text: `Last build ${shortTime(report.builtAt)}` })
        : null,
    ]),
    el('p', {
      class: 'dn-intro',
      text: 'Match dependency names from posts to catalog mods. '
        + 'Hand entries take priority over rules and LLM matches.',
    }),
  ];
  if (state.loadError) {
    parts.push(el('p', { class: 'dn-banner bad', text: state.loadError }));
    return parts;
  }
  if (state.error) parts.push(el('p', { class: 'dn-banner bad', text: state.error }));
  if (!report) {
    parts.push(el('div', { class: 'dn-banner' }, [
      el('strong', { text: 'No dependency report yet.' }),
      el('p', { text: 'Run "Rebuild from saved" on the Control page to create it. Saved answers are listed below.' }),
    ]));
  }
  return parts;
}

/// The legend for the match sources.
function howMatched() {
  const item = (label, text) => el('div', { class: 'dn-how-item' }, [
    el('dt', { text: label }),
    el('dd', { text }),
  ]);
  return el('dl', { class: 'dn-how' }, [
    item(SOURCE_LABELS.hand, 'Chosen by hand. It is used before the rules and the LLM.'),
    item(SOURCE_LABELS.rule, 'The name matches a mod\'s name, or a nickname only one mod uses.'),
    item(SOURCE_LABELS.llm, 'The LLM picked the mod in an earlier build.'),
    item(SOURCE_LABELS.unmatched, 'The site shows the name as written in the post.'),
  ]);
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

/// The mark on a row with a pending change, from the newest one.
function pendingTag(item, modNames) {
  const c = item.correction;
  let text;
  if (c.forget) text = 'Forget pending';
  else if (!c.modId) text = 'Match pending: none of our mods';
  else text = `Match pending: ${modNames.get(c.modId) || c.modId}`;
  return el('span', { class: 'tag dn-tag-pending', title: item.label, text });
}

function matchLabel(written, modName) {
  return `"${written}" means "${modName}"`;
}

function noneLabel(written) {
  return `"${written}" means none of our mods`;
}

function forgetLabel(written) {
  return `Forget the saved answer for "${written}"`;
}

function addMatch(row, mod) {
  addPending({
    kind: 'matchRequirement',
    label: matchLabel(row.written, mod.name),
    key: row.key,
    correction: { kind: 'matchRequirement', written: row.written, modId: mod.id },
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

function rowTable(rows, state) {
  const withPending = rows.map((row) => ({ row, pending: pendingFor(row) }));
  // With jobs off there is nothing to change, but a pending change can still be undone.
  const actions = state.on || withPending.some((r) => r.pending.length);
  return el('div', { class: 'table-wrap' }, [
    el('table', { class: 'table dn-table' }, [
      el('thead', {}, [el('tr', {}, [
        el('th', { text: 'Name in post' }),
        el('th', { class: 'num', text: 'Mod count' }),
        el('th', { text: 'Matched mod' }),
        el('th', { text: 'Match source' }),
        actions ? el('th', { text: 'Change' }) : null,
      ])]),
      el('tbody', {}, withPending.map(({ row, pending }) => rowView(row, pending, state, actions))),
    ]),
  ]);
}

function rowView(row, pending, state, actions) {
  const { modNames } = state;
  const count = row.count
    ? el('span', { text: String(row.count) })
    : el('span', { class: 'dim', text: '0', title: 'No mod used this spelling in the last build.' });

  return el('tr', { class: pending.length ? 'is-pending' : null }, [
    el('td', { class: 'dn-written', 'data-label': 'Name in post' }, [el('strong', { text: row.written })]),
    el('td', { class: 'num mono', 'data-label': 'Mod count' }, [count]),
    el('td', { class: 'dn-match', 'data-label': 'Matched mod' }, [
      matchView(row, modNames),
      pending.length ? pendingTag(pending[pending.length - 1], modNames) : null,
    ]),
    el('td', { class: 'dn-source', 'data-label': 'Match source' }, [sourceView(row, modNames)]),
    actions ? el('td', { class: 'dn-actions' }, [actionsView(row, pending, state)]) : null,
  ]);
}

/// The mod a spelling matched, with its id, or why there is none.
function matchView(row, modNames) {
  if (row.id) {
    const name = row.name || modNames.get(row.id);
    return el('span', { class: 'dn-mod' }, [
      el('a', { href: `#/mods/${encodeURIComponent(row.id)}`, text: name || row.id }),
      el('code', { class: 'dn-id', text: name ? row.id : 'unknown id' }),
    ]);
  }
  if (row.saved && !row.saved.id) return el('span', { class: 'dim', text: 'None of our mods' });
  return el('span', { class: 'dim', text: '—' });
}

/// How the spelling was matched, with the saved answer on hover.
function sourceView(row, modNames) {
  const saved = row.saved;
  let title = null;
  if (saved) {
    const what = saved.id ? `"${modNames.get(saved.id) || saved.id}"` : 'none of our mods';
    const who = saved.by === 'hand' ? 'Hand entry' : 'LLM answer';
    title = `${who}${saved.on ? ` saved ${saved.on}` : ''}: ${what}.`;
  }
  return el('span', { class: 'dn-source-cell', title }, [
    statusMark(row.by === 'unmatched' ? 'warning' : 'idle'),
    SOURCE_LABELS[row.by] || row.by,
  ]);
}

function actionsView(row, pending, state) {
  if (pending.length) {
    return el('button', {
      type: 'button',
      class: 'button quiet dn-small',
      text: 'Undo',
      title: 'Remove this change from the pending changes.',
      onclick: () => { for (const item of pending) removePending(item.id); },
    });
  }
  if (!state.on) return null;
  const alreadyNone = row.by === 'hand' && !row.id;
  return el('div', { class: 'dn-buttons' }, [
    el('button', {
      type: 'button',
      class: 'button dn-small',
      text: 'Match…',
      title: 'Pick the mod this name means.',
      onclick: () => openPicker(row, state),
    }),
    alreadyNone ? null : el('button', {
      type: 'button',
      class: 'button dn-small',
      text: 'None of our mods',
      title: 'Mark this name as none of our mods.',
      onclick: () => addNone(row),
    }),
    row.saved ? el('button', {
      type: 'button',
      class: 'button quiet dn-small',
      text: 'Forget saved answer',
      title: 'Remove the saved answer and use the rules. A future LLM run may match it again.',
      onclick: () => addForget(row),
    }) : null,
  ]);
}

// --- The mod picker ---

/// The shared mod picker, with what is known about this spelling. Picking a
/// mod adds the pending change.
function openPicker(row, state) {
  const { mods, modNames } = state;
  const name = row.id ? (row.name || modNames.get(row.id) || row.id) : null;
  let now = 'Not matched.';
  if (row.id) now = `Matched to "${name}" by ${row.by === 'hand' ? 'hand' : row.by === 'rule' ? 'the rules' : 'the LLM'}.`;
  else if (row.saved && !row.saved.id) {
    now = row.saved.by === 'hand' ? 'Marked by hand as none of our mods.' : 'The LLM said it is none of our mods.';
  }
  const used = row.count === 1 ? 'Used by 1 mod in the last build.' : `Used by ${row.count || 0} mods in the last build.`;
  openModPicker({
    written: row.written,
    facts: `${used} ${now}`,
    mods,
    current: row.by === 'hand' ? row.id : null,
    onPick: (mod) => addMatch(row, mod),
  });
}
