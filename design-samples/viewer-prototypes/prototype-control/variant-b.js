// PROTOTYPE — throwaway. Variant B: "Timeline".
// One column reads now → next → before down a time rail, like a log. No boxes:
// structure comes from alignment and hairlines. Starting jobs and what needs
// attention live in a right-hand rail. Warm near-black with an orange accent.
import { NAV, START_JOBS, MORE_JOBS, esc, ico, kindLabel, duration, runDuration, ago, clock, pct, STATE_WORDS, logLevel } from './data.js';

export const name = 'Timeline';

export const css = `
.variant-B {
  --bg: #131210; --raise: #1a1916; --line: #2c2924; --line-2: #3d3932;
  --text: #ece7dd; --dim: #a8a295; --faint: #736e63;
  --accent: #ff9b52; --accent-ink: #1d1206;
  --run: #78c2ff; --ok: #7fd18b; --bad: #ff7468; --warn: #f2c14e;
  --mono: 'Cascadia Mono', 'Cascadia Code', Consolas, monospace;
  display: grid; grid-template-columns: 184px minmax(0, 1fr) 300px; min-height: 100vh;
  background: var(--bg); color: var(--text); font: 13px/1.5 'Segoe UI', system-ui, sans-serif; font-variant-numeric: tabular-nums;
}
.variant-B a { color: inherit; text-decoration: none; }
.variant-B .accent { color: var(--accent); cursor: pointer; }
.variant-B .accent:hover { text-decoration: underline; }
.variant-B .dim { color: var(--dim); } .variant-B .faint { color: var(--faint); }
.variant-B .mono { font-family: var(--mono); font-size: 12px; }

.variant-B .side { position: sticky; top: 0; height: 100vh; display: flex; flex-direction: column; padding: 16px 0 12px; border-right: 1px solid var(--line); }
.variant-B .brand { padding: 0 18px 8px; font-weight: 700; font-size: 14px; }
.variant-B .brand small { display: block; font-weight: 400; color: var(--faint); font-size: 11px; }
.variant-B .grp { padding: 14px 18px 3px; color: var(--faint); font-size: 11px; }
.variant-B .nav a { display: block; padding: 3px 18px; color: var(--dim); }
.variant-B .nav a:hover { color: var(--text); }
.variant-B .nav a.on { color: var(--text); font-weight: 650; }
.variant-B .nav a.on::before { content: '▸'; color: var(--accent); margin-left: -12px; width: 12px; display: inline-block; }
.variant-B .foot { margin-top: auto; padding: 10px 18px 0; border-top: 1px solid var(--line); display: grid; gap: 4px; }
.variant-B .status { display: flex; align-items: center; gap: 7px; font-weight: 650; }
.variant-B .sq { width: 8px; height: 8px; background: var(--faint); }
.variant-B .sq.run { background: var(--run); } .variant-B .sq.ok { background: var(--ok); }

.variant-B main { padding: 0 32px 90px; min-width: 0; }
.variant-B .head { display: flex; align-items: center; gap: 16px; padding: 14px 0 12px; border-bottom: 1px solid var(--line); position: sticky; top: 0; background: var(--bg); z-index: 3; }
.variant-B h1 { margin: 0; font-size: 20px; font-weight: 650; }
.variant-B .search { flex: 1; max-width: 460px; display: flex; align-items: center; gap: 8px; border-bottom: 1px solid var(--line-2); padding: 3px 0; color: var(--faint); }
.variant-B .search input { flex: 1; border: 0; background: none; color: var(--text); font: inherit; outline: none; }

.variant-B .tl { display: grid; grid-template-columns: 74px 22px minmax(0, 1fr); column-gap: 10px; margin-top: 18px; }
.variant-B .t { text-align: right; color: var(--faint); font-family: var(--mono); font-size: 11.5px; padding-top: 2px; white-space: nowrap; }
.variant-B .rail { position: relative; display: flex; justify-content: center; }
.variant-B .rail::before { content: ''; position: absolute; top: 0; bottom: 0; width: 1px; background: var(--line-2); }
.variant-B .rail i { position: relative; margin-top: 6px; width: 9px; height: 9px; border-radius: 50%; background: var(--bg); border: 1.5px solid var(--faint); }
.variant-B .rail i.running { background: var(--run); border-color: var(--run); box-shadow: 0 0 0 4px rgba(120,194,255,.15); }
.variant-B .rail i.queued { border-style: dashed; border-color: var(--dim); }
.variant-B .rail i.completed { background: var(--ok); border-color: var(--ok); }
.variant-B .rail i.failed { background: var(--bad); border-color: var(--bad); }
.variant-B .rail i.cancelled, .variant-B .rail i.interrupted { background: var(--warn); border-color: var(--warn); }
.variant-B .e { padding-bottom: 10px; min-width: 0; }
.variant-B .section { grid-column: 3; padding: 14px 0 6px; color: var(--faint); font-size: 11px; text-transform: uppercase; letter-spacing: .1em; }
.variant-B .title { display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap; }
.variant-B .title b { font-size: 15px; font-weight: 650; }
.variant-B .now b { font-size: 18px; }
.variant-B .meta { color: var(--dim); display: flex; gap: 14px; flex-wrap: wrap; }
.variant-B .meta .bad { color: var(--bad); }
.variant-B .prog { position: relative; height: 2px; background: var(--line-2); margin: 8px 0; }
.variant-B .prog i { position: absolute; left: 0; top: 0; bottom: 0; background: var(--run); }
.variant-B .log { margin: 8px 0 6px; padding: 2px 0 2px 12px; border-left: 2px solid var(--line-2); font: 11.5px/1.6 var(--mono); color: var(--dim); }
.variant-B .log div { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.variant-B .log .warn { color: var(--warn); } .variant-B .log .error { color: var(--bad); }
.variant-B .acts { display: flex; gap: 16px; }
.variant-B .row { display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 12px; padding-bottom: 4px; }
.variant-B .row .k { font-weight: 600; }
.variant-B .row .r { color: var(--dim); white-space: nowrap; }
.variant-B .row .err { grid-column: 1 / -1; color: var(--bad); opacity: .85; font-size: 12px; }
.variant-B .res.completed { color: var(--ok); } .variant-B .res.failed { color: var(--bad); }
.variant-B .res.cancelled, .variant-B .res.interrupted { color: var(--warn); }
.variant-B .offnote { margin-top: 18px; color: var(--dim); max-width: 560px; }

.variant-B .rail-r { border-left: 1px solid var(--line); padding: 14px 20px 90px; position: sticky; top: 0; height: 100vh; overflow: auto; }
.variant-B .rh { font-size: 11px; color: var(--faint); text-transform: uppercase; letter-spacing: .1em; margin: 0 0 8px; }
.variant-B .rh + * { margin-top: 0; }
.variant-B .blk { margin-bottom: 22px; }
.variant-B .start { display: grid; grid-template-columns: 20px 1fr auto; gap: 0 8px; align-items: baseline; padding: 7px 0; border-bottom: 1px solid var(--line); cursor: pointer; }
.variant-B .start:hover b { color: var(--accent); }
.variant-B .start .d { grid-column: 2 / -1; color: var(--faint); font-size: 12px; }
.variant-B .start .go { color: var(--accent); font-weight: 650; }
.variant-B .num { color: var(--faint); font-family: var(--mono); font-size: 11px; }
.variant-B .also { margin-top: 8px; color: var(--faint); font-size: 12px; }
.variant-B .also a { color: var(--dim); } .variant-B .also a:hover { color: var(--accent); }
.variant-B .att { display: grid; grid-template-columns: 34px 1fr; gap: 8px; padding: 4px 0; }
.variant-B .att b { text-align: right; color: var(--warn); }
.variant-B .att.bad b { color: var(--bad); }
.variant-B .att:hover span { color: var(--accent); }
.variant-B .pend { border-left: 2px solid var(--warn); padding: 4px 0 4px 10px; }
.variant-B .pend div { padding: 2px 0; }
.variant-B .pend .faint { font-size: 11px; display: block; }
.variant-B .btn { display: inline-block; margin-top: 8px; padding: 5px 12px; background: var(--accent); color: var(--accent-ink); border: 0; font: inherit; font-weight: 700; cursor: pointer; }
.variant-B .btn.line { background: none; color: var(--dim); border: 1px solid var(--line-2); font-weight: 500; }
`;

