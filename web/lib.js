// Shared helpers for DOM elements, API requests and in-page dialogs.

import { icon } from './icons.js';

/// Builds an element. `attrs` may hold `class`, `text`, an `on<event>`
/// function, or any other attribute. `children` is a list of nodes or strings.
/// There is no way to set HTML from text, so data can never become markup.
export function el(tag, attrs = {}, children = []) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v == null || v === false) continue;
    if (k === 'class') node.className = v;
    else if (k === 'text') node.textContent = v;
    else if (k.startsWith('on') && typeof v === 'function') {
      node.addEventListener(k.slice(2), v);
    } else node.setAttribute(k, v === true ? '' : v);
  }
  for (const c of [].concat(children)) {
    if (c == null || c === false) continue;
    node.append(c.nodeType ? c : document.createTextNode(String(c)));
  }
  return node;
}

export function clear(node) {
  node.replaceChildren();
  return node;
}

/// Fetches `/api/<path>` as JSON. Throws with the server's error message
/// if the request fails.
export async function api(path, params = {}) {
  const url = new URL('/api/' + path.replace(/^\/+/, ''), location.origin);
  for (const [k, v] of Object.entries(params)) {
    if (v == null || v === '') continue;
    url.searchParams.set(k, v);
  }
  const res = await fetch(url, { headers: { accept: 'application/json' } });
  const body = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error((body && body.error) || `Server returned ${res.status} ${res.statusText}.`);
  }
  return body;
}

/// Shows `box` as a dialog in the page. Returns `shut(value)`, which closes
/// and removes it once and calls `onShut(value)`. Every way out (buttons,
/// Escape, the back button) goes through `shut`: some browsers never send the
/// dialog's own close event.
///
/// Moving to another page closes the dialog, unless `stayOnPageChange` is
/// set. Use that for a dialog that follows work outside the page, such as an
/// update.
export function showDialog(box, onShut, { stayOnPageChange = false } = {}) {
  let done = false;
  const shut = (value) => {
    if (done) return;
    done = true;
    if (box.open) box.close();
    box.remove();
    window.removeEventListener('hashchange', onLeave);
    onShut(value);
  };
  const onLeave = () => shut(null);
  box.addEventListener('cancel', (e) => {
    e.preventDefault();
    shut(null);
  });
  box.addEventListener('close', () => shut(null));
  if (!stayOnPageChange) window.addEventListener('hashchange', onLeave);
  document.body.append(box);
  box.showModal();
  return shut;
}

/// A dialog in the page. Resolves true on confirm, false on Cancel or Escape.
/// Blank lines split the message into paragraphs. The confirm button has the
/// focus, so Enter confirms.
export function askDialog({ title, message, confirmLabel = 'Yes', cancelLabel = 'Cancel' }) {
  return new Promise((resolve) => {
    const box = el('dialog', { class: 'dialog' });
    const yes = el('button', { type: 'button', class: 'button primary', text: confirmLabel });
    const buttons = el('div', { class: 'dialog-buttons' });
    let no = null;
    if (cancelLabel != null) {
      no = el('button', { type: 'button', class: 'button', text: cancelLabel });
      buttons.append(no);
    }
    buttons.append(yes);

    box.append(el('h2', { text: title }));
    for (const para of String(message || '').split('\n\n')) {
      if (para.trim()) box.append(el('p', { text: para }));
    }
    box.append(buttons);
    const shut = showDialog(box, (value) => resolve(value === true));
    yes.addEventListener('click', () => shut(true));
    if (no) no.addEventListener('click', () => shut(false));
    yes.focus();
  });
}

export function noticeDialog(title, message) {
  return askDialog({ title, message, confirmLabel: 'OK', cancelLabel: null });
}

/// An info icon button for beside a page heading. `label` is its name and
/// tooltip ("About takedowns"). Pressing it opens a dialog titled `title`
/// holding `body` (nodes, or a function that builds them), with an OK button.
/// A page keeps its explanations here rather than on the page.
export function infoButton(label, title, body) {
  return el('button', {
    type: 'button',
    class: 'info-button',
    'aria-label': label,
    title: label,
    onclick: () => {
      const ok = el('button', { type: 'button', class: 'button primary', text: 'OK' });
      const box = el('dialog', { class: 'dialog info-dialog' }, [
        el('h2', { text: title }),
        ...[].concat(typeof body === 'function' ? body() : body),
        el('div', { class: 'dialog-buttons' }, [ok]),
      ]);
      const shut = showDialog(box, () => {});
      ok.addEventListener('click', () => shut(true));
      ok.focus();
    },
  }, [icon('info-circle', 16)]);
}

