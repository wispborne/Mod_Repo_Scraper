// Takedowns: mods and people left out of everything we publish, at their
// request. The page only reads. Taking something down or restoring it adds a
// pending change; nothing is written until the pending changes are saved,
// which runs one job for all of them.

import { el, clear, api, noticeDialog, showDialog, shortTime } from '../lib.js';
import { pageLayout, sidePanel, statusMark } from '../frame.js';
import { subscribe, status } from '../status.js';
import {
  addPending, isPending, onPendingChange, pendingItems, removePending, correctionKey,
} from '../pending.js';
import { pendingPanel } from '../pending_view.js';

/// How many suggestions a form's box shows at once.
const SUGGESTION_COUNT = 8;

/// The sentence the other pages use when jobs are off.
function managerOffText(s) {
  if (s && s.offline) return 'The server could not be reached. Takedowns cannot be changed.';
  return `${(s && s.reason) || 'Job management is disabled on this server.'} Start the viewer with a readable `
    + 'config.properties file (or specify it with --config) and omit --no-manager to enable jobs.';
}

export function render({ content, onLeave }) {
  // What the page knows. `catalog` is the catalog's mods and Collection pages
  // (from /api/takedowns/mods), or null when the catalog cannot be read.
  const state = { list: null, matches: new Map(), builtAt: null, error: null, catalog: null, on: null };

  const main = el('div', { class: 'td-page' }, [el('p', { class: 'empty', text: 'Loading…' })]);
  const formSlot = el('div');
  content.append(pageLayout(main, [pendingPanel(), formSlot]));

  const load = async () => {
    const [body, mods] = await Promise.all([
      api('takedowns').catch((err) => ({ error: err.message })),
      api('takedowns/mods').catch(() => null),
    ]);
    state.error = body && body.error ? body.error : null;
    state.list = (body && body.list) || { mods: [], authors: [] };
    state.matches = new Map(((body && body.matches && body.matches.matches) || []).map((m) => [m.entry, m]));
    state.builtAt = (body && body.matches && body.matches.builtAt) || null;
    state.catalog = mods && Array.isArray(mods.mods) ? mods.mods : null;
  };

  const drawMain = () => {
    if (!state.list) return;
    clear(main).append(...mainPanel(state));
  };

  const drawSide = () => {
    if (state.on) {
      formSlot.replaceChildren(sidePanel({ name: 'Take down', body: takedownForms(state) }));
    } else if (state.on === false) {
      formSlot.replaceChildren(sidePanel({
        name: 'Viewing only',
        body: el('p', { class: 'td-side-note', text: managerOffText(status()) }),
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
      drawMain();
    }
    lastRunId = runId;
  }));

  load().then(() => {
    state.on = status() ? status().on : state.on;
    drawMain();
    drawSide();
  });
}

// --- The list ---

function mainPanel(state) {
  const { list, builtAt, on } = state;
  const mods = (list.mods || []).map((entry) => describeEntry(entry.id, entry, state));
  const authors = (list.authors || []).map((entry) => describeEntry(authorEntryKey(entry), entry, state));
  const returned = mods.filter((e) => e.warn === 'returned').length;
  const nothing = [...mods, ...authors].filter((e) => e.warn === 'nothing').length;

  const parts = [
    el('div', { class: 'td-head' }, [
      el('h2', { class: 'panel-heading', text: 'Takedown list' }),
      el('div', { class: 'td-counts' }, [
        countChip(mods.length, 'mod', 'mods'),
        countChip(authors.length, 'author', 'authors'),
        builtAt ? el('span', { class: 'td-built', title: builtAt, text: `Last build ${shortTime(builtAt)}` }) : null,
      ]),
    ]),
    el('p', {
      class: 'td-intro',
      text: 'These mods and all mods credited to these authors are excluded from the catalog, the mod details and Starmodder. '
        + 'The list is published with the outputs for anyone to read. It does not include reasons for removal.',
    }),
  ];

  if (state.error) parts.push(el('p', { class: 'td-banner bad', text: state.error }));

  if (returned || nothing) {
    const lines = [];
    if (returned) {
      lines.push(el('p', {}, [
        el('strong', { text: `${returned} taken-down ${returned === 1 ? 'mod is' : 'mods are'} back under a new id.` }),
        ' Take each one down again using its new id.',
      ]));
    }
    if (nothing) {
      lines.push(el('p', {}, [
        el('strong', { text: `${nothing} ${nothing === 1 ? 'entry' : 'entries'} excluded nothing from the last build.` }),
        ' Check what is written under each one.',
      ]));
    }
    lines.push(el('p', { class: 'dim', text: 'They are listed first below.' }));
    parts.push(el('div', { class: 'td-banner', role: 'note' }, lines));
  }

  if (!mods.length && !authors.length && !state.error) {
    parts.push(el('div', { class: 'note' }, [
      el('h2', { class: 'panel-heading', text: 'Nothing is taken down' }),
      el('p', {
        text: on
          ? 'Use the Take down panel to add a mod or an author.'
          : 'Takedowns are added from the viewer when the manager is on.',
      }),
    ]));
  }
  if (mods.length) parts.push(entrySection('Mods', mods, state));
  if (authors.length) parts.push(entrySection('Authors', authors, state));
  return parts;
}

function countChip(n, one, many) {
  return el('span', { class: 'chip' }, [el('b', { text: String(n) }), ` ${n === 1 ? one : many}`]);
}

function authorEntryKey(entry) {
  return `author:${(entry.names || [])[0] || ''}`;
}

/// The post a key such as `forum:34161#Useful.Tithes` belongs to.
function postOf(key) {
  const at = key.indexOf('#');
  return at < 0 ? key : key.slice(0, at);
}

/// An entry with what the last build did with it. `warn` is null, 'nothing'
/// (it left out nothing) or 'returned' (a mod entry that left out nothing
/// while one of its posts is still a source post of a catalog mod: the mod
/// most likely came back under a new id). The same rule as /api/attention.
/// `backOn` is the catalog's mods from those posts.
function describeEntry(key, entry, state) {
  const isAuthor = key.startsWith('author:');
  const match = state.matches.get(key) || null;
  const removed = match ? [...(match.mods || []), ...(match.collections || [])] : [];
  let warn = null;
  let backOn = [];
  if (match && removed.length === 0) {
    warn = 'nothing';
    if (!isAuthor && state.catalog) {
      const posts = new Set((entry.posts || []).map(postOf));
      backOn = state.catalog.filter((m) => !m.collection && (m.posts || []).some((p) => posts.has(p)));
      if (backOn.length) warn = 'returned';
    }
  }
  return { key, entry, match, warn, backOn, isAuthor };
}

/// One group of entries. Mods back under a new id come first, then the
/// entries that excluded nothing.
function entrySection(title, items, state) {
  const order = { returned: 0, nothing: 1 };
  const sorted = [...items].sort((a, b) => (order[a.warn] ?? 2) - (order[b.warn] ?? 2));
  return el('section', { class: 'td-section' }, [
    el('h2', { class: 'td-section-head' }, [
      el('span', { class: 'panel-heading', text: title }),
      el('span', { class: 'td-section-count', text: String(items.length) }),
    ]),
    el('div', { class: 'td-entries' }, sorted.map((item) => entryRow(item, state))),
  ]);
}

function entryTitle({ entry, isAuthor }) {
  return isAuthor ? (entry.names || []).join(', ') : (entry.name || entry.id);
}

/// Every name in a pending author takedown, in lower case.
function pendingAuthorNames() {
  return new Set(pendingItems()
    .filter((i) => i.correction.kind === 'takeDownAuthor')
    .flatMap((i) => i.correction.names || [])
    .map((n) => String(n).trim().toLowerCase()));
}

/// The pending item that restores `key`, or null.
function pendingRestore(key) {
  const wanted = correctionKey({ kind: 'restore', entry: key });
  return pendingItems().find((i) => correctionKey(i.correction) === wanted) || null;
}

/// One entry: what it is, what it blocks, what it excluded last time.
function entryRow(item, state) {
  const { key, entry, match, warn, isAuthor } = item;
  const restoring = isPending({ kind: 'restore', entry: key });

  const meta = el('div', { class: 'td-meta' });
  if (!isAuthor) {
    meta.append(el('code', { class: 'td-id', text: entry.id }));
    const posts = entry.posts || [];
    if (posts.length) {
      for (const post of posts) {
        const named = post.includes('#');
        meta.append(el('span', {
          class: 'td-post',
          title: named ? 'Only this mod\'s listing on the post is blocked.' : 'The whole post is blocked.',
        }, [el('code', { text: post }), named ? ' · listing' : ' · whole post']));
      }
    } else {
      meta.append(el('span', { class: 'td-post', text: 'Collection page only' }));
    }
  } else if ((entry.names || []).length > 1) {
    meta.append(el('span', { class: 'td-post', text: `${entry.names.length} names` }));
  }
  meta.append(el('span', { class: 'td-added', text: `Added ${entry.on}` }));

  const tags = [];
  if (warn === 'returned') tags.push(el('span', { class: 'tag tag-warning', text: 'Back under a new id' }));
  if (warn === 'nothing') tags.push(el('span', { class: 'tag tag-warning', text: 'Nothing excluded' }));
  if (restoring) tags.push(el('span', { class: 'tag td-tag-pending', text: 'Restore pending' }));

  let action = null;
  if (restoring) {
    action = el('button', {
      type: 'button',
      class: 'button quiet',
      text: 'Undo',
      title: 'Remove this restore from the pending changes.',
      onclick: () => {
        const pending = pendingRestore(key);
        if (pending) removePending(pending.id);
      },
    });
  } else if (state.on) {
    action = el('button', { type: 'button', class: 'button', text: 'Restore', onclick: () => confirmRestore(item) });
  }

  const mark = warn ? 'warning' : match ? 'done' : 'idle';
  return el('article', { class: `td-entry${warn ? ' is-warning' : ''}${restoring ? ' is-pending' : ''}` }, [
    statusMark(mark),
    el('div', { class: 'td-entry-main' }, [
      el('div', { class: 'td-entry-title' }, [el('h3', { text: entryTitle(item) }), ...tags]),
      meta,
      outcome(item, state),
    ]),
    action ? el('div', { class: 'td-entry-actions' }, [action]) : null,
  ]);
}

/// What the entry excluded from the last build, or why it excluded nothing.
function outcome({ entry, match, warn, backOn, isAuthor }, state) {
  if (!match) {
    return el('p', {
      class: 'td-outcome dim',
      text: state.builtAt ? 'The last build did not have this entry yet.' : 'No build has run with the takedown list yet.',
    });
  }
  if (warn === 'returned') {
    return el('div', { class: 'td-outcome' }, [
      el('p', {
        class: 'warn-text',
        text: 'This entry excluded nothing from the last build, but its post is still in the catalog. '
          + 'The mod has most likely returned under a new id. Take it down again using that id.',
      }),
      el('ul', { class: 'td-list plain' }, backOn.map((mod) => el('li', { class: 'td-back' }, [
        el('span', { class: 'td-back-name', text: mod.name }),
        el('code', { class: 'td-id', text: mod.id }),
        state.on || isPending({ kind: 'takeDownMod', modId: mod.id }) ? takeDownLink(mod.id) : null,
      ]))),
    ]);
  }
  if (warn === 'nothing') {
    let text;
    if (isAuthor) {
      text = 'This entry excluded no mods from the last build. The author may be using a new name. '
        + 'Add a new author entry with that name.';
    } else if (state.catalog) {
      text = 'This entry excluded nothing from the last build, and its post is no longer in the catalog. '
        + 'The post may be gone.';
    } else {
      text = 'This entry excluded nothing from the last build. The mod may have returned under a new id, or its post may be gone. '
        + 'If it has a new id, take it down again using that id.';
    }
    return el('p', { class: 'td-outcome warn-text', text });
  }
  // A mod entry that excluded just its own mod needs no list repeating its name.
  const onlyItself = !isAuthor && !(match.collections || []).length
    && (match.mods || []).length === 1 && match.mods[0].id === entry.id;
  if (onlyItself) {
    return el('p', { class: 'td-outcome td-done', text: 'Excluded from the last build' });
  }
  const items = [
    ...(match.mods || []).map((mod) => el('li', {}, [
      el('span', { text: mod.name }),
      mod.credit ? el('span', { class: 'dim', text: ` · credited to ${mod.credit}` }) : null,
    ])),
    ...(match.collections || []).map((c) => el('li', {}, [
      el('span', { text: c.name }), el('span', { class: 'dim', text: ' · Collection page' }),
    ])),
  ];
  return el('div', { class: 'td-outcome' }, [
    el('span', { class: 'td-label', text: `Excluded from the last build (${items.length})` }),
    el('ul', { class: 'td-list' }, items),
  ]);
}

/// A small "Take down" button for one catalog mod, beside a warning.
function takeDownLink(modId) {
  if (isPending({ kind: 'takeDownMod', modId })) {
    return el('span', { class: 'tag td-tag-pending', text: 'Take-down pending' });
  }
  return el('button', {
    type: 'button',
    class: 'button danger td-small',
    text: 'Take down',
    onclick: () => previewAndAdd({ modId }),
  });
}

// --- Labels for pending changes ---

/// `"A"`, `"A" and "B"`, or `"A", "B" and "C"`.
function quoted(names) {
  const q = names.map((n) => `"${n}"`);
  return q.length <= 1 ? q.join('') : `${q.slice(0, -1).join(', ')} and ${q[q.length - 1]}`;
}

function takeDownLabel(preview) {
  if (preview.kind !== 'mod') return `Take down all mods by ${quoted(preview.names)}`;
  return preview.isCollection
    ? `Take down the Collection page "${preview.name}"`
    : `Take down "${preview.name}"`;
}

function restoreLabel({ entry, isAuthor }) {
  return isAuthor
    ? `Restore all mods by ${quoted(entry.names || [])}`
    : `Restore "${entry.name || entry.id}"`;
}

// --- Restore ---

async function confirmRestore(item) {
  const { key, entry, match, isAuthor } = item;
  const rows = [
    ...((match && match.mods) || []).map((mod) => dialogRow(mod.name, el('code', { class: 'td-id', text: mod.id }))),
    ...((match && match.collections) || []).map((c) => dialogRow(c.name, el('span', { class: 'dim', text: 'Collection page' }))),
  ];
  const restoreText = 'The entry is removed from the takedown list. Everything it hid comes back at its old address.';
  const count = backCount(match);
  const body = [count ? summary(count, restoreText) : el('p', { text: restoreText })];
  if (rows.length) body.push(section('Coming back (from the last build)', el('div', { class: 'td-rows scroll' }, rows)));
  const yes = await confirmDialog({
    eyebrow: isAuthor ? 'Restore an author\'s mods' : 'Restore a mod',
    title: entryTitle(item),
    body,
    confirmLabel: 'Restore',
  });
  if (!yes) return;
  addPending({
    kind: 'restore',
    label: restoreLabel(item),
    correction: { kind: 'restore', entry: key },
  });
}

/// "4 mods", "1 page" or "4 mods, 1 page": what a restore brings back. Empty
/// when the last build has no record of the entry.
function backCount(match) {
  const mods = ((match && match.mods) || []).length;
  const pages = ((match && match.collections) || []).length;
  return [
    mods ? `${mods} mod${mods === 1 ? '' : 's'}` : '',
    pages ? `${pages} page${pages === 1 ? '' : 's'}` : '',
  ].filter(Boolean).join(', ');
}

// --- The Take down forms ---

/// Two tabs: one for a mod or Collection page, one for an author's mods.
function takedownForms(state) {
  const tabs = [
    { label: 'A mod', body: modForm(state) },
    { label: 'An author', body: authorForm(state) },
  ];
  const bar = el('div', { class: 'td-tabs', role: 'tablist' });
  const holder = el('div', { class: 'td-tab-body' });
  const show = (i, focus) => {
    [...bar.children].forEach((tab, n) => {
      tab.classList.toggle('on', n === i);
      tab.setAttribute('aria-selected', String(n === i));
    });
    holder.replaceChildren(tabs[i].body);
    const field = tabs[i].body.querySelector('input');
    if (focus && field) field.focus();
  };
  tabs.forEach((tab, i) => bar.append(el('button', {
    type: 'button', role: 'tab', class: 'tab', text: tab.label, onclick: () => show(i, true),
  })));
  show(0, false);
  return el('div', { class: 'td-forms' }, [bar, holder]);
}

/// The post a pasted forum or Discord link (or a `forum:123` key) points at,
/// as a post key, or null.
function postKeyOf(text) {
  const t = text.trim();
  const key = t.match(/^(forum|discord|nexus):(\d+)$/i);
  if (key) return `${key[1].toLowerCase()}:${key[2]}`;
  const topic = t.match(/[?&;]topic=(\d+)/);
  if (topic) return `forum:${topic[1]}`;
  const thread = t.match(/\/channels\/\d+\/(\d+)/);
  if (thread) return `discord:${thread[1]}`;
  const nexus = t.match(/nexusmods\.com\/starsector\/mods\/(\d+)/);
  if (nexus) return `nexus:${nexus[1]}`;
  return null;
}

/// A text box with a list of suggestions under it, worked with the arrow
/// keys, Enter and Escape. `find(text)` returns `{ items, more, empty }`;
/// `row(item)` draws one suggestion; `usable(item)` says whether it can be
/// picked; `pick(item)` is called with the chosen one. `onEnter(text)` is
/// called when Enter is pressed with no suggestion chosen.
function comboBox({ id, label, placeholder, find, row, usable, pick, onEnter = null }) {
  const input = el('input', {
    type: 'text', class: 'input td-input', autocomplete: 'off', spellcheck: 'false',
    placeholder,
    role: 'combobox', 'aria-label': label, 'aria-autocomplete': 'list',
    'aria-controls': id, 'aria-expanded': 'false',
  });
  const list = el('ul', { class: 'td-suggestions', id, role: 'listbox', hidden: true });
  const note = el('p', { class: 'td-hint warn-text', hidden: true });
  let shown = [];
  let active = -1;

  const hide = () => {
    list.hidden = true;
    input.setAttribute('aria-expanded', 'false');
    input.removeAttribute('aria-activedescendant');
    shown = [];
    active = -1;
  };
  const highlight = (i) => {
    active = i;
    [...list.children].forEach((li, n) => li.classList.toggle('on', n === i));
    if (i >= 0) input.setAttribute('aria-activedescendant', `${id}-${i}`);
    else input.removeAttribute('aria-activedescendant');
  };
  const choose = (item) => {
    if (!usable(item)) return;
    hide();
    pick(item);
  };
  const suggest = () => {
    note.hidden = true;
    const text = input.value.trim();
    if (!text) return hide();
    const found = find(text);
    shown = found.items.slice(0, SUGGESTION_COUNT);
    clear(list);
    if (!shown.length) {
      hide();
      if (found.empty) {
        note.textContent = found.empty;
        note.hidden = false;
      }
      return;
    }
    shown.forEach((item, i) => {
      const ok = usable(item);
      const li = el('li', {
        id: `${id}-${i}`, role: 'option',
        class: `td-suggestion${ok ? '' : ' disabled'}`,
        'aria-disabled': ok ? null : 'true',
      }, row(item));
      // Select before the input loses focus and hides the suggestions.
      li.addEventListener('mousedown', (e) => { e.preventDefault(); choose(item); });
      list.append(li);
    });
    const more = found.items.length - shown.length;
    if (more > 0) {
      list.append(el('li', {
        class: 'td-suggestion-more', role: 'presentation',
        text: `${more} more. Keep typing to narrow it down.`,
      }));
    }
    list.hidden = false;
    input.setAttribute('aria-expanded', 'true');
    highlight(shown.findIndex(usable));
  };

  input.addEventListener('input', suggest);
  input.addEventListener('focus', () => { if (input.value.trim()) suggest(); });
  input.addEventListener('blur', hide);
  input.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowDown' && shown.length) {
      e.preventDefault();
      highlight((active + 1) % shown.length);
    } else if (e.key === 'ArrowUp' && shown.length) {
      e.preventDefault();
      highlight((active - 1 + shown.length) % shown.length);
    } else if (e.key === 'Enter') {
      if (active >= 0 && shown[active]) {
        e.preventDefault();
        choose(shown[active]);
      } else if (onEnter) {
        onEnter(e);
      } else {
        e.preventDefault();
      }
    } else if (e.key === 'Escape' && !list.hidden) {
      e.preventDefault();
      hide();
    }
  });

  return { input, suggest, hide, root: el('div', { class: 'td-combo' }, [input, list]), note };
}