function sidebar(d) {
  const nav = NAV.map((g) => `<div class="grp">${g.title}</div><div class="nav">${g.items.map((it) =>
    `<a href="#" class="${it.active ? 'on' : ''}">${esc(it.label)}</a>`).join('')}</div>`).join('');
  const status = !d.managerOn ? `<div class="status"><span class="sq"></span>Viewing only</div>`
    : d.current ? `<div class="status"><span class="sq run"></span>Running ${pct(d.current.itemsDone, d.current.itemsTotal)}%</div>`
      : `<div class="status"><span class="sq ok"></span>Ready</div>`;
  return `<aside class="side"><div class="brand">Mod Repo Scraper<small>viewer</small></div>${nav}
    <div class="foot">${status}<div class="faint mono">v${esc(d.version.build)} · ${esc(d.version.commit)}</div>
    ${d.update ? `<a class="accent" href="#">Update to ${esc(d.update.available)}</a>` : ''}</div></aside>`;
}

function hhmm(iso) {
  if (!iso) return '';
  return new Date(iso).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit', hour12: false });
}
function dayOf(iso) {
  return iso ? new Date(iso).toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' }) : '';
}

function timeline(d) {
  const out = [];
  const row = (time, dot, body) => out.push(`<div class="t">${time}</div><div class="rail"><i class="${dot}"></i></div><div class="e">${body}</div>`);
  const section = (label) => out.push(`<div class="t"></div><div class="rail"></div><div class="section">${label}</div>`);

  if (d.current) {
    const c = d.current; const cn = c.record.counters; const p = pct(c.itemsDone, c.itemsTotal);
    section('Now');
    row(hhmm(c.record.startedAt), 'running', `<div class="now">
      <div class="title"><b>${esc(kindLabel(c.record.request.kind))}</b><span class="dim">${esc(c.phase)} — ${esc(c.item)}</span></div>
      <div class="prog"><i style="width:${p}%"></i></div>
      <div class="meta"><span>${p}% · ${c.itemsDone} of ${c.itemsTotal} topics</span><span>${duration(runDuration(c.record))}</span><span>${cn.llmCalls} LLM calls</span><span class="bad">${cn.errors} errors</span></div>
      <div class="log">${d.log.map((l) => `<div class="${logLevel(l)}">${esc(l)}</div>`).join('')}</div>
      <div class="acts"><a class="accent">Stop</a><a class="accent">Open run</a><a class="accent">What it has changed so far</a></div></div>`);
  } else if (d.managerOn) {
    section('Now');
    row('', '', `<div class="dim">Nothing running.</div>`);
  }
  if (d.queued.length) {
    section('Next');
    for (const j of d.queued) row('', 'queued', `<div class="title"><b>${esc(kindLabel(j.request.kind))}</b><span class="dim">starts when the run above ends</span> <a class="accent">Remove</a></div>`);
  }
  section('Before');
  let lastDay = '';
  for (const r of d.runs.slice(0, 18)) {
    const day = dayOf(r.startedAt);
    const time = day !== lastDay ? `${day}<br>${hhmm(r.startedAt)}` : hhmm(r.startedAt);
    lastDay = day;
    const counts = [r.counters.itemsDone ? `${r.counters.itemsDone} topics` : '', r.counters.llmCalls ? `${r.counters.llmCalls} LLM calls` : '', r.counters.errors ? `<span style="color:var(--bad)">${r.counters.errors} errors</span>` : ''].filter(Boolean).join(' · ');
    row(time, r.state, `<div class="row"><div><span class="k">${esc(kindLabel(r.request.kind))}</span> <span class="res ${r.state}">${esc(STATE_WORDS[r.state]?.toLowerCase())}</span>${counts ? ` <span class="dim">· ${counts}</span>` : ''}</div>
      <div class="r">${duration(runDuration(r))}</div>
      ${r.errorMessage || r.guardrailStop ? `<div class="err">${esc(r.errorMessage || r.guardrailStop)}</div>` : ''}</div>`);
  }
  out.push(`<div class="t"></div><div class="rail"></div><div class="e"><a class="accent">All run history</a></div>`);
  return `<div class="tl">${out.join('')}</div>`;
}

