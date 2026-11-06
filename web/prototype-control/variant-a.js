// PROTOTYPE — throwaway. Variant A: "Instrument panel".
// A wide band for the live run, then tiles, then a dense table of recent runs.
// Graphite with a lime accent for anything you can press.
import { NAV, START_JOBS, MORE_JOBS, esc, ico, kindLabel, duration, runDuration, ago, clock, pct, STATE_WORDS, logLevel } from './data.js';

export const name = 'Instrument panel';

export const css = `
.variant-A {
  --bg: #111214; --panel: #18191c; --panel-2: #1f2125; --line: #2a2d32; --line-2: #3a3e45;
  --text: #e8e6e1; --dim: #a2a4a9; --faint: #6f7278;
  --accent: #d4f25f; --accent-ink: #15170c;
  --run: #6cb6ff; --ok: #5bd49a; --bad: #ff6b6b; --warn: #f0b84f;
  --mono: 'Cascadia Mono', 'Cascadia Code', Consolas, monospace;
  display: flex; min-height: 100vh; background: var(--bg); color: var(--text);
  font: 13px/1.45 'Segoe UI', system-ui, sans-serif; font-variant-numeric: tabular-nums;
}
.variant-A a { color: inherit; text-decoration: none; }
.variant-A .ico { flex-shrink: 0; }
.variant-A .side { width: 208px; flex-shrink: 0; background: var(--panel); border-right: 1px solid var(--line);
  display: flex; flex-direction: column; position: sticky; top: 0; height: 100vh; }
.variant-A .brand { display: flex; align-items: center; gap: 8px; padding: 14px 14px 10px; font-weight: 700; letter-spacing: .02em; }
.variant-A .brand .mark { width: 18px; height: 18px; background: var(--accent); clip-path: polygon(50% 0, 100% 100%, 0 100%); }
.variant-A .grp { padding: 14px 14px 4px; font-size: 11px; font-weight: 600; color: var(--faint); text-transform: uppercase; letter-spacing: .08em; }
.variant-A .nav a { display: flex; align-items: center; gap: 9px; padding: 5px 14px; color: var(--dim); }
.variant-A .nav a:hover { color: var(--text); background: var(--panel-2); }
.variant-A .nav a.on { color: var(--text); background: var(--panel-2); box-shadow: inset 2px 0 0 var(--accent); }
.variant-A .nav a.on .ico { color: var(--accent); }
.variant-A .foot { margin-top: auto; border-top: 1px solid var(--line); padding: 10px 14px; display: grid; gap: 6px; }
.variant-A .chip { display: flex; align-items: center; gap: 8px; font-weight: 600; }
.variant-A .dot { width: 8px; height: 8px; border-radius: 50%; background: var(--faint); flex-shrink: 0; }
.variant-A .dot.run { background: var(--run); box-shadow: 0 0 0 3px rgba(108,182,255,.18); }
.variant-A .dot.ok { background: var(--ok); }
.variant-A .ver { color: var(--faint); font-family: var(--mono); font-size: 11px; }
.variant-A .upd { justify-self: start; }

.variant-A main { flex: 1; min-width: 0; }
.variant-A .top { display: flex; align-items: center; gap: 10px; padding: 8px 20px; border-bottom: 1px solid var(--line); background: var(--bg); position: sticky; top: 0; z-index: 5; }
.variant-A .search { flex: 1; max-width: 520px; display: flex; align-items: center; gap: 8px; padding: 5px 10px; border: 1px solid var(--line-2); background: var(--panel); color: var(--faint); border-radius: 4px; }
.variant-A .search input { flex: 1; background: none; border: 0; color: var(--text); font: inherit; outline: none; }
.variant-A kbd { font: 11px var(--mono); padding: 0 5px; border: 1px solid var(--line-2); border-radius: 3px; color: var(--dim); }
.variant-A .pending { display: flex; align-items: center; gap: 8px; margin-left: auto; padding: 4px 10px; border: 1px solid var(--warn); color: var(--warn); border-radius: 4px; font-weight: 600; }
.variant-A .content { padding: 16px 20px 80px; display: grid; gap: 14px; max-width: 1400px; }
.variant-A h1 { margin: 0; font-size: 18px; font-weight: 650; }
.variant-A .h { font-size: 11px; font-weight: 600; color: var(--faint); text-transform: uppercase; letter-spacing: .08em; margin: 0 0 8px; display: flex; align-items: center; gap: 8px; }
.variant-A .h .n { color: var(--dim); letter-spacing: 0; }

.variant-A .btn { display: inline-flex; align-items: center; gap: 6px; padding: 5px 10px; border: 1px solid var(--line-2); background: var(--panel-2); color: var(--text); border-radius: 4px; font: inherit; font-weight: 600; cursor: pointer; }
.variant-A .btn:hover { border-color: var(--dim); }
.variant-A .btn.primary { background: var(--accent); color: var(--accent-ink); border-color: var(--accent); }
.variant-A .btn.ghost { background: none; }
.variant-A .btn.danger { color: var(--bad); }
.variant-A .link { color: var(--accent); cursor: pointer; }
.variant-A .link:hover { text-decoration: underline; }

/* The live run band */
.variant-A .now { border: 1px solid var(--line); background: var(--panel); border-radius: 6px; display: grid; grid-template-columns: minmax(0, 1fr) 360px; }
.variant-A .now.running { border-color: rgba(108,182,255,.45); }
.variant-A .now-main { padding: 14px 16px; display: grid; gap: 10px; }
.variant-A .now-title { display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap; }
.variant-A .state { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .08em; padding: 2px 7px; border-radius: 3px; }
.variant-A .state.running { color: var(--run); background: rgba(108,182,255,.12); }
.variant-A .state.idle { color: var(--dim); background: var(--panel-2); }
.variant-A .now-kind { font-size: 18px; font-weight: 650; }
.variant-A .now-phase { color: var(--dim); }
.variant-A .bar { height: 6px; background: var(--panel-2); border-radius: 3px; overflow: hidden; }
.variant-A .bar > i { display: block; height: 100%; background: var(--run); }
.variant-A .stats { display: flex; gap: 24px; flex-wrap: wrap; }
.variant-A .stat b { display: block; font-size: 17px; font-weight: 650; }
.variant-A .stat span { color: var(--faint); font-size: 11px; text-transform: uppercase; letter-spacing: .06em; }
.variant-A .stat.bad b { color: var(--bad); }
.variant-A .now-log { border-left: 1px solid var(--line); background: #0c0d0f; padding: 10px 12px; font: 11.5px/1.55 var(--mono); color: var(--dim); overflow: hidden; border-radius: 0 6px 6px 0; }
.variant-A .now-log div { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.variant-A .now-log .warn { color: var(--warn); }
.variant-A .now-log .error { color: var(--bad); }

.variant-A .tiles { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 14px; }
.variant-A .tile { border: 1px solid var(--line); background: var(--panel); border-radius: 6px; padding: 12px 14px; }
.variant-A .job { display: grid; grid-template-columns: auto 1fr auto; gap: 2px 10px; align-items: center; padding: 8px 0; border-top: 1px solid var(--line); }
.variant-A .job:first-of-type { border-top: 0; padding-top: 0; }
.variant-A .job .d { grid-column: 2; color: var(--faint); font-size: 12px; }
.variant-A .job .opts { grid-column: 1 / -1; margin: 6px 0 0; padding: 8px 10px; background: var(--panel-2); border-radius: 4px; color: var(--dim); font-size: 12px; }
.variant-A .more { margin-top: 8px; padding-top: 8px; border-top: 1px solid var(--line); display: flex; gap: 6px; flex-wrap: wrap; }
.variant-A .att { display: flex; align-items: center; gap: 10px; padding: 6px 0; border-top: 1px solid var(--line); }
.variant-A .att:first-of-type { border-top: 0; }
.variant-A .att .c { min-width: 34px; text-align: right; font-weight: 700; font-size: 15px; color: var(--warn); }
.variant-A .att.bad .c { color: var(--bad); }
.variant-A .att .w { margin-left: auto; color: var(--faint); font-size: 12px; }
.variant-A .att:hover .w { color: var(--accent); }
.variant-A .q { display: flex; align-items: center; gap: 8px; padding: 6px 0; border-top: 1px solid var(--line); }
.variant-A .q:first-of-type { border-top: 0; }
.variant-A .muted { color: var(--faint); }
.variant-A .kv { display: grid; grid-template-columns: auto 1fr; gap: 3px 12px; }
.variant-A .kv dt { color: var(--faint); }
.variant-A .kv dd { margin: 0; }

.variant-A table { width: 100%; border-collapse: collapse; }
.variant-A th { text-align: left; font-size: 11px; font-weight: 600; color: var(--faint); text-transform: uppercase; letter-spacing: .06em; padding: 6px 10px; border-bottom: 1px solid var(--line-2); }
.variant-A td { padding: 5px 10px; border-bottom: 1px solid var(--line); white-space: nowrap; }
.variant-A tr:hover td { background: var(--panel-2); }
.variant-A td.num { text-align: right; }
.variant-A .rs { display: inline-flex; align-items: center; gap: 6px; }
.variant-A .rs.completed { color: var(--ok); }
.variant-A .rs.failed { color: var(--bad); }
.variant-A .rs.cancelled, .variant-A .rs.interrupted { color: var(--warn); }
.variant-A .off { padding: 14px 16px; color: var(--dim); }
`;

