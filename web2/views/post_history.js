// One forum topic's history (#/posts/topic/<id>/history): every run whose
// saved mod details changed the topic, newest first, along a vertical line.
// Saved data that is not published yet appears first. Ported from the old viewer's
// web/views/topic_history.js.

import { el, api, breadcrumbs, rawJson } from '../lib.js';
import { pageLayout } from '../frame.js';
import { icon } from '../icons.js';
import { subscribe } from '../status.js';
import { oldViewerAddress } from '../routes.js';
import { badge, emptyLine, when, topicStaleness, rebuildButton } from '../post_parts.js';

export async function render({ content, parts, toolbar, onLeave }) {
  const id = parts[1] || '';
  const postHref = `#/posts/topic/${encodeURIComponent(id)}`;
  const crumbs = el('div');
  const main = el('div', { class: 'pp-page' }, [crumbs, emptyLine('Loading… Reading every saved snapshot can take a minute.')]);
  // One column: the rail needs the width, and the toolbar still shows the
  // pending count.
  content.append(pageLayout(main));
  const gone = () => !main.isConnected;

  const drawCrumbs = (title) => crumbs.replaceChildren(breadcrumbs([
    { label: 'Source posts', href: '#/posts' },
    { label: title, href: postHref },
    { label: 'History' },
  ]));
  drawCrumbs(`Topic ${id}`);

  // The saved data gives the title and whether anything is unpublished. The
  // history can exist without it.
  const [history, working] = await Promise.all([
    api(`topics/${encodeURIComponent(id)}/history`).catch((err) => ({ error: err.message })),
    api(`topics/${encodeURIComponent(id)}`).catch(() => null),
  ]);
  if (gone()) return;

  const title = (working && working.index && working.index.title) || (history && history.title) || `Topic ${id}`;
  drawCrumbs(title);
  const head = el('header', { class: 'pp-head' }, [el('h2', { class: 'pp-title', text: title })]);

  if (!history || history.error) {
    main.replaceChildren(crumbs, head, el('p', { class: 'error-text', text: (history && history.error) || 'Could not read the history.' }));
    return;
  }

  const entries = history.entries || [];
  head.append(el('p', { class: 'pp-source-line', text: summaryLine(id, entries.length, history) }));

  const log = el('div', { class: 'ph-log' });
  const leadSlot = el('div', { class: 'ph-lead' });
  log.append(leadSlot);
  // The Details diff searches by the title in the newer snapshot, so walk the
  // title back through any run that changed it.
  let titleThen = (history && history.title) || title;
  for (const entry of entries) {
    log.append(logEntry(entry, titleThen));
    const renamed = (entry.changes || []).find((c) => c.field === 'title' && typeof c.before === 'string');
    if (renamed) titleThen = renamed.before;
  }
  if (!entries.length) {
    log.append(el('div', { class: 'ph-entry' }, [
      el('div', { class: 'ph-rail' }, el('span', { class: 'ph-dot dim' })),
      el('div', { class: 'ph-body' }, [el('p', { class: 'pp-source-line', text: nothingChangedLine(history) })]),
    ]));
  }
  log.append(historyEndsHere(history));

  main.replaceChildren(crumbs, head, log, el('div', { class: 'raw-slot' }, [rawJson(history)]));
  if (entries.length) toolbar.actions.replaceChildren(expandAllButton(log, 'details.ph-card'));

  // Saved data that is not published yet leads the list.
  if (!working) return;
  const staleness = await topicStaleness(id, working.index || {}, working.detail);
  if (gone() || !staleness || staleness.state === 'current') return;
  // Drawn again only when the manager goes on or off, so the button under
  // the pointer is not replaced on every status check.
  let shownOn = null;
  onLeave(subscribe((s) => {
    if (!!s.on === shownOn) return;
    shownOn = !!s.on;
    leadSlot.replaceChildren(unpublishedEntry(staleness, shownOn, title));
  }));
}

/// How many changes, across how many readable saved snapshots.
function summaryLine(topicId, changed, history) {
  const checked = history.snapshotsRead || 0;
  const bundles = `${checked} saved snapshot${checked === 1 ? '' : 's'}`;
  if (!history.everInBundle) return `Topic ${topicId} · Not found in ${bundles}.`;
  if (!changed) return `Topic ${topicId} · Unchanged across ${bundles}.`;
  return `Topic ${topicId} · ${changed} change${changed === 1 ? '' : 's'} across ${bundles}.`;
}

/// Tells a topic that was never published from one that never changed.
function nothingChangedLine(history) {
  const from = when(history.oldestSavedAt);
  if (!history.everInBundle) return 'No saved snapshot includes this thread yet.';
  return from ? `No changes in saved snapshots since ${from}.` : 'No changes in saved snapshots.';
}

