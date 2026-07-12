// Router: hash-based view switching (D3). Each view module exports
// `render(root, parts)`, where `parts` are the hash segments after the view id.

import { el, clear, hashParts, errorPanel, loading } from './lib.js';
import * as topics from './views/topics.js';
import * as topic from './views/topic.js';
import * as llmTest from './views/llm_test.js';
import * as merge from './views/merge.js';
import * as modrepo from './views/modrepo.js';
import * as bundle from './views/bundle.js';
import * as files from './views/files.js';
import * as log from './views/log.js';

const NAV = [
  { id: 'topics', label: 'Topics' },
  { id: 'llm-test', label: 'LLM Test' },
  { id: 'merge', label: 'Merge' },
  { id: 'modrepo', label: 'ModRepo' },
  { id: 'bundle', label: 'Bundle' },
  { id: 'files', label: 'Files' },
  { id: 'log', label: 'Log' },
];

// Map a view id to the module that renders it. Detail routes (e.g. a single
// topic) reuse a dedicated module but stay under the same nav id.
const ROUTES = {
  topics: (root, parts) =>
    parts.length ? topic.render(root, parts) : topics.render(root, parts),
  'llm-test': (root, parts) => llmTest.render(root, parts),
  merge: (root, parts) => merge.render(root, parts),
  modrepo: (root, parts) => modrepo.render(root, parts),
  bundle: (root, parts) => bundle.render(root, parts),
  files: (root, parts) => files.render(root, parts),
  log: (root, parts) => log.render(root, parts),
};

function renderNav(activeId) {
  const nav = document.getElementById('nav');
  clear(nav);
  for (const item of NAV) {
    nav.append(
      el('a', {
        href: `#/${item.id}`,
        text: item.label,
        class: item.id === activeId ? 'active' : '',
      })
    );
  }
}

async function route() {
  const parts = hashParts();
  const viewId = parts[0] || 'topics';
  const rest = parts.slice(1);
  renderNav(viewId);

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
  if (!location.hash) location.hash = '#/topics';
  else route();
});
