// The router. Every page has its own address, so a link to a mod, an author or
// a filtered list can be shared and comes back the same.
//
// Nothing here talks to a server. Every view draws itself from the published
// files, fetched off this site's own origin.

import {
  aiSummariesOn, buildHash, clear, el, errorPanel, everyOtherName, formatDay,
  go, hashParts, loading, modHref, modList, modName, notePageScroll,
  setAiSummaries, takeScrollPlaced, thumbnail,
} from './lib.js';
import * as home from './views/home.js';
import * as browse from './views/browse.js';
import * as mod from './views/mod.js';
import * as author from './views/author.js';
import * as about from './views/about.js';

const NAV = [
  { route: 'home', label: 'Home' },
  { route: 'browse', label: 'Browse mods' },
  { route: 'authors', label: 'People' },
  { route: 'about', label: 'About' },
];

const ROUTES = {
  home: (root, parts) => home.render(root, parts),
  browse: (root, parts) => browse.render(root, parts),
  mods: (root, parts) => mod.render(root, parts),
  authors: (root, parts) => author.render(root, parts),
  about: (root, parts) => about.render(root, parts),
};

/// How many mods the search box suggests as you type.
const SUGGESTION_COUNT = 5;

/// How many people it suggests alongside them.
const PEOPLE_SUGGESTION_COUNT = 3;

function renderNav(viewId) {
  const nav = document.getElementById('nav');
  clear(nav);
  for (const item of NAV) {
    nav.append(el('a', {
      href: `#/${item.route}`,
      class: item.route === viewId ? 'active' : '',
      text: item.label,
    }));
  }
}

async function route() {
  // Before anything is cleared, so the view being left can still find out where
  // its reader had got to.
  notePageScroll();

  const parts = hashParts();
  const viewId = parts[0] || 'home';
  renderNav(viewId);
  document.title = 'Starmodder — Starsector mods';

  const root = document.getElementById('app');
  clear(root).append(loading());

  const handler = ROUTES[viewId];
  if (!handler) {
    clear(root).append(errorPanel(new Error(`There is no page called "${viewId}".`)));
    window.scrollTo(0, 0);
    return;
  }
  try {
    await handler(root, parts.slice(1));
  } catch (err) {
    clear(root).append(errorPanel(err));
    console.error(err);
  }

  // A new page starts at its top. Without this, going from the foot of Home to
  // Browse lands halfway down Browse.
  //
  // It happens after the page is drawn, not before, so the reader does not see
  // the old page jump while the new one loads. A view that has already put the
  // page where it wants it — Browse, putting a reader back where they were — is
  // left alone.
  if (!takeScrollPlaced()) window.scrollTo(0, 0);
}

/// Says when the data on show was last collected. It is on every page, at the
/// foot, so a reader can tell at a glance how fresh what they are reading is.
async function showFreshness() {
  const line = document.getElementById('freshness');
  if (!line) return;
  try {
    const list = await modList();
    if (!list || !list.generatedAt) return;
    line.textContent = `Data collected ${formatDay(list.generatedAt)}`;
    line.title = new Date(list.generatedAt).toString();
  } catch {
    // If the data would not load, the page itself already says so.
  }
}

/// The AI summaries switch. It is on unless the reader turned it off, the choice
/// is kept in a cookie so it holds between visits, and flipping it redraws
/// whatever page is open so every summary appears or disappears at once.
function mountAiToggle() {
  const box = document.getElementById('ai-summaries');
  if (!box) return;
  box.checked = aiSummariesOn();
  box.addEventListener('change', () => {
    setAiSummaries(box.checked);
    route();
  });
}

