// Edits are queued as manager jobs so they share the data lock and run history.

import { api, el, clear, missingPanel, MissingFile, breadcrumbs, go } from '../lib.js';
import * as manager from '../manager.js';

const MATCH_LABELS = {
  unmatched: 'Unmatched',
  llm: 'LLM',
  hand: 'Manual override',
  rule: 'Rules',
};
const FILTERS = [['all', 'All'], ...Object.entries(MATCH_LABELS)];

// Keep unsaved edits when navigating away from the page.
const pending = new Map();

export async function render(root) {
  clear(root);
  root.append(breadcrumbs([{ label: 'Dependencies' }]));
  root.append(el('h1', { text: 'Dependencies' }));

  const body = await api('requirement-names');
  if (body instanceof MissingFile) return root.append(missingPanel(body));

  const status = manager.status() || await manager.refresh();
  const managerOn = !!status?.on;
  const report = body.report;
  const mods = report?.mods || [];
  const modNames = new Map(mods.map((m) => [m.id, m.name]));
  const rows = rowsOf(report, body.saved || []);

  const page = el('div', { class: 'stack' });
  page.append(el('p', {
    class: 'takedown-intro',
    text: 'Match dependency names from posts to catalog mods. '
      + 'Manual overrides take priority over rules and LLM matches.',
  }));
  if (body.error) {
    page.append(el('div', { class: 'missing error' }, [el('h3', { text: body.error })]));
  }
  if (!report) {
    page.append(el('div', { class: 'missing' }, [
      el('h3', { text: 'No dependency report yet' }),
      el('p', { text: 'Run "Rebuild from saved files" on the Runs and queue page to create it.' }),
    ]));
    root.append(page);
    return;
  }
  page.append(el('div', { class: 'dim', text: `Last build ${new Date(report.builtAt).toLocaleString()}` }));

  const state = { filter: 'all', search: '' };
  const list = el('div');
  const saveBar = el('div', { class: 'req-save-bar' });
  const counts = Object.fromEntries(FILTERS.map(([key]) => [key, 0]));
  for (const row of rows) {
    counts.all++;
    counts[row.by]++;
  }

  const filterButtons = el('div', { class: 'req-filters' });
  const search = el('input', {
    type: 'search',
    placeholder: 'Search dependencies',
    class: 'req-search',
    oninput: () => { state.search = search.value.trim().toLowerCase(); draw(); },
  });
  const drawFilters = () => {
    clear(filterButtons);
    for (const [key, label] of FILTERS) {
      filterButtons.append(el('button', {
        class: `btn req-small${state.filter === key ? ' btn-primary' : ''}`,
        text: `${label} (${counts[key]})`,
        onclick: () => { state.filter = key; drawFilters(); draw(); },
      }));
    }
  };

  const options = el('datalist', { id: 'req-mod-options' },
    mods.map((m) => el('option', { value: m.id, text: m.name })));

  const draw = () => {
    clear(list);
    const shown = rows.filter((row) => (state.filter === 'all' || row.by === state.filter)
      && (!state.search || row.written.toLowerCase().includes(state.search)
        || (row.name || '').toLowerCase().includes(state.search)));
    if (!shown.length) {
      list.append(el('p', { class: 'dim', text: 'No dependencies match these filters.' }));
    } else {
      list.append(el('table', { class: 'req-table' }, [
        el('thead', {}, [el('tr', {}, [
          el('th', { text: 'Name in post' }),
          el('th', { text: 'Mod count' }),
          el('th', { text: 'Matched mod' }),
          el('th', { text: 'Match source' }),
          managerOn ? el('th', { text: 'Change' }) : null,
        ])]),
        el('tbody', {}, shown.map((row) => rowView(row, modNames, managerOn, draw))),
      ]));
    }
    drawSaveBar(saveBar, managerOn, modNames, draw);
  };

  drawFilters();
  page.append(el('div', { class: 'req-toolbar' }, [filterButtons, search]), options, saveBar, list);
  root.append(page);
  draw();
}

