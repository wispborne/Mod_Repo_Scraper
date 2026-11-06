// The Control page. Its job buttons and run panel come in a later change; for
// now the central panel points to the old viewer, and the side panels show
// the real queue and recent runs.

import { el, clear, api, shortTime } from '../lib.js';
import { subscribe } from '../status.js';
import { kindLabel } from '../routes.js';
import { pageLayout, sidePanel, statusMark } from '../frame.js';
import { notBuiltYet } from './placeholder.js';

const MARK_FOR_STATE = {
  running: 'running',
  queued: 'idle',
  completed: 'done',
  failed: 'failed',
  cancelled: 'warning',
  interrupted: 'warning',
};

const STATE_WORDS = {
  running: 'Running',
  queued: 'Waiting',
  completed: 'Done',
  failed: 'Failed',
  cancelled: 'Stopped',
  interrupted: 'Interrupted',
};

/// One run as a row: a diamond in its state's colour, its kind, its time.
function runRow(record) {
  const kind = kindLabel(record.request && record.request.kind);
  const errors = record.counters && record.counters.errors;
  return el('a', {
    class: 'row',
    href: `#/runs/${encodeURIComponent(record.id)}`,
    title: `${STATE_WORDS[record.state] || record.state}${record.errorMessage ? `: ${record.errorMessage}` : ''}`,
  }, [
    statusMark(MARK_FOR_STATE[record.state] || 'idle'),
    el('span', { class: 'row-main' }, [
      kind,
      errors ? el('span', { class: 'failed-text', text: ` · ${errors} ${errors === 1 ? 'error' : 'errors'}` }) : null,
    ]),
    el('span', { class: 'row-time', text: shortTime(record.startedAt || record.queuedAt) }),
  ]);
}

/// Shows why the manager is off, using the server's message, and how to enable it.
function viewingOnly(s) {
  return el('div', { class: 'note' }, [
    el('h2', { class: 'panel-heading', text: 'Viewing only' }),
    el('p', {
      text: s.offline
        ? 'Cannot reach the server. Jobs cannot start.'
        : `${s.reason || 'Jobs are turned off on this server.'} To turn them on, start the server with a readable config.properties (or specify one with --config) and without --no-manager.`,
    }),
  ]);
}

export function render({ content, entry, onLeave }) {
  const main = el('div', { class: 'main-body' });
  const queueBody = el('div', { class: 'rows' });
  const runsBody = el('div', { class: 'rows' }, [el('p', { class: 'empty', text: 'Loading…' })]);
  const queuePanel = el('div');
  const sides = [queuePanel, sidePanel({ name: 'Recent runs', body: runsBody })];
  content.append(pageLayout(main, sides));

  const loadRuns = async () => {
    try {
      const page = await api('manager/runs', { pageSize: 12 });
      const runs = (page && page.items) || [];
      clear(runsBody).append(...(runs.length
        ? runs.map(runRow)
        : [el('p', { class: 'empty', text: 'No runs yet.' })]));
    } catch (err) {
      clear(runsBody).append(el('p', { class: 'empty', text: err.message }));
    }
  };

  let lastOn = null;
  let lastQueueKey = null;
  // Reload recent runs when the running job changes.
  let lastCurrent;
  onLeave(subscribe((s) => {
    const current = s.current && s.current.record ? s.current.record.id : null;
    if (current !== lastCurrent) {
      lastCurrent = current;
      loadRuns();
    }
    if (s.on !== lastOn) {
      lastOn = s.on;
      clear(main).append(s.on ? notBuiltYet(entry) : viewingOnly(s));
    }
    const queued = s.on ? s.queued || [] : [];
    const key = queued.map((r) => r.id).join(',') + (s.on ? '' : ':off');
    if (key === lastQueueKey) return;
    lastQueueKey = key;
    clear(queueBody).append(...(queued.length
      ? queued.map(runRow)
      : [el('p', { class: 'empty', text: s.on ? 'Nothing waiting.' : 'Jobs are off.' })]));
    // The heading's count changes, so the panel is built again.
    queuePanel.replaceChildren(sidePanel({ name: 'Queue', count: queued.length, body: queueBody }));
  }));
}
