// Author aliases: the names that belong to one person. The page only reads.
// Each action adds a pending change; nothing is written until the pending
// changes are saved, which runs one job for all of them. The lists are drawn
// as the server sends them. A pending change is marked on the rows it names,
// but the page does not try to work out what the list will look like after
// the save: the save job is the one place the rules run.

import { el, clear, api, askDialog, infoButton } from '../lib.js';
import { pageLayout, sidePanel, statusMark } from '../frame.js';
import { subscribe, status } from '../status.js';
import { hashQuery, buildHash } from '../routes.js';
import {
  addPending, onPendingChange, pendingItems, removePending, correctionKey, heldBackNameChanges,
} from '../pending.js';
import { pendingPanel } from '../pending_view.js';

/// How many suggestions show before "Show all".
const SUGGESTIONS_SHOWN = 20;

/// How many of a suggestion's mods are named before "and N more".
const MODS_NAMED = 3;

/// The correction kinds this page adds.
const AUTHOR_KINDS = new Set(['sameAuthor', 'differentAuthors', 'removeAuthorName', 'publishAuthorAs']);

/// The sentence the other pages use when jobs are off.
function managerOffText(s) {
  if (s && s.offline) return 'The server could not be reached. Author aliases cannot be changed.';
  return `${(s && s.reason) || 'Job management is disabled on this server.'} Start the viewer with a readable `
    + 'config.properties file (or specify it with --config) and omit --no-manager to enable jobs.';
}

export function render({ content, onLeave }) {
  const query = hashQuery(location.hash);
  // `body` is the server's answer, or null before it arrives.
  const state = {
    body: null,
    on: null,
    search: (query.get('q') || '').trim(),
    showAll: query.get('all') === '1',
    // The person whose "Add a name" box is open, by their first name.
    adding: null,
  };

  const main = el('div', { class: 'aa-page' }, [el('p', { class: 'empty', text: 'Loading…' })]);
  const formSlot = el('div');
  // One list of names for every name box on the page.
  const options = el('datalist', { id: 'aa-name-options' });
  content.append(pageLayout(main, [pendingPanel(), formSlot]), options);

  const saveAddress = () => {
    history.replaceState(null, '', buildHash(['author-aliases'], {
      q: state.search || null,
      all: state.showAll ? '1' : null,
    }));
  };

  const ctx = { state, redraw: () => drawMain(), saveAddress };

  const load = async () => {
    try {
      state.body = await api('author-aliases');
    } catch (err) {
      state.body = { error: err.message, rows: [], notSame: [], suggestions: [], names: [], modCounts: {} };
    }
  };

  const drawMain = () => {
    if (!state.body) return;
    clear(main).append(...mainPanel(ctx));
  };

  const drawSide = () => {
    if (state.on && state.body && !state.body.error) {
      formSlot.replaceChildren(sidePanel({ name: 'Join two names', body: joinForm(ctx) }));
    } else if (state.on === false) {
      formSlot.replaceChildren(sidePanel({
        name: 'Viewing only',
        body: el('p', { class: 'aa-side-note', text: managerOffText(status()) }),
      }));
    } else {
      formSlot.replaceChildren();
    }
  };

  onLeave(onPendingChange(drawMain));

  let lastRunId;
  onLeave(subscribe(async (s) => {
    if (s.on !== state.on) {
      state.on = s.on;
      drawSide();
      drawMain();
    }
    // A job that just ended may have changed the list: read it again.
    const runId = s.current ? s.current.record.id : null;
    if (lastRunId !== undefined && runId !== lastRunId && lastRunId !== null) {
      await load();
      options.replaceChildren(...nameOptions(state.body));
      drawMain();
      drawSide();
    }
    lastRunId = runId;
  }));

  load().then(() => {
    options.replaceChildren(...nameOptions(state.body));
    state.on = status() ? status().on : state.on;
    drawMain();
    drawSide();
  });
}