/// The form for taking down one mod or Collection page. Typing finds mods by
/// name, id or author; a pasted thread link lists that thread's mods.
function modForm(state) {
  const takenDown = () => new Set((state.list.mods || []).map((m) => m.id));
  const pendingNow = (mod) => isPending({ kind: 'takeDownMod', modId: mod.id });

  const box = comboBox({
    id: 'td-mod-suggestions',
    label: 'Mod to take down',
    placeholder: 'Mod name, id, author, or a thread link',
    find(text) {
      const known = state.catalog || [];
      const q = text.toLowerCase();
      const post = postKeyOf(text);
      let items;
      if (post) {
        items = known.filter((m) => (m.posts || []).includes(post));
      } else {
        const ranked = [];
        for (const mod of known) {
          const name = mod.name.toLowerCase();
          const id = mod.id.toLowerCase();
          let rank = -1;
          if (name.startsWith(q) || id.startsWith(q)) rank = 0;
          else if (name.includes(q) || id.includes(q)) rank = 1;
          else if ((mod.authors || []).some((a) => a.toLowerCase().includes(q))) rank = 2;
          if (rank >= 0) ranked.push([rank, mod]);
        }
        ranked.sort((a, b) => a[0] - b[0] || a[1].name.localeCompare(b[1].name));
        items = ranked.map(([, mod]) => mod);
      }
      const empty = !state.catalog
        ? 'The catalog could not be read. Build the catalog first.'
        : post ? `No mod in the catalog comes from ${post}.` : 'No mod or Collection page in the catalog matches.';
      return { items, empty };
    },
    usable: (mod) => !takenDown().has(mod.id) && !pendingNow(mod),
    row(mod) {
      const authors = mod.authors || [];
      return [
        el('span', { class: 'td-suggestion-name' }, [
          mod.name,
          el('span', { class: 'td-suggestion-others', text: mod.id }),
        ]),
        el('span', {
          class: 'td-suggestion-count',
          text: takenDown().has(mod.id)
            ? 'already taken down'
            : pendingNow(mod)
              ? 'takedown pending'
              : mod.collection
                ? 'Collection page'
                : authors.slice(0, 2).join(', ') + (authors.length > 2 ? ` +${authors.length - 2}` : ''),
        }),
      ];
    },
    pick(mod) {
      box.input.value = '';
      previewAndAdd({ modId: mod.id });
    },
  });

  return el('div', { class: 'td-form' }, [
    el('p', {
      class: 'td-hint',
      text: 'Excludes one mod, and blocks only the posts it comes from. Other mods on a shared post stay published. '
        + 'A Collection page can be taken down too; the mods it lists stay published.',
    }),
    box.root,
    box.note,
    el('p', {
      class: 'td-hint',
      text: 'Pick a mod to see exactly what would be removed. Nothing changes until you confirm.',
    }),
  ]);
}

