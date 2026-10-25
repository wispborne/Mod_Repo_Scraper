// #/takedowns — the takedown list: mods and people left out of everything we
// publish, at their request. The page and the preview only read; every change
// is a manager job, so it waits in the queue and shows in the run history.

import {
  api, el, clear, missingPanel, MissingFile, breadcrumbs, go, noticeDialog,
} from '../lib.js';
import * as manager from '../manager.js';


export async function render(root) {
  clear(root);
  root.append(breadcrumbs([{ label: 'Takedowns' }]));

  const body = await api('takedowns');
  if (body instanceof MissingFile) {
    root.append(el('h1', { text: 'Takedowns' }));
    return root.append(missingPanel(body));
  }
  if (body.error) {
    root.append(el('h1', { text: 'Takedowns' }));
    return root.append(el('div', { class: 'missing error' }, [el('h3', { text: body.error })]));
  }

  const status = manager.status() || await manager.refresh();
  const managerOn = !!(status && status.on);
  const list = body.list || { mods: [], authors: [] };
  const matches = new Map(((body.matches && body.matches.matches) || []).map((m) => [m.entry, m]));
  const builtAt = body.matches && body.matches.builtAt;

  const mods = (list.mods || []).map((entry) => describeEntry(entry.id, entry, matches));
  const authors = (list.authors || []).map((entry) => describeEntry(authorEntryKey(entry), entry, matches));
  const warnings = [...mods, ...authors].filter((e) => e.warn).length;

  root.append(el('div', { class: 'takedown-header' }, [
    el('h1', { text: 'Takedowns' }),
    el('div', { class: 'takedown-counts' }, [
      countChip(mods.length, 'mod', 'mods'),
      countChip(authors.length, 'author', 'authors'),
      builtAt ? el('span', { class: 'takedown-built', text: `Last build ${formatWhen(builtAt)}` }) : null,
    ]),
  ]));

  const page = el('div', { class: 'stack' });
  page.append(el('p', {
    class: 'takedown-intro',
    text: 'These mods and all mods credited to these authors are excluded from the catalog, the mod details and Starmodder. '
      + 'The list is published with the outputs for anyone to read. It does not include reasons for removal.',
  }));

  if (warnings) {
    page.append(el('div', { class: 'notice-banner' }, [
      el('div', { class: 'notice-text' }, [
        el('strong', { text: `${warnings} ${warnings === 1 ? 'entry' : 'entries'} excluded nothing from the last build` }),
        el('div', { text: 'They are listed first below, with what to check.' }),
      ]),
    ]));
  }

  if (managerOn) page.append(takedownCard(list));

  if (!mods.length && !authors.length) {
    page.append(el('div', { class: 'takedown-empty' }, [
      el('h3', { text: 'Nothing is taken down' }),
      el('p', {
        text: managerOn
          ? 'Use the Take down box above, or the "Take down" button on a Mod Catalog or thread page.'
          : 'Takedowns are added from the viewer when the manager is on.',
      }),
    ]));
  }
  if (mods.length) page.append(entrySection('Mods', mods, builtAt, managerOn));
  if (authors.length) page.append(entrySection('Authors', authors, builtAt, managerOn));
  root.append(page);
}

function countChip(n, one, many) {
  return el('span', { class: 'takedown-count' }, [el('strong', { text: String(n) }), ` ${n === 1 ? one : many}`]);
}

function formatWhen(iso) {
  const when = new Date(iso);
  return Number.isNaN(when.getTime()) ? iso : when.toLocaleString();
}

function authorEntryKey(entry) {
  return `author:${(entry.names || [])[0] || ''}`;
}

/// An entry with what the last build did with it.
function describeEntry(key, entry, matches) {
  const match = matches.get(key);
  const removed = match ? [...(match.mods || []), ...(match.collections || [])] : [];
  return { key, entry, match, warn: !!match && removed.length === 0, isAuthor: key.startsWith('author:') };
}