function sidebar(d) {
  const nav = NAV.map((g) => `<div class="grp">${g.title}</div><div class="nav">${g.items.map((it) =>
    `<a href="#" class="${it.active ? 'on' : ''}">${ico(it.icon, 16)}${esc(it.label)}</a>`).join('')}</div>`).join('');
  const chip = !d.managerOn
    ? `<div class="chip"><span class="dot"></span>Viewing only</div>`
    : d.current
      ? `<div class="chip"><span class="dot run"></span>Running · ${pct(d.current.itemsDone, d.current.itemsTotal)}%</div>`
      : `<div class="chip"><span class="dot ok"></span>Ready</div>`;
  return `<aside class="side">
    <div class="brand"><span class="mark"></span>Mod Repo Scraper</div>
    ${nav}
    <div class="foot">${chip}
      <div class="ver">v${esc(d.version.build)} · ${esc(d.version.commit)}</div>
      ${d.update ? `<button class="btn upd">${ico('download', 14)}Update to ${esc(d.update.available)}</button>` : ''}
    </div></aside>`;
}

function topBar(d) {
  return `<div class="top">
    <label class="search">${ico('search', 15)}<input placeholder="Search mods, topics, Discord threads, runs"><kbd>/</kbd></label>
    ${d.pending.length ? `<a class="pending" href="#">${ico('inbox', 15)}${d.pending.length} pending changes</a>` : ''}
  </div>`;
}