/// The form for taking down every mod credited to one person. Names are added
/// as chips; typing suggests the names credited in the current catalog.
function authorForm(state) {
  const names = [];
  const takenDown = () => new Set((state.list.authors || []).flatMap((a) => a.names || []).map((n) => n.toLowerCase()));
  let known = [];
  api('takedowns/authors').then((body) => {
    if (body && Array.isArray(body.authors)) known = body.authors;
  }).catch(() => {});

  const chips = el('div', { class: 'td-chips' });
  const preview = el('button', { type: 'submit', class: 'button primary', text: 'Preview', disabled: true });

  const add = (name) => {
    const clean = name.trim();
    if (clean && !names.some((n) => n.toLowerCase() === clean.toLowerCase())) names.push(clean);
    box.input.value = '';
    box.hide();
    drawChips();
    box.input.focus();
  };

  const box = comboBox({
    id: 'td-author-suggestions',
    label: 'Author names',
    placeholder: 'Type an author name',
    find(text) {
      const q = text.toLowerCase();
      const picked = new Set(names.map((n) => n.toLowerCase()));
      const starts = [];
      const inside = [];
      for (const author of known) {
        const spellings = [author.name, ...(author.others || [])].map((n) => n.toLowerCase());
        if (spellings.some((n) => picked.has(n))) continue;
        if (spellings.some((n) => n.startsWith(q))) starts.push(author);
        else if (spellings.some((n) => n.includes(q))) inside.push(author);
      }
      return { items: [...starts, ...inside] };
    },
    usable: () => true,
    row(author) {
      const others = author.others || [];
      const gone = takenDown();
      const already = [author.name, ...others].some((n) => gone.has(n.toLowerCase()));
      const pendingNames = pendingAuthorNames();
      const pending = [author.name, ...others].some((n) => pendingNames.has(n.toLowerCase()));
      return [
        el('span', { class: 'td-suggestion-name' }, [
          author.name,
          // A takedown matches these spellings too, so they are not separate choices.
          others.length ? el('span', { class: 'td-suggestion-others', text: `also ${others.join(', ')}` }) : null,
        ]),
        el('span', {
          class: 'td-suggestion-count',
          text: already
            ? 'already taken down'
            : pending
              ? 'takedown pending'
              : `${author.mods} mod${author.mods === 1 ? '' : 's'}`,
        }),
      ];
    },
    pick: (author) => add(author.name),
    // Enter with no suggestion chosen adds the typed name; with an empty box
    // it submits the form.
    onEnter(e) {
      if (box.input.value.trim()) {
        e.preventDefault();
        add(box.input.value);
      }
    },
  });

  const drawChips = () => {
    clear(chips);
    for (const name of names) {
      chips.append(el('span', { class: 'td-chip' }, [
        el('span', { text: name }),
        el('button', {
          type: 'button', class: 'td-chip-remove', 'aria-label': `Remove ${name}`, text: '×',
          onclick: () => { names.splice(names.indexOf(name), 1); drawChips(); box.input.focus(); },
        }),
      ]));
    }
    chips.hidden = names.length === 0;
    preview.disabled = names.length === 0;
    box.input.placeholder = names.length ? 'Add another name' : 'Type an author name';
  };

  box.input.addEventListener('input', () => {
    // A comma ends a name, for anyone pasting a list.
    if (box.input.value.includes(',')) {
      const parts = box.input.value.split(',');
      const rest = parts.pop();
      for (const part of parts) if (part.trim()) add(part);
      box.input.value = rest;
      box.suggest();
    }
  });
  box.input.addEventListener('keydown', (e) => {
    if (e.key === 'Backspace' && !box.input.value && names.length) {
      names.pop();
      drawChips();
    }
  });
  drawChips();

  const form = el('form', { class: 'td-form' }, [
    el('p', {
      class: 'td-hint',
      text: 'Excludes every mod that credits this person, including mods added later and mods made with others. '
        + 'Names are matched using the same rules as author names in the merge.',
    }),
    chips,
    el('div', { class: 'td-form-row' }, [box.root, preview]),
    box.note,
    el('p', { class: 'td-hint', text: 'Press Enter to add a name. Add every name the person goes by.' }),
  ]);
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (box.input.value.trim()) add(box.input.value);
    if (!names.length) return;
    const added = await previewAndAdd({ authors: [...names] });
    if (added) {
      names.length = 0;
      drawChips();
    }
  });
  return form;
}

