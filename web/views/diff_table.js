// Shared diff renderer for ModRepo changes, bundle changes and topic history.
// Shows changed fields and, for lists and maps, only entries that changed.

import { el } from '../lib.js';
import { cellText } from './merge_shared.js';

/// One row per changed field, with entry-level changes for lists and maps.
export function diffTable(changes) {
  const table = el('table', { class: 'diff-table' });
  // Before/after headers apply only when a row displays both values.
  const sided = (changes || []).some((c) => !c.items && !c.note);
  table.append(el('thead', {}, el('tr', {}, sided
    ? [
      el('th', { text: 'Field' }),
      el('th', { text: 'Older' }),
      el('th', { text: 'Newer' }),
    ]
    : [
      el('th', { text: 'Field' }),
      el('th', { colspan: '2', text: 'What changed' }),
    ])));

  const tbody = el('tbody');
  for (const change of changes || []) {
    const tr = el('tr', {});
    tr.append(el('td', { class: 'diff-field', text: change.field }));
    if (change.items) {
      tr.append(el('td', { colspan: '2' }, itemList(change.items)));
    } else if (change.note) {
      // Snapshots retain post fingerprints, so no old text is available.
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

/// Render changed entries recursively, including downloads nested under LLM mods.
export function itemList(items) {
  const list = el('ul', { class: 'item-diff' });
  for (const item of items || []) {
    const row = el('li', { class: `item-${item.change}` }, [
      el('span', { class: 'item-mark', text: mark(item.change) }),
      el('span', { class: 'item-label', text: item.label || '' }),
    ]);
    if ('before' in item || 'after' in item) row.append(valueLine(item));
    for (const part of item.parts || []) {
      const partRow = el('div', { class: 'item-part' }, [
        el('span', { class: 'item-part-name', text: part.name }),
      ]);
      if (part.note) {
        // Fingerprint changes have a note rather than old and new post text.
        partRow.append(el('span', { class: 'change-note', text: part.note }));
      } else {
        partRow.append(el('span', { class: 'diff-before', text: diffText(part.before) }));
        partRow.append(el('span', { class: 'item-arrow', text: '→' }));
        partRow.append(el('span', { class: 'diff-after', text: diffText(part.after) }));
      }
      row.append(partRow);
    }
    if (item.items && item.items.length) row.append(itemList(item.items));
    list.append(row);
  }
  return list;
}

/// Show the new value for additions, old for removals, and both for changes.
function valueLine(item) {
  const line = el('div', { class: 'item-part' });
  if (item.change !== 'added') {
    line.append(el('span', { class: 'diff-before', text: diffText(item.before) }));
  }
  if (item.change === 'changed') {
    line.append(el('span', { class: 'item-arrow', text: '→' }));
  }
  if (item.change !== 'removed') {
    line.append(el('span', { class: 'diff-after', text: diffText(item.after) }));
  }
  return line;
}

function mark(change) {
  return { added: '+', removed: '−', changed: '~' }[change] || '·';
}

/// Formats booleans and distinguishes absent values from empty ones.
export function diffText(value) {
  if (value == null) return '(not set)';
  if (Array.isArray(value) && !value.length) return '(empty list)';
  if (value === '') return '(empty)';
  if (value === true) return 'yes';
  if (value === false) return 'no';
  return cellText(value);
}
