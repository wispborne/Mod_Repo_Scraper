// Router: hash-based view switching (D3). Each view module exports
// `render(root, parts)`, where `parts` are the hash segments after the view id.

import { el, clear, hashParts, errorPanel, loading } from './lib.js';
import * as home from './views/home.js';
import * as topics from './views/topics.js';
import * as topic from './views/topic.js';
import * as llmTest from './views/llm_test.js';
import * as merge from './views/merge.js';
import * as modrepo from './views/modrepo.js';
import * as bundle from './views/bundle.js';
import * as files from './views/files.js';
import * as log from './views/log.js';
import * as runs from './views/runs.js';
import * as run from './views/run.js';
import { mountHeaderChip } from './manager.js';
import { icon } from './icons.js';

// The sidebar, in sections. Each entry names a whole route: the one whose
// route matches the most of the current hash is the one lit up, which is how
// "#/bundle/changes" lights Bundle diff while "#/bundle/123" lights the
// bundle itself.
const NAV_SECTIONS = [
  {
    items: [
      { route: ['home'], label: 'Home', icon: 'home' },
    ],
  },
  {
    title: 'Data',
    items: [
      { route: ['topics'], label: 'Topics', icon: 'list-details' },
      { route: ['modrepo'], label: 'ModRepo', icon: 'packages' },
      { route: ['bundle'], label: 'Forum Data Bundle', icon: 'package-export' },
    ],
  },
  {
    title: 'Jobs',
    items: [
      { route: ['runs'], label: 'Runs and queue', icon: 'player-play' },
    ],
  },
  {
    title: 'Debug',
    items: [
      { route: ['merge'], label: 'ModRepo explorer', icon: 'git-merge' },
      { route: ['merge', 'changes'], label: 'ModRepo diff', icon: 'git-compare' },
      { route: ['bundle', 'changes'], label: 'Bundle diff', icon: 'file-diff' },
      { route: ['llm-test'], label: 'LLM test report', icon: 'flask' },
      { route: ['files'], label: 'Files', icon: 'files' },
      { route: ['log'], label: 'Log', icon: 'terminal-2' },
    ],
  },
];

// Map a view id to the module that renders it. Detail routes (e.g. a single
// topic) reuse a dedicated module but stay under the same nav id.
const ROUTES = {
  home: (root, parts) => home.render(root, parts),
  // A topic id is always a number, so `#/topics/12345` opens that topic. Plain
  // `#/topics` (with any `?q=…&filters=…` query) opens the list.
  topics: (root, parts) =>
    parts.length && /^\d+$/.test(parts[0])
      ? topic.render(root, parts)
      : topics.render(root, parts),
  runs: (root, parts) =>
    parts.length ? run.render(root, parts) : runs.render(root, parts),
  'llm-test': (root, parts) => llmTest.render(root, parts),
  merge: (root, parts) => merge.render(root, parts),
  modrepo: (root, parts) => modrepo.render(root, parts),
  bundle: (root, parts) => bundle.render(root, parts),
  files: (root, parts) => files.render(root, parts),
  log: (root, parts) => log.render(root, parts),
};

/// True when the hash starts with every segment of the entry's route.
function routeMatches(route, parts) {
  return route.length <= parts.length
    && route.every((seg, i) => seg === parts[i]);
}

function renderNav(parts) {
  // The lit entry is the deepest route that matches the current hash.
  let active = null;
  for (const section of NAV_SECTIONS) {
    for (const item of section.items) {
      if (!routeMatches(item.route, parts)) continue;
      if (!active || item.route.length > active.route.length) active = item;
    }
  }

  const nav = document.getElementById('nav');
  clear(nav);
  for (const section of NAV_SECTIONS) {
    if (section.title) {
      nav.append(el('div', { class: 'nav-section-title', text: section.title }));
    }
    for (const item of section.items) {
      nav.append(
        el('a', {
          href: `#/${item.route.join('/')}`,
          class: item === active ? 'active' : '',
        }, [
          item.icon ? icon(item.icon) : null,
          el('span', { text: item.label }),
        ])
      );
    }
  }
}

async function route() {
  const parts = hashParts();
  const viewId = parts[0] || 'home';
  const rest = parts.slice(1);
  renderNav(parts.length ? parts : ['home']);

  const root = document.getElementById('app');
  clear(root).append(loading());

  const handler = ROUTES[viewId];
  if (!handler) {
    clear(root).append(errorPanel(new Error(`Unknown view: ${viewId}`)));
    return;
  }
  try {
    await handler(root, rest);
  } catch (err) {
    clear(root).append(errorPanel(err));
    // eslint-disable-next-line no-console
    console.error(err);
  }
}

window.addEventListener('hashchange', route);
window.addEventListener('DOMContentLoaded', () => {
  mountHeaderChip(document.getElementById('status-chip'));
  if (!location.hash) location.hash = '#/home';
  else route();
});