function rightRail(d) {
  const parts = [];
  if (d.managerOn) {
    parts.push(`<div class="blk"><h2 class="rh">Start</h2>
      ${START_JOBS.map((j, i) => `<div class="start"><span class="num">${i + 1}</span><b>${esc(j.label)}</b><span class="go">Start</span><span class="d">${esc(j.detail)} · <a class="accent" data-toggle="b-opt-${i}">options</a></span>
      <div class="d" id="b-opt-${i}" hidden>${j.options.map(esc).join('<br>')}</div></div>`).join('')}
      <div class="also">Also: ${MORE_JOBS.map((j) => `<a href="#">${esc(j.label)}</a>`).join(' · ')}</div></div>`);
  }
  if (d.pending.length) {
    parts.push(`<div class="blk"><h2 class="rh">Pending changes</h2><div class="pend">
      ${d.pending.map((p) => `<div><span class="faint">${esc(p.kind)}</span>${esc(p.text)}</div>`).join('')}</div>
      <button class="btn">Save and rebuild</button> <button class="btn line">Review</button></div>`);
  }
  if (d.attention.length) {
    parts.push(`<div class="blk"><h2 class="rh">Needs attention</h2>
      ${d.attention.map((a) => `<a class="att ${a.bad ? 'bad' : ''}" href="#"><b>${a.count}</b><span>${esc(a.label)}</span></a>`).join('')}</div>`);
  }
  return `<aside class="rail-r">${parts.join('')}</aside>`;
}

export function render(d) {
  return `${sidebar(d)}<main>
    <div class="head"><h1>Control</h1><label class="search">${ico('search', 14)}<input placeholder="Search mods, topics, threads, runs   ( / )"></label></div>
    ${d.managerOn ? '' : `<p class="offnote"><b>Viewing only.</b> The manager is off, so nothing can be started from here. Start the server without <span class="mono">--no-manager</span> to turn it on.</p>`}
    ${timeline(d)}
  </main>${rightRail(d)}`;
}