/// The search box in the bar at the top, on every page.
///
/// Someone reading one mod's page who wants another used to have to go back to
/// Home or Browse first. Typing here suggests the five best-matching names
/// straight away — the whole mod list is already loaded, so it costs nothing —
/// and Enter sends the rest to Browse.
function mountHeaderSearch() {
  const box = document.getElementById('site-search');
  const drop = document.getElementById('search-suggestions');
  if (!box || !drop) return;

  let mods = [];
  modList().then((list) => { mods = list.mods || []; }).catch(() => {});

  const hide = () => { clear(drop); drop.hidden = true; };
  const search = () => {
    hide();
    box.blur();
    go(buildHash(['browse'], { q: box.value.trim() }));
  };

  box.addEventListener('input', () => {
    const wanted = box.value.trim().toLowerCase();
    clear(drop);
    if (wanted.length < 2) { hide(); return; }

    const hits = mods
      .filter((m) => matchStrength(m, wanted) > 0)
      .sort((a, b) => matchStrength(b, wanted) - matchStrength(a, wanted)
        || modName(a).localeCompare(modName(b)))
      .slice(0, SUGGESTION_COUNT);
    const people = peopleMatching(mods, wanted);

    if (!hits.length && !people.length) { hide(); return; }
    if (hits.length) {
      drop.append(el('div', { class: 'suggestion-group', text: 'Mods' }));
      for (const hit of hits) drop.append(suggestion(hit, hide));
    }
    if (people.length) {
      drop.append(el('div', { class: 'suggestion-group', text: 'People' }));
      for (const person of people) drop.append(personSuggestion(person, hide));
    }
    drop.hidden = false;
  });

  box.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') search();
    if (e.key === 'Escape') { hide(); box.blur(); }
  });
  box.addEventListener('blur', () => {
    // Late enough for a click on a suggestion to land first.
    setTimeout(hide, 150);
  });

  // "/" puts the cursor in the search box, wherever the reader is on the page,
  // unless they are already typing into something.
  document.addEventListener('keydown', (e) => {
    if (e.key !== '/' || e.ctrlKey || e.metaKey || e.altKey) return;
    const inField = /^(input|textarea|select)$/i.test(e.target.tagName || '');
    if (inField || e.target.isContentEditable) return;
    e.preventDefault();
    box.focus();
    box.select();
  });
}

/// One suggested mod under the search box.
function suggestion(hit, hide) {
  const row = el('a', { class: 'suggestion', href: modHref(hit.id) }, [
    thumbnail(hit.imageUrl, 'suggestion-thumb'),
    el('div', { class: 'suggestion-main' }, [
      el('div', { class: 'suggestion-name', text: modName(hit) }),
      (hit.authors || []).length
        ? el('div', { class: 'suggestion-by', text: hit.authors.join(', ') })
        : null,
    ]),
  ]);
  row.addEventListener('click', hide);
  return row;
}

/// The people whose name holds what has been typed, with how many mods each
/// has. Search already covers authors, so this is only to save the reader
/// working out that a name is a person rather than a mod.
function peopleMatching(mods, wanted) {
  const counts = new Map();
  for (const mod of mods) {
    for (const name of mod.authors || []) {
      if (!name.toLowerCase().includes(wanted)) continue;
      const key = name.toLowerCase();
      if (!counts.has(key)) counts.set(key, { name, count: 0 });
      counts.get(key).count += 1;
    }
  }
  return [...counts.values()]
    .sort((a, b) => b.count - a.count || a.name.localeCompare(b.name))
    .slice(0, PEOPLE_SUGGESTION_COUNT);
}

/// One suggested person under the search box.
function personSuggestion(person, hide) {
  const row = el('a', {
    class: 'suggestion',
    href: `#/authors/${encodeURIComponent(person.name)}`,
  }, [
    el('div', { class: 'suggestion-thumb person-thumb', 'aria-hidden': 'true' }),
    el('div', { class: 'suggestion-main' }, [
      el('div', { class: 'suggestion-name', text: person.name }),
      el('div', {
        class: 'suggestion-by',
        text: `${person.count} mod${person.count === 1 ? '' : 's'}`,
      }),
    ]),
  ]);
  row.addEventListener('click', hide);
  return row;
}

/// How well a mod matches what has been typed. A name that starts with it beats
/// a name that merely holds it, which beats a match on the author's name.
function matchStrength(mod, wanted) {
  const name = modName(mod).toLowerCase();
  if (name.startsWith(wanted)) return 3;
  if (name.includes(wanted)) return 2;
  const people = [...(mod.authors || []), ...everyOtherName(mod)];
  if (people.some((p) => p.toLowerCase().includes(wanted))) return 1;
  return 0;
}

/// The skip link at the very top, for anyone moving through the page by
/// keyboard. It cannot be a plain `#app` link — the address bar's hash is what
/// picks the page, so following one would send the router looking for a page
/// called "app".
function mountSkipLink() {
  const link = document.querySelector('.skip-link');
  const main = document.getElementById('app');
  if (!link || !main) return;
  link.addEventListener('click', (e) => {
    e.preventDefault();
    main.focus();
    main.scrollIntoView();
  });
}

window.addEventListener('hashchange', route);
window.addEventListener('DOMContentLoaded', () => {
  mountAiToggle();
  mountHeaderSearch();
  mountSkipLink();
  showFreshness();
  if (!location.hash) location.hash = '#/home';
  else route();
});
