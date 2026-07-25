// The two "before and after" pages of the Merge Explorer:
//   #/merge/groups/<id>/fields   what each source put in, and what came out
//   #/merge/changes              what changed between two saved merges
//
// Which two merges are compared, the search, the filter and the page all ride
// in the hash query (#/merge/changes?a=…&b=…), so a comparison can be
// bookmarked and shared.

import {
  api, el, clear, missingPanel, MissingFile, pager, pageSizePreference,
  hashQuery, buildHash, replaceHash,
} from '../lib.js';
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

const state = { a: '', b: '', q: '', kind: '', page: 0, pageSize: 50 };

export async function changesPage(body) {
  const query = hashQuery();
  state.a = query.get('a') || '';
  state.b = query.get('b') || '';
  state.q = (query.get('q') || '').trim();
  state.kind = query.get('kind') || '';
  state.page = Math.max(0, parseInt(query.get('page'), 10) || 0);
  state.pageSize = pageSizePreference();

  const data = await loadRuns();
  const runs = data.items || [];
  if (runs.length < 2) {
    return body.append(el('div', { class: 'missing' }, [
      el('h3', { text: 'Two saved merges are needed to compare' }),
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
  if (!runs.some((r) => r.id === state.a) || state.a === state.b) {
    state.a = runs.find((r) => r.id !== state.b).id;
  }

  body.append(el('p', {
    class: 'run-when',
    text: 'Every merge keeps a snapshot of what came out of it. '
      + 'Pick two and see what changed between them.',
  }));

  const selects = {};
  const pickerFor = (which) => {
    const select = el('select', { class: 'field-input' });
    for (const run of runs) {
      select.append(el('option', { value: run.id, text: runLabel(run) }));
    }
    select.value = state[which];
    select.addEventListener('change', () => {
      // Picking the merge already on the other side swaps the two, rather
      // than comparing a merge with itself.
      const other = which === 'a' ? 'b' : 'a';
      if (select.value === state[other]) {
        selects[other].value = state[which];
        state[other] = state[which];
      }
      state[which] = select.value;
      state.page = 0;
      load();
    });
    selects[which] = select;
    return select;
  };

  const swap = el('button', {
    class: 'btn',
    text: 'Swap',
    title: 'Switch which merge counts as older and which as newer.',
    onclick: () => {
      [state.a, state.b] = [state.b, state.a];
      selects.a.value = state.a;
      selects.b.value = state.b;
      state.page = 0;
      load();
    },
  });

  body.append(el('div', { class: 'toolbar' }, [
    el('span', { class: 'field-label', text: 'Older' }),
    pickerFor('a'),
    swap,
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

  const counts = el('div', { class: 'stat-grid' });
  const results = el('div', {});
  body.append(el('div', { class: 'toolbar' }, [search]));
  body.append(counts, results);

  function syncUrl() {
    replaceHash(buildHash(['merge', 'changes'], {
      a: state.a,
      b: state.b,
      q: state.q,
      kind: state.kind,
      page: state.page || '',
    }));
  }

  async function load() {
    syncUrl();
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
    if (state.kind) {
      results.append(el('p', {
        class: 'run-when',
        text: `Showing only the ${kindWord(state.kind)} mods — click the `
          + 'highlighted card again to show everything.',
      }));
    }
    for (const row of answer.items || []) {
      results.append(changeCard(row));
    }
    if (!(answer.items || []).length) {
      results.append(el('p', {
        class: 'loading',
        text: state.q || state.kind
          ? 'Nothing matches this search or filter.'
          : 'These two merges are the same — nothing was added, removed '
            + 'or changed.',
      }));
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

  function drawCounts(node, answer) {
    for (const [kind, label, value, cls] of [
      ['added', 'Added', answer.addedCount, 'success'],
      ['gone', 'Removed', answer.goneCount, 'error'],
      ['changed', 'Changed', answer.changedCount, 'warning'],
      ['', 'Unchanged', answer.sameCount, ''],
    ]) {
      const filtering = kind !== '';
      node.append(el('div', {
        class: 'stat-card'
          + (value ? ` ${cls}` : '')
          + (filtering ? ' stat-card-filter' : '')
          + (filtering && state.kind === kind ? ' on' : ''),
        title: filtering ? `Show only the ${kindWord(kind)} mods.` : null,
        onclick: filtering ? () => {
          state.kind = state.kind === kind ? '' : kind;
          state.page = 0;
          load();
        } : null,
      }, [
        el('div', { class: 'label', text: label }),
        el('div', { class: 'value', text: String(value ?? '—') }),
      ]));
    }
  }

  load();
}

const forumTopic = /topic=(\d+)/;

function changeCard(row) {
  const mod = row.mod || {};
  const changes = row.changes || [];
  const card = el('details', { class: 'change-card' });
  card.append(el('summary', {}, [
    el('span', { class: 'badge ' + kindBadge(row.kind), text: kindWord(row.kind) }),
    el('span', { class: 'change-name', text: row.name || '(no name)' }),
    el('span', { class: 'change-author', text: row.authors || '' }),
    el('span', {
      class: 'change-hint',
      text: changes.length
        ? `${changes.length} field${changes.length === 1 ? '' : 's'}`
        : '',
    }),
    el('span', { class: 'chev', text: '▸' }),
  ]));

  const inner = el('div', { class: 'change-body' });
  const topic = (((mod.urls || {}).Forum || '').match(forumTopic) || [])[1];
  if (topic) {
    inner.append(el('a', {
      href: `#/topics/${encodeURIComponent(topic)}`,
      text: `Open thread ${topic}`,
    }));
  }
  if (row.note) inner.append(el('p', { class: 'change-note', text: row.note }));
  if (changes.length) inner.append(diffTable(changes));
  if (!changes.length && mod.urls) {
    // An added or removed mod has no field changes; its links say which mod
    // this is.
    inner.append(el('p', { class: 'change-note', text: cellText(mod.urls) }));
  }
  card.append(inner);
  return card;
}

/// One row per changed field, the older value beside the newer one.
function diffTable(changes) {
  const table = el('table', { class: 'diff-table' });
  table.append(el('thead', {}, el('tr', {}, [
    el('th', { text: 'Field' }),
    el('th', { text: 'Older' }),
    el('th', { text: 'Newer' }),
  ])));
  const tbody = el('tbody');
  for (const change of changes) {
    const tr = el('tr', {});
    tr.append(el('td', { class: 'diff-field', text: change.field }));
    if (change.note) {
      // A field where the two values are no use on screen.
      tr.append(el('td', { class: 'change-note', colspan: '2', text: change.note }));
    } else {
      tr.append(el('td', { class: 'diff-before', text: diffText(change.before) }));
      tr.append(el('td', { class: 'diff-after', text: diffText(change.after) }));
    }
    tbody.append(tr);
  }
  table.append(tbody);
  return el('div', { class: 'table-wrapper' }, table);
}

/// Like cellText, but tells "not there" apart from "there but empty" — a row
/// where both sides read "—" would look like nothing changed — and reads
/// booleans out as words.
function diffText(value) {
  if (Array.isArray(value) && !value.length) return '(empty list)';
  if (value === '') return '(empty)';
  if (value === true) return 'yes';
  if (value === false) return 'no';
  return cellText(value);
}

function kindWord(kind) {
  return { added: 'added', gone: 'removed', changed: 'changed' }[kind] || kind;
}

function kindBadge(kind) {
  return {
    added: 'badge-success',
    gone: 'badge-error',
    changed: 'badge-warning',
  }[kind] || 'badge-dim';
}
