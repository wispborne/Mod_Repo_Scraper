// Hash router. Views export render(root, parts); parts excludes the view id.

import { el, clear, hashParts, errorPanel, loading, api } from './lib.js';
import * as home from './views/home.js';
import * as topics from './views/topics.js';
import * as topic from './views/topic.js';
import * as llmTest from './views/llm_test.js';
import * as merge from './views/merge.js';
import * as modrepo from './views/modrepo.js';
import * as discord from './views/discord.js';
import * as bundle from './views/bundle.js';
import * as files from './views/files.js';
import * as log from './views/log.js';
import * as runs from './views/runs.js';
import * as run from './views/run.js';
import { mountHeaderChip } from './manager.js';
import { icon } from './icons.js';

// The longest matching route is active, so Details diff takes precedence over
// the bundle list for #/bundle/changes.
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
      { route: ['modrepo'], label: 'Mod Catalog', icon: 'packages' },
      { route: ['bundle'], label: 'Mod Details', icon: 'package-export' },
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
      { route: ['merge'], label: 'Catalog explorer', icon: 'git-merge' },
      { route: ['merge', 'changes'], label: 'Catalog diff', icon: 'git-compare' },
      { route: ['bundle', 'changes'], label: 'Details diff', icon: 'file-diff' },
      { route: ['llm-test'], label: 'LLM test report', icon: 'flask' },
      { route: ['files'], label: 'Files', icon: 'files' },
      { route: ['log'], label: 'Log', icon: 'terminal-2' },
    ],
  },
];

// Detail routes share their parent view's navigation entry.
const ROUTES = {
  home: home.render,
  // Numeric topic paths open a detail page; the bare route opens the list.
  topics: (root, parts) =>
    parts.length && /^\d+$/.test(parts[0])
      ? topic.render(root, parts)
      : topics.render(root, parts),
  runs: (root, parts) =>
    parts.length ? run.render(root, parts) : runs.render(root, parts),
  'llm-test': llmTest.render,
  merge: merge.render,
  modrepo: modrepo.render,
  discord: discord.render,
  bundle: bundle.render,
  files: files.render,
  log: log.render,
};

function routeMatches(route, parts) {
  return route.length <= parts.length
    && route.every((seg, i) => seg === parts[i]);
}

function renderNav(parts) {
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
    clear(root).append(errorPanel(new Error(`Page not found: ${viewId}`)));
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

// Show the build identifier for bug reports; omit it when unavailable.
async function showVersion(element) {
  if (!element) return;
  try {
    const version = await api('version');
    if (!version || !version.build) return;

    element.textContent = `v${version.build} · ${version.commit}`;
    element.title = version.date
      ? `Built from commit ${version.commit} on ${version.date}.`
      : `Built from commit ${version.commit}.`;
  } catch {
    // Version metadata is optional.
  }
}

window.addEventListener('hashchange', route);
window.addEventListener('DOMContentLoaded', () => {
  mountHeaderChip(document.getElementById('status-chip'));
  showVersion(document.getElementById('site-version'));
  if (!location.hash) location.hash = '#/home';
  else route();
});