function nowBand(d) {
  if (!d.managerOn) {
    return `<section class="now"><div class="off"><b>Viewing only.</b> The manager is off, so jobs can't be started here. Start the server without <code>--no-manager</code> to turn it on.</div></section>`;
  }
  const c = d.current;
  if (!c) {
    const r = d.lastRun;
    return `<section class="now"><div class="now-main">
      <div class="now-title"><span class="state idle">Idle</span><span class="now-kind">Nothing running</span>
      ${r ? `<span class="now-phase">Last run: ${esc(kindLabel(r.request.kind))}, ${esc(STATE_WORDS[r.state]?.toLowerCase())} ${esc(ago(r.finishedAt))}</span>` : ''}</div>
      </div><div class="now-log">${d.log.map((l) => `<div class="${logLevel(l)}">${esc(l)}</div>`).join('') || '<div>No log yet.</div>'}</div></section>`;
  }
  const p = pct(c.itemsDone, c.itemsTotal);
  const cn = c.record.counters;
  return `<section class="now running"><div class="now-main">
    <div class="now-title"><span class="state running">Running</span><span class="now-kind">${esc(kindLabel(c.record.request.kind))}</span>
      <span class="now-phase">${esc(c.phase)} — ${esc(c.item)}</span></div>
    <div class="bar"><i style="width:${p}%"></i></div>
    <div class="stats">
      <div class="stat"><b>${p}%</b><span>${c.itemsDone} of ${c.itemsTotal} topics</span></div>
      <div class="stat"><b>${duration(runDuration(c.record))}</b><span>Elapsed</span></div>
      <div class="stat"><b>${cn.llmCalls}</b><span>LLM calls</span></div>
      <div class="stat bad"><b>${cn.errors}</b><span>Errors</span></div>
      <div style="margin-left:auto;display:flex;gap:8px;align-items:center">
        <a class="link" href="#">What it has changed so far</a>
        <button class="btn danger">${ico('stop', 13)}Stop</button></div>
    </div></div>
    <div class="now-log">${d.log.map((l) => `<div class="${logLevel(l)}">${esc(l)}</div>`).join('')}</div></section>`;
}