// Include saved matches even when no mod used them in the last build.
function rowsOf(report, saved) {
  const rows = (report?.names || []).map((n) => ({ ...n }));
  const keys = new Set(rows.map((r) => r.key));
  const savedByKey = new Map(saved.map((s) => [s.key, s]));
  for (const row of rows) row.saved = savedByKey.get(row.key) || null;
  for (const entry of saved) {
    if (keys.has(entry.key)) continue;
    rows.push({
      key: entry.key,
      written: entry.written,
      count: 0,
      id: entry.id,
      by: entry.by === 'hand' ? 'hand' : (entry.id ? 'llm' : 'unmatched'),
      saved: entry,
    });
  }
  return rows;
}

function rowView(row, modNames, managerOn, redraw) {
  const change = pending.get(row.key);
  const name = row.name || modNames.get(row.id) || row.id;
  const match = row.id
    ? el('a', { href: `#/modrepo?q=${encodeURIComponent(name)}`, text: name, title: row.id })
    : el('span', { class: 'dim', text: row.by === 'unmatched' && row.saved ? 'Not in catalog' : '—' });
  const count = row.count
    ? String(row.count)
    : el('span', { class: 'dim', text: '0', title: 'No mod used this spelling in the last build.' });

  return el('tr', { class: change ? 'req-changed' : '' }, [
    el('td', {}, [el('strong', { text: row.written })]),
    el('td', {}, [count]),
    el('td', {}, [match, change ? el('div', { class: 'req-pending', text: `→ ${describeChange(change, modNames)}` }) : null]),
    el('td', {}, [el('span', { class: `badge ${row.by === 'unmatched' ? 'badge-warning' : 'badge-dim'}`, text: MATCH_LABELS[row.by] || row.by })]),
    managerOn ? el('td', {}, [editControls(row, redraw)]) : null,
  ]);
}

function editControls(row, redraw) {
  const input = el('input', {
    list: 'req-mod-options',
    placeholder: 'Mod ID',
    class: 'req-pick',
    title: 'Type part of a mod\'s name and pick it from the list.',
  });
  const set = (change) => { pending.set(row.key, change); redraw(); };
  return el('div', { class: 'req-edit' }, [
    input,
    el('button', {
      class: 'btn req-small',
      text: 'Match',
      onclick: () => {
        const id = input.value.trim();
        if (id) set({ written: row.written, id });
      },
    }),
    el('button', {
      class: 'btn req-small',
      text: 'Not in catalog',
      title: 'Mark this dependency as absent from the catalog.',
      onclick: () => set({ written: row.written, id: null }),
    }),
    row.saved
      ? el('button', {
        class: 'btn req-small',
        text: 'Clear saved match',
        title: 'Remove the saved match and use the rules. A future LLM run may match it again.',
        onclick: () => set({ written: row.written, forget: true }),
      })
      : null,
    pending.has(row.key)
      ? el('button', { class: 'btn req-small', text: 'Undo', onclick: () => { pending.delete(row.key); redraw(); } })
      : null,
  ]);
}

function describeChange(change, modNames) {
  if (change.forget) return 'clear saved match';
  if (!change.id) return 'not in catalog';
  const name = modNames.get(change.id);
  return name ? `${name} (${change.id})` : `${change.id} (unknown ID)`;
}

function drawSaveBar(bar, managerOn, modNames, redraw) {
  clear(bar);
  if (!managerOn || !pending.size) return;
  const unknown = [...pending.values()].filter((c) => !c.forget && c.id && !modNames.has(c.id));
  bar.append(...[
    el('span', { text: `${pending.size} unsaved ${pending.size === 1 ? 'change' : 'changes'}` }),
    unknown.length
      ? el('span', { class: 'takedown-warning-text', text: `${unknown.length} unknown mod ${unknown.length === 1 ? 'ID' : 'IDs'}` })
      : null,
    el('button', {
      class: 'btn btn-primary',
      text: 'Save and rebuild website',
      disabled: unknown.length ? 'true' : null,
      onclick: async () => {
        const request = { kind: 'setRequirementNames', requirementChanges: [...pending.values()] };
        const run = await manager.confirmAndSubmit(request);
        if (!run) return;
        pending.clear();
        go(`#/runs/${run.id}`);
      },
    }),
    el('button', { class: 'btn', text: 'Discard changes', onclick: () => { pending.clear(); redraw(); } }),
  ].filter(Boolean));
}
