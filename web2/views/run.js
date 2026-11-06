// One run: breadcrumbs back to Run history, the panel with live updates
// while the run is running, and its raw JSON at the end.

import { el, api, shortTime, breadcrumbs, rawJson } from '../lib.js';
import { subscribe } from '../status.js';
import { kindLabel } from '../routes.js';
import { pageLayout } from '../frame.js';
import { runPanel } from '../run_panel.js';

export async function render({ content, parts, onLeave }) {
  const id = parts[0] || '';
  const crumbs = el('div');
  const main = el('div', { class: 'run-panel' });
  const raw = el('div', { class: 'raw-slot' });
  content.append(pageLayout(el('div', { class: 'detail-page' }, [crumbs, main, raw])));

  const drawCrumbs = (record) => crumbs.replaceChildren(breadcrumbs([
    { label: 'Run history', href: '#/runs' },
    { label: record
      ? `${kindLabel(record.request && record.request.kind)} · ${shortTime(record.startedAt || record.queuedAt)}`
      : id },
  ]));
  drawCrumbs(null);

  const panel = runPanel(main);
  let record = null;
  let rawFor = null;

  const showRecord = (r) => {
    record = r;
    drawCrumbs(r);
    // The raw JSON is drawn again only when the record itself changes.
    const key = JSON.stringify(r);
    if (key !== rawFor) {
      rawFor = key;
      raw.replaceChildren(rawJson(r));
    }
  };

  const fetchRecord = async () => {
    try {
      const r = await api(`manager/runs/${encodeURIComponent(id)}`);
      showRecord(r);
      return r;
    } catch (err) {
      record = null;
      raw.replaceChildren();
      main.replaceChildren(el('p', { class: 'error-text', text: err.message }));
      return null;
    }
  };

  const first = await fetchRecord();
  if (first) panel.show(first, null);

  let wasLive = false;
  onLeave(subscribe(async (s) => {
    const current = s.on && s.current && s.current.record && s.current.record.id === id ? s.current : null;
    if (current) {
      wasLive = true;
      panel.show(current.record, current);
      return;
    }
    if (wasLive) {
      // The run just ended: read its final record once.
      wasLive = false;
      const r = await fetchRecord();
      if (r) panel.show(r, null);
      return;
    }
    // A waiting run is read again when it leaves the queue.
    if (record && record.state === 'queued' && !(s.queued || []).some((q) => q.id === id)) {
      const r = await fetchRecord();
      if (r) panel.show(r, null);
    }
  }));
}