/// The end of the history list: the earliest kept snapshot.
function historyEndsHere(history) {
  const total = history.snapshotsTotal || 0;
  const read = history.snapshotsRead || 0;
  const from = when(history.oldestSavedAt);
  const lines = [from
    ? `History starts ${from}. Earlier snapshots are unavailable.`
    : 'Earlier snapshots are unavailable.'];
  if (read < total) {
    lines.push(`${total - read} of the ${total} saved snapshots could not be read and were skipped.`);
  }
  return el('div', { class: 'ph-entry ph-tail' }, [
    el('div', { class: 'ph-rail' }, el('span', { class: 'ph-cap' })),
    el('div', { class: 'ph-body' }, lines.map((text) => el('p', { class: 'pp-source-line', text }))),
  ]);
}

/// A link to the old viewer's Details diff, which the What changed page will
/// replace.
function compareLink(query, text) {
  return el('a', { class: 'out-link', href: oldViewerAddress(location.pathname, `bundle/changes?${query}`) },
    [text, icon('external-link', 14)]);
}

/// The leading entry for data that is saved on disk but not published yet.
function unpublishedEntry(staleness, managerOn, title) {
  const said = {
    stale: ['Unpublished changes', 'This thread has newer saved data than the latest mod details snapshot.'],
    absent: ['Unpublished thread', 'This thread is saved locally but is not in the built mod details.'],
    noBundle: ['Mod details not built yet', 'Rebuild from saved to create the first snapshot.'],
  }[staleness.state];
  const body = el('div', { class: 'ph-body' }, [
    el('div', { class: 'ph-head' }, [
      badge('unpublished', 'warn'),
      el('span', { class: 'ph-name', text: said[0] }),
      el('span', { class: 'ph-job', text: when(staleness.scrapedAt) || '' }),
    ]),
    el('p', { class: 'pp-source-line', text: said[1] }),
  ]);
  const actions = el('div', { class: 'ph-actions' });
  if (managerOn) actions.append(rebuildButton());
  if (staleness.state !== 'noBundle') {
    actions.append(compareLink(`b=working&q=${encodeURIComponent(title)}`, 'Changes so far'));
  }
  body.append(actions);
  return el('div', { class: 'ph-entry ph-unpublished' }, [
    el('div', { class: 'ph-rail' }, el('span', { class: 'ph-dot hollow' })),
    body,
  ]);
}

const KIND_WORDS = { changed: ['changed', 'warn'], first: ['first seen', 'good'], gone: ['removed', 'bad'] };

/// One run that changed the topic. Shut, it names the fields that moved;
/// open, it shows them.
function logEntry(entry, title) {
  const changes = entry.changes || [];
  const [word, tone] = KIND_WORDS[entry.kind] || [entry.kind, ''];
  const card = el('details', { class: 'ph-card' });
  card.append(el('summary', {}, [
    badge(word, tone),
    el('span', { class: 'ph-name', text: when(entry.savedAt) || entry.runId }),
    el('span', { class: 'ph-job', text: jobWord(entry.runId) }),
    el('span', { class: 'ph-chev', 'aria-hidden': 'true' }, [icon('chevron-right', 14)]),
    // After the chevron, so it wraps to its own line under the date.
    // First-seen and removed entries name no fields.
    changes.length ? el('span', { class: 'ph-hint', text: changedFieldsLine(changes), title: changedFieldsTitle(changes) }) : null,
  ]));

  const body = el('div', { class: 'ph-card-body' });
  const links = el('div', { class: 'ph-actions' });
  // A snapshot imported from git has no run here to link to.
  if (isImported(entry.runId)) {
    body.append(el('p', { class: 'pp-source-line', text: 'Imported from the published repo’s Git history. No local run record.' }));
  } else {
    links.append(el('a', { href: `#/runs/${encodeURIComponent(entry.runId)}`, text: 'View run' }));
  }
  if (entry.kind !== 'first') {
    links.append(compareLink(`b=${encodeURIComponent(entry.runId)}&q=${encodeURIComponent(title)}`, 'View changes'));
  }
  body.append(links);
  if (entry.kind === 'first') body.append(el('p', { class: 'pp-source-line', text: 'First saved snapshot containing this thread.' }));
  if (entry.kind === 'gone') body.append(el('p', { class: 'pp-source-line', text: 'This thread was removed from the mod details.' }));
  if (changes.length) body.append(diffTable(changes));
  card.append(body);

  return el('div', { class: 'ph-entry' }, [
    el('div', { class: 'ph-rail' }, el('span', { class: 'ph-dot' })),
    el('div', { class: 'ph-body' }, [card]),
  ]);
}

/// The kind of job that saved the snapshot, read from the end of the run id
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
    matchRequirements: 'dependency names',
    setRequirementNames: 'dependency names',
    setAuthorAliases: 'author aliases',
    saveCorrections: 'corrections',
    rebuildBundle: 'rebuild',
    scrapeAndMerge: 'scrape and merge',
    fetchAndUpdate: 'fetch and update',
    rebuildFromSaved: 'rebuild from saved',
    takeDown: 'take down',
    restoreTakedown: 'restore a takedown',
    imported: 'imported',
  }[kind] || kind;
}