// --- Preview, then add a pending change ---

/// Shows what a takedown would leave out, then adds it to the pending changes
/// if confirmed. Resolves true when it was added. The source post page uses
/// it too.
export async function previewAndAdd({ modId = null, authors = [] }) {
  const correction = modId
    ? { kind: 'takeDownMod', modId }
    : { kind: 'takeDownAuthor', names: authors };
  if (isPending(correction)) {
    await noticeDialog('Already pending', 'This takedown is already in the pending changes.');
    return false;
  }
  const alreadyPending = authors.filter((name) => pendingAuthorNames().has(name.trim().toLowerCase()));
  if (alreadyPending.length) {
    await noticeDialog('Already pending', `Already pending: ${alreadyPending.join(', ')}.`);
    return false;
  }

  const params = new URLSearchParams();
  if (modId) params.set('mod', modId);
  for (const name of authors) params.append('author', name);
  let preview;
  try {
    const res = await fetch(`/api/takedowns/preview?${params}`, { headers: { accept: 'application/json' } });
    preview = await res.json().catch(() => null);
    if (!preview) throw new Error(`Server returned ${res.status} ${res.statusText}.`);
  } catch (err) {
    await noticeDialog('Could not preview the takedown', err.message);
    return false;
  }
  if (preview.error) {
    await noticeDialog('Could not preview the takedown', preview.error);
    return false;
  }

  const isMod = preview.kind === 'mod';
  if (isMod && preview.alreadyTakenDown) {
    await noticeDialog('Already taken down', `"${preview.id}" is already on the takedown list.`);
    return false;
  }
  if (!isMod && (preview.alreadyTakenDown || []).length) {
    await noticeDialog('Already taken down', `${preview.alreadyTakenDown.join(', ')} is already on the takedown list.`);
    return false;
  }

  const modCount = isMod ? (preview.isCollection ? 0 : 1) : (preview.mods || []).length;
  const yes = await confirmDialog({
    eyebrow: isMod ? (preview.isCollection ? 'Take down a Collection page' : 'Take down a mod') : 'Take down an author\'s mods',
    title: isMod ? preview.name : preview.names.join(', '),
    body: isMod ? modPreview(preview) : authorPreview(preview),
    confirmLabel: isMod
      ? (preview.isCollection ? 'Take down page' : 'Take down mod')
      : `Take down ${modCount} mod${modCount === 1 ? '' : 's'}`,
    danger: true,
    publicNote: true,
  });
  if (!yes) return false;
  addPending({
    kind: correction.kind,
    label: takeDownLabel(preview),
    correction: isMod ? { kind: 'takeDownMod', modId: preview.id } : { kind: 'takeDownAuthor', names: preview.names },
  });
  return true;
}

