// The table of what changed about one thing, shared by the three pages that
// show one: the ModRepo diff, the Bundle diff, and one topic's history.
//
// The rule the whole thing is built on: show what moved and nothing else. Only
// changed fields get a row, and a field holding a list or a map is picked apart
// so only its changed entries are listed. Printing a mod's four links twice
// because one of them gained an "s" is not a diff, it is homework.

import { el } from '../lib.js';
import { cellText } from './merge_shared.js';

/// One row per changed field. A field whose entries were picked apart gets a
/// small list of what was added, removed and changed instead of two blocks of
/// JSON.
export function diffTable(changes) {
  const table = el('table', { class: 'diff-table' });
  // "Older" and "Newer" would be two empty promises on an entry where every
  // field is a list or a note, so the header says what the rows actually hold.
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

/// The added, removed and changed entries of one field. A changed entry shows
/// only the parts of it that moved; an LLM mod can carry its own downloads,
/// which sit one step further in.
export function itemList(items) {
  const list = el('ul', { class: 'item-diff' });
  for (const item of items || []) {
    const row = el('li', { class: `item-${item.change}` }, [
      el('span', { class: 'item-mark', text: mark(item.change) }),
      el('span', { class: 'item-label', text: item.label || '' }),
    ]);
    // An entry that is a value in its own right — one of a mod's links, say —
    // says what that value is here, rather than under a part with no name.
    if ('before' in item || 'after' in item) row.append(valueLine(item));
    for (const part of item.parts || []) {
      const partRow = el('div', { class: 'item-part' }, [
        el('span', { class: 'item-part-name', text: part.name }),
      ]);
      if (part.note) {
        // A part whose two values are no use on screen — a post's text, which
        // a snapshot keeps only a fingerprint of.
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

/// The value of an entry that has one: the new one where it was added, the old
/// one where it was removed, and both where it changed.
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

/// Like cellText, but tells "not there" apart from "there but empty" — a row
/// where both sides read "—" would look like nothing changed — and reads
/// booleans out as words.
export function diffText(value) {
  if (value == null) return '(not set)';
  if (Array.isArray(value) && !value.length) return '(empty list)';
  if (value === '') return '(empty)';
  if (value === true) return 'yes';
  if (value === false) return 'no';
  return cellText(value);
}
