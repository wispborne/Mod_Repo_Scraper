// Shared helpers for DOM elements, API requests and in-page dialogs.

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

/// A dialog in the page. Resolves true on confirm, false on Cancel or Escape.
/// Blank lines split the message into paragraphs. The confirm button has the
/// focus, so Enter confirms.
export function askDialog({ title, message, confirmLabel = 'Yes', cancelLabel = 'Cancel' }) {
  return new Promise((resolve) => {
    const box = el('dialog', { class: 'dialog' });
    const yes = el('button', { class: 'button primary', text: confirmLabel });
    yes.addEventListener('click', () => box.close('yes'));
    const buttons = el('div', { class: 'dialog-buttons' });
    if (cancelLabel != null) {
      const no = el('button', { class: 'button', text: cancelLabel });
      no.addEventListener('click', () => box.close(''));
      buttons.append(no);
    }
    buttons.append(yes);

    box.append(el('h2', { text: title }));
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

export function noticeDialog(title, message) {
  return askDialog({ title, message, confirmLabel: 'OK', cancelLabel: null });
}

/// A time as "5 Nov 23:07", in the reader's own time zone.
export function shortTime(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleString(undefined, {
    day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', hour12: false,
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
