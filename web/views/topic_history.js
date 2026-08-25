// One topic's history: every run whose saved bundle changed it, newest first.
// Reached from the thread page, at #/topics/<id>/history and #/bundle/<id>/history.
//
// It reads like a log of commits, because that is what it is: a run that
// published a bundle either changed this topic or left it alone, and only the
// ones that changed it are here. Runs that left it alone are not listed — on
// real data that is most of them.
//
// History only goes back as far as the saved bundles the server still keeps, so
// the foot of the log says where it starts. A topic that never changed says so,
// naming how many bundles were checked, rather than showing an empty page.

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

  // The working data gives the title and lets us say whether what is on disk
  // has been published yet. A topic with no working data still has a history.
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
    el('a', { class: 'btn', href: threadHref, text: '‹ Back to the thread' }),
  ]);
  page.append(controls);

  const entries = history.entries || [];
  page.append(el('p', {
    class: 'run-when',
    text: summaryLine(topicId, entries.length, history),
  }));

  const log = el('div', { class: 'log' });

  // What is on disk but not published yet leads the log, the way a git viewer
  // puts uncommitted changes above the commits.
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

  // Built after the log, so the button knows straight away how many entries
  // there are to open.
  if (entries.length) {
    controls.append(expandAllButton(log, 'details.change-card'));
  }

  page.append(rawJson(history));
  root.append(page);
}

/// The line under the title: how many runs changed this topic, out of how many
/// saved bundles there were to look at.
function summaryLine(topicId, changed, history) {
  const checked = history.snapshotsRead || 0;
  const bundles = `${checked} saved bundle${checked === 1 ? '' : 's'}`;
  if (!history.everInBundle) {
    return `Topic ${topicId} — in none of the ${bundles}.`;
  }
  if (!changed) return `Topic ${topicId} — the same in all ${bundles}.`;
  return `Topic ${topicId} — changed in ${changed} of ${bundles}.`;
}

/// What to say when the log has nothing in it. "Nothing changed" and "this
/// thread was never in a bundle" are different answers, and reading the second
/// as the first would send somebody hunting for a change that never happened.
function nothingChangedLine(history) {
  const from = when(history.oldestSavedAt);
  if (!history.everInBundle) {
    return 'This thread is not in any of the saved bundles, so there is nothing '
      + 'to compare. Scrape it and rebuild the bundle, and its history starts '
      + 'from there.';
  }
  return from
    ? 'Nothing has changed about this thread in any of the saved bundles, '
      + `going back to ${from}.`
    : 'Nothing has changed about this thread in any of the saved bundles.';
}

/// The cap at the foot of the rail. Only the newest runs keep a bundle
/// snapshot, so this is where the trail genuinely stops — saying so is better
/// than letting it look as though nothing happened before then.
function historyEndsHere(history) {
  const total = history.snapshotsTotal || 0;
  const read = history.snapshotsRead || 0;
  const from = when(history.oldestSavedAt);

  const lines = [
    from
      ? `Older runs are not kept. History starts ${from}.`
      : 'Older runs are not kept.',
  ];
  if (read < total) {
    lines.push(`${total - read} of the ${total} saved bundles could not be read `
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
      'On disk now, not published',
      'This thread was scraped after the Forum Data Bundle was last built, so '
        + 'what changed is not in a saved bundle yet.',
    ],
    absent: [
      'On disk now, not published',
      'This thread is saved on disk but is not in the published bundle at all.',
    ],
    noBundle: [
      'Nothing published yet',
      'No Forum Data Bundle has been published, so there is nothing saved to '
        + 'compare against.',
    ],
  }[staleness.state];

  // On a cold load the shared poller may not have answered yet, and a null
  // status would quietly hide the button on a manager that is switched on.
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

/// One run in the log: a summary line that says which fields moved, opening on
/// click to what they moved from and to.
function logEntry(entry, threadHref) {
  const changes = entry.changes || [];
  const card = el('details', { class: 'change-card' });

  card.append(el('summary', {}, [
    el('span', { class: `badge ${kindBadge(entry.kind)}`, text: kindWord(entry.kind) }),
    el('span', { class: 'change-name', text: when(entry.savedAt) || entry.runId }),
    el('span', { class: 'change-author', text: jobWord(entry.runId) }),
    el('span', { class: 'chev', text: '▸' }),
    // After the chevron so the chevron stays up on the first line; the CSS
    // drops the field names onto a second one, under the date. Left out when
    // there is nothing to say — a first-seen or dropped entry lists no fields.
    changes.length ? el('span', {
      class: 'change-hint',
      text: changedFieldsLine(changes),
      title: changedFieldsTitle(changes),
    }) : null,
  ]));

  const body = el('div', { class: 'change-body' });
  // Imported snapshots have no run behind them, so there is nothing to open —
  // they came from the published repo's git history, not from a run here.
  if (isImported(entry.runId)) {
    body.append(el('p', {
      class: 'change-note',
      text: 'Imported from the published repo’s git history — there '
        + 'is no run record for it.',
    }));
  } else {
    body.append(el('a', {
      href: `#/runs/${encodeURIComponent(entry.runId)}`,
      text: 'Open this run',
    }));
  }
  if (entry.kind === 'first') {
    body.append(el('p', {
      class: 'change-note',
      text: 'This run is the first saved bundle that holds this thread.',
    }));
  }
  if (entry.kind === 'gone') {
    body.append(el('p', {
      class: 'change-note',
      text: 'This run published a bundle without this thread in it.',
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
    gone: 'dropped',
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
    rebuildBundle: 'rebuild',
    scrapeAndMerge: 'scrape and merge',
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
