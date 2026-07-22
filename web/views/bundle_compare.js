// #/bundle/changes — what changed between two saved bundles.
//
// A bundle snapshot is saved by every run that publishes one, so this answers
// "what did that run actually change?". The posts' text is not kept in a
// snapshot, so a changed post is reported as changed and no more — the page
// says so, rather than leaving somebody hunting for a before and after that was
// never saved.

import {
  api, el, clear, missingPanel, MissingFile, pager, pageSizePreference,
} from '../lib.js';
import { cellText } from './merge_shared.js';

const state = { a: '', b: '', q: '', kind: '', page: 0, pageSize: pageSizePreference() };

/// Which two runs to compare, when arriving from somewhere that already knows —
/// the "what did this run change?" link on a run's page.
export function compareRuns(older, newer) {
  state.a = older || '';
  state.b = newer || '';
  state.q = '';
  state.kind = '';
  state.page = 0;
}

export async function changesPage(body) {
  const data = await api('bundle/runs');
  const runs = data instanceof MissingFile ? [] : (data.items || []);
  if (runs.length < 2) {
    return body.append(el('div', { class: 'missing' }, [
      el('h3', { text: 'Two saved bundles are needed to compare' }),
      el('p', {
        text: runs.length === 1
          ? 'Only one bundle has been saved so far. Run the scraper again and '
            + 'this page will show what changed.'
          : 'No bundles have been saved yet. Run the scraper and one will be '
            + 'saved for you.',
      }),
    ]));
  }

  // Newest against the one before it — the comparison people want most.
  if (!runs.some((r) => r.id === state.b)) state.b = runs[0].id;
  if (!runs.some((r) => r.id === state.a) || state.a === state.b) {
    state.a = runs.find((r) => r.id !== state.b).id;
  }

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
    placeholder: 'Search mod title or author…',
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
      ['gone', 'Gone'],
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
    const answer = await api('bundle/compare', {
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

/// How a saved bundle reads in a picker: when the run was, and how big it was.
function runLabel(run) {
  const when = run.savedAt ? new Date(run.savedAt).toLocaleString() : run.id;
  return run.indexCount != null ? `${when} — ${run.indexCount} topics` : when;
}

function drawCounts(node, answer) {
  for (const [label, value, cls] of [
    ['Added', answer.addedCount, answer.addedCount ? 'warning' : ''],
    ['Gone', answer.goneCount, answer.goneCount ? 'error' : ''],
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
  const topic = row.topic || {};
  card.append(el('summary', {}, [
    el('span', { class: 'badge ' + kindBadge(row.kind), text: kindWord(row.kind) }),
    ` ${row.name || '(no title)'} `,
    el('span', { class: 'field-value', text: row.authors || '' }),
  ]));

  const inner = el('div', {});
  if (topic.topicId != null) {
    inner.append(el('a', {
      href: `#/topics/${encodeURIComponent(topic.topicId)}`,
      text: `Open thread ${topic.topicId}`,
    }));
  }
  if (row.note) inner.append(el('p', { class: 'field-value', text: row.note }));

  for (const change of row.changes || []) {
    const box = el('div', { class: 'field-value', style: 'margin-top:6px;' });
    box.append(el('strong', { text: change.field }));
    if (change.note) {
      // A field where the two values are no use on screen — the post text.
      box.append(el('div', { text: change.note }));
    } else {
      box.append(el('div', { text: `before: ${cellText(change.before)}` }));
      box.append(el('div', { text: `after: ${cellText(change.after)}` }));
    }
    inner.append(box);
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