/// One group of entries. The ones that excluded nothing come first.
function entrySection(title, items, builtAt, managerOn) {
  const sorted = [...items].sort((a, b) => Number(b.warn) - Number(a.warn));
  return el('section', { class: 'takedown-section' }, [
    el('h2', {}, [title, el('span', { class: 'takedown-section-count', text: String(items.length) })]),
    el('div', { class: 'takedown-list' }, sorted.map((item) => entryRow(item, builtAt, managerOn))),
  ]);
}

/// One entry as a row: what it is, what it blocks, what it excluded last time.
function entryRow({ key, entry, match, warn, isAuthor }, builtAt, managerOn) {
  const title = isAuthor ? (entry.names || []).join(', ') : (entry.name || entry.id);

  const meta = el('div', { class: 'takedown-meta' });
  if (!isAuthor) {
    meta.append(el('code', { class: 'takedown-id', text: entry.id }));
    const posts = entry.posts || [];
    if (posts.length) {
      for (const post of posts) {
        const named = post.includes('#');
        meta.append(el('span', {
          class: 'takedown-post',
          title: named ? 'Only this mod\'s listing on the post is blocked.' : 'The whole post is blocked.',
        }, [el('code', { text: post }), named ? ' · listing' : ' · whole post']));
      }
    } else {
      meta.append(el('span', { class: 'takedown-post', text: 'Collection page only' }));
    }
  } else if ((entry.names || []).length > 1) {
    meta.append(el('span', { class: 'takedown-post', text: `${entry.names.length} names` }));
  }
  meta.append(el('span', { class: 'takedown-added', text: `Added ${entry.on}` }));

  const row = el('article', { class: `takedown-row${warn ? ' is-warning' : ''}` }, [
    el('div', { class: 'takedown-row-main' }, [
      el('div', { class: 'takedown-row-title' }, [
        el('h3', { text: title }),
        warn ? el('span', { class: 'badge badge-warning', text: 'Nothing excluded' }) : null,
      ]),
      meta,
      outcome({ entry, match, warn, isAuthor }, builtAt),
    ]),
    managerOn
      ? el('div', { class: 'takedown-row-actions' }, [
        el('button', { class: 'btn', text: 'Restore', onclick: () => confirmRestore(key, entry, match) }),
      ])
      : null,
  ]);
  return row;
}

