// Shared merge selection, snapshot labels, and field formatting.

import { api, el, MissingFile } from '../lib.js';

/// Selection persists across merge pages; an empty run selects the newest.
export const picked = { run: '', runs: null };

/// Adds the picked merge to an API call's parameters.
export function withRun(params = {}) {
  return picked.run ? { ...params, run: picked.run } : params;
}

/// Snapshot date and output count.
export function runLabel(run) {
  const when = run.savedAt ? new Date(run.savedAt).toLocaleString() : run.id;
  return run.finalCount != null ? `${when} — ${run.finalCount} mods` : when;
}

/// Cache for one page load. Call forgetRuns on navigation to include new merges.
export async function loadRuns() {
  if (picked.runs) return picked.runs;
  const data = await api('merge/runs');
  picked.runs = data instanceof MissingFile ? { items: [] } : data;
  return picked.runs;
}

export function forgetRuns() {
  picked.runs = null;
}

/// Truncate long values and display missing values as a dash.
export function cellText(value) {
  if (value == null || value === '') return '—';
  if (Array.isArray(value)) {
    return value.length ? value.map(cellText).join(', ') : '—';
  }
  if (typeof value === 'object') {
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
