// The two "before and after" pages of the Merge Explorer:
//   #/merge/groups/<id>/fields   what each source put in, and what came out
//   #/merge/changes              what changed between two saved merges

import { api, el, clear, missingPanel, MissingFile, pager, pageSizePreference } from '../lib.js';
import { withRun, loadRuns, runLabel, cellText } from './merge_shared.js';

// --- Before and after, field by field ---

/// The badge saying where a value came from.
function fromBadge(row, members) {
  const from = row.from || [];
  switch (row.verdict) {
    case 'one':
      return el('span', {
        class: 'badge badge-primary',
        text: memberName(members, from[0]),
      });
    case 'agreed':
      return el('span', { class: 'badge badge-secondary', text: 'they agreed' });
    case 'empty':
      return el('span', { class: 'badge badge-dim', text: 'nothing to take' });
    default:
      return el('span', { class: 'badge badge-warning', text: "couldn't tell" });
  }
}

function memberName(members, index) {
  const member = (members || [])[index];
  if (!member) return `entry ${index}`;
  const sources = (member.sources || []).join(', ');
  return sources ? `from ${sources}` : member.name || `entry ${index}`;
}

function memberHeading(member) {
  const sources = (member.sources || []).join(', ') || '?';
  return `${member.name || '(no name)'} [${sources}]`;
}

export async function groupFields(body, id) {
  body.append(el('a', {
    class: 'back-link',
    href: `#/merge/groups/${encodeURIComponent(id)}`,
    text: '‹ Back to the group',
  }));

  const data = await api(
    `merge/groups/${encodeURIComponent(id)}/fields`, withRun());
  if (data instanceof MissingFile) return body.append(missingPanel(data));
  if (data.error) {
    return body.append(
      el('div', { class: 'missing error' }, el('h3', { text: data.error })));
  }

  const members = data.members || [];
  body.append(el('h2', { text: `Before and after — group #${data.groupIndex}` }));
  body.append(el('p', {
    class: 'run-when',
    text: data.wasMerged
      ? `${members.length} entries went in and one mod came out. Each row shows `
        + 'what every entry had and where the final value came from.'
      : 'Only one entry went in, so nothing was merged. These are its values.',
  }));

  const wrap = el('div', { class: 'table-wrapper' });
  const table = el('table');
  table.append(el('thead', {}, el('tr', {}, [
    el('th', { text: 'Field' }),
    ...members.map((m) => el('th', { text: memberHeading(m) })),
    el('th', { text: 'Came out as' }),
    el('th', { text: 'From' }),
  ])));

  const tbody = el('tbody');
  for (const row of data.rows || []) {
    const tr = el('tr', {});
    tr.append(el('td', {}, el('strong', { text: row.field })));
    for (const value of row.values || []) {
      tr.append(el('td', { class: 'field-value', text: cellText(value.value) }));
    }
    tr.append(el('td', { class: 'field-value', text: cellText(row.final) }));
    tr.append(fromCell(row, members));
    tbody.append(tr);
  }
  table.append(tbody);
  wrap.append(table);
  body.append(wrap);
}

/// Lists and maps are answered entry by entry: a merged one usually takes a bit
/// from each side, so one badge for the whole field would be a lie.
function fromCell(row, members) {
  if (row.kind === 'scalar') return el('td', {}, fromBadge(row, members));

  const cell = el('td', {});
  for (const entry of row.entries || []) {
    const label = entry.key != null ? `${entry.key}: ${entry.value}` : `${entry.value}`;
    cell.append(el('div', { class: 'field-value' }, [
      el('span', { text: `${label} ` }),
      fromBadge(entry, members),
    ]));
  }
  if (!(row.entries || []).length) {
    cell.append(el('span', { class: 'badge badge-dim', text: 'nothing to take' }));
  }
  return cell;
}

// --- What changed between two merges ---

const state = { a: '', b: '', q: '', kind: '', page: 0, pageSize: pageSizePreference() };