function modPreview(preview) {
  if (preview.isCollection) {
    return [
      summary('1 page', 'The Collection page is removed. The mods it lists stay published.'),
      el('p', {
        class: 'td-dialog-note',
        text: 'To remove those mods too, take each one down, or take down all mods credited to their author.',
      }),
      appliesTo({ modRepo: 'skip' }),
    ];
  }

  const posts = preview.posts || [];
  const parts = [
    summary('1 mod', 'Hidden from the catalog, the mod details and Starmodder.', preview.id),
    section(`Blocked posts (${posts.length})`, el('div', { class: 'td-rows' }, posts.map((post) => dialogRow(
      el('code', { text: post.key }),
      el('span', {
        class: `td-pill${post.whole ? '' : ' info'}`,
        text: post.whole ? 'Whole post' : 'This listing only',
      }),
      post.whole ? 'No other mod comes from this post.' : 'Other mods come from this post. They stay published.',
    )))),
  ];
  const also = alsoAffected(preview.collections, (c) => `${c.name}: loses this mod, ${c.modsLeft} left`, preview.oldIds);
  if (also) parts.push(also);
  const partial = (preview.notInModRepo || []).length > 0;
  parts.push(appliesTo({ modRepo: partial ? 'partial' : 'yes' }));
  if (partial) {
    parts.push(el('p', {
      class: 'td-dialog-note warn-text',
      text: `ModRepo.json cannot leave out one mod of several on a shared post (${preview.notInModRepo.join(', ')}). `
        + 'TriOS may keep listing this mod until the switch to mod-catalog.json.',
    }));
  }
  return parts;
}

