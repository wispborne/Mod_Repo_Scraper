// Files: the output files and caches the viewer can show, and each one as raw
// text.
//   #/files          the list with size and date
//   #/files/<id>     the file as text, in the parts the server sends; a file
//                    that fits in one part is shown whole, as formatted JSON
//                    when it is JSON. The address stores the part's start.

import { el, api, breadcrumbs, rawJson } from '../lib.js';
import { pageLayout } from '../frame.js';
import { hashQuery, buildHash } from '../routes.js';
import { badge, emptyLine, fieldList, when } from '../post_parts.js';

const SLICE = 256 * 1024;
const PRETTY_LIMIT = 5 * 1024 * 1024;

export function render(ctx) {
  if (ctx.parts.length) return viewer(ctx, ctx.parts[0]);
  return list(ctx);
}

/// "1.4 MB".
function fmtBytes(n) {
  if (n == null || Number.isNaN(n)) return '—';
  const units = ['B', 'KB', 'MB', 'GB'];
  let i = 0;
  let v = n;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i += 1;
  }
  return `${v.toFixed(i === 0 ? 0 : 1)} ${units[i]}`;
}

async function list({ content }) {
  const main = el('div', { class: 'list-page fl-page' }, [el('p', { class: 'empty pl-message', text: 'Loading…' })]);
  content.append(pageLayout(main));
  let data;
  try {
    data = await api('files', { pageSize: 0 });
  } catch (err) {
    main.replaceChildren(el('p', { class: 'error-text', text: err.message }));
    return;
  }
  const items = (data && data.items) || [];
  const rows = items.map((f) => {
    const href = `#/files/${encodeURIComponent(f.id)}`;
    const tr = el('tr', { class: f.exists ? 'clickable' : '' }, [
      el('td', {}, [f.exists ? el('a', { class: 'fl-name', href, text: f.id }) : el('span', { class: 'fl-name', text: f.id })]),
      el('td', { class: 'mono dim fl-path', text: f.path }),
      el('td', { class: 'num mono', text: f.exists ? fmtBytes(f.size) : '—' }),
      el('td', { class: 'mono', text: (f.exists && when(f.mtime)) || '—' }),
      el('td', {}, [f.exists ? badge('on disk', 'good') : el('span', { title: f.hint || '' }, [badge('missing')])]),
    ]);
    if (f.exists) {
      tr.addEventListener('click', (e) => {
        if (e.target.closest('a, button')) return;
        location.hash = href;
      });
    }
    return tr;
  });
  main.replaceChildren(
    items.length
      ? el('div', { class: 'table-wrap' }, [
        el('table', { class: 'table fl-table' }, [
          el('thead', {}, el('tr', {}, [
            el('th', { text: 'File' }),
            el('th', { text: 'Path' }),
            el('th', { class: 'num', text: 'Size' }),
            el('th', { text: 'Modified' }),
            el('th', { text: '' }),
          ])),
          el('tbody', {}, rows),
        ]),
      ])
      : el('p', { class: 'empty pl-message', text: 'No files.' }),
  );
}

async function viewer({ content }, id) {
  const crumbs = breadcrumbs([{ label: 'Files', href: '#/files' }, { label: id }]);
  const facts = el('div');
  const status = el('p', { class: 'mono dim fl-status' });
  const nav = el('div');
  const pre = el('pre', { class: 'log fl-text' });
  const rawSlot = el('div', { class: 'raw-slot' });
  const main = el('div', { class: 'pp-page fl-page' }, [crumbs, facts, status, nav, pre, rawSlot]);
  content.append(pageLayout(main));
  const gone = () => !main.isConnected;

  // The list entry gives the path and date, and is the raw JSON at the end.
  api('files', { pageSize: 0 }).then((data) => {
    const entry = ((data && data.items) || []).find((f) => f.id === id);
    if (gone() || !entry) return;
    facts.replaceChildren(el('header', { class: 'pp-head' }, [
      el('h2', { class: 'pp-title', text: id }),
      fieldList([
        ['Path', entry.path],
        ['Size', entry.exists ? fmtBytes(entry.size) : null],
        ['Modified', entry.exists ? when(entry.mtime) : null],
      ]),
    ]));
    rawSlot.replaceChildren(rawJson(entry, 'Raw file details (JSON)'));
  }).catch(() => {});

  const goTo = async (offset) => {
    let data;
    try {
      data = await api(`files/${encodeURIComponent(id)}`, { offset, length: SLICE });
    } catch (err) {
      if (gone()) return;
      main.replaceChildren(crumbs, el('p', { class: 'error-text', text: err.message }));
      return;
    }
    if (gone()) return;
    if (data.missing) {
      main.replaceChildren(crumbs, el('div', { class: 'pp-missing' }, [
        el('p', { text: `${data.file} is unavailable` }),
        el('p', { class: 'dim', text: data.hint || 'Run the scraper to produce it.' }),
      ]));
      return;
    }
    // Keep the part's start in the address, so a reload shows the same part.
    if (location.hash.split('?')[0] === `#/files/${encodeURIComponent(id)}`) {
      history.replaceState(null, '', buildHash(['files', id], { offset: data.offset > 0 ? data.offset : null }));
    }

    // A small file fetched whole is shown as formatted JSON when it is JSON.
    if (data.offset === 0 && data.eof && data.totalSize < PRETTY_LIMIT) {
      nav.replaceChildren();
      status.textContent = `${fmtBytes(data.totalSize)} · complete file`;
      pre.textContent = tryPretty(data.content);
      return;
    }

    status.textContent = `${fmtBytes(data.totalSize)} · ${data.length} bytes from offset ${data.offset} · plain text`;
    pre.textContent = data.content;
    const button = (text, disabled, target) => el('button', {
      type: 'button',
      class: 'button quiet',
      text,
      disabled,
      onclick: () => goTo(target),
    });
    nav.replaceChildren(el('div', { class: 'pager' }, [
      button('‹ Previous', data.offset <= 0, Math.max(0, data.offset - SLICE)),
      el('span', { class: 'pager-info', text: `Byte offset ${data.offset}` }),
      button('Next ›', data.eof, data.offset + data.length),
    ]));
  };

  const start = Math.max(0, parseInt(hashQuery(location.hash).get('offset'), 10) || 0);
  pre.textContent = '';
  status.textContent = 'Loading…';
  await goTo(start);
  if (gone()) return;
  if (!pre.textContent && !main.querySelector('.pp-missing, .error-text')) pre.replaceWith(emptyLine('The file is empty.'));
}

function tryPretty(text) {
  try {
    return JSON.stringify(JSON.parse(text), null, 2);
  } catch {
    return text;
  }
}