export async function changesPage(body) {
  const data = await loadRuns();
  const runs = data.items || [];
  if (runs.length < 2) {
    return body.append(el('div', { class: 'missing' }, [
      el('h3', { text: 'Two merges are needed to compare' }),
      el('p', {
        text: runs.length === 1
          ? 'Only one merge has been saved so far. Run another one and this page '
            + 'will show what changed.'
          : 'No merges have been saved yet. Run a merge from the Runs page.',
      }),
    ]));
  }

  // Newest against the one before it — the comparison people want most.
  if (!runs.some((r) => r.id === state.b)) state.b = runs[0].id;
  if (!runs.some((r) => r.id === state.a)) state.a = runs[1].id;

  const pickerFor = (which) => {
    const select = el('select', { class: 'field-input' });
    for (const run of runs) {
      select.append(el('option', { value: run.id, text: runLabel(run) }));
    }
    select.value = state[which];
    select.addEventListener('change', () => {
      state[which] = select.value;
      state.page = 0;
      load();
    });
    return select;
  };

  body.append(el('div', { class: 'toolbar' }, [
    el('span', { class: 'field-label', text: 'Older' }),
    pickerFor('a'),
    el('span', { class: 'field-label', text: 'Newer' }),
    pickerFor('b'),
  ]));

  const search = el('input', {
    type: 'search',
    placeholder: 'Search mod name or author…',
    value: state.q,
  });
  let typing;
  search.addEventListener('input', () => {
    clearTimeout(typing);
    typing = setTimeout(() => {
      state.q = search.value.trim();
      state.page = 0;
      load();
    }, 250);
  });

  const kindChips = el('span', {});
  const counts = el('div', { class: 'stat-grid' });
  const results = el('div', {});
  body.append(el('div', { class: 'toolbar' }, [search, kindChips]));
  body.append(counts, results);

  function drawKindChips() {
    clear(kindChips);
    for (const [value, label] of [
      ['', 'Everything'],
      ['added', 'Added'],
      ['gone', 'Removed'],
      ['changed', 'Changed'],
    ]) {
      kindChips.append(el('span', {
        class: 'chip' + (state.kind === value ? ' on' : ''),
        text: label,
        onclick: () => {
          state.kind = value;
          state.page = 0;
          load();
        },
      }));
    }
  }

  async function load() {
    drawKindChips();
    clear(results).append(el('div', { class: 'loading', text: 'Loading…' }));
    const answer = await api('merge/compare', {
      a: state.a,
      b: state.b,
      q: state.q,
      kind: state.kind,
      page: state.page,
      pageSize: state.pageSize,
    });
    clear(results);
    clear(counts);
    if (answer instanceof MissingFile) return results.append(missingPanel(answer));

    drawCounts(counts, answer);
    for (const row of answer.items || []) {
      results.append(changeCard(row));
    }
    if (!(answer.items || []).length) {
      results.append(el('p', { class: 'loading', text: 'Nothing to show here.' }));
    }
    results.append(pager(answer.page, answer.pageSize, answer.total, (p) => {
      state.page = p;
      load();
    }, (size) => {
      state.pageSize = size;
      state.page = 0;
      load();
    }));
  }

  load();
}

function drawCounts(node, answer) {
  for (const [label, value, cls] of [
    ['Added', answer.addedCount, answer.addedCount ? 'warning' : ''],
    ['Removed', answer.goneCount, answer.goneCount ? 'error' : ''],
    ['Changed', answer.changedCount, ''],
    ['Unchanged', answer.sameCount, ''],
  ]) {
    node.append(el('div', { class: 'stat-card ' + cls }, [
      el('div', { class: 'label', text: label }),
      el('div', { class: 'value', text: String(value ?? '—') }),
    ]));
  }
}

function changeCard(row) {
  const card = el('details', { class: 'panel', style: 'margin-bottom:8px;' });
  card.append(el('summary', {}, [
    el('span', { class: 'badge ' + kindBadge(row.kind), text: kindWord(row.kind) }),
    ` ${row.name || '(no name)'} `,
    el('span', { class: 'field-value', text: row.authors || '' }),
  ]));

  const inner = el('div', {});
  if (row.note) inner.append(el('p', { class: 'field-value', text: row.note }));
  for (const change of row.changes || []) {
    inner.append(el('div', { class: 'field-value' }, [
      el('strong', { text: change.field }),
      el('div', { text: `before: ${cellText(change.before)}` }),
      el('div', { text: `after: ${cellText(change.after)}` }),
    ]));
  }
  if (row.kind !== 'changed') {
    inner.append(el('div', {
      class: 'field-value',
      text: cellText((row.mod || {}).urls),
    }));
  }
  card.append(inner);
  return card;
}

function kindWord(kind) {
  return { added: 'new', gone: 'gone', changed: 'changed' }[kind] || kind;
}

function kindBadge(kind) {
  return {
    added: 'badge-primary',
    gone: 'badge-error',
    changed: 'badge-secondary',
  }[kind] || 'badge-dim';
}
