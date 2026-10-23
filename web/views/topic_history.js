// Saved bundle changes for one topic, newest first, under topics/ or bundle/.
// History is limited by retained snapshots; empty histories explain whether
// the topic was never published or simply has no recorded changes.

import {
  api, el, clear, missingPanel, MissingFile, breadcrumbs, rawJson, loading,
  expandAllButton, changedFieldsLine, changedFieldsTitle,
} from '../lib.js';
import * as manager from '../manager.js';
import { topicStaleness, rebuildBundleButton } from './extraction_views.js';
import { diffTable } from './diff_table.js';

export async function render(root, topicId, { parent } = {}) {
  clear(root);
  const up = parent || { label: 'Topics', href: '#/topics' };
  const threadHref = `#/${up.href === '#/bundle' ? 'bundle' : 'topics'}`
    + `/${encodeURIComponent(topicId)}`;

  const crumbs = (title) => breadcrumbs([
    up,
    { label: title, href: threadHref },
    { label: 'History' },
  ]);

  root.append(loading());

  // Working data supplies the title and publication status; history can exist without it.
  const [history, working] = await Promise.all([
    api(`topics/${encodeURIComponent(topicId)}/history`),
    api(`topics/${encodeURIComponent(topicId)}`).catch(() => null),
  ]);

  clear(root);

  const title = (working && working.index && working.index.title)
    || (history && history.title)
    || `Topic ${topicId}`;

  if (history instanceof MissingFile) {
    root.append(crumbs(title), el('h1', { text: title }));
    return root.append(missingPanel(history));
  }

  root.append(crumbs(title));

  const page = el('div', { class: 'stack' });
  page.append(el('h1', { text: title }));
  const controls = el('div', { class: 'thread-controls' }, [
    el('a', { class: 'btn', href: threadHref, text: '‹ Back to thread' }),
  ]);
  page.append(controls);

  const entries = history.entries || [];
  page.append(el('p', {
    class: 'run-when',
    text: summaryLine(topicId, entries.length, history),
  }));

  const log = el('div', { class: 'log' });

  // Unpublished working data appears before saved history.
  const lead = await unpublishedEntry(topicId, working);
  if (lead) log.append(lead);

  for (const entry of entries) log.append(logEntry(entry, threadHref));

  if (!entries.length) {
    log.append(el('div', { class: 'log-entry' }, [
      el('div', { class: 'log-rail' }, el('span', { class: 'log-dot dim' })),
      el('div', { class: 'log-body' }, [
        el('p', { class: 'change-note', text: nothingChangedLine(history) }),
      ]),
    ]));
  }

  log.append(historyEndsHere(history));
  page.append(log);

  // Build the button after the entries so its initial state reflects the folds.
  if (entries.length) {
    controls.append(expandAllButton(log, 'details.change-card'));
  }

  page.append(rawJson(history));
  root.append(page);
}

/// Counts changes across the readable saved bundles.
function summaryLine(topicId, changed, history) {
  const checked = history.snapshotsRead || 0;
  const bundles = `${checked} saved snapshot${checked === 1 ? '' : 's'}`;
  if (!history.everInBundle) {
    return `Topic ${topicId} · Not found in ${bundles}.`;
  }
  if (!changed) return `Topic ${topicId} · Unchanged across ${bundles}.`;
  return `Topic ${topicId} · ${changed} changes across ${bundles}.`;
}

/// Distinguishes never-published topics from published but unchanged topics.
function nothingChangedLine(history) {
  const from = when(history.oldestSavedAt);
  if (!history.everInBundle) {
    return 'No saved snapshot includes this thread yet.';
  }
  return from
    ? `No changes in saved snapshots since ${from}.`
    : 'No changes in saved snapshots.';
}

/// Marks the oldest retained snapshot as the history boundary.
function historyEndsHere(history) {
  const total = history.snapshotsTotal || 0;
  const read = history.snapshotsRead || 0;
  const from = when(history.oldestSavedAt);

  const lines = [
    from
      ? `History starts ${from}. Earlier snapshots are unavailable.`
      : 'Earlier snapshots are unavailable.',
  ];
  if (read < total) {
    lines.push(`${total - read} of the ${total} saved snapshots could not be read `
      + 'and were skipped.');
  }

  return el('div', { class: 'log-entry log-tail' }, [
    el('div', { class: 'log-rail' }, el('span', { class: 'log-cap' })),
    el('div', { class: 'log-body' },
      lines.map((text) => el('p', { class: 'change-note', text }))),
  ]);
}