// --- Names ---

const lower = (name) => String(name).toLowerCase();

/// The person (a row of names) holding `name`, ignoring capitals, or null.
function rowHolding(rows, name) {
  return rows.find((row) => row.some((n) => lower(n) === lower(name))) || null;
}

function modCount(body, name) {
  return (body.modCounts || {})[lower(name)] || 0;
}

/// The old page's words for how many mods use a name.
function modsLine(n) {
  return n ? `${n} ${n === 1 ? 'mod uses' : 'mods use'} this name` : 'No mod in the catalog uses this name';
}

// --- Labels for pending changes, in the shapes the save job uses ---

const sameLabel = (a, b) => `"${a}" and "${b}" are the same person`;
const differentLabel = (a, b) => `"${a}" and "${b}" are different people`;
const takeOffLabel = (a) => `Take "${a}" off its person`;
const publishLabel = (a) => `Publish the person as "${a}"`;

/// The pending item for `correction`, or null.
function pendingFor(correction) {
  const wanted = correctionKey(correction);
  return pendingItems().find((i) => correctionKey(i.correction) === wanted) || null;
}

/// Pending author changes that name any of `names`.
function pendingNaming(names) {
  const wanted = new Set(names.map(lower));
  return pendingItems().filter((i) => AUTHOR_KINDS.has(i.correction.kind)
    && (i.correction.names || []).some((n) => wanted.has(lower(n))));
}

function undoButton(item) {
  return el('button', {
    type: 'button',
    class: 'button quiet aa-small',
    text: 'Undo',
    title: 'Undo this unsaved change.',
    onclick: () => removePending(item.id),
  });
}

/// Adds "these two names are the same person". If the names belong to two
/// different people, asks before adding the change because saving joins them.
/// Resolves true when the change was added.
async function addSame(body, a, b) {
  const rowA = rowHolding(body.rows || [], a);
  const rowB = rowHolding(body.rows || [], b);
  if (rowA && rowB && rowA !== rowB) {
    const yes = await askDialog({
      title: 'Join two people?',
      message: `"${a}" is a name of one person (${rowA.join(', ')}). "${b}" is a name of another (${rowB.join(', ')}).`
        + `\n\nSaving joins them into one person with all their names. The person is shown as "${rowA[0]}".`,
      confirmLabel: 'Join them',
    });
    if (!yes) return false;
  }
  return addPending({ kind: 'sameAuthor', label: sameLabel(a, b), correction: { kind: 'sameAuthor', names: [a, b] } });
}

// --- The page ---

function mainPanel(ctx) {
  const { body } = ctx.state;
  const rows = body.rows || [];
  const parts = [
    el('div', { class: 'aa-head' }, [
      el('h2', { class: 'panel-heading', text: 'Alias list' }),
      infoButton('About author aliases', 'Author aliases', aboutAliases),
      el('div', { class: 'aa-counts' }, [
        countChip(rows.length, 'person', 'people'),
        body.saved != null
          ? el('span', {
            class: 'aa-source',
            text: body.saved ? 'Saved list' : 'Built-in list',
            title: body.saved
              ? 'The list saved in author-aliases.json, plus any built-in row added to the code since.'
              : 'Nothing is saved yet, so the rows built into the code are in use.',
          })
          : null,
      ]),
    ]),
  ];
  if (body.error) {
    parts.push(el('div', { class: 'aa-banner bad' }, [
      el('strong', { text: 'The alias file cannot be read' }),
      el('p', { text: body.error }),
    ]));
    return parts;
  }
  parts.push(suggestionsSection(ctx), peopleSection(ctx), differentSection(ctx));
  return parts;
}

