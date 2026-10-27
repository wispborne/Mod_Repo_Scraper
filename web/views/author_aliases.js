// Author aliases: the names that belong to one person. Edits are saved by one
// manager job, so they share the data lock and the run history.

import { api, el, clear, breadcrumbs, go } from '../lib.js';
import * as manager from '../manager.js';

const SUGGESTIONS_SHOWN = 20;

// Unsaved edits survive moving to another page and back.
let draft = null;

export async function render(root) {
  clear(root);
  root.append(breadcrumbs([{ label: 'Author aliases' }]));
  root.append(el('h1', { text: 'Author aliases' }));

  const body = await api('author-aliases');
  const status = manager.status() || await manager.refresh();
  const managerOn = !!status?.on;

  const page = el('div', { class: 'stack' });
  root.append(page);
  page.append(el('p', {
    class: 'takedown-intro',
    text: 'Each row is one person and every name they use. Mods credited to any of the names '
      + 'are credited to one author. The first name is the one shown on the site and in TriOS.',
  }));
  if (body.error) {
    page.append(el('div', { class: 'missing error' }, [
      el('h3', { text: 'The alias file cannot be read' }),
      el('p', { text: body.error }),
    ]));
    return;
  }

  const original = { rows: body.rows, notSame: body.notSame || [] };
  if (!draft || draft.base !== JSON.stringify(original)) {
    draft = { base: JSON.stringify(original), rows: copy(original.rows), notSame: copy(original.notSame) };
  }
  const counts = body.modCounts || {};
  const state = { search: '', showAllSuggestions: false, focusRow: null };

  const saveBar = el('div', { class: 'req-save-bar' });
  const suggestionsBox = el('div', { class: 'stack' });
  const peopleBox = el('div', { class: 'stack' });
  const nameOptions = el('datalist', { id: 'alias-name-options' },
    (body.names || []).map((name) => el('option', { value: name })));
  page.append(nameOptions, saveBar, suggestionsBox, peopleBox);

  const draw = () => {
    drawSaveBar(saveBar, original, managerOn, draw);
    drawSuggestions(suggestionsBox, body, state, managerOn, draw);
    drawPeople(peopleBox, original, counts, state, managerOn, draw);
  };
  draw();
}

function copy(rows) {
  return rows.map((row) => [...row]);
}

const lower = (name) => name.toLowerCase();
const rowKey = (row) => row.map(lower).join('\n');

/// The row in the draft holding [name], ignoring capitals.
function rowHolding(name) {
  return draft.rows.find((row) => row.some((n) => lower(n) === lower(name)));
}

function isDismissed(a, b) {
  return draft.notSame.some((pair) => {
    const names = pair.map(lower);
    return names.includes(lower(a)) && names.includes(lower(b));
  });
}

// ----------------------------------------------------------------- Save bar

/// What the draft changes, one line each, compared with what is in force.
function changesFrom(original) {
  const before = new Map(original.rows.map((row) => [rowKey(row), row]));
  const after = new Map(draft.rows.map((row) => [rowKey(row), row]));
  const lines = [];
  for (const [key, row] of after) if (!before.has(key)) lines.push(`Now: ${row.join(', ')}`);
  for (const [key, row] of before) if (!after.has(key)) lines.push(`Was: ${row.join(', ')}`);
  const pairKey = (pair) => pair.map(lower).sort().join('\n');
  const oldPairs = new Set(original.notSame.map(pairKey));
  for (const pair of draft.notSame) {
    if (!oldPairs.has(pairKey(pair))) lines.push(`Different people: ${pair.join(' and ')}`);
  }
  const newPairs = new Set(draft.notSame.map(pairKey));
  for (const pair of original.notSame) {
    if (!newPairs.has(pairKey(pair))) lines.push(`No longer marked different: ${pair.join(' and ')}`);
  }
  return lines;
}

/// Why the draft cannot be saved yet, or null.
function problem() {
  const seen = new Map();
  for (const row of draft.rows) {
    if (row.length < 2) return `"${row[0]}" needs a second name, or remove that person.`;
    for (const name of row) {
      const other = seen.get(lower(name));
      if (other && other !== row) return `"${name}" is listed for two people.`;
      seen.set(lower(name), row);
    }
  }
  return null;
}

function drawSaveBar(bar, original, managerOn, redraw) {
  clear(bar);
  if (!managerOn) return;
  const changes = changesFrom(original);
  if (!changes.length) return;
  const blocked = problem();
  bar.append(...[
    el('span', {
      text: `${changes.length} unsaved ${changes.length === 1 ? 'change' : 'changes'}`,
      title: changes.join('\n'),
    }),
    blocked ? el('span', { class: 'takedown-warning-text', text: blocked }) : null,
    el('button', {
      class: 'btn btn-primary',
      text: 'Save and rebuild',
      disabled: blocked ? 'true' : null,
      onclick: async () => {
        const request = {
          kind: 'setAuthorAliases',
          authorAliasPeople: draft.rows,
          authorAliasNotSame: draft.notSame,
          collectMergeDebug: true,
        };
        const run = await manager.confirmAndSubmit(request);
        if (!run) return;
        draft = null;
        go(`#/runs/${run.id}`);
      },
    }),
    el('button', {
      class: 'btn',
      text: 'Discard changes',
      onclick: () => {
        draft.rows = copy(original.rows);
        draft.notSame = copy(original.notSame);
        redraw();
      },
    }),
  ].filter(Boolean));
}