/// A time as "5 Nov 23:07", in the reader's own time zone.
export function shortTime(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  // The year is written only when it is not this year.
  return d.toLocaleString(undefined, {
    day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', hour12: false,
    ...(d.getFullYear() === new Date().getFullYear() ? {} : { year: 'numeric' }),
  });
}

/// Reads or writes local storage, doing nothing when the browser refuses.
export const store = {
  get(key) {
    try { return localStorage.getItem(key); } catch { return null; }
  },
  set(key, value) {
    try { localStorage.setItem(key, value); } catch { /* storage blocked */ }
  },
};

// --- Lists and detail pages ---

/// Rows-per-page choices. 0 shows every row on one page.
export const PAGE_SIZES = [25, 50, 100, 250, 500, 0];

// Every list shares this setting. Keeping the previous viewer's key name
// preserves the saved choice.
const PAGE_SIZE_KEY = 'viewerPageSize';
const DEFAULT_PAGE_SIZE = 50;

export function pageSizePreference() {
  const raw = store.get(PAGE_SIZE_KEY);
  // Use the default when no value is saved. Converting an empty value to 0 would show every row.
  if (raw == null || raw === '') return DEFAULT_PAGE_SIZE;
  const saved = Number(raw);
  return PAGE_SIZES.includes(saved) ? saved : DEFAULT_PAGE_SIZE;
}

function pageSizeLabel(size) {
  return size === 0 ? 'All on one page' : `${size} rows`;
}

/// Page buttons and the rows-per-page choice. `onPage(page)` gets a 0-based
/// page; `onPageSize(size)` is called after the choice is saved.
export function pager(page, pageSize, total, onPage, onPageSize) {
  const showingAll = !pageSize;
  const pages = showingAll ? 1 : Math.max(1, Math.ceil(total / pageSize));
  const current = showingAll ? 1 : page + 1;
  const row = el('div', { class: 'pager' });
  const button = (text, target, disabled) => el('button', {
    type: 'button',
    class: 'button quiet',
    text,
    disabled,
    onclick: () => onPage(target),
  });

  if (!showingAll) row.append(button('« First', 0, page <= 0), button('‹ Previous', page - 1, page <= 0));
  row.append(el('span', {
    class: 'pager-info',
    text: showingAll ? `All ${total} on one page` : `Page ${current} of ${pages} (${total} total)`,
  }));
  if (!showingAll) row.append(button('Next ›', page + 1, current >= pages), button('Last »', pages - 1, current >= pages));

  const select = el('select', { class: 'select', 'aria-label': 'Rows per page' });
  for (const size of PAGE_SIZES) select.append(el('option', { value: String(size), text: pageSizeLabel(size) }));
  select.value = String(PAGE_SIZES.includes(pageSize) ? pageSize : DEFAULT_PAGE_SIZE);
  select.addEventListener('change', () => {
    const picked = Number(select.value);
    store.set(PAGE_SIZE_KEY, String(picked));
    onPageSize(picked);
  });
  row.append(el('span', { class: 'gap' }), el('label', { class: 'pager-size' }, ['Show ', select]));
  return row;
}

/// A trail of links back up from a detail page. Each item is
/// `{ label, href }`; the last is the current page and is not a link.
export function breadcrumbs(trail) {
  const nav = el('nav', { class: 'breadcrumbs', 'aria-label': 'Breadcrumbs' });
  trail.forEach((item, i) => {
    if (i > 0) nav.append(el('span', { class: 'crumb-sep', 'aria-hidden': 'true', text: '›' }));
    const last = i === trail.length - 1;
    nav.append(last
      ? el('span', { class: 'crumb-here', 'aria-current': 'page', text: item.label })
      : el('a', { href: item.href, text: item.label }));
  });
  return nav;
}

/// A collapsed section showing the value as formatted JSON, for the end of a
/// detail page.
export function rawJson(value, label = 'Raw data (JSON)') {
  return el('details', { class: 'raw-fold' }, [
    el('summary', { text: label }),
    el('pre', { class: 'log raw', text: JSON.stringify(value, null, 2) }),
  ]);
}