/// The info dialog: what a row means, and what each section is for.
function aboutAliases() {
  const item = (label, text) => el('div', {}, [el('dt', { text: label }), el('dd', { text })]);
  return [
    el('p', {
      text: 'Each row lists all the names used by one person. Mods credited to any of these names are credited to '
        + 'that person. The first name is shown on the site and in TriOS.',
    }),
    el('dl', {}, [
      item('Possible aliases', 'The forum and Discord credit the same mod to different names. Often, both names belong to '
        + 'one person with two accounts. Sometimes they belong to a team. Sometimes someone else has changed the mod and '
        + 'posted their version.'),
      item('Different people', 'After you save, pairs marked as Different people no longer appear under Possible aliases. '
        + 'Nothing else changes.'),
      item('Join two names', 'Select names from the list or enter names. If neither name is listed under People, a new row '
        + 'is added. The name in the First name box appears under Shown as.'),
    ]),
  ];
}

function countChip(n, one, many) {
  return el('span', { class: 'chip' }, [el('b', { text: String(n) }), ` ${n === 1 ? one : many}`]);
}

function sectionHead(title, count) {
  return el('h2', { class: 'aa-section-head' }, [
    el('span', { class: 'panel-heading', text: title }),
    el('span', { class: 'aa-section-count', text: String(count) }),
  ]);
}

// --- Possible aliases ---

function suggestionsSection(ctx) {
  const { state } = ctx;
  const { body } = state;
  const all = body.suggestions || [];
  const section = el('section', { class: 'aa-section' }, [sectionHead('Possible aliases', all.length)]);
  if (!body.hasCatalog) {
    section.append(el('p', { class: 'aa-note dim', text: 'Build the catalog to see possible aliases.' }));
    return section;
  }
  if (!all.length) {
    section.append(el('p', { class: 'aa-note dim', text: 'Nothing to check. Every mod\'s forum and Discord names match.' }));
    return section;
  }
  const shown = state.showAll ? all : all.slice(0, SUGGESTIONS_SHOWN);
  section.append(el('div', { class: 'aa-entries' }, shown.map((s) => suggestionRow(s, ctx))));
  if (all.length > shown.length) {
    section.append(el('div', { class: 'aa-more' }, [el('button', {
      type: 'button',
      class: 'button',
      text: `Show all ${all.length}`,
      onclick: () => { state.showAll = true; ctx.saveAddress(); ctx.redraw(); },
    })]));
  }
  return section;
}

function suggestionRow(s, ctx) {
  const { body, on } = ctx.state;
  const same = pendingFor({ kind: 'sameAuthor', names: [s.forum, s.discord] });
  const different = pendingFor({ kind: 'differentAuthors', names: [s.forum, s.discord] });
  const pending = same || different;

  const mods = s.mods || [];
  const modLinks = mods.slice(0, MODS_NAMED).flatMap((m, i) => [
    i ? ', ' : null,
    el('a', {
      href: buildHash(['mods'], { q: m.name }),
      text: m.name,
    }),
  ]);
  if (mods.length > MODS_NAMED) modLinks.push(el('span', { class: 'dim', text: ` and ${mods.length - MODS_NAMED} more` }));

  const tags = [];
  if (same) tags.push(el('span', { class: 'tag aa-tag-pending', text: 'Same person pending' }));
  if (different) tags.push(el('span', { class: 'tag aa-tag-pending', text: 'Different people pending' }));

  let actions = null;
  if (pending) {
    actions = [undoButton(pending)];
  } else if (on) {
    actions = [
      el('button', {
        type: 'button',
        class: 'button',
        text: 'These are the same person',
        title: `Add "${s.discord}" as another name for "${s.forum}".`,
        onclick: () => addSame(body, s.forum, s.discord),
      }),
      el('button', {
        type: 'button',
        class: 'button quiet',
        text: 'Different people',
        title: 'Stop suggesting this pair.',
        onclick: () => addPending({
          kind: 'differentAuthors',
          label: differentLabel(s.forum, s.discord),
          correction: { kind: 'differentAuthors', names: [s.forum, s.discord] },
        }),
      }),
    ];
  }

  return el('article', { class: `aa-entry${pending ? ' is-pending' : ''}` }, [
    statusMark(pending ? 'warning' : 'idle'),
    el('div', { class: 'aa-entry-main' }, [
      el('div', { class: 'aa-pair' }, [
        nameWithWhere(body, s.forum, 'Forum'),
        nameWithWhere(body, s.discord, 'Discord'),
        ...tags,
      ]),
      el('div', { class: 'aa-mods' }, [el('span', { class: 'aa-label', text: 'Mods with both' }), ' ', ...modLinks]),
    ]),
    actions ? el('div', { class: 'aa-entry-actions' }, actions) : null,
  ]);
}

