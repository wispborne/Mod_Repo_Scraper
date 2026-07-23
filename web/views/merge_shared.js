// Bits the merge pages share: which merge is being looked at, how a saved merge
// reads in a picker, and how a value reads in a table cell.

import { api, el, MissingFile } from '../lib.js';

/// Which merge is being looked at. Empty means "the newest one". Kept here so
/// the pick survives moving between the merge pages.
export const picked = { run: '', runs: null };

/// Adds the picked merge to an API call's parameters.
export function withRun(params = {}) {
  return picked.run ? { ...params, run: picked.run } : params;
}

/// How a saved merge reads in a picker: when it ran, and what came out of it.
export function runLabel(run) {
  const when = run.savedAt ? new Date(run.savedAt).toLocaleString() : run.id;
  return run.finalCount != null ? `${when} — ${run.finalCount} mods out` : when;
}

/// The saved merges, asked for once per page load. Call [forgetRuns] when
/// moving to a page, so a merge that finished while the tab sat open shows up.
export async function loadRuns() {
  if (picked.runs) return picked.runs;
  const data = await api('merge/runs');
  picked.runs = data instanceof MissingFile ? { items: [] } : data;
  return picked.runs;
}

export function forgetRuns() {
  picked.runs = null;
}

/// What a value looks like in a table cell. Long text is cut short, and a
/// missing value reads as a dash rather than as "null".
export function cellText(value) {
  if (value == null || value === '') return '—';
  if (Array.isArray(value)) {
    return value.length ? value.map(cellText).join(', ') : '—';
  }
  if (typeof value === 'object') {
    // Nested values are run through here too, so a list or object inside a
    // field reads out instead of showing as "[object Object]".
    const parts = Object.entries(value).map(([k, v]) => `${k}: ${cellText(v)}`);
    return parts.length ? parts.join('\n') : '—';
  }
  const text = String(value);
  return text.length > 300 ? `${text.slice(0, 300)}…` : text;
}

/// The picker at the top of every merge page. Calls [redraw] when the choice
/// changes.
export async function drawPicker(node, redraw) {
  const data = await loadRuns();
  const runs = data.items || [];
  node.replaceChildren();
  // Nothing saved yet: the latest merge-debug.json is all there is to show.
  if (!runs.length) return;

  const select = el('select', { class: 'field-input' });
  select.append(el('option', {
    value: '',
    text: `Newest merge (${runLabel(runs[0])})`,
  }));
  for (const run of runs) {
    select.append(el('option', { value: run.id, text: runLabel(run) }));
  }
  select.value = picked.run;
  select.addEventListener('change', () => {
    picked.run = select.value;
    redraw();
  });

  node.append(el('div', { class: 'toolbar' }, [
    el('span', { class: 'field-label', text: 'Showing' }),
    select,
    el('span', {
      class: 'run-when',
      text: `${runs.length} merge${runs.length === 1 ? '' : 's'} saved`,
    }),
  ]));
}