/// What the entry excluded from the last build, or why nothing.
function outcome({ entry, match, warn, isAuthor }, builtAt) {
  if (!match) {
    return el('p', {
      class: 'takedown-outcome dim',
      text: builtAt ? 'The last build did not have this entry yet.' : 'No build has run with the takedown list yet.',
    });
  }
  if (warn) {
    return el('p', {
      class: 'takedown-outcome takedown-warning-text',
      text: isAuthor
        ? 'This entry excluded no mods from the last build. The author may be using a new name. Add a new author entry with that name.'
        : 'This entry excluded nothing from the last build. The mod may have returned under a new id, or its post may be gone. '
          + 'If it has a new id, take it down again using that id.',
    });
  }
  // A mod entry that excluded just its own mod needs no list repeating its name.
  const onlyItself = !isAuthor && !(match.collections || []).length
    && (match.mods || []).length === 1 && match.mods[0].id === entry.id;
  if (onlyItself) {
    return el('p', { class: 'takedown-outcome takedown-done', text: '✓ Excluded from the last build' });
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
  return el('div', { class: 'takedown-outcome' }, [
    el('span', { class: 'takedown-outcome-label', text: `Excluded from the last build (${items.length})` }),
    el('ul', { class: 'takedown-excluded' }, items),
  ]);
}

async function confirmRestore(key, entry, match) {
  const isAuthor = key.startsWith('author:');
  const name = isAuthor ? (entry.names || []).join(', ') : (entry.name || entry.id);
  const back = [
    ...((match && match.mods) || []).map((mod) => el('div', { class: 'td-row' }, [
      el('span', { class: 'td-row-text' }, [
        el('span', { class: 'td-row-name', text: mod.name }),
        el('code', { class: 'td-row-id', text: mod.id }),
      ]),
    ])),
    ...((match && match.collections) || []).map((c) => el('div', { class: 'td-row' }, [
      el('span', { class: 'td-row-text' }, [
        el('span', { class: 'td-row-name', text: c.name }),
        el('span', { class: 'td-row-sub', text: 'Collection page' }),
      ]),
    ])),
  ];
  const restoreText = 'The entry is removed from the takedown list. Everything it hid comes back at its old address.';
  const count = backCount(match);
  // With no count from the last build, the sentence stands on its own.
  const body = [count ? summary(count, restoreText) : el('p', { class: 'td-note', text: restoreText })];
  if (back.length) body.push(section('Coming back (from the last build)', el('div', { class: 'td-rows td-rows-scroll' }, back)));
  body.push(el('p', {
    class: 'td-note',
    text: 'Every output is rebuilt from saved files. No pages are fetched. The LLM is not called.',
  }));
  const answer = await takedownDialog({
    eyebrow: isAuthor ? 'Restore an author\'s mods' : 'Restore a mod',
    title: name,
    body,
    confirmLabel: 'Restore',
  });
  if (!answer) return;
  await send({ kind: 'restoreTakedown', takedownEntry: key, publishAfter: answer.publishAfter, collectMergeDebug: true });
}

/// "4 mods", "1 page" or "4 mods, 1 page": what a restore brings back. Empty when the
/// last build has no record of the entry.
function backCount(match) {
  const mods = ((match && match.mods) || []).length;
  const pages = ((match && match.collections) || []).length;
  return [
    mods ? `${mods} mod${mods === 1 ? '' : 's'}` : '',
    pages ? `${pages} page${pages === 1 ? '' : 's'}` : '',
  ].filter(Boolean).join(', ');
}

/// The "Take down" card: one tab for a mod or Collection page, one for an
/// author's mods.
function takedownCard(list) {
  const tabs = [
    { label: 'A mod or Collection page', body: modForm(list) },
    { label: 'An author\'s mods', body: authorForm(list) },
  ];
  const bar = el('div', { class: 'takedown-tabs', role: 'tablist' });
  const holder = el('div', { class: 'takedown-tab-holder' });
  const show = (i) => {
    [...bar.children].forEach((tab, n) => {
      tab.classList.toggle('active', n === i);
      tab.setAttribute('aria-selected', String(n === i));
    });
    holder.replaceChildren(tabs[i].body);
    const field = tabs[i].body.querySelector('input');
    if (field) field.focus();
  };
  tabs.forEach((tab, i) => bar.append(el('button', {
    type: 'button', role: 'tab', class: 'takedown-tab', text: tab.label, onclick: () => show(i),
  })));
  const card = el('div', { class: 'panel takedown-form' }, [el('h3', { text: 'Take down' }), bar, holder]);
  [...bar.children].forEach((tab, n) => {
    tab.classList.toggle('active', n === 0);
    tab.setAttribute('aria-selected', String(n === 0));
  });
  holder.append(tabs[0].body);
  return card;
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

/// The form for taking down one mod or Collection page. Typing finds mods by
/// name, id or author; a pasted thread link lists that thread's mods.
function modForm(list) {
  const takenDown = new Set((list.mods || []).map((m) => m.id));
  let known = [];
  api('takedowns/mods').then((body) => {
    if (body && Array.isArray(body.mods)) known = body.mods;
  }).catch(() => {});

  const input = el('input', {
    type: 'text', class: 'takedown-names', autocomplete: 'off',
    placeholder: 'Mod name, id, author, or a thread link',
    role: 'combobox', 'aria-label': 'Mod to take down', 'aria-autocomplete': 'list',
    'aria-controls': 'takedown-mod-suggestions', 'aria-expanded': 'false',
  });
  const box = el('div', { class: 'takedown-name-box' }, [input]);
  const suggestions = el('ul', {
    class: 'takedown-suggestions', id: 'takedown-mod-suggestions', role: 'listbox', hidden: '',
  });
  const empty = el('p', { class: 'takedown-form-hint takedown-no-match', hidden: '' });
  let shown = [];
  let active = -1;

  const hide = () => {
    suggestions.hidden = true;
    input.setAttribute('aria-expanded', 'false');
    shown = [];
    active = -1;
  };

  const highlight = (i) => {
    active = i;
    [...suggestions.children].forEach((li, n) => li.classList.toggle('active', n === i));
    if (i >= 0) input.setAttribute('aria-activedescendant', `takedown-mod-suggestion-${i}`);
    else input.removeAttribute('aria-activedescendant');
  };

  const pick = async (mod) => {
    if (takenDown.has(mod.id)) return;
    hide();
    input.value = '';
    await previewAndConfirm({ modId: mod.id });
  };

  const suggest = () => {
    const text = input.value.trim();
    const q = text.toLowerCase();
    empty.hidden = true;
    if (!q) return hide();
    const post = postKeyOf(text);
    let found;
    if (post) {
      found = known.filter((m) => (m.posts || []).includes(post));
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
      found = ranked.map(([, mod]) => mod);
    }
    shown = found.slice(0, SUGGESTION_COUNT);
    clear(suggestions);
    if (!shown.length) {
      hide();
      empty.textContent = post
        ? `No mod in the catalog comes from ${post}.`
        : 'No mod or Collection page in the catalog matches.';
      empty.hidden = false;
      return;
    }
    shown.forEach((mod, i) => {
      const already = takenDown.has(mod.id);
      const authors = mod.authors || [];
      const li = el('li', {
        id: `takedown-mod-suggestion-${i}`, role: 'option',
        class: `takedown-suggestion${already ? ' is-disabled' : ''}`,
        'aria-disabled': already ? 'true' : null,
      }, [
        el('span', { class: 'takedown-suggestion-name' }, [
          mod.name,
          el('span', { class: 'takedown-suggestion-others', text: mod.id }),
        ]),
        el('span', {
          class: 'takedown-suggestion-count',
          text: already
            ? 'already taken down'
            : mod.collection
              ? 'Collection page'
              : authors.slice(0, 2).join(', ') + (authors.length > 2 ? ` +${authors.length - 2}` : ''),
        }),
      ]);
      // Before the input loses focus, so the pick is not lost to the blur.
      li.addEventListener('mousedown', (e) => { e.preventDefault(); pick(mod); });
      suggestions.append(li);
    });
    if (found.length > shown.length) {
      suggestions.append(el('li', {
        class: 'takedown-suggestion-more', role: 'presentation',
        text: `${found.length - shown.length} more. Keep typing to narrow it down.`,
      }));
    }
    suggestions.hidden = false;
    input.setAttribute('aria-expanded', 'true');
    highlight(shown.findIndex((m) => !takenDown.has(m.id)));
  };

  input.addEventListener('input', suggest);
  input.addEventListener('focus', () => { if (input.value.trim()) suggest(); });
  input.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowDown' && shown.length) {
      e.preventDefault();
      highlight((active + 1) % shown.length);
    } else if (e.key === 'ArrowUp' && shown.length) {
      e.preventDefault();
      highlight((active - 1 + shown.length) % shown.length);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (active >= 0 && shown[active]) pick(shown[active]);
    } else if (e.key === 'Escape') {
      hide();
    }
  });
  input.addEventListener('blur', () => hide());

  return el('div', { class: 'takedown-tab-body' }, [
    el('p', {
      class: 'dim',
      text: 'Excludes one mod, and blocks only the posts it comes from. Other mods on a shared post stay published. '
        + 'A Collection page can be taken down too; the mods it lists stay published.',
    }),
    el('div', { class: 'takedown-combo' }, [box, suggestions]),
    empty,
    el('p', {
      class: 'takedown-form-hint',
      text: 'Pick a mod to see exactly what would be removed. Nothing changes until you confirm.',
    }),
  ]);
}