/// A name with where it came from and how many mods use it.
function nameWithWhere(body, name, where) {
  const n = modCount(body, name);
  const row = rowHolding(body.rows || [], name);
  return el('span', { class: 'aa-who', title: row ? `${modsLine(n)}. Already a name of the person shown as "${row[0]}".` : modsLine(n) }, [
    el('span', { class: 'aa-where', text: where }),
    el('strong', { text: name }),
    n ? el('span', { class: 'aa-count', text: String(n) }) : null,
  ]);
}

// --- People ---

function peopleSection(ctx) {
  const { state } = ctx;
  const rows = state.body.rows || [];
  const listBox = el('div', { class: 'aa-entries' });
  const search = el('input', {
    type: 'search',
    class: 'input aa-search',
    placeholder: 'Search names',
    'aria-label': 'Search names',
    value: state.search,
  });
  const drawList = () => {
    const q = lower(state.search);
    const shown = q ? rows.filter((row) => row.some((n) => lower(n).includes(q))) : rows;
    clear(listBox);
    if (!rows.length) {
      listBox.append(el('p', { class: 'aa-note dim', text: 'No names are joined yet.' }));
    } else if (!shown.length) {
      listBox.append(el('p', { class: 'aa-note dim', text: 'No names match.' }));
    } else {
      listBox.append(
        el('div', { class: 'aa-entry aa-people-head', 'aria-hidden': 'true' }, [
          el('span'),
          el('div', { class: 'aa-person-names' }, [
            el('span', { class: 'aa-label', text: 'Shown as' }),
            el('span', { class: 'aa-label', text: 'Other names' }),
          ]),
        ]),
        ...shown.map((row) => personRow(row, ctx)),
      );
    }
  };
  search.addEventListener('input', () => {
    state.search = search.value.trim();
    ctx.saveAddress();
    drawList();
  });
  drawList();
  return el('section', { class: 'aa-section' }, [
    sectionHead('People', rows.length),
    el('div', { class: 'aa-toolbar' }, [search]),
    listBox,
  ]);
}

function personRow(row, ctx) {
  const { on } = ctx.state;
  const [first, ...rest] = row;
  const pending = pendingNaming(row);
  const pendingNames = new Set(pending.flatMap((i) => (i.correction.names || []).map(lower)));
  const held = heldBackNameChanges(row, pending);

  const chip = (name) => nameChip(name, row, ctx, pendingNames.has(lower(name)), held);
  const others = el('div', { class: 'aa-names' }, rest.map(chip));
  if (on) others.append(addNameBox(row, ctx));

  return el('article', { class: `aa-entry aa-person${pending.length ? ' is-pending' : ''}` }, [
    statusMark(pending.length ? 'warning' : 'idle'),
    el('div', { class: 'aa-entry-main' }, [
      el('div', { class: 'aa-person-names' }, [
        el('div', { class: 'aa-shown' }, [chip(first)]),
        el('div', { class: 'aa-others' }, [others]),
      ]),
      pending.length ? el('ul', { class: 'aa-pending' }, pending.map((item) => el('li', {}, [
        el('span', { class: 'tag aa-tag-pending', text: 'Pending' }),
        el('span', { class: 'aa-pending-label', text: item.label }),
        undoButton(item),
      ]))) : null,
    ]),
  ]);
}

