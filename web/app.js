// The viewer's router. The shared layout is drawn once. Route changes
// redraw only the toolbar contents and page content.
//
// A page module exports `render({ content, parts, entry, toolbar, onLeave,
// guardLeave, gone })`. `onLeave(fn)` runs `fn` when the user leaves the page.
// Use it to stop the status subscription. `gone()` is true once the user has
// left the page, so a page still loading can stop before it draws anything.

import { el, clear, api, askDialog } from './lib.js';
import { hashParts, navEntryFor, DEFAULT_PAGE, tabTitle, movedAddress } from './routes.js';
import { mountRail, mountToolbar, mountStatusBar, pageLayout } from './frame.js';
import { subscribe, status, watchRunEnds, endedRun, forgetEndedRun } from './status.js';
import { mountUpdateLink } from './update.js';
import { stepOf, withStep, arrivedStep } from './history_steps.js';
import * as control from './views/control.js';
import * as runs from './views/runs.js';
import * as run from './views/run.js';
import * as settings from './views/settings.js';
import * as takedowns from './views/takedowns.js';
import * as authorAliases from './views/author_aliases.js';
import * as dependencyNames from './views/dependency_names.js';
import * as posts from './views/posts.js';
import * as post from './views/post.js';
import * as postHistory from './views/post_history.js';
import * as mods from './views/mods.js';
import * as mod from './views/mod.js';
import * as changes from './views/changes.js';
import * as explorer from './views/explorer.js';
import * as llmTest from './views/llm_test.js';
import * as files from './views/files.js';

const PAGES = {
  control,
  runs,
  settings,
  takedowns,
  'author-aliases': authorAliases,
  'dependency-names': dependencyNames,
  posts,
  mods,
  changes,
  explorer,
  'llm-test': llmTest,
  files,
};

/// Detail pages: a page id with something after it, such as `#/runs/<id>`.
const DETAIL_PAGES = {
  runs: run,
  explorer,
  files,
  mods: mod,
  // #/posts/<kind>/<id>, and #/posts/topic/<id>/history.
  posts: { render: (ctx) => (ctx.parts[2] === 'history' ? postHistory : post).render(ctx) },
};

let markCurrent;
let toolbar;
let leaving = [];
// Pages with unsaved changes return a confirmation question before navigation.
let guards = [];
// Each drawn page gets the next number, so work from a page already left can
// be told apart from the page now shown.
let generation = 0;
let shownHash = null;
// The number of the shown page's history entry (see history_steps.js).
let shownStep = null;
// True while the "Discard unsaved changes?" question is open.
let asking = false;
let pageName = 'Mod Repo Viewer';

// Pages write their filters and page numbers into the address with
// `history.replaceState(null, …)`. This keeps the entry's number when they do.
const plainReplaceState = history.replaceState.bind(history);
history.replaceState = (state, title, url) => {
  const step = stepOf(history.state);
  plainReplaceState(step == null ? state : withStep(state, step), title, url);
};

/// Writes the number into the current entry, leaving its address alone.
function numberThisEntry(step) {
  plainReplaceState(withStep(history.state, step), '');
}

/// The current entry's number. An entry with none is new and gets one now.
function currentStep() {
  const { step, isNew } = arrivedStep(history.state, shownStep);
  if (isNew) numberThisEntry(step);
  return step;
}

function drawTitle() {
  document.title = tabTitle({ pageName, current: status() && status().current, ended: endedRun() });
}

/// Asks first when the page has unsaved work. Returns false to stay.
async function mayLeave() {
  for (const guard of guards) {
    const question = guard();
    if (!question) continue;
    return askDialog({ title: question, message: 'Your changes on this page are not saved.', confirmLabel: 'Discard', cancelLabel: 'Keep editing' });
  }
  return true;
}

/// Goes back to the shown page's own history entry, without drawing it
/// again. Stepping (rather than replacing the address) leaves the history as
/// it was: after a link click, Back still goes where it went before; after
/// Back, Forward still goes to the page the user tried to leave for. The
/// entry numbers say which way and how far to step.
function returnToShownPage() {
  const now = currentStep();
  if (shownStep == null || now === shownStep) return;
  history.go(shownStep - now);
}

async function onHashChange() {
  // The open question closes itself on this change, and that counts as
  // "Keep editing". The question's own handler then returns to the page.
  if (asking) return;
  // Back on the shown page's own entry: the step back after "Keep editing".
  if (shownStep !== null && currentStep() === shownStep) return;
  if (shownHash !== null) {
    asking = true;
    let leave;
    try {
      leave = await mayLeave();
    } finally {
      asking = false;
    }
    if (!leave) {
      returnToShownPage();
      return;
    }
  }
  route();
}

async function route() {
  const gen = ++generation;
  const left = () => gen !== generation;
  // Old viewer addresses open the matching page.
  const moved = movedAddress(location.hash);
  if (moved) history.replaceState(null, '', moved);
  shownHash = location.hash;
  shownStep = currentStep();
  guards = [];
  const parts = hashParts(location.hash);
  for (const fn of leaving) runSafely(fn);
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
  const page = (parts.length > 1 && DETAIL_PAGES[entry.id]) || PAGES[entry.id];
  try {
    await page.render({
      content,
      parts: parts.slice(1),
      entry,
      toolbar,
      // A page left while loading has already had its leave callbacks run,
      // so a late one runs at once instead of joining the next page's list.
      onLeave: (fn) => (left() ? runSafely(fn) : leaving.push(fn)),
      guardLeave: (fn) => {
        if (!left()) guards.push(fn);
      },
      gone: left,
    });
  } catch (err) {
    console.error(err);
    // An error from a page already left must not land on the next page.
    if (!left()) content.append(el('p', { class: 'error-text', text: err.message }));
  }
}

function runSafely(fn) {
  try { fn(); } catch (err) { console.error(err); }
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

window.addEventListener('hashchange', onHashChange);
// Also confirm unsaved changes before reloading or closing the tab.
window.addEventListener('beforeunload', (e) => {
  if (guards.some((g) => g())) e.preventDefault();
});
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