/// How many suggestions the author box shows at once.
const SUGGESTION_COUNT = 8;

/// The form for taking down every mod credited to one person. Names are added
/// as chips; typing suggests the names credited in the current catalog.
function authorForm(list) {
  const names = [];
  const takenDown = (list.authors || []).flatMap((a) => a.names || []).map((n) => n.toLowerCase());
  let known = [];
  api('takedowns/authors').then((body) => {
    if (body && Array.isArray(body.authors)) known = body.authors;
  }).catch(() => {});

  const chips = el('div', { class: 'takedown-chips' });
  const input = el('input', {
    type: 'text', class: 'takedown-names', autocomplete: 'off',
    placeholder: 'Type an author name',
    role: 'combobox', 'aria-label': 'Author names', 'aria-autocomplete': 'list',
    'aria-controls': 'takedown-suggestions', 'aria-expanded': 'false',
  });
  const box = el('div', { class: 'takedown-name-box' }, [chips, input]);
  const suggestions = el('ul', { class: 'takedown-suggestions', id: 'takedown-suggestions', role: 'listbox', hidden: '' });
  const preview = el('button', { class: 'btn btn-primary', type: 'submit', text: 'Preview', disabled: '' });
  let shown = [];
  let active = -1;

  const drawChips = () => {
    clear(chips);
    for (const name of names) {
      chips.append(el('span', { class: 'takedown-chip' }, [
        name,
        el('button', {
          type: 'button', class: 'takedown-chip-remove', 'aria-label': `Remove ${name}`, text: '×',
          onclick: () => { names.splice(names.indexOf(name), 1); drawChips(); input.focus(); },
        }),
      ]));
    }
    if (names.length) preview.removeAttribute('disabled');
    else preview.setAttribute('disabled', '');
    input.placeholder = names.length ? 'Add another name' : 'Type an author name';
  };

  const add = (name) => {
    const clean = name.trim();
    if (clean && !names.some((n) => n.toLowerCase() === clean.toLowerCase())) names.push(clean);
    input.value = '';
    hide();
    drawChips();
    input.focus();
  };

  const hide = () => {
    suggestions.hidden = true;
    input.setAttribute('aria-expanded', 'false');
    shown = [];
    active = -1;
  };

  const highlight = (i) => {
    active = i;
    [...suggestions.children].forEach((li, n) => li.classList.toggle('active', n === i));
    if (i >= 0) input.setAttribute('aria-activedescendant', `takedown-suggestion-${i}`);
    else input.removeAttribute('aria-activedescendant');
  };

  const suggest = () => {
    const q = input.value.trim().toLowerCase();
    if (!q) return hide();
    const picked = new Set(names.map((n) => n.toLowerCase()));
    const starts = [];
    const inside = [];
    for (const author of known) {
      const spellings = [author.name, ...(author.others || [])].map((n) => n.toLowerCase());
      if (spellings.some((n) => picked.has(n))) continue;
      if (spellings.some((n) => n.startsWith(q))) starts.push(author);
      else if (spellings.some((n) => n.includes(q))) inside.push(author);
    }
    shown = [...starts, ...inside].slice(0, SUGGESTION_COUNT);
    clear(suggestions);
    if (!shown.length) return hide();
    shown.forEach((author, i) => {
      const others = author.others || [];
      const already = [author.name, ...others].some((n) => takenDown.includes(n.toLowerCase()));
      const li = el('li', {
        id: `takedown-suggestion-${i}`, role: 'option', class: 'takedown-suggestion',
      }, [
        el('span', { class: 'takedown-suggestion-name' }, [
          author.name,
          // A takedown matches these spellings too, so they are not separate choices.
          others.length
            ? el('span', { class: 'takedown-suggestion-others', text: `also ${others.join(', ')}` })
            : null,
        ]),
        el('span', {
          class: 'takedown-suggestion-count',
          text: already ? 'already taken down' : `${author.mods} mod${author.mods === 1 ? '' : 's'}`,
        }),
      ]);
      // Before the input loses focus, so the pick is not lost to the blur.
      li.addEventListener('mousedown', (e) => { e.preventDefault(); add(author.name); });
      suggestions.append(li);
    });
    suggestions.hidden = false;
    input.setAttribute('aria-expanded', 'true');
    highlight(0);
  };

  input.addEventListener('input', () => {
    // A comma ends a name, for anyone pasting a list.
    if (input.value.includes(',')) {
      const parts = input.value.split(',');
      const rest = parts.pop();
      for (const part of parts) if (part.trim()) add(part);
      input.value = rest;
    }
    suggest();
  });
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
        add(shown[active].name);
      } else if (input.value.trim()) {
        e.preventDefault();
        add(input.value);
      }
    } else if (e.key === 'Escape') {
      hide();
    } else if (e.key === 'Backspace' && !input.value && names.length) {
      names.pop();
      drawChips();
    }
  });
  input.addEventListener('blur', () => hide());
  box.addEventListener('click', () => input.focus());

  const form = el('form', { class: 'takedown-tab-body' }, [
    el('p', {
      class: 'dim',
      text: 'Excludes every mod that credits this person, including mods added later and mods made with others. '
        + 'Names are matched using the same rules as author names in the merge.',
    }),
    el('div', { class: 'takedown-form-row' }, [
      el('div', { class: 'takedown-combo' }, [box, suggestions]),
      preview,
    ]),
    el('p', { class: 'takedown-form-hint', text: 'Press Enter to add a name. Add every name the person goes by.' }),
  ]);
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    if (input.value.trim()) add(input.value);
    if (!names.length) return;
    await previewAndConfirm({ authors: [...names] });
  });
  return form;
}