/// Checks for a pending removal or choice of published name.
/// These changes conflict, so Undo must clear one before another is offered.
/// `heldBackNameChanges` does the same for the person's other names.
function nameChangePending(name) {
  const wanted = lower(name);
  return pendingItems().some((i) => (i.correction.kind === 'removeAuthorName' || i.correction.kind === 'publishAuthorAs')
    && (i.correction.names || []).some((n) => lower(n) === wanted));
}

/// One name of a person: the name, how many mods use it, and with jobs on, a
/// way to publish the person under it and a way to take it off. `held` says
/// which of the two a pending change on another of the person's names holds
/// back.
function nameChip(name, row, ctx, pending, held) {
  const { body } = ctx.state;
  const on = ctx.state.on && !nameChangePending(name);
  const n = modCount(body, name);
  const shown = row[0] === name;
  const last = row.filter((x) => lower(x) !== lower(name));
  const takeOffTitle = last.length < 2
    ? `${takeOffLabel(name)}. "${last.join('')}" has no other name left, so this person is no longer an alias.`
    : `${takeOffLabel(name)}.`;
  return el('span', {
    class: `aa-name${shown ? ' shown' : ''}${n ? '' : ' unused'}${pending ? ' is-pending' : ''}`,
    title: modsLine(n),
  }, [
    on && !shown && !held.publish
      ? el('button', {
        type: 'button',
        class: 'aa-name-text',
        text: name,
        title: `${modsLine(n)}. Click to publish the person as "${name}".`,
        onclick: () => addPending({
          kind: 'publishAuthorAs',
          label: publishLabel(name),
          correction: { kind: 'publishAuthorAs', names: [name] },
        }),
      })
      : el('span', { class: 'aa-name-text', text: name }),
    n ? el('span', { class: 'aa-count', text: String(n) }) : null,
    on && !held.remove
      ? el('button', {
        type: 'button',
        class: 'aa-remove',
        text: '×',
        title: takeOffTitle,
        'aria-label': takeOffLabel(name),
        onclick: () => addPending({
          kind: 'removeAuthorName',
          label: takeOffLabel(name),
          correction: { kind: 'removeAuthorName', names: [name] },
        }),
      })
      : null,
  ]);
}

/// "+ Add name" on a person, which opens a box for one more name. Adding it
/// is "the shown name and this name are the same person".
function addNameBox(row, ctx) {
  const { state } = ctx;
  const box = el('span', { class: 'aa-add-box' });
  const key = lower(row[0]);
  const open = () => {
    state.adding = key;
    const message = el('span', { class: 'aa-message warn-text' });
    const input = el('input', {
      class: 'input aa-add',
      list: 'aa-name-options',
      placeholder: 'Add a name',
      'aria-label': `Another name for ${row[0]}`,
    });
    const add = async () => {
      const name = input.value.trim();
      if (!name) return;
      if (row.some((n) => lower(n) === lower(name))) {
        message.textContent = `"${name}" is already listed here.`;
        return;
      }
      // Cleared first: adding redraws the page, and the new box must stay shut.
      state.adding = null;
      if (await addSame(state.body, row[0], name)) return;
      state.adding = key;
      if (pendingFor({ kind: 'sameAuthor', names: [row[0], name] })) message.textContent = 'This change is already pending.';
    };
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') { e.preventDefault(); add(); }
      if (e.key === 'Escape') { state.adding = null; close(); }
    });
    box.replaceChildren(
      input,
      el('button', { type: 'button', class: 'button aa-small', text: 'Add', onclick: add }),
      el('button', {
        type: 'button', class: 'button quiet aa-small', text: 'Cancel',
        onclick: () => { state.adding = null; close(); },
      }),
      message,
    );
    input.focus();
  };
  const close = () => {
    box.replaceChildren(el('button', {
      type: 'button',
      class: 'link-button aa-add-open',
      text: '+ Add name',
      title: 'Add another name this person uses.',
      onclick: open,
    }));
  };
  close();
  // Kept open across a redraw, once the box is on the page.
  if (state.adding === key) queueMicrotask(() => { if (state.adding === key && box.isConnected) open(); });
  return box;
}