function authorPreview(preview) {
  const mods = preview.mods || [];
  const typed = new Set(preview.names.map((n) => n.toLowerCase()));
  const parts = [];
  if (!mods.length) {
    parts.push(summary('0 mods', 'No mod in the current catalog credits this person. '
      + 'The entry still hides any mod that credits them later.'));
  } else {
    parts.push(summary(
      `${mods.length} mod${mods.length === 1 ? '' : 's'}`,
      'Hidden from the catalog, the mod details and Starmodder, plus any mod that credits this person later.',
    ));
    const loose = mods.filter((mod) => !typed.has(String(mod.credit).toLowerCase())).length;
    parts.push(section(`Mods (${mods.length})`, el('div', { class: 'td-rows scroll' }, mods.map((mod) => {
      const exact = typed.has(String(mod.credit).toLowerCase());
      return dialogRow(
        mod.name,
        el('span', {
          class: `td-pill${exact ? '' : ' check'}`,
          title: exact ? 'Credited under a name you entered.' : 'Credited under another spelling. Check this is the same person.',
          text: mod.credit,
        }),
        null,
        mod.id,
      );
    }))));
    if (loose) {
      parts.push(el('p', {
        class: 'td-dialog-note warn-text',
        text: `${loose} matched under another spelling (marked). Names that differ only in capitals, punctuation `
          + 'or digits on the end count as the same person. Check each one.',
      }));
    }
  }
  const also = alsoAffected(preview.collections, (c) => `${c.name}: ${c.modsLeft} mods left`);
  if (also) parts.push(also);
  parts.push(appliesTo({ modRepo: 'yes' }));
  return parts;
}

