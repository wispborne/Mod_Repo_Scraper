// #/modrepo — Mod Catalog: the mod-catalog.json browser.
//   #/modrepo            searchable, paged mod table
//   #/modrepo/<index>    one merged mod, with source provenance

import {
  api, el, clear, missingPanel, MissingFile, pager, pageSizePreference, go,
  noticeDialog, rawJson, hashQuery, buildHash, replaceHash, breadcrumbs,
} from '../lib.js';
import * as manager from '../manager.js';
import { takeDownModButton } from './takedowns.js';

const state = { q: '', page: 0, pageSize: pageSizePreference() };

export async function render(root, parts) {
  clear(root);
  if (parts.length) return detail(root, parts[0]);

  // Restore list state from the URL on reload or back navigation.
  const query = hashQuery();
  state.q = (query.get('q') || '').trim();
  state.page = Math.max(0, parseInt(query.get('page'), 10) || 0);
  state.pageSize = pageSizePreference();

  root.append(breadcrumbs([{ label: 'Mod Catalog' }]));
  root.append(el('h1', { text: 'Mod Catalog' }));
  root.append(el('p', { class: 'run-when', text: 'Merged mods from the forum, Discord, and Nexus.' }));
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

  function syncUrl() {
    replaceHash(buildHash(['modrepo'], { q: state.q, page: state.page || '' }));
  }

  async function load() {
    syncUrl();
    clear(results).append(el('div', { class: 'loading', text: 'Loading…' }));
    const data = await api('modrepo', { q: state.q, page: state.page, pageSize: state.pageSize });
    clear(results);
    if (data instanceof MissingFile) return results.append(missingPanel(data));

    const wrap = el('div', { class: 'table-wrapper' });
    const table = el('table');
    table.append(el('thead', {}, el('tr', {}, [
      el('th', { text: 'Name' }), el('th', { text: 'Authors' }),
      el('th', { text: 'Game version' }), el('th', { text: 'Sources' }),
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
    results.append(pager(data.page, data.pageSize, data.total,
      (p) => { state.page = p; load(); },
      (size) => { state.pageSize = size; state.page = 0; load(); }));
  }
  load();
}

async function detail(root, index) {
  const mod = await api(`modrepo/${encodeURIComponent(index)}`);
  if (mod instanceof MissingFile) {
    root.append(breadcrumbs([{ label: 'Mod Catalog', href: '#/modrepo' }]));
    return root.append(missingPanel(mod));
  }
  if (mod.error) {
    root.append(breadcrumbs([{ label: 'Mod Catalog', href: '#/modrepo' }]));
    return root.append(el('div', { class: 'missing error' }, el('h3', { text: mod.error })));
  }

  root.append(breadcrumbs([{ label: 'Mod Catalog', href: '#/modrepo' }, { label: mod.name || '(empty)' }]));
  root.append(el('h1', { text: mod.name || '(empty)' }));

  // Rebuild the outputs from saved files; fetching is set up on Runs.
  const status = manager.status() || await manager.refresh();
  if (status && status.on) {
    root.append(el('div', { class: 'topic-actions' }, [
      el('button', {
        class: 'btn',
        text: 'Rebuild from saved files',
        title: 'Rebuild every output from saved files. No network or LLM calls.',
        onclick: async () => {
          try {
            const record = await manager.confirmAndSubmit({
              kind: 'rebuildFromSaved',
              collectMergeDebug: true,
            });
            if (record) go(`#/runs/${encodeURIComponent(record.id)}`);
          } catch (err) {
            noticeDialog('Could not start job', err.message);
          }
        },
      }),
      mod.id ? takeDownModButton(mod.id) : null,
    ]));
  }

  const list = el('ul', { class: 'field-list' });
  const rows = [
    ['Permanent id', mod.id],
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

  // Which posts this mod was built from, as the catalog recorded them. A forum
  // topic opens its thread page; a Discord thread opens the LLM's answer.
  if ((mod.sourcePosts || []).length) {
    root.append(el('h3', { text: 'Source posts' }));
    const posts = el('ul', { class: 'field-list' });
    for (const post of mod.sourcePosts) {
      if (!post.id) continue;
      const where = post.kind === 'forum' ? `Forum topic ${post.id}`
        : post.kind === 'discord' ? `Discord thread ${post.id}` : `Nexus page ${post.id}`;
      const href = post.kind === 'forum' ? `#/topics/${encodeURIComponent(post.id)}`
        : post.kind === 'discord' ? `#/discord/${encodeURIComponent(post.id)}` : null;
      const by = post.foundBy === 'llm' ? 'found by the LLM'
        : post.foundBy === 'rulesAndLlm' ? 'found by the rules, joined by the LLM' : 'found by the rules';
      posts.append(el('li', {}, [
        el('span', { class: 'field-label' }, href ? el('a', { href, text: where }) : where),
        el('span', { class: 'field-value', text: post.llmModName ? `"${post.llmModName}" · ${by}` : by }),
      ]));
    }
    root.append(posts);
  }

  root.append(el('h3', { text: 'Sources' }));
  root.append(el('div', { class: 'meta-chips' }, (mod.sources || []).map((s) => el('span', { class: 'badge badge-primary', text: s }))));
  if (!(mod.sources || []).length) root.append(el('p', { class: 'loading', text: 'No sources listed.' }));

  if (mod.urls) {
    root.append(el('h3', { text: 'Links' }));
    const ul = el('ul', { class: 'field-list' });
    for (const [type, url] of Object.entries(mod.urls)) {
      ul.append(el('li', {}, [el('span', { class: 'field-label', text: type }), el('a', { class: 'field-value', href: url, target: '_blank', text: url })]));
    }
    root.append(ul);
  }

  if (mod.discordThreadId) {
    root.append(el('p', {},
      el('a', {
        href: `#/discord/${encodeURIComponent(mod.discordThreadId)}`,
        text: "View Discord thread and LLM results →",
      })));
  }

  // Show the group link only when merge debug data is available.
  const summary = await api('merge/summary');
  if (!(summary instanceof MissingFile)) {
    root.append(el('p', { style: 'margin-top:16px;' },
      el('a', {
        href: '#/merge/groups',
        text: 'View merge group and source values →',
        onclick: () => sessionStorage.setItem('mergeGroupSearch', mod.name || ''),
      })));
  }

  root.append(rawJson(mod, 'Raw mod data (JSON)'));
}