/// The names to suggest in a name box: every name the catalog credits, and
/// every name already on a person.
function nameOptions(body) {
  const seen = new Map();
  for (const name of [...(body.names || []), ...(body.rows || []).flat()]) {
    if (!seen.has(lower(name))) seen.set(lower(name), name);
  }
  return [...seen.values()].map((name) => el('option', { value: name }));
}

// --- Different people ---

function differentSection(ctx) {
  const { body } = ctx.state;
  const pairs = (body.notSame || []).filter((p) => Array.isArray(p) && p.length === 2);
  const section = el('section', { class: 'aa-section' }, [sectionHead('Different people', pairs.length)]);
  if (!pairs.length) {
    section.append(el('p', { class: 'aa-note dim', text: 'No pairs are marked as different people.' }));
    return section;
  }
  section.append(el('div', { class: 'aa-entries' }, pairs.map(([a, b]) => differentRow(a, b, ctx))));
  return section;
}

function differentRow(a, b, ctx) {
  const { body, on } = ctx.state;
  const same = pendingFor({ kind: 'sameAuthor', names: [a, b] });
  let action = null;
  if (same) {
    action = undoButton(same);
  } else if (on) {
    action = el('button', {
      type: 'button',
      class: 'button quiet',
      text: 'These are the same person',
      title: `Add "${b}" as another name for "${a}". This also removes the mark.`,
      onclick: () => addSame(body, a, b),
    });
  }
  const name = (n) => el('span', { class: 'aa-who', title: modsLine(modCount(body, n)) }, [
    el('strong', { text: n }),
    modCount(body, n) ? el('span', { class: 'aa-count', text: String(modCount(body, n)) }) : null,
  ]);
  return el('article', { class: `aa-entry${same ? ' is-pending' : ''}` }, [
    statusMark(same ? 'warning' : 'idle'),
    el('div', { class: 'aa-entry-main' }, [
      el('div', { class: 'aa-pair' }, [
        name(a),
        el('span', { class: 'dim', text: 'and' }),
        name(b),
        same ? el('span', { class: 'tag aa-tag-pending', text: 'Same person pending' }) : null,
      ]),
    ]),
    action ? el('div', { class: 'aa-entry-actions' }, [action]) : null,
  ]);
}

// --- Join two names by hand ---

function joinForm(ctx) {
  const { state } = ctx;
  const message = el('p', { class: 'aa-hint warn-text', hidden: true });
  const field = (label) => el('input', {
    type: 'text', class: 'input aa-input', list: 'aa-name-options', autocomplete: 'off', spellcheck: 'false',
    placeholder: label, 'aria-label': label,
  });
  const first = field('First name');
  const second = field('Second name');
  const say = (text) => { message.textContent = text; message.hidden = !text; };

  const form = el('form', { class: 'aa-form' }, [
    first,
    second,
    message,
    el('div', {}, [el('button', { type: 'submit', class: 'button primary', text: 'These are the same person' })]),
  ]);
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const a = first.value.trim();
    const b = second.value.trim();
    if (!a || !b) { say('Enter two names.'); return; }
    if (lower(a) === lower(b)) { say('Enter two different names.'); return; }
    const rowA = rowHolding(state.body.rows || [], a);
    if (rowA && rowA.some((n) => lower(n) === lower(b))) { say(`"${a}" and "${b}" are already one person.`); return; }
    if (pendingFor({ kind: 'sameAuthor', names: [a, b] })) { say('This change is already pending.'); return; }
    say('');
    if (await addSame(state.body, a, b)) {
      first.value = '';
      second.value = '';
      first.focus();
    }
  });
  return form;
}
