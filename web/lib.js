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

/// A reusable pager row. `onPage(newPage)` is called on click.
export function pager(page, pageSize, total, onPage) {
  const pages = Math.max(1, Math.ceil(total / pageSize));
  const cur = page + 1;
  const row = el('div', { class: 'pager' });
  const btn = (label, target, disabled) =>
    el('button', {
      text: label,
      disabled: disabled ? 'true' : null,
      onclick: () => onPage(target),
    });
  row.append(
    btn('« First', 0, page <= 0),
    btn('‹ Prev', page - 1, page <= 0),
    el('span', { class: 'pager-info', text: `Page ${cur} of ${pages} (${total} total)` }),
    btn('Next ›', page + 1, cur >= pages),
    btn('Last »', pages - 1, cur >= pages)
  );
  return row;
}

/// Reads `#/foo/bar` into ['foo','bar'].
export function hashParts() {
  const h = location.hash.replace(/^#\/?/, '');
  return h.length ? h.split('/').map(decodeURIComponent) : [];
}

export function go(hash) {
  location.hash = hash;
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