/// The leading entry for data that is saved on disk but not published yet.
/// Nothing is drawn when the published bundle is already up to date.
async function unpublishedEntry(topicId, working) {
  if (!working || working instanceof MissingFile) return null;

  const staleness = await topicStaleness(
    topicId, working.index || {}, working.detail);
  if (!staleness || staleness.state === 'current') return null;

  const said = {
    stale: [
      'Unpublished changes',
      'This thread has newer saved data than the latest mod details snapshot.',
    ],
    absent: [
      'Unpublished thread',
      'This thread is saved locally but is not in the built mod details.',
    ],
    noBundle: [
      'Mod details not built yet',
      'Rebuild mod details to create the first snapshot.',
    ],
  }[staleness.state];

  // Wait for initial status so enabled managers show the rebuild button.
  const status = manager.status() || await manager.refresh();
  const body = el('div', { class: 'log-body' }, [
    el('div', { class: 'log-head' }, [
      el('span', { class: 'badge badge-warning', text: 'unpublished' }),
      el('span', { class: 'change-name', text: said[0] }),
      el('span', {
        class: 'change-hint',
        text: when(staleness.scrapedAt) || '',
      }),
    ]),
    el('p', { class: 'change-note', text: said[1] }),
  ]);
  if (status && status.on) {
    body.append(el('div', { class: 'thread-controls' }, [rebuildBundleButton()]));
  }

  return el('div', { class: 'log-entry log-unpublished' }, [
    el('div', { class: 'log-rail' }, el('span', { class: 'log-dot hollow' })),
    body,
  ]);
}

/// Each entry summarizes changed fields and expands to show their values.
function logEntry(entry, threadHref) {
  const changes = entry.changes || [];
  const card = el('details', { class: 'change-card' });

  card.append(el('summary', {}, [
    el('span', { class: `badge ${kindBadge(entry.kind)}`, text: kindWord(entry.kind) }),
    el('span', { class: 'change-name', text: when(entry.savedAt) || entry.runId }),
    el('span', { class: 'change-author', text: jobWord(entry.runId) }),
    el('span', { class: 'chev', text: '▸' }),
    // Place field names after the chevron so they wrap below the date.
    // First-seen and removed entries have no changed fields.
    changes.length ? el('span', {
      class: 'change-hint',
      text: changedFieldsLine(changes),
      title: changedFieldsTitle(changes),
    }) : null,
  ]));

  const body = el('div', { class: 'change-body' });
  // Imported git snapshots have no local run record to link to.
  if (isImported(entry.runId)) {
    body.append(el('p', {
      class: 'change-note',
      text: 'Imported from the published repo’s Git history. No local run record.',
    }));
  } else {
    body.append(el('a', {
      href: `#/runs/${encodeURIComponent(entry.runId)}`,
      text: 'View run',
    }));
  }
  if (entry.kind === 'first') {
    body.append(el('p', {
      class: 'change-note',
      text: 'First saved snapshot containing this thread.',
    }));
  }
  if (entry.kind === 'gone') {
    body.append(el('p', {
      class: 'change-note',
      text: 'This thread was removed from the mod details.',
    }));
  }
  if (changes.length) body.append(diffTable(changes));
  card.append(body);

  return el('div', { class: 'log-entry' }, [
    el('div', { class: 'log-rail' }, el('span', { class: 'log-dot' })),
    el('div', { class: 'log-body' }, card),
  ]);
}

function kindWord(kind) {
  return {
    changed: 'changed',
    first: 'first seen',
    gone: 'removed',
  }[kind] || kind;
}

function kindBadge(kind) {
  return {
    changed: 'badge-warning',
    first: 'badge-success',
    gone: 'badge-error',
  }[kind] || 'badge-dim';
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
    scrapeAndMerge: 'scrape and merge',
    fetchAndUpdate: 'fetch and update',
    rebuildFromSaved: 'rebuild from saved',
    imported: 'imported',
  }[kind] || kind;
}

/// True for a snapshot brought in from the published repo's git history rather
/// than saved by a run here. Its name ends in `-imported`.
function isImported(id) {
  return String(id || '').endsWith('-imported');
}

function when(iso) {
  if (!iso) return null;
  const at = new Date(iso);
  return Number.isNaN(at.getTime()) ? String(iso) : at.toLocaleString();
}
