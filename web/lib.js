// Shared helpers: DOM building, escaping, and a fetch wrapper that understands
// the server's two envelopes (list + "missing file").

/// Builds an element. `attrs` may include `class`, `text`, `html`, `onclick`,
/// and any other attribute. `children` is a flat list of nodes/strings.
export function el(tag, attrs = {}, children = []) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v == null) continue;
    if (k === 'class') node.className = v;
    else if (k === 'text') node.textContent = v;
    else if (k === 'html') node.innerHTML = v;
    else if (k.startsWith('on') && typeof v === 'function') {
      node.addEventListener(k.slice(2), v);
    } else node.setAttribute(k, v);
  }
  for (const c of [].concat(children)) {
    if (c == null) continue;
    node.append(c.nodeType ? c : document.createTextNode(String(c)));
  }
  return node;
}

export function clear(node) {
  node.replaceChildren();
  return node;
}

export function esc(s) {
  return String(s ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

/// A response the server marked as "the file is not on disk".
export class MissingFile {
  constructor(file, hint) {
    this.file = file;
    this.hint = hint;
  }
}

/// Fetches JSON from `/api/...`. Returns a MissingFile instance when the server
/// says the backing file is absent; throws on real HTTP errors.
export async function api(path, params = {}) {
  const url = new URL('/api/' + path.replace(/^\/+/, ''), location.origin);
  for (const [k, v] of Object.entries(params)) {
    if (v == null || v === '') continue;
    url.searchParams.set(k, v);
  }
  const res = await fetch(url);
  if (!res.ok) {
    throw new Error(`${res.status} ${res.statusText} for ${url.pathname}`);
  }
  const body = await res.json();
  if (body && body.missing === true) {
    return new MissingFile(body.file, body.hint);
  }
  return body;
}

/// Renders the friendly "no such file yet" panel.
export function missingPanel(missing) {
  return el('div', { class: 'missing' }, [
    el('h3', { text: `${missing.file} is not on disk yet` }),
    el('p', { text: missing.hint || 'Run the scraper to produce it.' }),
  ]);
}

export function errorPanel(err) {
  return el('div', { class: 'missing error' }, [
    el('h3', { text: 'Something went wrong' }),
    el('p', { text: String(err && err.message ? err.message : err) }),
  ]);
}

export function loading() {
  return el('div', { class: 'loading', text: 'Loading…' });
}

/// A breadcrumb trail for the top of a page. `trail` is the crumbs after Home
/// (Home is prepended for you), each `{ label, href }`. The last crumb is the
/// current page and is drawn as plain text; the rest are links, so the trail
/// doubles as the page's way back. Example:
///   breadcrumbs([{ label: 'Topics', href: '#/topics' }, { label: title }])
export function breadcrumbs(trail = []) {
  const full = [{ label: 'Home', href: '#/home' }, ...trail];
  const nav = el('nav', { class: 'breadcrumbs', 'aria-label': 'Breadcrumb' });
  full.forEach((crumb, i) => {
    if (i) nav.append(el('span', { class: 'crumb-sep', text: '›' }));
    const isLast = i === full.length - 1;
    nav.append(!isLast && crumb.href
      ? el('a', { class: 'crumb', href: crumb.href, text: crumb.label })
      : el('span', { class: 'crumb crumb-current', text: crumb.label }));
  });
  return nav;
}

/// A closed-by-default "show the raw data" fold for detail pages, so anything
/// the tidy layout leaves out is still one click away. Pretty-prints the object.
export function rawJson(obj, label = 'Show the raw data (JSON)') {
  return el('details', { class: 'raw-fold' }, [
    el('summary', { text: label }),
    el('pre', { class: 'raw', text: JSON.stringify(obj, null, 2) }),
  ]);
}

// --- How many rows to a page ---

/// The choices in the "rows" box. 0 means all of them on one page.
export const PAGE_SIZES = [25, 50, 100, 250, 500, 0];

const PAGE_SIZE_KEY = 'viewerPageSize';
const DEFAULT_PAGE_SIZE = 50;

/// The rows-per-page the user last picked. One setting for the whole site, kept
/// in the browser, so a choice made on one list holds on the next one.
export function pageSizePreference() {
  const saved = Number(localStorage.getItem(PAGE_SIZE_KEY));
  return PAGE_SIZES.includes(saved) ? saved : DEFAULT_PAGE_SIZE;
}

export function setPageSizePreference(size) {
  localStorage.setItem(PAGE_SIZE_KEY, String(size));
}

function pageSizeLabel(size) {
  return size === 0 ? 'All on one page' : `${size} rows`;
}

/// A reusable pager row.
///
/// `onPage(newPage)` is called when a page button is pressed. When
/// `onPageSize(newSize)` is given, the row also carries a box for choosing how
/// many rows a page holds — including all of them at once. A page size of 0
/// means everything is already on the page, so the buttons go away.
export function pager(page, pageSize, total, onPage, onPageSize) {
  const showingAll = !pageSize;
  const pages = showingAll ? 1 : Math.max(1, Math.ceil(total / pageSize));
  const cur = showingAll ? 1 : page + 1;
  const row = el('div', { class: 'pager' });
  const btn = (label, target, disabled) =>
    el('button', {
      text: label,
      disabled: disabled ? 'true' : null,
      onclick: () => onPage(target),
    });

  if (!showingAll) {
    row.append(
      btn('« First', 0, page <= 0),
      btn('‹ Prev', page - 1, page <= 0)
    );
  }
  row.append(el('span', {
    class: 'pager-info',
    text: showingAll
      ? `All ${total} on one page`
      : `Page ${cur} of ${pages} (${total} total)`,
  }));
  if (!showingAll) {
    row.append(
      btn('Next ›', page + 1, cur >= pages),
      btn('Last »', pages - 1, cur >= pages)
    );
  }

  if (onPageSize) row.append(pageSizePicker(pageSize, onPageSize));
  return row;
}

function pageSizePicker(pageSize, onPageSize) {
  const select = el('select', { class: 'pager-size' });
  for (const size of PAGE_SIZES) {
    select.append(el('option', { value: String(size), text: pageSizeLabel(size) }));
  }
  select.value = String(PAGE_SIZES.includes(pageSize) ? pageSize : DEFAULT_PAGE_SIZE);
  select.addEventListener('change', () => {
    const picked = Number(select.value);
    setPageSizePreference(picked);
    onPageSize(picked);
  });
  return el('label', { class: 'pager-size-label' }, [
    el('span', { text: 'Show ' }),
    select,
  ]);
}

// --- Asking before doing, without the browser's own popups ---

/// Asks a yes-or-no question in a proper in-page box. Resolves true on yes,
/// false on no or Escape. Blank lines in the message become paragraph breaks.
/// The yes button starts focused, so Enter still says yes as fast as the old
/// browser popup did.
export function askDialog({ title, message, confirmLabel = 'Yes', cancelLabel = 'Cancel', danger = false }) {
  return new Promise((resolve) => {
    const box = el('dialog', { class: 'ask-dialog' });
    const yes = el('button', {
      class: danger ? 'btn btn-danger' : 'btn btn-primary',
      text: confirmLabel,
    });
    const buttons = el('div', { class: 'dialog-buttons' });
    if (cancelLabel != null) {
      const no = el('button', { class: 'btn', text: cancelLabel });
      no.addEventListener('click', () => box.close(''));
      buttons.append(no);
    }
    buttons.append(yes);
    yes.addEventListener('click', () => box.close('yes'));

    box.append(el('h3', { text: title }));
    for (const para of String(message || '').split('\n\n')) {
      if (para.trim()) box.append(el('p', { text: para }));
    }
    box.append(buttons);

    box.addEventListener('close', () => {
      const said = box.returnValue === 'yes';
      box.remove();
      resolve(said);
    });
    document.body.append(box);
    box.showModal();
    yes.focus();
  });
}

/// Tells the user one thing, with just an OK button.
export function noticeDialog(title, message) {
  return askDialog({ title, message, confirmLabel: 'OK', cancelLabel: null });
}

/// Reads the path part of `#/foo/bar?x=1` into ['foo','bar']. The query, if any,
/// is left for `hashQuery`.
export function hashParts() {
  const h = location.hash.replace(/^#\/?/, '').split('?')[0];
  return h.length ? h.split('/').map(decodeURIComponent) : [];
}

/// The query part of the current hash, e.g. `?q=foo&page=2`, as URLSearchParams.
export function hashQuery() {
  const i = location.hash.indexOf('?');
  return new URLSearchParams(i >= 0 ? location.hash.slice(i + 1) : '');
}

/// Builds a hash from path parts and a params object, dropping empty values so
/// the URL stays short: `buildHash(['topics'], {q:'foo', page:2})` →
/// `#/topics?q=foo&page=2`.
export function buildHash(parts, params = {}) {
  const path = parts.map(encodeURIComponent).join('/');
  const q = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v == null || v === '') continue;
    q.set(k, String(v));
  }
  const qs = q.toString();
  return `#/${path}${qs ? '?' + qs : ''}`;
}

export function go(hash) {
  location.hash = hash;
}

/// Updates the address bar to `hash` without adding a history entry or setting
/// off a re-route. A view calls this as its own state (search, filters, page)
/// changes, so a reload or a bookmark brings the same view back, and the back
/// button returns to the list as it was left — without every keystroke piling
/// up in the history.
export function replaceHash(hash) {
  history.replaceState(null, '', hash);
}

export function fmtBytes(n) {
  if (n == null) return '—';
  const units = ['B', 'KB', 'MB', 'GB'];
  let i = 0;
  let v = n;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return `${v.toFixed(i === 0 ? 0 : 1)} ${units[i]}`;
}
