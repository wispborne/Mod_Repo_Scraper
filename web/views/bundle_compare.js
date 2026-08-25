// #/bundle/changes — what changed between two bundles.
//
// A bundle snapshot is saved by every run that publishes one, so this answers
// "what did that run actually change?". The posts' text is not kept in a
// snapshot, so a changed post is reported as changed and no more — the page
// says so, rather than leaving somebody hunting for a before and after that was
// never saved.
//
// The newer of the two can also be **the data on disk right now**, which is how
// a run is watched while it is still going. A run publishes its bundle at the
// end, but writes what it scrapes and what it pays the LLM for as it goes — so
// the difference between the last published bundle and what is on disk is what
// the run has done up to this second. That side is always the newer one; it can
// never be the older.
//
// It is refreshed by pressing Refresh and in no other way. Redrawing the page
// on a timer throws away where the reader had scrolled to and every card they
// had opened, which on a page whose whole purpose is reading what changed is
// worse than being a minute out of date.
//
// Which two bundles are compared, the search, the filter and the page all ride
// in the hash query (#/bundle/changes?a=…&b=…), so a comparison can be
// bookmarked and the run page can link straight to "what this run changed".

import {
  api, el, clear, missingPanel, MissingFile, pager, pageSizePreference,
  hashQuery, buildHash, replaceHash, expandAllButton, changedFieldsLine,
  changedFieldsTitle,
} from '../lib.js';
import { diffTable } from './diff_table.js';

/// What the data on disk goes by in the address and in the picker. Not a run
/// id — no run saved it, and there is only ever one of it.
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
      el('h3', { text: 'There is nothing to compare yet' }),
      el('p', {
        text: runs.length === 1
          ? 'Only one bundle has been saved so far, and there is no scraped '
            + 'data on disk to hold it against. Run the scraper again and this '
            + 'page will show what changed.'
          : 'No bundles have been saved yet. Run the scraper and one will be '
            + 'saved for you.',
      }),
    ]));
  }

  if (state.b === WORKING && !working) state.b = '';
  // Newest against the one before it — the comparison people want most.
  if (state.b !== WORKING && !runs.some((r) => r.id === state.b)) {
    state.b = runs.length > 1 || !working ? runs[0].id : WORKING;
  }
  if (state.b === WORKING) {
    // The data on disk is held against everything published so far, which is
    // the newest saved bundle.
    if (!runs.some((r) => r.id === state.a)) state.a = runs[0].id;
  } else if (!runs.some((r) => r.id === state.a) || state.a === state.b) {
    state.a = runs.find((r) => r.id !== state.b).id;
  }

  body.append(el('p', {
    class: 'run-when',
    text: 'Every run that publishes a bundle keeps a snapshot of it. '
      + 'Pick two and see what changed between them — or hold the newest one '
      + 'against the data on disk to watch a run as it goes.',
  }));

  const selects = {};
  const pickerFor = (which) => {
    const select = el('select', { class: 'field-input' });
    // Only the newer side may be the data on disk: it comes after everything
    // that has ever been published.
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
    title: 'Switch which bundle counts as older and which as newer.',
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

  /// Swapping is off while the newer side is the data on disk, since it can
  /// only ever be the newer one.
  function syncSwap() {
    const off = state.b === WORKING;
    swap.disabled = off;
    swap.title = off
      ? 'The data on disk is always the newer of the two.'
      : 'Switch which bundle counts as older and which as newer.';
  }
  /// Both sides ended up on the same bundle. Normally the two swap, which is
  /// what a reader picking "the one the other side is on" means. But the data
  /// on disk can never become the older side, so a newer side moving off it
  /// onto the bundle already selected as older has nothing to swap with — the
  /// older side moves along to the next saved bundle instead. Without this the
  /// page compared a bundle with itself and said nothing had changed.
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
    // Only one bundle has ever been saved, so there is nothing to hold it
    // against but the data on disk. Put the newer side back where it was.
    state.b = WORKING;
    selects.b.value = WORKING;
  }

  // Only worth offering while the newer side is the data on disk. Two saved
  // bundles never change, so a Refresh button over them would be a button that
  // does nothing.
  const refresh = el('button', {
    class: 'btn',
    text: 'Refresh',
    title: 'Read the data on disk again and work out what has changed since '
      + 'the last bundle was published.',
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
  // Says what the data-on-disk side means and, while a run is going, when it
  // was last read. It sits above the counts because it changes what they mean.
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

  /// Redraws the list.
  ///
  /// With [keepPlace], the cards that were open are opened again and the page
  /// is left at the same scroll — pressing Refresh is meant to bring in what a
  /// run has done since, not to send the reader back to the top of a list they
  /// were halfway through. Every other caller is a change of what is being
  /// shown (a different bundle, a search, a filter, a page), where starting at
  /// the top is right.
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
        text: `Showing only the ${kindWord(state.kind)} topics — click the `
          + 'highlighted card again to show everything.',
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

    // After the list is back, not before: an emptied page has nowhere to
    // scroll to, and the browser would clamp this to the top.
    if (wasAt != null) window.scrollTo({ top: wasAt });
  }

  /// Which topics the reader has open, by the key the row came with. Read off
  /// the page each time rather than remembered, since cards are opened and shut
  /// one at a time as well as all at once.
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

/// What the counts mean when the newer side is the data on disk, rather than
/// two saved bundles. Nothing at all when both sides are saved bundles — the
/// line above the pickers already says what those are.
function drawLiveNote(node, answer) {
  if (answer.b !== WORKING) return;
  const asOf = answer.workingUpdatedAt
    ? new Date(answer.workingUpdatedAt).toLocaleString()
    : null;
  node.append(el('span', {
    text: 'This is what is on disk now against the last bundle that was '
      + 'published — what has been scraped, resolved and read by the LLM since, '
      + 'and not published yet. '
      + (asOf ? `Read as it stood at ${asOf}. ` : '')
      + 'Press Refresh to bring it up to date; the page will not move on its '
      + 'own.',
  }));
}

/// How the data on disk reads in the picker.
function workingLabel(working) {
  const when = working.updatedAt
    ? new Date(working.updatedAt).toLocaleString()
    : null;
  const size = working.indexCount != null ? `${working.indexCount} topics` : '';
  return ['On disk now — not published yet', when, size]
    .filter(Boolean).join(' — ');
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
  // The key rides on the card so a redraw can open again whatever was open.
  const card = el('details', { class: 'change-card', 'data-key': row.key || '' });
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