/// The "Take down" button on the Mod Catalog's page for one mod.
export function takeDownModButton(modId) {
  return el('button', {
    class: 'btn btn-danger',
    text: 'Take down',
    title: 'Leave this mod out of everything we publish, at its owner\'s request.',
    onclick: () => previewAndConfirm({ modId }),
  });
}

/// The "Take down" button on a thread's page. It lists the catalog's mods from
/// the thread first when there are several, and is not drawn when there are
/// none.
export async function takeDownThreadButton(postKey) {
  const body = await api('takedowns/preview', { post: postKey });
  if (body instanceof MissingFile || !body || body.error) return null;
  const mods = body.mods || [];
  if (!mods.length) return null;
  return el('button', {
    class: 'btn btn-danger',
    text: 'Take down',
    title: 'Leave a mod from this thread out of everything we publish, at its owner\'s request.',
    onclick: async () => {
      const modId = mods.length === 1 ? mods[0].id : await pickMod(mods);
      if (modId) await previewAndConfirm({ modId });
    },
  });
}

/// Asks which of a thread's mods to take down. Resolves the id, or null.
function pickMod(mods) {
  return new Promise((resolve) => {
    const box = el('dialog', { class: 'ask-dialog takedown-dialog' });
    let picked = null;
    const list = el('div', { class: 'td-pick' });
    for (const mod of mods) {
      list.append(el('button', {
        type: 'button', class: 'td-pick-row',
        onclick: () => { picked = mod.id; box.close(); },
      }, [
        el('span', { class: 'td-row-text' }, [
          el('span', { class: 'td-row-name', text: mod.name }),
          el('code', { class: 'td-row-id', text: mod.id }),
        ]),
        el('span', { class: 'td-pick-arrow', 'aria-hidden': 'true', text: '›' }),
      ]));
    }
    const cancel = el('button', { type: 'button', class: 'btn', text: 'Cancel', onclick: () => box.close() });
    box.append(
      dialogHeader('Take down a mod', 'Which mod?', () => box.close()),
      el('p', { class: 'td-lead', text: `The catalog lists ${mods.length} mods from this thread. Choose the one to take down.` }),
      list,
      el('div', { class: 'dialog-buttons' }, [cancel]),
    );
    box.addEventListener('close', () => { box.remove(); resolve(picked); });
    document.body.append(box);
    box.showModal();
    cancel.focus();
  });
}

