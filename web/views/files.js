// #/files — raw file list and chunked viewer (4.6).
//   #/files          allowlist with size / mtime / exists
//   #/files/<id>     whole file pretty-printed (< 5 MB), else plain-text slices

import { api, el, clear, missingPanel, MissingFile, fmtBytes, go } from '../lib.js';

const SLICE = 256 * 1024;
const PRETTY_LIMIT = 5 * 1024 * 1024;

export async function render(root, parts) {
  clear(root);
  if (parts.length) return viewer(root, parts[0]);

  root.append(el('h1', { text: 'Output Files' }));
  const data = await api('files');
  if (data instanceof MissingFile) return root.append(missingPanel(data));

  const wrap = el('div', { class: 'table-wrapper' });
  const table = el('table');
  table.append(el('thead', {}, el('tr', {}, [
    el('th', { text: 'File' }), el('th', { text: 'Path' }),
    el('th', { text: 'Size' }), el('th', { text: 'Modified' }), el('th', { text: '' }),
  ])));
  const tb = el('tbody');
  for (const f of data.items) {
    const tr = el('tr', f.exists ? { class: 'clickable', onclick: () => go(`#/files/${f.id}`) } : {});
    tr.append(
      el('td', {}, el('strong', { text: f.id })),
      el('td', { text: f.path }),
      el('td', { class: 'num', text: f.exists ? fmtBytes(f.size) : '—' }),
      el('td', { text: f.mtime || '—' }),
      el('td', {}, f.exists ? el('span', { class: 'badge badge-success', text: 'on disk' }) : el('span', { class: 'badge badge-dim', text: 'missing' })),
    );
    tb.append(tr);
  }
  table.append(tb);
  wrap.append(table);
  root.append(wrap);
}

async function viewer(root, id) {
  root.append(el('a', { class: 'back-link', href: '#/files', text: '‹ Back to files' }));
  root.append(el('h1', { text: id }));
  const status = el('p', { class: 'field-value' });
  const pre = el('pre', { class: 'raw' });
  const nav = el('div', { class: 'pager' });
  root.append(status, nav, pre);

  let offset = 0;

  async function loadSlice(off) {
    const data = await api(`files/${encodeURIComponent(id)}`, { offset: off, length: SLICE });
    if (data instanceof MissingFile) {
      clear(root).append(el('a', { class: 'back-link', href: '#/files', text: '‹ Back to files' }), missingPanel(data));
      return;
    }
    offset = data.offset;

    // Whole small file fetched in one slice → pretty-print JSON when possible.
    if (data.offset === 0 && data.eof && data.totalSize < PRETTY_LIMIT) {
      clear(nav);
      status.textContent = `${fmtBytes(data.totalSize)} · whole file`;
      pre.textContent = tryPretty(data.content);
      return;
    }

    // Large file → plain-text slices with prev/next.
    status.textContent = `${fmtBytes(data.totalSize)} · bytes ${data.offset}–${data.offset + data.length} (plain text, not pretty-printed)`;
    pre.textContent = data.content;
    clear(nav);
    nav.append(
      el('button', { text: '‹ Prev', disabled: data.offset <= 0 ? 'true' : null, onclick: () => loadSlice(Math.max(0, data.offset - SLICE)) }),
      el('span', { class: 'pager-info', text: `offset ${data.offset}` }),
      el('button', { text: 'Next ›', disabled: data.eof ? 'true' : null, onclick: () => loadSlice(data.offset + data.length) }),
    );
  }

  loadSlice(0);
}

function tryPretty(text) {
  try {
    return JSON.stringify(JSON.parse(text), null, 2);
  } catch (_) {
    return text;
  }
}
