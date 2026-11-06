// One run: breadcrumbs back to Run history, the panel with live updates
// while the run is running, and its raw JSON at the end.

import { el, api, shortTime, breadcrumbs, rawJson } from '../lib.js';
import { subscribe } from '../status.js';
import { kindLabel } from '../routes.js';
import { pageLayout } from '../frame.js';
import { runPanel } from '../run_panel.js';
import { runTime } from '../run_record.js';

export async function render({ content, parts, onLeave }) {
  const id = parts[0] || '';
  const crumbs = el('div');
  // A failed read is shown here, above the panel, so the panel and the last
  // record read stay as they were.
  const problem = el('p', { class: 'error-text', hidden: true });
  const main = el('div', { class: 'run-panel' });
  const raw = el('div', { class: 'raw-slot' });
  content.append(pageLayout(el('div', { class: 'detail-page' }, [crumbs, problem, main, raw])));

  const drawCrumbs = (record) => crumbs.replaceChildren(breadcrumbs([
    { label: 'Run history', href: '#/runs' },
    { label: record
      ? `${kindLabel(record.request && record.request.kind)} · ${shortTime(runTime(record))}`
      : id },
  ]));
  drawCrumbs(null);

  const panel = runPanel(main);
  // The last record read. A failed read keeps it.
  let record = null;
  let rawFor = null;
  // True when the record has to be read again on the next status answer
  // from the server: a read failed, or the server could not be reached.
  let readOwed = false;

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

  // Reads that overlap share one request.
  let reading = null;
  const fetchRecord = () => {
    if (!reading) {
      reading = (async () => {
        try {
          const r = await api(`manager/runs/${encodeURIComponent(id)}`);
          readOwed = false;
          problem.hidden = true;
          showRecord(r);
          return r;
        } catch (err) {
          readOwed = true;
          problem.textContent = err.message;
          problem.hidden = false;
          return null;
        } finally {
          reading = null;
        }
      })();
    }
    return reading;
  };

  // True once the reader has moved to another page.
  let left = false;
  onLeave(() => { left = true; });
  const gone = () => left || !main.isConnected;

  const first = await fetchRecord();
  if (gone()) return;
  // A record that says it is running waits for the status, so a running job
  // is drawn as running from the start and its log follows new lines.
  let shown = false;
  if (first && first.state !== 'running') {
    shown = true;
    panel.show(first, null);
  }

  let wasLive = false;
  // Each answer that draws the panel gets the next number, so a read that
  // comes back after a newer answer does not draw over it.
  let drawTicket = 0;
  onLeave(subscribe(async (s) => {
    if (!s.on) {
      // The server could not be reached, or jobs are off: the record cannot
      // be read either. Read it again once the server answers.
      drawTicket++;
      readOwed = true;
      shown = false;
      problem.hidden = true;
      panel.off(s);
      return;
    }
    const current = s.current && s.current.record && s.current.record.id === id ? s.current : null;
    if (current) {
      drawTicket++;
      wasLive = true;
      shown = true;
      readOwed = false;
      problem.hidden = true;
      panel.show(current.record, current);
      return;
    }
    // The status does not list the run as running, so draw it as saved. This
    // also replaces "Viewing only" once the server answers again.
    if (record && !shown) {
      shown = true;
      panel.show(record, null);
    }
    // Read the record again when the run just ended (for its final record),
    // after a failed read, and when a waiting run has left the queue.
    const leftQueue = record && record.state === 'queued' && !(s.queued || []).some((q) => q.id === id);
    if (wasLive || readOwed || leftQueue) {
      const mine = drawTicket;
      const r = await fetchRecord();
      if (gone() || mine !== drawTicket || !r) return;
      wasLive = false;
      shown = true;
      panel.show(r, null);
    }
  }));
}
