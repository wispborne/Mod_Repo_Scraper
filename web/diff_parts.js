// Shared parts of every page that shows what changed: the diff table, the
// line naming which fields changed, the Expand all button, and the plain
// words for the job that saved a snapshot. Used by What changed, one topic's
// history and the mod page's history, so a change is worded the same way on
// all three.

import { el } from './lib.js';

// --- Folds ---

/// One button that opens or shuts every fold matched by `selector`. Its label
/// says what a press would do. It keeps up with folds opened one at a time.
/// A list that redraws itself calls `button.refresh()` afterwards.
export function expandAllButton(container, selector) {
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
  // A fold's toggle event does not bubble, so listen during the capture phase.
  container.addEventListener('toggle', refresh, true);
  button.refresh = refresh;
  refresh();
  return button;
}

/// "name, downloads and 3 more".
export function changedFieldsLine(changes, limit = 3) {
  const names = changes.map((c) => c.field).filter(Boolean);
  if (names.length <= limit) return names.join(', ');
  return `${names.slice(0, limit).join(', ')} and ${names.length - limit} more`;
}

export function changedFieldsTitle(changes) {
  const names = changes.map((c) => c.field).filter(Boolean);
  return names.length ? names.join(', ') : null;
}

// --- Which job saved a snapshot ---

/// The kind of job that saved the snapshot, read from the end of the run id
/// ("…Z-rebuildBundle"), in plain words.
export function jobWord(id) {
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
    mergeModRepo: 'merge',
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
export function isImported(id) {
  return String(id || '').endsWith('-imported');
}

// --- The diff ---

/// One row per changed field. A list or map lists only its changed entries.
export function diffTable(changes) {
  // Older and Newer headings only when a row shows both values.
  const sided = changes.some((c) => !c.items && !c.note);
  const headings = sided ? ['Field', 'Older', 'Newer'] : ['Field', 'What changed'];
  const rows = changes.map((change) => {
    const tr = el('tr', {}, [el('td', { class: 'ph-field', text: change.field })]);
    if (change.items) {
      tr.append(el('td', { colspan: sided ? '2' : null }, [itemList(change.items)]));
    } else if (change.note) {
      // Snapshots keep only a hash of the post text, so the old text is unavailable.
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
export function diffText(value) {
  if (value == null) return '(not set)';
  if (Array.isArray(value) && !value.length) return '(empty list)';
  if (value === '') return '(empty)';
  if (value === true) return 'yes';
  if (value === false) return 'no';
  return cellText(value);
}

/// A value as text: a dash for nothing, lists joined, maps as one
/// "key: value" line each, and long text cut at 300 characters.
export function cellText(value) {
  if (value == null || value === '') return '—';
  if (Array.isArray(value)) return value.length ? value.map(cellText).join(', ') : '—';
  if (typeof value === 'object') {
    const parts = Object.entries(value).map(([k, v]) => `${k}: ${cellText(v)}`);
    return parts.length ? parts.join('\n') : '—';
  }
  const text = String(value);
  return text.length > 300 ? `${text.slice(0, 300)}…` : text;
}