/// True for a snapshot imported from the published repo's git history. Its
/// name ends in `-imported`.
function isImported(id) {
  return String(id || '').endsWith('-imported');
}

// --- Folds ---

/// One button that opens or shuts every fold matched by `selector`. Its label
/// says what a press would do. It keeps up with folds opened one at a time.
function expandAllButton(container, selector) {
  const button = el('button', { type: 'button', class: 'button' });
  const folds = () => [...container.querySelectorAll(selector)];
  const refresh = () => {
    const anyShut = folds().some((f) => !f.open);
    button.textContent = anyShut ? 'Expand all' : 'Collapse all';
  };
  button.addEventListener('click', () => {
    const open = folds().some((f) => !f.open);
    for (const f of folds()) f.open = open;
    refresh();
  });
  // A fold's toggle event does not bubble, so it is caught on the way down.
  container.addEventListener('toggle', refresh, true);
  refresh();
  return button;
}

/// "name, downloads and 3 more".
function changedFieldsLine(changes, limit = 3) {
  const names = changes.map((c) => c.field).filter(Boolean);
  if (names.length <= limit) return names.join(', ');
  return `${names.slice(0, limit).join(', ')} and ${names.length - limit} more`;
}

function changedFieldsTitle(changes) {
  const names = changes.map((c) => c.field).filter(Boolean);
  return names.length ? names.join(', ') : null;
}

// --- The diff ---

/// One row per changed field. A list or map lists only its changed entries.
/// Ported from the old viewer's web/views/diff_table.js.
function diffTable(changes) {
  // Older and Newer headings only when a row shows both values.
  const sided = changes.some((c) => !c.items && !c.note);
  const headings = sided ? ['Field', 'Older', 'Newer'] : ['Field', 'What changed'];
  const rows = changes.map((change) => {
    const tr = el('tr', {}, [el('td', { class: 'ph-field', text: change.field })]);
    if (change.items) {
      tr.append(el('td', { colspan: sided ? '2' : null }, [itemList(change.items)]));
    } else if (change.note) {
      // Snapshots keep only a fingerprint of the post text, so no old words.
      tr.append(el('td', { class: 'dim', colspan: sided ? '2' : null, text: change.note }));
    } else {
      tr.append(
        el('td', { class: 'ph-before', text: diffText(change.before) }),
        el('td', { class: 'ph-after', text: diffText(change.after) }),
      );
    }
    return tr;
  });
  return el('div', { class: 'table-wrap' }, [el('table', { class: 'ph-diff' }, [
    el('thead', {}, el('tr', {}, headings.map((h) => el('th', { text: h })))),
    el('tbody', {}, rows),
  ])]);
}

/// Changed entries, nested where an entry has its own (downloads under a mod).
function itemList(items) {
  return el('ul', { class: 'ph-items' }, items.map((item) => {
    const row = el('li', { class: `ph-item-${item.change}` }, [
      el('span', { class: 'ph-mark', text: { added: '+', removed: '−', changed: '~' }[item.change] || '·' }),
      el('span', { class: 'ph-label', text: item.label || '' }),
    ]);
    if ('before' in item || 'after' in item) row.append(valueLine(item));
    for (const part of item.parts || []) {
      const line = el('div', { class: 'ph-part' }, [el('span', { class: 'ph-part-name', text: part.name })]);
      if (part.note) {
        line.append(el('span', { class: 'dim', text: part.note }));
      } else {
        line.append(
          el('span', { class: 'ph-before', text: diffText(part.before) }),
          el('span', { class: 'ph-arrow', text: '→' }),
          el('span', { class: 'ph-after', text: diffText(part.after) }),
        );
      }
      row.append(line);
    }
    if ((item.items || []).length) row.append(itemList(item.items));
    return row;
  }));
}

/// The new value for an addition, the old for a removal, both for a change.
function valueLine(item) {
  const line = el('div', { class: 'ph-part' });
  if (item.change !== 'added') line.append(el('span', { class: 'ph-before', text: diffText(item.before) }));
  if (item.change === 'changed') line.append(el('span', { class: 'ph-arrow', text: '→' }));
  if (item.change !== 'removed') line.append(el('span', { class: 'ph-after', text: diffText(item.after) }));
  return line;
}

/// Shows yes and no for true and false, and tells an absent value from an
/// empty one.
function diffText(value) {
  if (value == null) return '(not set)';
  if (Array.isArray(value) && !value.length) return '(empty list)';
  if (value === '') return '(empty)';
  if (value === true) return 'yes';
  if (value === false) return 'no';
  return cellText(value);
}

function cellText(value) {
  if (value == null || value === '') return '—';
  if (Array.isArray(value)) return value.length ? value.map(cellText).join(', ') : '—';
  if (typeof value === 'object') {
    const parts = Object.entries(value).map(([k, v]) => `${k}: ${cellText(v)}`);
    return parts.length ? parts.join('\n') : '—';
  }
  const text = String(value);
  return text.length > 300 ? `${text.slice(0, 300)}…` : text;
}