function startTile(d) {
  if (!d.managerOn) return '';
  const jobs = START_JOBS.map((j, i) => `<div class="job">
      ${ico(j.icon, 18)}<b>${esc(j.label)}</b>
      <button class="btn ${i === 0 ? 'primary' : ''}">Start</button>
      <span class="d">${esc(j.detail)} · <a class="link" data-toggle="a-opt-${i}">Options</a></span>
      <div class="opts" id="a-opt-${i}" hidden>${j.options.map(esc).join('<br>')}</div>
    </div>`).join('');
  return `<section class="tile"><h2 class="h">Start a job</h2>${jobs}
    <div class="more"><span class="muted" style="align-self:center">Also:</span>${MORE_JOBS.map((j) => `<button class="btn ghost">${esc(j.label)}</button>`).join('')}</div></section>`;
}

function attentionTile(d) {
  if (!d.attention.length) return '';
  return `<section class="tile"><h2 class="h">Needs attention <span class="n">${d.attention.length}</span></h2>
    ${d.attention.map((a) => `<a class="att ${a.bad ? 'bad' : ''}" href="#"><span class="c">${a.count}</span><span>${esc(a.label)}</span><span class="w">${esc(a.where)} ${ico('chevron', 13)}</span></a>`).join('')}</section>`;
}

function queueAndLast(d) {
  const r = d.lastRun;
  const q = d.managerOn ? `<h2 class="h">Queue <span class="n">${d.queued.length}</span></h2>
    ${d.queued.length ? d.queued.map((j) => `<div class="q">${ico('clock', 15)}<span>${esc(kindLabel(j.request.kind))}</span><span class="muted" style="margin-left:auto">after this run</span></div>`).join('') : '<div class="muted">Nothing waiting.</div>'}` : '';
  const last = r ? `<h2 class="h" style="margin-top:14px">Last run</h2>
    <dl class="kv">
      <dt>Job</dt><dd>${esc(kindLabel(r.request.kind))}</dd>
      <dt>Result</dt><dd><span class="rs ${r.state}">${esc(STATE_WORDS[r.state])}</span>${r.errorMessage ? ` — ${esc(r.errorMessage)}` : ''}</dd>
      <dt>Ended</dt><dd>${esc(clock(r.finishedAt))} (${esc(ago(r.finishedAt))})</dd>
      <dt>Took</dt><dd>${duration(runDuration(r))}</dd>
      <dt>Counts</dt><dd>${r.counters.errors} errors · ${r.counters.llmCalls} LLM calls</dd>
    </dl><div style="margin-top:8px"><a class="link" href="#">What this run changed</a></div>` : '';
  return `<section class="tile">${q}${last}</section>`;
}

function history(d) {
  const rows = d.runs.slice(0, 12).map((r) => `<tr>
    <td><span class="rs ${r.state}">${ico(r.state === 'completed' ? 'check' : r.state === 'failed' ? 'x' : 'alert', 14)}${esc(STATE_WORDS[r.state])}</span></td>
    <td>${esc(kindLabel(r.request.kind))}</td>
    <td class="muted">${esc(clock(r.startedAt))}</td>
    <td class="num">${duration(runDuration(r))}</td>
    <td class="num">${r.counters.itemsDone || '—'}</td>
    <td class="num">${r.counters.llmCalls || '—'}</td>
    <td class="num" style="${r.counters.errors ? 'color:var(--bad)' : ''}">${r.counters.errors || '—'}</td>
    <td class="muted" style="max-width:340px;overflow:hidden;text-overflow:ellipsis">${esc(r.errorMessage || r.guardrailStop || '')}</td>
  </tr>`).join('');
  return `<section><h2 class="h">Recent runs <a class="link" style="margin-left:auto;text-transform:none;letter-spacing:0;font-weight:500" href="#">All run history</a></h2>
    <table><thead><tr><th>Result</th><th>Job</th><th>Started</th><th style="text-align:right">Took</th><th style="text-align:right">Topics</th><th style="text-align:right">LLM calls</th><th style="text-align:right">Errors</th><th>Note</th></tr></thead>
    <tbody>${rows}</tbody></table></section>`;
}

export function render(d) {
  return `${sidebar(d)}<main>${topBar(d)}<div class="content">
    <h1>Control</h1>
    ${nowBand(d)}
    <div class="tiles" style="${d.managerOn ? '' : 'grid-template-columns:1fr 1fr'}">${startTile(d)}${attentionTile(d)}${queueAndLast(d)}</div>
    ${history(d)}
  </div></main>`;
}
