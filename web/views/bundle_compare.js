// #/bundle/changes — what changed between two saved bundles.
//
// A bundle snapshot is saved by every run that publishes one, so this answers
// "what did that run actually change?". The posts' text is not kept in a
// snapshot, so a changed post is reported as changed and no more — the page
// says so, rather than leaving somebody hunting for a before and after that was
// never saved.
//
// Which two bundles are compared, the search, the filter and the page all ride
// in the hash query (#/bundle/changes?a=…&b=…), so a comparison can be
// bookmarked and the run page can link straight to "what this run changed".

import {
  api, el, clear, missingPanel, MissingFile, pager, pageSizePreference,
  hashQuery, buildHash, replaceHash, expandAllButton, changedFieldsLine,
  changedFieldsTitle,
} from '../lib.js';
import { cellText } from './merge_shared.js';

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

  body.append(el('p', {
    class: 'run-when',
    text: 'Every run that publishes a bundle keeps a snapshot of it. '
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
      // Picking the bundle already on the other side swaps the two, rather
      // than comparing a bundle with itself.
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
    title: 'Switch which bundle counts as older and which as newer.',
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

  const counts = el('div', { class: 'stat-grid' });
  const results = el('div', {});
  const foldAll = expandAllButton(results, 'details.change-card');
  body.append(el('div', { class: 'toolbar' }, [search, foldAll]));
  body.append(counts, results);

  function syncUrl() {
    replaceHash(buildHash(['bundle', 'changes'], {
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
    if (state.kind) {
      results.append(el('p', {
        class: 'run-when',
        text: `Showing only the ${kindWord(state.kind)} topics — click the `
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
          : 'These two bundles are the same — nothing was added, removed '
            + 'or changed.',
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
        title: filtering ? `Show only the ${kindWord(kind)} topics.` : null,
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

/// How a saved bundle reads in a picker: when it was, what kind of run made
/// it, and how big it was. The dates alone all look alike.
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
    rebuildBundle: 'rebuild',
  }[kind] || kind;
}

function changeCard(row) {
  const topic = row.topic || {};
  const changes = row.changes || [];
  const card = el('details', { class: 'change-card' });
  card.append(el('summary', {}, [
    el('span', { class: 'badge ' + kindBadge(row.kind), text: kindWord(row.kind) }),
    el('span', { class: 'change-name', text: row.name || '(no title)' }),
    el('span', { class: 'change-author', text: row.authors || '' }),
    el('span', { class: 'chev', text: '▸' }),
    // Which fields moved, not just how many — the whole point of the shut row
    // is to be read without opening it. It comes after the chevron so that the
    // chevron stays up on the first line; the CSS drops this onto a second.
    // Left out when there is nothing to say, so an added or removed topic
    // doesn't carry an empty second line.
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
      // A field where the two values are no use on screen — the post text.
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
