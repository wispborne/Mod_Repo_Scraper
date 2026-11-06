// The new viewer's router. The shared layout is drawn once. Route changes
// redraw only the toolbar contents and page content.
//
// A page module exports `render({ content, parts, entry, toolbar, onLeave })`.
// `onLeave(fn)` runs `fn` when the user leaves the page. Use it to stop
// the status subscription.

import { el, clear, api } from './lib.js';
import { hashParts, navEntryFor, DEFAULT_PAGE, tabTitle } from './routes.js';
import { mountRail, mountToolbar, mountStatusBar, pageLayout } from './frame.js';
import { subscribe, status, watchRunEnds, endedRun, forgetEndedRun } from './status.js';
import { mountUpdateLink } from './update.js';
import * as placeholder from './views/placeholder.js';
import * as control from './views/control.js';
import * as runs from './views/runs.js';
import * as run from './views/run.js';

const PAGES = {
  control,
  runs,
};

/// Detail pages: a page id with something after it, such as `#/runs/<id>`.
const DETAIL_PAGES = {
  runs: run,
};

let markCurrent;
let toolbar;
let leaving = [];
let pageName = 'Mod Repo Viewer';

function drawTitle() {
  document.title = tabTitle({ pageName, current: status() && status().current, ended: endedRun() });
}

async function route() {
  const parts = hashParts(location.hash);
  for (const fn of leaving) {
    try { fn(); } catch (err) { console.error(err); }
  }
  leaving = [];
  forgetEndedRun();

  const entry = navEntryFor(parts);
  markCurrent(entry ? entry.id : null);
  pageName = entry ? entry.label : 'Page not found';
  toolbar.reset(pageName);
  drawTitle();

  const content = clear(document.getElementById('content'));
  window.scrollTo(0, 0);
  if (!entry) {
    content.append(pageLayout(el('div', { class: 'note' }, [
      el('h2', { class: 'panel-heading', text: 'Page not found' }),
      el('p', { text: `There is no page at #/${parts.join('/')}. Choose a page from the menu.` }),
    ])));
    return;
  }
  const page = (parts.length > 1 && DETAIL_PAGES[entry.id]) || PAGES[entry.id] || placeholder;
  try {
    await page.render({
      content,
      parts: parts.slice(1),
      entry,
      toolbar,
      onLeave: (fn) => leaving.push(fn),
    });
  } catch (err) {
    console.error(err);
    content.append(el('p', { class: 'error-text', text: err.message }));
  }
}

/// The build number and commit, for bug reports. Left out when unknown.
async function showVersion(node) {
  try {
    const v = await api('version');
    if (!v || !v.build) return;
    node.textContent = `v${v.build} · ${v.commit}`;
    node.title = v.date ? `Built from commit ${v.commit} on ${v.date}.` : `Built from commit ${v.commit}.`;
  } catch {
    // The version is optional.
  }
}

window.addEventListener('hashchange', route);
window.addEventListener('DOMContentLoaded', () => {
  markCurrent = mountRail(document.getElementById('rail'));
  toolbar = mountToolbar(document.getElementById('toolbar'));
  const bar = mountStatusBar(document.getElementById('statusbar'));
  bar.drawStatus(null);
  subscribe(bar.drawStatus);
  watchRunEnds(drawTitle);
  showVersion(bar.version);
  mountUpdateLink(bar.update);

  document.getElementById('skip-link').addEventListener('click', () => {
    document.getElementById('content').focus();
  });

  if (!location.hash || location.hash === '#' || location.hash === '#/') {
    history.replaceState(null, '', `#/${DEFAULT_PAGE}`);
  }
  route();
});
