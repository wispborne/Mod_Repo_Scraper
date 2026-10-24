// Compares saved bundle snapshots, or a snapshot against newer on-disk data.
// Snapshots keep text fingerprints rather than old posts. Working comparisons
// update only on Refresh, preserving scroll position and open cards.
// The selected sides, search, filter and page are stored in the hash query.

import {
  api, el, clear, missingPanel, MissingFile, pager, pageSizePreference,
  hashQuery, buildHash, replaceHash, expandAllButton, changedFieldsLine,
  changedFieldsTitle,
} from '../lib.js';
import { diffTable } from './diff_table.js';

/// Current on-disk comparison side, distinct from saved run ids.
const WORKING = 'working';

const state = { a: '', b: '', q: '', kind: '', page: 0, pageSize: 50 };

export async function changesPage(body) {
  const query = hashQuery();
  state.a = query.get('a') || '';
  state.b = query.get('b') || '';
  state.q = (query.get('q') || '').trim();
  state.kind = query.get('kind') || '';
  state.page = Math.max(0, parseInt(query.get('page'), 10) || 0);
  state.pageSize = pageSizePreference();

  const data = await api('bundle/runs');
  const runs = data instanceof MissingFile ? [] : (data.items || []);
  const working = data instanceof MissingFile ? null : (data.working || null);

  // One saved bundle is enough once the data on disk can be the other side.
  if (!runs.length || (runs.length < 2 && !working)) {
    return body.append(el('div', { class: 'missing' }, [
      el('h3', { text: 'Nothing to compare yet' }),
      el('p', {
        text: runs.length === 1
          ? 'Only one snapshot is saved, and there is no local data to compare. '
            + 'Run the scraper to create another snapshot.'
          : 'No snapshots have been saved yet. Run the scraper to save one.',
      }),
    ]));
  }

  if (state.b === WORKING && !working) state.b = '';
  // Default to the two newest snapshots, or one snapshot and working data.
  if (state.b !== WORKING && !runs.some((r) => r.id === state.b)) {
    state.b = runs.length > 1 || !working ? runs[0].id : WORKING;
  }
  if (state.b === WORKING) {
    // Default working comparisons to the newest saved bundle.
    if (!runs.some((r) => r.id === state.a)) state.a = runs[0].id;
  } else if (!runs.some((r) => r.id === state.a) || state.a === state.b) {
    state.a = runs.find((r) => r.id !== state.b).id;
  }

  body.append(el('p', {
    class: 'run-when',
    text: 'Compare two snapshots, or compare a snapshot with current local data.',
  }));

  const selects = {};
  const pickerFor = (which) => {
    const select = el('select', { class: 'field-input' });
    // Working data is allowed only on the newer side.
    if (which === 'b' && working) {
      select.append(el('option', { value: WORKING, text: workingLabel(working) }));
    }
    for (const run of runs) {
      select.append(el('option', { value: run.id, text: runLabel(run) }));
    }
    select.value = state[which];
    select.addEventListener('change', () => {
      const leaving = state[which];
      state[which] = select.value;
      if (state.a === state.b) settleSameSide(which, leaving);
      state.page = 0;
      syncSwap();
      syncRefresh();
      load();
    });
    selects[which] = select;
    return select;
  };

  const swap = el('button', {
    class: 'btn',
    text: 'Swap',
    title: 'Swap older and newer snapshots.',
    onclick: () => {
      if (state.b === WORKING) return;
      [state.a, state.b] = [state.b, state.a];
      selects.a.value = state.a;
      selects.b.value = state.b;
      state.page = 0;
      syncSwap();
      syncRefresh();
      load();
    },
  });

  // Working data is allowed only on the newer side.
  function syncSwap() {
    const off = state.b === WORKING;
    swap.disabled = off;
    swap.title = off
      ? 'Current local data can only be the newer side.'
      : 'Swap older and newer snapshots.';
  }
  /// Prevents self-comparison by swapping saved sides. When leaving working
  /// data, choose another older snapshot: working data cannot become older.
  function settleSameSide(which, leaving) {
    const other = which === 'a' ? 'b' : 'a';
    if (leaving !== WORKING) {
      state[other] = leaving;
      selects[other].value = leaving;
      return;
    }
    const next = runs.find((r) => r.id !== state.b);
    if (next) {
      state.a = next.id;
      selects.a.value = next.id;
      return;
    }
    // With one snapshot, keep working data as the newer side.
    state.b = WORKING;
    selects.b.value = WORKING;
  }

  // Saved snapshots are immutable; only working comparisons need Refresh.
  const refresh = el('button', {
    class: 'btn',
    text: 'Refresh',
    title: 'Reload current data and update the comparison.',
    onclick: () => load({ keepPlace: true }),
  });

  function syncRefresh() {
    refresh.hidden = state.b !== WORKING;
  }
  syncSwap();
  syncRefresh();

  body.append(el('div', { class: 'toolbar' }, [
    el('span', { class: 'field-label', text: 'Older' }),
    pickerFor('a'),
    swap,
    el('span', { class: 'field-label', text: 'Newer' }),
    pickerFor('b'),
    refresh,
  ]));

  const search = el('input', {
    type: 'search',
    placeholder: 'Search topic title or author…',
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
  // Explain working data above the counts, including its latest write time.
  const liveNote = el('p', { class: 'run-when' });
  body.append(liveNote, counts, results);

  function syncUrl() {
    replaceHash(buildHash(['bundle', 'changes'], {
      a: state.a,
      b: state.b,
      q: state.q,
      kind: state.kind,
      page: state.page || '',
    }));
  }

  /// Refresh preserves open cards and scroll with `keepPlace`. Changes to the
  /// selected bundles, search, filter or page reset the list position.
  async function load({ keepPlace = false } = {}) {
    const wasOpen = keepPlace ? openCards() : null;
    const wasAt = keepPlace ? window.scrollY : null;

    syncUrl();
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
    clear(liveNote);
    if (answer instanceof MissingFile) return results.append(missingPanel(answer));

    drawLiveNote(liveNote, answer);
    drawCounts(counts, answer);
    if (state.kind) {
      results.append(el('p', {
        class: 'run-when',
        text: `Showing ${kindWord(state.kind)} topics. Click the selected count to clear the filter.`,
      }));
    }
    for (const row of answer.items || []) {
      const card = changeCard(row);
      if (wasOpen && wasOpen.has(row.key)) card.open = true;
      results.append(card);
    }
    if (!(answer.items || []).length) {
      results.append(el('p', {
        class: 'loading',
        text: state.q || state.kind
          ? 'Nothing matches this search or filter.'
          : 'No differences found.',
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

    // Restore scroll after inserting results; an empty page clamps it to zero.
    if (wasAt != null) window.scrollTo({ top: wasAt });
  }

  /// Reads open card keys from the DOM to include manual and bulk toggles.
  function openCards() {
    return new Set([...results.querySelectorAll('details.change-card[open]')]
      .map((card) => card.dataset.key)
      .filter(Boolean));
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
        title: filtering ? `Show ${kindWord(kind)} topics.` : null,
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

/// Explains working-data counts and the manual refresh requirement.
function drawLiveNote(node, answer) {
  if (answer.b !== WORKING) return;
  const asOf = answer.workingUpdatedAt
    ? new Date(answer.workingUpdatedAt).toLocaleString()
    : null;
  node.append(el('span', {
    text: 'Comparing current local data with the selected snapshot. '
      + (asOf ? `Last written ${asOf}. ` : '')
      + 'Select Refresh to check for updates.',
  }));
}

/// How the data on disk reads in the picker.
function workingLabel(working) {
  const when = working.updatedAt
    ? new Date(working.updatedAt).toLocaleString()
    : null;
  const size = working.indexCount != null ? `${working.indexCount} topics` : '';
  return ['Current local data', when, size]
    .filter(Boolean).join(' — ');
}

/// Include job kind and topic count to distinguish snapshots with similar dates.
function runLabel(run) {
  const when = run.savedAt ? new Date(run.savedAt).toLocaleString() : run.id;
  const size = run.indexCount != null ? `${run.indexCount} topics` : '';
  return [when, jobWord(run.id), size].filter(Boolean).join(' — ');
}

/// The kind of job that saved the bundle, read from the tail of the run id
/// ("…Z-rebuildBundle"), in plain words.
function jobWord(id) {
  const kind = String(id || '').split('-')[1] || '';
  return {
    fullRun: 'full run',
    rescrapeTopics: 're-scrape',
    resolveDownloads: 'downloads',
    extractLlm: 'LLM extraction',
    llmCoveragePass: 'LLM coverage',
    describePictures: 'image scan',
    rebuildBundle: 'rebuild',
    fetchAndUpdate: 'fetch and update',
    rebuildFromSaved: 'rebuild from saved',
    takeDown: 'take down',
    restoreTakedown: 'restore a takedown',
  }[kind] || kind;
}

function changeCard(row) {
  const topic = row.topic || {};
  const changes = row.changes || [];
  // Retain the key to restore open cards after Refresh.
  const card = el('details', { class: 'change-card', 'data-key': row.key || '' });
  card.append(el('summary', {}, [
    el('span', { class: 'badge ' + kindBadge(row.kind), text: kindWord(row.kind) }),
    el('span', { class: 'change-name', text: row.name || '(no title)' }),
    el('span', { class: 'change-author', text: row.authors || '' }),
    el('span', { class: 'chev', text: '▸' }),
    // Place changed fields after the chevron so they wrap below the name.
    // Added and removed topics have no field summary.
    changes.length ? el('span', {
      class: 'change-hint',
      text: changedFieldsLine(changes),
      title: changedFieldsTitle(changes),
    }) : null,
  ]));

  const inner = el('div', { class: 'change-body' });
  if (topic.topicId != null) {
    inner.append(el('a', {
      href: `#/topics/${encodeURIComponent(topic.topicId)}`,
      text: `Open thread ${topic.topicId}`,
    }));
  }
  if (row.note) inner.append(el('p', { class: 'change-note', text: row.note }));
  if (changes.length) inner.append(diffTable(changes));
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
