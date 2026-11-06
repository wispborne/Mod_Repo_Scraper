// Run history: every saved run, newest first, a page at a time. The page
// number is kept in the address; rows per page is the viewer-wide setting.

import { el, clear, api, shortTime, pager, pageSizePreference } from '../lib.js';
import { subscribe } from '../status.js';
import { kindLabel, hashQuery, buildHash } from '../routes.js';
import { pageLayout, statusMark } from '../frame.js';
import { MARK_FOR_STATE, STATE_WORDS } from '../run_panel.js';
import { duration } from '../jobs.js';
import { runTime, startedAt } from '../run_record.js';

export function render({ content, onLeave, gone }) {
  // The address counts pages from 1; the server counts from 0.
  let page = Math.max(0, (parseInt(hashQuery(location.hash).get('page'), 10) || 1) - 1);
  let pageSize = pageSizePreference();
  const body = el('div', { class: 'list-page' }, [el('p', { class: 'empty', text: 'Loading…' })]);
  content.append(pageLayout(body));

  // Ignore responses to older requests once a newer request starts.
  let ticket = 0;
  let failed = false;
  const writeAddress = () => {
    history.replaceState(null, '', buildHash(['runs'], { page: page > 0 ? page + 1 : null }));
  };
  const load = async () => {
    // The address and the page belong to the next page once the reader has left.
    if (gone()) return;
    const mine = ++ticket;
    writeAddress();
    let data;
    try {
      data = await api('manager/runs', { page, pageSize });
    } catch (err) {
      if (mine !== ticket || gone()) return;
      failed = true;
      clear(body).append(el('p', { class: 'error-text', text: err.message }));
      return;
    }
    if (mine !== ticket || gone()) return;
    failed = false;
    const items = (data && data.items) || [];
    const total = (data && data.total) || 0;
    // A page past the end (old runs were removed, or the address asked for
    // too much) is answered with the last page, and the answer says which.
    if (data && Number.isInteger(data.page) && data.page !== page) {
      page = data.page;
      writeAddress();
    }
    clear(body).append(
      items.length ? runTable(items) : el('p', { class: 'empty', text: 'No runs yet.' }),
      pager(page, pageSize, total, (p) => {
        page = p;
        load();
      }, (size) => {
        pageSize = size;
        page = 0;
        load();
      }),
    );
  };

  // Refresh when the running job changes to show the finished run, when jobs
  // come back on (the server was down or restarted), and after a failed read.
  let lastCurrent;
  let lastOn = null;
  onLeave(subscribe((s) => {
    const current = s.current && s.current.record ? s.current.record.id : null;
    const cameBack = s.on && lastOn !== true;
    lastOn = !!s.on;
    if (current === lastCurrent && !cameBack && !(s.on && failed)) return;
    lastCurrent = current;
    load();
  }));
}

function runTable(items) {
  const head = el('tr', {}, [
    ['State', ''], ['Job', ''], ['Started', ''], ['Took', 'num'], ['Done', 'num'],
    ['Errors', 'num'], ['LLM calls', 'num'], ['Notes', ''],
  ].map(([text, cls]) => el('th', { class: cls, text })));

  const rows = items.map((r) => {
    const c = r.counters || {};
    const href = `#/runs/${encodeURIComponent(r.id)}`;
    const row = el('tr', { class: 'clickable' }, [
      el('td', {}, [el('span', { class: 'state-cell' }, [
        statusMark(MARK_FOR_STATE[r.state] || 'idle'),
        STATE_WORDS[r.state] || r.state,
      ])]),
      el('td', {}, [el('a', { href, text: kindLabel(r.request && r.request.kind) })]),
      el('td', { class: 'mono', text: shortTime(runTime(r)) }),
      el('td', { class: 'num mono', text: startedAt(r) ? duration(r.startedAt, r.finishedAt) : '' }),
      el('td', { class: 'num mono', text: c.itemsTotal ? `${c.itemsDone || 0} / ${c.itemsTotal}` : String(c.itemsDone || 0) }),
      el('td', { class: c.errors ? 'num mono failed-text' : 'num mono', text: String(c.errors || 0) }),
      el('td', { class: 'num mono', text: String(c.llmCalls || 0) }),
      el('td', {}, notes(r)),
    ]);
    // Clicking anywhere in the row opens the run. The job link supports keyboard navigation.
    row.addEventListener('click', (e) => {
      if (e.target.closest('a')) return;
      location.hash = href;
    });
    return row;
  });

  return el('div', { class: 'table-wrap' }, [
    el('table', { class: 'table' }, [el('thead', {}, [head]), el('tbody', {}, rows)]),
  ]);
}

function notes(r) {
  const out = [];
  if (r.guardrailStop) out.push(el('span', { class: 'note-tag warn-text', title: r.guardrailStop, text: 'Limit reached' }));
  if (r.errorMessage) out.push(el('span', { class: 'note-tag failed-text', title: r.errorMessage, text: 'Error' }));
  return out;
}
