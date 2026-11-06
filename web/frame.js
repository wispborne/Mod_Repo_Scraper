// The shared page layout: the nav rail, toolbar, side panels and
// the status bar. Pages fill the toolbar's action area and the content area.

import { el, clear, store } from './lib.js';
import { icon } from './icons.js';
import { NAV, kindLabel, percent } from './routes.js';
import { mountPendingButton } from './pending_view.js';
import { searchBox } from './search_box.js';

// --- Nav rail ---

/// Draws the nav rail once. Returns a function that marks the current page.
export function mountRail(node) {
  const links = new Map();
  const groups = NAV.map((group, i) => {
    const items = group.items.map((item) => {
      const link = el('a', {
        class: 'rail-link',
        href: `#/${item.id}`,
        'aria-label': item.label,
      }, [icon(item.icon, 20), el('span', { class: 'rail-label', text: item.label, 'aria-hidden': 'true' })]);
      links.set(item.id, link);
      return link;
    });
    return [i > 0 ? el('hr', { class: 'rail-line' }) : null, ...items];
  });

  clear(node).append(
    el('a', { class: 'rail-logo', href: '#/control', 'aria-label': 'Mod Repo Viewer' }),
    el('nav', { class: 'rail-groups', 'aria-label': 'Pages' }, groups.flat()),
  );

  return (currentId) => {
    for (const [id, link] of links) {
      const on = id === currentId;
      link.classList.toggle('on', on);
      if (on) link.setAttribute('aria-current', 'page');
      else link.removeAttribute('aria-current');
    }
  };
}

// --- Toolbar ---

/// Draws the toolbar once: title, page buttons, Pending changes count and
/// search box. Returns the parts that each page updates.
export function mountToolbar(node) {
  const title = el('h1', { class: 'toolbar-title' });
  const actions = el('div', { class: 'toolbar-actions' });
  // The Pending changes button, and the list it opens.
  const pending = el('div', { class: 'pending-host' });
  mountPendingButton(pending);
  // The search box and the matches under it (search_box.js).
  const { form, input } = searchBox();

  clear(node).append(title, actions, el('span', { class: 'gap' }), pending, form);

  // "/" anywhere outside a text box puts the cursor in the search box.
  document.addEventListener('keydown', (e) => {
    if (e.key !== '/' || e.ctrlKey || e.metaKey || e.altKey) return;
    const t = e.target;
    if (t && t.closest && t.closest('input, textarea, select, [contenteditable=""], [contenteditable="true"]')) return;
    e.preventDefault();
    input.focus();
    input.select();
  });

  return {
    /// Sets the page name and clears the page's buttons.
    reset(pageName) {
      title.textContent = pageName;
      clear(actions);
    },
    actions,
  };
}

// --- Side panels ---

const FOLDED_KEY = 'viewer2FoldedPanels';

function foldedPanels() {
  try {
    const list = JSON.parse(store.get(FOLDED_KEY) || '[]');
    return new Set(Array.isArray(list) ? list : []);
  } catch {
    return new Set();
  }
}

/// A side panel with a heading bar that folds and opens it. The browser
/// remembers folded panels by name.
export function sidePanel({ name, count = null, body }) {
  const folded = foldedPanels().has(name);
  const content = el('div', { class: 'side-body' }, [body]);
  content.hidden = folded;
  const heading = el('button', {
    type: 'button',
    class: 'side-head',
    'aria-expanded': String(!folded),
  }, [
    icon('chevron-down', 14),
    el('span', { text: name }),
    count == null ? null : el('span', { class: 'side-count', text: String(count) }),
  ]);
  heading.addEventListener('click', () => {
    const nowFolded = !content.hidden;
    content.hidden = nowFolded;
    heading.setAttribute('aria-expanded', String(!nowFolded));
    const all = foldedPanels();
    if (nowFolded) all.add(name);
    else all.delete(name);
    store.set(FOLDED_KEY, JSON.stringify([...all]));
  });
  return el('section', { class: 'side-panel' }, [el('h2', { class: 'side-title' }, [heading]), content]);
}

/// The page layout: a large central panel, and side panels on its right.
export function pageLayout(main, sides = []) {
  const centre = el('section', { class: 'main-panel' }, [main]);
  if (!sides.length) return el('div', { class: 'page one' }, [centre]);
  return el('div', { class: 'page' }, [centre, el('aside', { class: 'side-stack' }, sides)]);
}

// --- Status bar ---

/// A diamond mark in a status colour: 'running', 'done', 'failed', 'warning'
/// or 'idle'.
export function statusMark(kind) {
  return el('span', { class: `mark mark-${kind}`, 'aria-hidden': 'true' });
}

/// A thin bar split into parts, filled to `pct` (0 to 100), or moving back and
/// forth when the amount is not known.
export function progressBar(pct) {
  const fill = el('span', { class: 'progress-fill' });
  if (pct == null) fill.classList.add('unknown');
  else fill.style.width = `${pct}%`;
  return el('span', {
    class: 'progress',
    role: 'progressbar',
    'aria-valuemin': '0',
    'aria-valuemax': '100',
    'aria-valuenow': pct == null ? null : String(pct),
  }, [fill]);
}

/// Draws the status bar's parts. `drawStatus(s)` redraws the left side from
/// the manager's status; the version and update link are slots on the right.
export function mountStatusBar(node) {
  const left = el('div', { class: 'status-left' });
  const version = el('span', { class: 'status-version' });
  const update = el('span', { class: 'status-update' });
  clear(node).append(left, el('span', { class: 'gap' }), version, update);

  return {
    version,
    update,
    drawStatus(s) {
      clear(left);
      if (!s) {
        left.append(statusMark('idle'), el('span', { text: 'Connecting…' }));
        return;
      }
      if (!s.on) {
        left.append(
          statusMark('idle'),
          el('span', { class: 'status-state', text: s.offline ? 'Offline' : 'Viewing only', title: s.reason || '' }),
        );
        return;
      }
      const c = s.current;
      if (c) {
        const pct = percent(c.itemsDone, c.itemsTotal);
        const kind = kindLabel(c.record && c.record.request && c.record.request.kind);
        left.append(
          statusMark('running'),
          el('span', { class: 'status-state', text: 'Running' }),
          el('a', { class: 'status-job', href: `#/runs/${encodeURIComponent(c.record.id)}`, text: kind, title: c.phase || '' }),
          progressBar(pct),
          el('span', { class: 'status-pct', text: pct == null ? '…' : `${pct}%` }),
        );
      } else {
        left.append(statusMark('done'), el('span', { class: 'status-state', text: 'Ready' }));
      }
      const waiting = (s.queued || []).length;
      if (waiting) left.append(el('span', { class: 'status-waiting', text: `${waiting} waiting` }));
    },
  };
}