// --- Dialog parts ---

/// One row in a dialog list: a name (text or node), something on the right,
/// and an optional line under the name or id beside it.
function dialogRow(name, right, sub = null, id = null) {
  return el('div', { class: 'td-row' }, [
    el('span', { class: 'td-row-text' }, [
      typeof name === 'string' ? el('span', { class: 'td-row-name', text: name }) : name,
      id ? el('code', { class: 'td-id', text: id }) : null,
      sub ? el('span', { class: 'td-row-sub', text: sub }) : null,
    ]),
    right,
  ]);
}

/// The count in large type, with one line saying what happens to it.
function summary(count, text, id = null) {
  return el('div', { class: 'td-summary' }, [
    el('span', { class: 'td-summary-count', text: count }),
    el('span', { class: 'td-summary-text' }, [text, id ? el('code', { class: 'td-id', text: id }) : null]),
  ]);
}

function section(label, content) {
  return el('div', { class: 'td-dialog-section' }, [el('div', { class: 'td-label', text: label }), content]);
}

/// Collections and old addresses also affected by the takedown, or null.
function alsoAffected(collections = [], describe, oldIds = []) {
  const rows = [
    ...collections.map((c) => el('li', { text: describe(c) })),
    ...oldIds.map((id) => el('li', {}, ['Old address ', el('code', { text: id }), ' stops working'])),
  ];
  if (!rows.length) return null;
  return section('Also affected', el('ul', { class: 'td-list' }, rows));
}

