// #/modrepo — ModRepo.json browser (4.2).
//   #/modrepo            searchable, paged mod table
//   #/modrepo/<index>    one merged mod, with source provenance

import { api, el, clear, missingPanel, MissingFile, pager, go } from '../lib.js';

const state = { q: '', page: 0, pageSize: 50 };

export async function render(root, parts) {
  clear(root);
  if (parts.length) return detail(root, parts[0]);

  root.append(el('h1', { text: 'ModRepo (merged output)' }));
  const toolbar = el('div', { class: 'toolbar' });
  const search = el('input', { type: 'search', placeholder: 'Search name or author…', value: state.q });
  let d;
  search.addEventListener('input', () => {
    clearTimeout(d);
    d = setTimeout(() => { state.q = search.value.trim(); state.page = 0; load(); }, 250);
  });
  toolbar.append(search);
  root.append(toolbar);
  const results = el('div', {});
  root.append(results);

  async function load() {
    clear(results).append(el('div', { class: 'loading', text: 'Loading…' }));
    const data = await api('modrepo', { q: state.q, page: state.page, pageSize: state.pageSize });
    clear(results);
    if (data instanceof MissingFile) return results.append(missingPanel(data));

    const wrap = el('div', { class: 'table-wrapper' });
    const table = el('table');
    table.append(el('thead', {}, el('tr', {}, [
      el('th', { text: 'Name' }), el('th', { text: 'Authors' }),
      el('th', { text: 'Game ver' }), el('th', { text: 'Sources' }),
    ])));
    const tb = el('tbody');
    for (const m of data.items) {
      tb.append(el('tr', { class: 'clickable', onclick: () => go(`#/modrepo/${m.index}`) }, [
        el('td', { text: m.name || '(empty)' }),
        el('td', { text: (m.authorsList || []).join(', ') }),
        el('td', { text: m.gameVersionReq || '—' }),
        el('td', {}, (m.sources || []).map((s) => el('span', { class: 'badge badge-secondary', text: s, style: 'margin-right:3px;' }))),
      ]));
    }
    table.append(tb);
    wrap.append(table);
    results.append(wrap);
    if (!data.items.length) results.append(el('p', { class: 'loading', text: 'No mods match.' }));
    results.append(pager(data.page, data.pageSize, data.total, (p) => { state.page = p; load(); }));
  }
  load();
}

async function detail(root, index) {
  root.append(el('a', { class: 'back-link', href: '#/modrepo', text: '‹ Back to ModRepo' }));
  const mod = await api(`modrepo/${encodeURIComponent(index)}`);
  if (mod instanceof MissingFile) return root.append(missingPanel(mod));
  if (mod.error) return root.append(el('div', { class: 'missing error' }, el('h3', { text: mod.error })));

  root.append(el('h1', { text: mod.name || '(empty)' }));

  const list = el('ul', { class: 'field-list' });
  const rows = [
    ['Authors', (mod.authorsList || []).join(', ')],
    ['Game version', mod.gameVersionReq],
    ['Mod version', mod.modVersion],
    ['Categories', (mod.categories || []).join(', ')],
    ['Summary', mod.summary],
  ];
  for (const [label, value] of rows) {
    if (!value) continue;
    list.append(el('li', {}, [el('span', { class: 'field-label', text: label }), el('span', { class: 'field-value', text: value })]));
  }
  root.append(list);

  root.append(el('h3', { text: 'Contributing sources' }));
  root.append(el('div', { class: 'meta-chips' }, (mod.sources || []).map((s) => el('span', { class: 'badge badge-primary', text: s }))));
  if (!(mod.sources || []).length) root.append(el('p', { class: 'loading', text: 'No sources listed.' }));

  if (mod.urls) {
    root.append(el('h3', { text: 'URLs' }));
    const ul = el('ul', { class: 'field-list' });
    for (const [type, url] of Object.entries(mod.urls)) {
      ul.append(el('li', {}, [el('span', { class: 'field-label', text: type }), el('a', { class: 'field-value', href: url, target: '_blank', text: url })]));
    }
    root.append(ul);
  }

  // Link into the merge explorer for per-source field values, only when the
  // merge debug file is present (per updated spec).
  const summary = await api('merge/summary');
  if (!(summary instanceof MissingFile)) {
    root.append(el('p', { style: 'margin-top:16px;' },
      el('a', {
        href: '#/merge/groups',
        text: '→ Find this mod\'s merge group (per-source field values)',
        onclick: () => sessionStorage.setItem('mergeGroupSearch', mod.name || ''),
      })));
  }
}
