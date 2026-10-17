// Merge group field values and saved merge comparisons.
// Comparison state lives in the hash query for bookmarks and shared links.

import {
  api, el, clear, missingPanel, MissingFile, pager, pageSizePreference,
  hashQuery, buildHash, replaceHash, expandAllButton, changedFieldsLine,
  changedFieldsTitle,
} from '../lib.js';
import { withRun, loadRuns, runLabel, cellText } from './merge_shared.js';
import { diffTable } from './diff_table.js';

// --- Before and after, field by field ---

/// Identifies the sources contributing a field value.
function fromBadge(row, members) {
  const from = row.from || [];
  switch (row.verdict) {
    case 'one':
      return el('span', {
        class: 'badge badge-primary',
        text: memberName(members, from[0]),
      });
    case 'agreed':
      return el('span', { class: 'badge badge-secondary', text: 'sources agree' });
    case 'empty':
      return el('span', { class: 'badge badge-dim', text: 'empty' });
    default:
      return el('span', { class: 'badge badge-warning', text: 'source unknown' });
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
  const posts = (member.sourcePosts || [])
    .filter((post) => post && post.id)
    .map((post) => (post.kind === 'forum' ? `topic ${post.id}` : `${post.kind} ${post.id}`)
      + (post.llmModName ? ` "${post.llmModName}"` : ''));
  return `${member.name || '(no name)'} [${sources}]${posts.length ? ` — ${posts.join(', ')}` : ''}`;
}

export async function groupFields(body, id) {
  body.append(el('a', {
    class: 'back-link',
    href: `#/merge/groups/${encodeURIComponent(id)}`,
    text: '‹ Back to group',
  }));

  const data = await api(
    `merge/groups/${encodeURIComponent(id)}/fields`, withRun());
  if (data instanceof MissingFile) return body.append(missingPanel(data));
  if (data.error) {
    return body.append(
      el('div', { class: 'missing error' }, el('h3', { text: data.error })));
  }

  const members = data.members || [];
  body.append(el('h2', { text: `Field comparison — group #${data.groupIndex}` }));
  body.append(el('p', {
    class: 'run-when',
    text: data.wasMerged
      ? `${members.length} entries merged into one mod. Each row shows the `
        + 'source values, final value, and contributing sources.'
      : 'One entry; no merge needed. These are its values.',
  }));

  const wrap = el('div', { class: 'table-wrapper' });
  const table = el('table');
  table.append(el('thead', {}, el('tr', {}, [
    el('th', { text: 'Field' }),
    ...members.map((m) => el('th', { text: memberHeading(m) })),
    el('th', { text: 'Final value' }),
    el('th', { text: 'Source' }),
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

/// Lists and maps can combine sources, so provenance is shown per entry.
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
    cell.append(el('span', { class: 'badge badge-dim', text: 'empty' }));
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
      el('h3', { text: 'Two saved merges needed' }),
      el('p', {
        text: runs.length === 1
          ? 'Only one merge is saved. Run another to compare changes.'
          : 'No merges have been saved yet. Run a merge from the Runs page.',
      }),
    ]));
  }

  // Default to comparing the two newest merges.
  if (!runs.some((r) => r.id === state.b)) state.b = runs[0].id;
  if (!runs.some((r) => r.id === state.a) || state.a === state.b) {
    state.a = runs.find((r) => r.id !== state.b).id;
  }

  body.append(el('p', {
    class: 'run-when',
    text: 'Choose two saved merges to compare their output.',
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
    title: 'Swap older and newer merges.',
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
  const foldAll = expandAllButton(results, 'details.change-card');
  body.append(el('div', { class: 'toolbar' }, [search, foldAll]));
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
        text: `Showing ${kindWord(state.kind)} mods. Click the selected count to clear the filter.`,
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
          : 'No changes between these merges.',
      }));
    }
    foldAll.refresh();
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
        title: filtering ? `Show ${kindWord(kind)} mods.` : null,
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
    el('span', { class: 'chev', text: '▸' }),
    // Place changed fields after the chevron so they wrap below the name.
    // Added and removed mods have no field summary.
    changes.length ? el('span', {
      class: 'change-hint',
      text: changedFieldsLine(changes),
      title: changedFieldsTitle(changes),
    }) : null,
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