// -------------------------------------------------------------- Suggestions

function drawSuggestions(box, body, state, managerOn, redraw) {
  clear(box);
  const open = (body.suggestions || []).filter((s) => {
    const row = rowHolding(s.forum);
    const together = row && row.some((n) => lower(n) === lower(s.discord));
    return !together && !isDismissed(s.forum, s.discord);
  });
  box.append(el('div', { class: 'alias-section-head' }, [
    el('h2', { text: 'Possible aliases' }),
    el('span', { class: 'badge badge-dim', text: String(open.length) }),
  ]));
  if (!body.hasCatalog) {
    box.append(el('p', { class: 'dim', text: 'Build the catalog to see possible aliases.' }));
    return;
  }
  if (!open.length) {
    box.append(el('p', { class: 'dim', text: 'Nothing to check. Every mod\'s forum and Discord names match.' }));
    return;
  }
  box.append(el('p', {
    class: 'takedown-intro',
    text: 'The forum and Discord name a different author for the same mod. Often it is one person '
      + 'with two accounts. Sometimes it is a team, or a fork posted by someone else.',
  }));

  const shown = state.showAllSuggestions ? open : open.slice(0, SUGGESTIONS_SHOWN);
  box.append(el('div', { class: 'table-wrapper' }, [
    el('table', { class: 'req-table alias-suggestions' }, [
      el('thead', {}, [el('tr', {}, [
        el('th', { text: 'Forum' }),
        el('th', { text: 'Discord' }),
        el('th', { text: 'Mods with both' }),
        managerOn ? el('th', { text: '' }) : null,
      ])]),
      el('tbody', {}, shown.map((s) => suggestionRow(s, managerOn, state, redraw))),
    ]),
  ]));
  if (open.length > shown.length) {
    box.append(el('button', {
      class: 'btn req-small alias-more',
      text: `Show all ${open.length}`,
      onclick: () => { state.showAllSuggestions = true; redraw(); },
    }));
  }
}

function suggestionRow(s, managerOn, state, redraw) {
  const mods = s.mods.slice(0, 3).map((m, i) => [
    i ? ', ' : null,
    el('a', { href: `#/modrepo?q=${encodeURIComponent(m.name)}`, text: m.name }),
  ]).flat();
  if (s.mods.length > 3) mods.push(el('span', { class: 'dim', text: ` and ${s.mods.length - 3} more` }));
  return el('tr', {}, [
    el('td', { class: 'alias-who' }, [el('strong', { text: s.forum })]),
    el('td', { class: 'alias-who' }, [el('strong', { text: s.discord })]),
    el('td', {}, mods),
    managerOn ? el('td', {}, [el('div', { class: 'req-edit alias-actions' }, [
      el('button', {
        class: 'btn req-small',
        text: 'Same person',
        title: `Add "${s.discord}" as another name for "${s.forum}".`,
        onclick: () => {
          joinNames(s.forum, s.discord);
          redraw();
        },
      }),
      el('button', {
        class: 'btn req-small',
        text: 'Different people',
        title: 'Stop suggesting this pair.',
        onclick: () => { draft.notSame.push([s.forum, s.discord]); redraw(); },
      }),
    ])]) : null,
  ]);
}

/// Puts [a] and [b] in one row, joining the rows they are already in, and
/// returns that row.
function joinNames(a, b) {
  const rowA = rowHolding(a);
  const rowB = rowHolding(b);
  if (rowA && rowB && rowA !== rowB) {
    rowA.push(...rowB.filter((n) => !rowA.some((m) => lower(m) === lower(n))));
    draft.rows.splice(draft.rows.indexOf(rowB), 1);
    return rowA;
  }
  if (rowA) { if (!rowB) rowA.push(b); return rowA; }
  if (rowB) { rowB.push(a); return rowB; }
  const row = [a, b];
  draft.rows.unshift(row);
  return row;
}

// ------------------------------------------------------------------- People