/// Shows what a takedown would leave out, then sends the job if confirmed.
async function previewAndConfirm({ modId = null, authors = [] }) {
  const params = new URLSearchParams();
  if (modId) params.set('mod', modId);
  for (const name of authors) params.append('author', name);
  let preview;
  try {
    const res = await fetch(`/api/takedowns/preview?${params}`);
    preview = await res.json();
  } catch (err) {
    return noticeDialog('Could not preview the takedown', err.message);
  }
  if (preview.error) return noticeDialog('Could not preview the takedown', preview.error);

  const isMod = preview.kind === 'mod';
  if (isMod && preview.alreadyTakenDown) {
    return noticeDialog('Already taken down', `"${preview.id}" is already on the takedown list.`);
  }
  if (!isMod && (preview.alreadyTakenDown || []).length) {
    return noticeDialog('Already taken down', `${preview.alreadyTakenDown.join(', ')} is already on the takedown list.`);
  }

  const modCount = isMod ? (preview.isCollection ? 0 : 1) : (preview.mods || []).length;
  const answer = await takedownDialog({
    eyebrow: isMod ? (preview.isCollection ? 'Take down a Collection page' : 'Take down a mod') : 'Take down an author\'s mods',
    title: isMod ? preview.name : preview.names.join(', '),
    body: isMod ? modPreview(preview) : authorPreview(preview),
    confirmLabel: isMod
      ? (preview.isCollection ? 'Take down page' : 'Take down mod')
      : `Take down ${modCount} mod${modCount === 1 ? '' : 's'}`,
    danger: true,
    publicNote: true,
  });
  if (!answer) return;
  await send(isMod
    ? { kind: 'takeDown', takedownModId: preview.id, publishAfter: answer.publishAfter, collectMergeDebug: true }
    : { kind: 'takeDown', takedownAuthors: preview.names, publishAfter: answer.publishAfter, collectMergeDebug: true });
}