/// Which outputs the takedown affects. `modRepo` is 'yes', 'partial' or 'skip'.
function appliesTo({ modRepo }) {
  const item = (label, state, note) => el('li', { class: `td-applies-${state}`, title: note || null }, [
    el('span', { class: 'td-applies-mark', 'aria-hidden': 'true', text: state === 'yes' ? '✓' : state === 'partial' ? '!' : '–' }),
    label,
  ]);
  return section('Applies to', el('ul', { class: 'td-applies' }, [
    item('Catalog', 'yes'),
    item('Mod details', 'yes'),
    item('Starmodder', 'yes'),
    modRepo === 'skip'
      ? item('ModRepo.json (TriOS)', 'skip', 'ModRepo.json has no Collection pages.')
      : item('ModRepo.json (TriOS)', modRepo, modRepo === 'partial' ? 'Not for a listing on a shared post.' : ''),
  ]));
}

/// A confirm dialog for a takedown or a restore. Resolves true on confirm.
/// For a takedown, Cancel has the focus, so Enter never takes anything down
/// by accident.
function confirmDialog({ eyebrow, title, body, confirmLabel, danger = false, publicNote = false }) {
  return new Promise((resolve) => {
    const yes = el('button', { type: 'button', class: danger ? 'button danger' : 'button primary', text: confirmLabel });
    const no = el('button', { type: 'button', class: 'button', text: 'Cancel' });
    const box = el('dialog', { class: 'dialog td-dialog' }, [
      el('div', { class: 'td-eyebrow', text: eyebrow }),
      el('h2', { text: title }),
      el('div', { class: 'td-dialog-body' }, body),
      publicNote ? el('p', {
        class: 'td-dialog-note dim',
        text: 'This entry will appear in the public takedown list, which is published with the outputs. It has no reason in it.',
      }) : null,
      el('p', {
        class: 'td-dialog-note td-pending-note',
        text: 'This is added to the pending changes. Nothing is written until you save them.',
      }),
      el('div', { class: 'dialog-buttons' }, [no, yes]),
    ]);
    const shut = showDialog(box, (value) => resolve(value === true));
    yes.addEventListener('click', () => shut(true));
    no.addEventListener('click', () => shut(false));
    (danger ? no : yes).focus();
  });
}