function drawPeople(box, original, counts, state, managerOn, redraw) {
  clear(box);
  const originalKeys = new Set(original.rows.map(rowKey));
  const search = el('input', {
    type: 'search',
    class: 'req-search',
    placeholder: 'Search names',
    value: state.search,
    oninput: () => {
      state.search = search.value.trim().toLowerCase();
      drawTable();
      search.focus();
    },
  });
  box.append(el('div', { class: 'alias-section-head' }, [
    el('h2', { text: 'People' }),
    el('span', { class: 'badge badge-dim', text: String(draft.rows.length) }),
  ]));
  box.append(el('div', { class: 'req-toolbar' }, [
    search,
    managerOn ? el('button', {
      class: 'btn',
      text: 'Add a person',
      onclick: () => {
        const row = [];
        draft.rows.unshift(row);
        state.focusRow = row;
        state.search = '';
        redraw();
      },
    }) : null,
  ]));
  const tableBox = el('div');
  box.append(tableBox);

  const drawTable = () => {
    clear(tableBox);
    const shown = draft.rows.filter((row) => !state.search || !row.length
      || row.some((n) => lower(n).includes(state.search)));
    if (!shown.length) {
      tableBox.append(el('p', { class: 'dim', text: 'No names match.' }));
      return;
    }
    tableBox.append(el('div', { class: 'table-wrapper' }, [
      el('table', { class: 'req-table alias-table' }, [
        el('thead', {}, [el('tr', {}, [
          el('th', { text: 'Shown as' }),
          el('th', { text: 'Other names' }),
          managerOn ? el('th', { text: '' }) : null,
        ])]),
        el('tbody', {}, shown.map((row) =>
          personRow(row, counts, !originalKeys.has(rowKey(row)), state, managerOn, redraw))),
      ]),
    ]));
    const focus = tableBox.querySelector('.alias-focus input');
    if (focus) {
      focus.focus();
      focus.closest('tr').scrollIntoView({ block: 'nearest' });
    }
    state.focusRow = null;
  };
  drawTable();
}

function modsLine(n) {
  return n ? `${n} ${n === 1 ? 'mod uses' : 'mods use'} this name` : 'No mod in the catalog uses this name';
}

function nameChip(name, row, counts, managerOn, redraw) {
  const n = counts[lower(name)] || 0;
  const shown = row[0] === name;
  return el('span', {
    class: `alias-name${shown ? ' shown' : ''}${n ? '' : ' unused'}`,
    title: modsLine(n),
  }, [
    managerOn && !shown
      ? el('button', {
        class: 'alias-name-text',
        text: name,
        title: `${modsLine(n)}. Click to show this person as "${name}".`,
        onclick: () => {
          row.splice(row.indexOf(name), 1);
          row.unshift(name);
          redraw();
        },
      })
      : el('span', { class: 'alias-name-text', text: name }),
    n ? el('span', { class: 'alias-count', text: String(n) }) : null,
    managerOn
      ? el('button', {
        class: 'alias-remove',
        text: '×',
        title: `Remove "${name}"`,
        'aria-label': `Remove ${name}`,
        onclick: () => {
          row.splice(row.indexOf(name), 1);
          redraw();
        },
      })
      : null,
  ]);
}

function personRow(row, counts, changed, state, managerOn, redraw) {
  const [first, ...rest] = row;
  const message = el('div', { class: 'alias-message' });
  const input = el('input', {
    class: 'req-pick alias-add',
    list: 'alias-name-options',
    placeholder: row.length ? 'Add a name' : 'First name',
    onkeydown: (e) => { if (e.key === 'Enter') add(); },
  });
  const addBox = el('span', { class: 'alias-add-box' });
  const openAdd = () => {
    clear(addBox);
    addBox.append(input, el('button', { class: 'btn req-small', text: 'Add', onclick: () => add() }));
    input.focus();
  };
  const add = () => {
    const name = input.value.trim();
    if (!name) return;
    if (row.some((n) => lower(n) === lower(name))) {
      message.textContent = `"${name}" is already listed here.`;
      return;
    }
    const other = rowHolding(name);
    if (other) {
      message.textContent = `"${name}" already belongs to another person (shown as ${other[0]}). `
        + 'Remove it there first.';
      return;
    }
    row.push(name);
    state.focusRow = row;
    redraw();
  };

  if (managerOn) {
    if (row.length < 2 || state.focusRow === row) {
      addBox.append(input, el('button', { class: 'btn req-small', text: 'Add', onclick: () => add() }));
    } else {
      addBox.append(el('button', {
        class: 'alias-add-open',
        text: '+ Add name',
        title: 'Add another name this person uses.',
        onclick: openAdd,
      }));
    }
  }

  const classes = [changed ? 'req-changed' : '', state.focusRow === row ? 'alias-focus' : ''].join(' ').trim();
  return el('tr', { class: classes || null }, [
    el('td', { class: 'alias-shown' }, [
      first != null
        ? nameChip(first, row, counts, managerOn, redraw)
        : el('span', { class: 'dim', text: 'New person' }),
    ]),
    el('td', {}, [
      el('div', { class: 'alias-names' }, [
        ...rest.map((name) => nameChip(name, row, counts, managerOn, redraw)),
        row.length === 1 ? el('span', { class: 'badge badge-warning', text: 'Needs a second name' }) : null,
        managerOn ? addBox : null,
      ]),
      message,
    ]),
    managerOn ? el('td', { class: 'alias-row-actions' }, [
      el('button', {
        class: 'btn req-small',
        text: 'Remove person',
        title: 'Stop treating these names as one person.',
        onclick: () => {
          draft.rows.splice(draft.rows.indexOf(row), 1);
          redraw();
        },
      }),
    ]) : null,
  ]);
}