function modPreview(preview) {
  if (preview.isCollection) {
    return [
      summary('1 page', 'The Collection page is removed. The mods it lists stay published.'),
      el('p', {
        class: 'td-note',
        text: 'To remove those mods too, take each one down, or take down all mods credited to their author.',
      }),
      appliesTo({ modRepo: 'skip' }),
    ];
  }

  const posts = preview.posts || [];
  const parts = [
    summary('1 mod', 'Hidden from the catalog, the mod details and Starmodder.', preview.id),
    section(`Blocked posts (${posts.length})`, el('div', { class: 'td-rows' }, posts.map((post) => el('div', { class: 'td-row' }, [
      el('span', { class: 'td-row-text' }, [
        el('code', { class: 'td-row-name', text: post.key }),
        el('span', {
          class: 'td-row-sub',
          text: post.whole
            ? 'No other mod comes from this post.'
            : 'Other mods come from this post. They stay published.',
        }),
      ]),
      el('span', {
        class: `td-pill ${post.whole ? '' : 'td-pill-info'}`,
        text: post.whole ? 'Whole post' : 'This listing only',
      }),
    ])))),
  ];
  const also = alsoAffected(preview.collections, (c) => `${c.name}: loses this mod, ${c.modsLeft} left`, preview.oldIds);
  if (also) parts.push(also);
  const partial = (preview.notInModRepo || []).length > 0;
  parts.push(appliesTo({ modRepo: partial ? 'partial' : 'yes' }));
  if (partial) {
    parts.push(el('p', {
      class: 'td-note td-note-warning',
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
    parts.push(section(`Mods (${mods.length})`, el('div', { class: 'td-rows td-rows-scroll' }, mods.map((mod) => {
      const exact = typed.has(String(mod.credit).toLowerCase());
      return el('div', { class: 'td-row' }, [
        el('span', { class: 'td-row-text' }, [
          el('span', { class: 'td-row-name', text: mod.name }),
          el('code', { class: 'td-row-id', text: mod.id }),
        ]),
        el('span', {
          class: `td-pill ${exact ? '' : 'td-pill-check'}`,
          title: exact
            ? 'Credited under a name you entered.'
            : 'Credited under another spelling. Check this is the same person.',
          text: mod.credit,
        }),
      ]);
    }))));
    if (loose) {
      parts.push(el('p', {
        class: 'td-note td-note-warning',
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

/// The count in large type, with one line saying what happens to it.
function summary(count, text, id = null) {
  return el('div', { class: 'td-summary' }, [
    el('span', { class: 'td-summary-count', text: count }),
    el('span', { class: 'td-summary-text' }, [
      text,
      id ? el('code', { class: 'td-row-id', text: id }) : null,
    ]),
  ]);
}

function section(label, content) {
  return el('div', { class: 'td-section' }, [el('div', { class: 'td-label', text: label }), content]);
}

/// Collections and old addresses the takedown also touches, or null.
function alsoAffected(collections = [], describe, oldIds = []) {
  const rows = [
    ...collections.map((c) => el('li', { text: describe(c) })),
    ...oldIds.map((id) => el('li', {}, ['Old address ', el('code', { text: id }), ' stops working'])),
  ];
  if (!rows.length) return null;
  return section('Also affected', el('ul', { class: 'td-also' }, rows));
}

/// Which outputs the takedown reaches. `modRepo` is 'yes', 'partial' or 'skip'.
function appliesTo({ modRepo }) {
  const item = (label, state, note) => el('li', { class: `td-applies-${state}`, title: note || '' }, [
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

function dialogHeader(eyebrow, title, onClose) {
  return el('div', { class: 'td-header' }, [
    el('div', {}, [
      el('div', { class: 'td-eyebrow', text: eyebrow }),
      el('h3', { text: title }),
    ]),
    el('button', { type: 'button', class: 'td-close', 'aria-label': 'Close', text: '×', onclick: onClose }),
  ]);
}

/// A confirm box with a "Publish when done" choice. Resolves
/// `{ publishAfter }` on confirm, or null. Cancel has the focus, so Enter
/// never takes anything down by accident.
function takedownDialog({ eyebrow, title, body, confirmLabel, danger = false, publicNote = false }) {
  return new Promise((resolve) => {
    const box = el('dialog', { class: 'ask-dialog takedown-dialog' });
    const publish = el('input', { type: 'checkbox', id: 'takedown-publish' });
    const yes = el('button', { type: 'button', class: danger ? 'btn btn-danger btn-danger-solid' : 'btn btn-primary', text: confirmLabel });
    const no = el('button', { type: 'button', class: 'btn', text: 'Cancel' });
    let confirmed = false;
    yes.addEventListener('click', () => { confirmed = true; box.close(); });
    no.addEventListener('click', () => box.close());

    box.append(
      dialogHeader(eyebrow, title, () => box.close()),
      el('div', { class: 'td-body' }, body),
      el('div', { class: 'td-footer' }, [
        el('label', { class: 'td-publish', for: 'takedown-publish' }, [
          publish,
          el('span', {}, [
            el('strong', { text: 'Publish when done' }),
            el('span', {
              class: 'td-publish-note',
              text: 'Sends the catalog, the mod details and the website. ModRepo.json goes out with the next scheduled '
                + 'publish, which runs twice a day.',
            }),
          ]),
      ]),
      publicNote ? el('p', {
        class: 'td-footnote',
        text: 'This entry will appear in the public takedown list, which is published with the outputs. It has no reason in it.',
      }) : null,
      el('div', { class: 'dialog-buttons' }, [no, yes]),
      ]),
    );
    box.addEventListener('close', () => {
      box.remove();
      resolve(confirmed ? { publishAfter: publish.checked } : null);
    });
    document.body.append(box);
    box.showModal();
    no.focus();
  });
}

async function send(request) {
  try {
    const record = await manager.submitJob(request);
    if (record) go(`#/runs/${encodeURIComponent(record.id)}`);
  } catch (err) {
    noticeDialog('Could not start the job', err.message);
  }
}
