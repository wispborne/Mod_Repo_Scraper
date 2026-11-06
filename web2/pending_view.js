// How the pending changes are shown and saved: a button in the toolbar that
// opens the list, the same list as a side panel on some pages, and one save
// for everything. The list itself is kept by pending.js.

import { el, noticeDialog, showDialog } from './lib.js';
import { icon } from './icons.js';
import { sidePanel } from './frame.js';
import { refresh } from './status.js';
import {
  pendingItems, removePending, clearPending, onPendingChange, saveRequest,
} from './pending.js';

// Keep the checkbox state for this visit without storing it.
let publishAfter = false;

/// The list with its buttons: each item with a remove button, then
/// "Publish afterwards", "Save all" and "Discard all".
function pendingList(onAction = () => {}) {
  const items = pendingItems();
  const list = el('ul', { class: 'pending-list' }, items.map((item) => el('li', { class: 'pending-item' }, [
    el('span', { class: 'pending-label', text: item.label }),
    el('button', {
      type: 'button',
      class: 'icon-button',
      'aria-label': `Remove "${item.label}"`,
      title: 'Remove',
      onclick: () => removePending(item.id),
    }, [icon('x', 14)]),
  ])));

  const box = el('input', { type: 'checkbox' });
  box.checked = publishAfter;
  box.addEventListener('change', () => { publishAfter = box.checked; });

  return el('div', { class: 'pending-body' }, [
    list,
    el('label', { class: 'check pending-publish' }, [box, 'Publish afterwards']),
    el('div', { class: 'pending-actions' }, [
      el('button', {
        type: 'button',
        class: 'button primary',
        text: 'Save all',
        onclick: () => { onAction(); saveAll(); },
      }),
      el('button', {
        type: 'button',
        class: 'button quiet',
        text: 'Discard all',
        onclick: () => { onAction(); discardAll(); },
      }),
    ]),
  ]);
}

/// The toolbar button: "N pending", shown only while the list is not empty.
/// Pressing it opens the list under it.
export function mountPendingButton(host) {
  const button = el('button', {
    type: 'button',
    class: 'pending-count',
    'aria-haspopup': 'true',
    'aria-expanded': 'false',
    hidden: true,
  });
  const panel = el('div', { class: 'menu pending-menu', hidden: true });
  host.append(button, panel);

  const close = () => {
    panel.hidden = true;
    button.setAttribute('aria-expanded', 'false');
  };
  const drawPanel = () => panel.replaceChildren(
    el('h2', { class: 'side-head pending-menu-head' }, ['Pending changes']),
    pendingList(close),
  );
  const draw = () => {
    const n = pendingItems().length;
    button.hidden = n === 0;
    button.replaceChildren(icon('inbox', 14), `${n} pending`);
    button.title = n === 1 ? '1 unsaved change.' : `${n} unsaved changes.`;
    if (n === 0) close();
    else if (!panel.hidden) drawPanel();
  };
  button.addEventListener('click', () => {
    if (!panel.hidden) { close(); return; }
    drawPanel();
    panel.hidden = false;
    button.setAttribute('aria-expanded', 'true');
  });
  document.addEventListener('mousedown', (e) => {
    if (!host.contains(e.target)) close();
  });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); });
  onPendingChange(draw);
  draw();
}

/// A side panel showing the list. It hides itself while the list is empty,
/// and stops listening once it has left the page.
export function pendingPanel() {
  const wrap = el('div', { class: 'pending-side' });
  let placed = false;
  const draw = () => {
    if (placed && !wrap.isConnected) {
      stop();
      return;
    }
    const n = pendingItems().length;
    wrap.replaceChildren(...(n ? [sidePanel({ name: 'Pending changes', count: n, body: pendingList() })] : []));
  };
  const stop = onPendingChange(draw);
  draw();
  // Known to be on the page once the page has been drawn.
  setTimeout(() => { placed = true; }, 0);
  return wrap;
}

function discardAll() {
  const items = pendingItems();
  if (!items.length) return;
  const yes = el('button', { type: 'button', class: 'button primary', text: 'Discard' });
  const no = el('button', { type: 'button', class: 'button', text: 'Keep editing' });
  const box = el('dialog', { class: 'dialog' }, [
    el('h2', { text: 'Discard unsaved changes?' }),
    el('p', { text: items.length === 1 ? '1 change will be removed.' : `${items.length} changes will be removed.` }),
    el('div', { class: 'dialog-buttons' }, [no, yes]),
  ]);
  const shut = showDialog(box, (value) => { if (value === true) clearPending(); });
  yes.addEventListener('click', () => shut(true));
  no.addEventListener('click', () => shut(false));
  yes.focus();
}

/// Lists every change, asks for confirmation, then starts one job for them all.
async function saveAll() {
  const items = pendingItems();
  if (!items.length) return;
  const publish = publishAfter;
  const confirmed = await new Promise((resolve) => {
    const yes = el('button', { type: 'button', class: 'button primary', text: publish ? 'Save and publish' : 'Save' });
    const no = el('button', { type: 'button', class: 'button', text: 'Cancel' });
    const box = el('dialog', { class: 'dialog' }, [
      el('h2', { text: items.length === 1 ? 'Save 1 change?' : `Save ${items.length} changes?` }),
      el('ul', { class: 'change-list pending-confirm' }, items.map((i) => el('li', { text: i.label }))),
      el('p', {
        text: publish
          ? 'Then rebuild every output from saved files and publish, with no LLM calls.'
          : 'Then rebuild every output from saved files, with no network or LLM calls.',
      }),
      el('div', { class: 'dialog-buttons' }, [no, yes]),
    ]);
    const shut = showDialog(box, (value) => resolve(value === true));
    yes.addEventListener('click', () => shut(true));
    no.addEventListener('click', () => shut(false));
    yes.focus();
  });
  if (!confirmed) return;

  let record;
  try {
    const res = await fetch('/api/manager/jobs', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(saveRequest(items, publish)),
    });
    record = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(record.error || `Server returned ${res.status} ${res.statusText}.`);
  } catch (err) {
    await noticeDialog('Could not start job', err.message);
    return;
  }
  // Remove only the items sent to the server. Keep any added since then.
  for (const item of items) removePending(item.id);
  publishAfter = false;
  refresh();
  if (record && record.id) location.hash = `#/runs/${encodeURIComponent(record.id)}`;
}

// Closing or reloading the tab with pending changes asks first.
window.addEventListener('beforeunload', (e) => {
  if (pendingItems().length) e.preventDefault();
});
