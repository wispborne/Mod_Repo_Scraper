// PROTOTYPE — throwaway. Variant C: "Workbench".
// Laid out like a code editor: a narrow icon rail, a toolbar that holds the
// jobs, a large log panel with tabs, stacked side panels, and a status bar
// along the bottom. Blue-grey slate with a violet accent.
import { NAV, START_JOBS, MORE_JOBS, esc, ico, kindLabel, duration, runDuration, ago, clock, pct, STATE_WORDS, logLevel } from './data.js';

export const name = 'Workbench';

export const css = `
.variant-C {
  --bg: #0e1217; --panel: #141a21; --panel-2: #1a222b; --line: #232c37; --line-2: #2f3a47;
  --text: #dfe6ee; --dim: #94a1b0; --faint: #64707e;
  --accent: #b69dff; --accent-ink: #160f2a;
  --run: #5cc8ff; --ok: #57d68d; --bad: #ff6b81; --warn: #ffc34d;
  --mono: 'Cascadia Mono', 'Cascadia Code', Consolas, monospace;
  display: grid; grid-template-columns: 48px minmax(0, 1fr); grid-template-rows: minmax(0, 1fr) 24px;
  height: 100vh; background: var(--bg); color: var(--text); font: 12.5px/1.45 'Segoe UI', system-ui, sans-serif; font-variant-numeric: tabular-nums;
}
.variant-C a { color: inherit; text-decoration: none; }
.variant-C .dim { color: var(--dim); } .variant-C .faint { color: var(--faint); }

.variant-C .rail { grid-row: 1 / 3; background: var(--panel); border-right: 1px solid var(--line); display: flex; flex-direction: column; align-items: center; padding: 8px 0; gap: 2px; }
.variant-C .rail .logo { width: 26px; height: 26px; margin-bottom: 8px; display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-weight: 800; font-size: 13px; border-radius: 6px; }
.variant-C .rail a { width: 36px; height: 32px; display: grid; place-items: center; color: var(--faint); border-radius: 6px; position: relative; }
.variant-C .rail a:hover { color: var(--text); background: var(--panel-2); }
.variant-C .rail a.on { color: var(--accent); background: var(--panel-2); }
.variant-C .rail a.on::before { content: ''; position: absolute; left: -6px; top: 7px; bottom: 7px; width: 2px; background: var(--accent); }
.variant-C .rail hr { width: 22px; border: 0; border-top: 1px solid var(--line-2); margin: 6px 0; }
.variant-C .rail a[data-tip]:hover::after { content: attr(data-tip); position: absolute; left: 44px; white-space: nowrap; background: var(--panel-2); border: 1px solid var(--line-2); color: var(--text); padding: 3px 8px; border-radius: 4px; z-index: 9; }

.variant-C .work { display: flex; flex-direction: column; min-width: 0; min-height: 0; }
.variant-C .split-view { flex: 1; }
.variant-C .tool { display: flex; align-items: center; gap: 6px; padding: 6px 12px; border-bottom: 1px solid var(--line); background: var(--panel); }
.variant-C .tool h1 { font-size: 13px; margin: 0 10px 0 0; font-weight: 650; }
.variant-C .tb { display: inline-flex; align-items: center; gap: 6px; height: 26px; padding: 0 10px; border: 1px solid var(--line-2); background: var(--panel-2); color: var(--text); border-radius: 5px; font: inherit; cursor: pointer; white-space: nowrap; }
.variant-C .tb:hover { border-color: var(--accent); }
.variant-C .tb.primary { background: var(--accent); color: var(--accent-ink); border-color: var(--accent); font-weight: 650; }
.variant-C .tb.split { padding-right: 6px; }
.variant-C .tb .caret { border-left: 1px solid rgba(0,0,0,.25); padding-left: 5px; margin-left: 2px; display: inline-flex; }
.variant-C .tb.danger { color: var(--bad); }
.variant-C .tb[disabled] { opacity: .45; cursor: default; }
.variant-C .gap { flex: 1; }
.variant-C .search { display: flex; align-items: center; gap: 6px; width: 340px; height: 26px; padding: 0 8px; background: var(--bg); border: 1px solid var(--line-2); border-radius: 5px; color: var(--faint); }
.variant-C .search input { flex: 1; border: 0; background: none; color: var(--text); font: inherit; outline: none; }
.variant-C .badge { display: inline-flex; align-items: center; gap: 5px; height: 26px; padding: 0 9px; border-radius: 5px; background: rgba(255,195,77,.12); color: var(--warn); font-weight: 650; cursor: pointer; }

.variant-C .opts { display: flex; gap: 16px; flex-wrap: wrap; padding: 8px 12px; border-bottom: 1px solid var(--line); background: var(--panel-2); color: var(--dim); }
.variant-C .opts label { display: inline-flex; gap: 5px; align-items: center; }

.variant-C .split-view { display: grid; grid-template-columns: minmax(0, 1fr) 360px; min-height: 0; }
.variant-C .center { display: grid; grid-template-rows: auto auto minmax(0, 1fr); min-height: 0; border-right: 1px solid var(--line); }
.variant-C .runhead { display: grid; grid-template-columns: auto 1fr auto; gap: 4px 12px; align-items: center; padding: 10px 14px; border-bottom: 1px solid var(--line); }
.variant-C .pill { font-size: 11px; font-weight: 700; padding: 2px 8px; border-radius: 10px; text-transform: uppercase; letter-spacing: .06em; }
.variant-C .pill.running { background: rgba(92,200,255,.14); color: var(--run); }
.variant-C .pill.completed { background: rgba(87,214,141,.12); color: var(--ok); }
.variant-C .pill.failed { background: rgba(255,107,129,.14); color: var(--bad); }
.variant-C .pill.idle, .variant-C .pill.cancelled, .variant-C .pill.interrupted { background: var(--panel-2); color: var(--dim); }
.variant-C .runhead b { font-size: 15px; }
.variant-C .chips { grid-column: 1 / -1; display: flex; gap: 6px; flex-wrap: wrap; }
.variant-C .chip { font-family: var(--mono); font-size: 11.5px; padding: 1px 7px; background: var(--panel-2); border: 1px solid var(--line); border-radius: 4px; color: var(--dim); }
.variant-C .chip b { color: var(--text); font-weight: 600; }
.variant-C .chip.bad b { color: var(--bad); }
.variant-C .meter { grid-column: 1 / -1; height: 3px; background: var(--panel-2); border-radius: 2px; overflow: hidden; }
.variant-C .meter i { display: block; height: 100%; background: linear-gradient(90deg, var(--run), var(--accent)); }
.variant-C .tabs { display: flex; gap: 0; border-bottom: 1px solid var(--line); padding: 0 8px; background: var(--panel); }
.variant-C .tabs a { padding: 7px 12px; color: var(--dim); border-bottom: 2px solid transparent; }
.variant-C .tabs a.on { color: var(--text); border-bottom-color: var(--accent); }
.variant-C .term { overflow: auto; background: #0a0d11; padding: 10px 14px; font: 12px/1.65 var(--mono); color: var(--dim); }
.variant-C .term div { white-space: pre; }
.variant-C .term .ln { display: inline-block; width: 34px; color: #3a4552; user-select: none; }
.variant-C .term .warn { color: var(--warn); } .variant-C .term .error { color: var(--bad); }
.variant-C .term .cursor { display: inline-block; width: 7px; height: 13px; background: var(--run); vertical-align: -2px; animation: c-blink 1s steps(2) infinite; }
@keyframes c-blink { 50% { opacity: 0; } }
.variant-C .offmsg { padding: 18px; color: var(--dim); }

.variant-C .stack { overflow: auto; min-height: 0; }
.variant-C .pane { border-bottom: 1px solid var(--line); }
.variant-C .pane h2 { display: flex; align-items: center; gap: 6px; margin: 0; padding: 7px 12px; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .08em; color: var(--dim); background: var(--panel); cursor: pointer; }
.variant-C .pane h2 .n { margin-left: auto; font-family: var(--mono); color: var(--faint); letter-spacing: 0; }
.variant-C .item { display: grid; grid-template-columns: 38px minmax(0, 1fr) auto; gap: 8px; align-items: center; padding: 5px 12px; }
.variant-C .item:hover { background: var(--panel-2); }
.variant-C .item .c { text-align: right; font-family: var(--mono); font-weight: 700; color: var(--warn); }
.variant-C .item.bad .c { color: var(--bad); }
.variant-C .item .go { color: var(--faint); }
.variant-C .item:hover .go { color: var(--accent); }
.variant-C .pend { padding: 6px 12px 10px; display: grid; gap: 4px; }
.variant-C .pend .p { display: flex; gap: 8px; align-items: baseline; }
.variant-C .pend .k { font-size: 11px; color: var(--warn); min-width: 78px; }
.variant-C .runs .r { display: grid; grid-template-columns: 14px minmax(0, 1fr) auto; gap: 8px; align-items: center; padding: 4px 12px; }
.variant-C .runs .r:hover { background: var(--panel-2); }
.variant-C .sd { width: 7px; height: 7px; border-radius: 50%; background: var(--faint); justify-self: center; }
.variant-C .sd.completed { background: var(--ok); } .variant-C .sd.failed { background: var(--bad); }
.variant-C .sd.cancelled, .variant-C .sd.interrupted { background: var(--warn); }
.variant-C .runs .when { font-family: var(--mono); font-size: 11px; color: var(--faint); }
.variant-C .more { padding: 6px 12px 10px; }
.variant-C .more a { color: var(--accent); }

.variant-C .statusbar { grid-column: 2; display: flex; align-items: center; gap: 14px; padding: 0 10px; background: var(--panel); border-top: 1px solid var(--line); font-size: 11.5px; color: var(--dim); }
.variant-C .statusbar .st { display: inline-flex; align-items: center; gap: 6px; color: var(--text); }
.variant-C .statusbar .st i { width: 7px; height: 7px; border-radius: 50%; background: var(--faint); }
.variant-C .statusbar .st i.run { background: var(--run); } .variant-C .statusbar .st i.ok { background: var(--ok); }
.variant-C .statusbar .upd { color: var(--accent); }
`;

function rail() {
  const groups = NAV.map((g) => g.items.map((it) => `<a href="#" class="${it.active ? 'on' : ''}" data-tip="${esc(it.label)}" aria-label="${esc(it.label)}">${ico(it.icon, 18)}</a>`).join(''));
  return `<nav class="rail"><div class="logo">M</div>${groups.join('<hr>')}</nav>`;
}

function toolbar(d) {
  const off = !d.managerOn;
  const [fetchJob, llm, rebuild, publish] = START_JOBS;
  return `<div class="tool"><h1>Control</h1>
    <button class="tb primary split" ${off ? 'disabled' : ''}>${ico('play', 13)}${esc(fetchJob.label)}<span class="caret" data-toggle="c-opts">${ico('chevron-down', 13)}</span></button>
    <button class="tb split" ${off ? 'disabled' : ''}>${ico(llm.icon, 14)}${esc(llm.label)} <span class="faint">· only changed</span><span class="caret" data-toggle="c-llm">${ico('chevron-down', 13)}</span></button>
    <button class="tb" ${off ? 'disabled' : ''}>${ico(rebuild.icon, 14)}${esc(rebuild.label)}</button>
    <button class="tb" ${off ? 'disabled' : ''}>${ico(publish.icon, 14)}${esc(publish.label)}</button>
    <button class="tb" ${off ? 'disabled' : ''}>More ${ico('chevron-down', 13)}</button>
    <span class="gap"></span>
    ${d.pending.length ? `<span class="badge">${ico('inbox', 14)}${d.pending.length} pending</span>` : ''}
    <label class="search">${ico('search', 14)}<input placeholder="Search…"><span class="faint">/</span></label>
  </div>
  <div class="opts" id="c-opts" hidden>
    <span>Fetch and update:</span>
    <label>Scope <select><option>New and changed</option><option>Everything</option></select></label>
    <label><input type="checkbox" checked>Mods</label><label><input type="checkbox" checked>Lesser</label><label><input type="checkbox" checked>Libraries</label>
    <label><input type="checkbox" checked>Discord</label><label><input type="checkbox">Nexus</label>
    <label><input type="checkbox" checked>LLM</label>
    <span class="faint">Also: ${MORE_JOBS.map((j) => esc(j.label)).join(' · ')}</span>
  </div>
  <div class="opts" id="c-llm" hidden>
    <span>Run LLM on:</span>
    <label><input type="radio" name="c-llm" checked>Only changed posts</label>
    <label><input type="radio" name="c-llm">All posts</label>
    <span class="faint">The LLM call cap still applies.</span>
  </div>`;
}

function center(d) {
  if (!d.managerOn) {
    return `<section class="center"><div class="runhead"><span class="pill idle">Viewing only</span><b>The manager is off</b><span></span></div>
      <div class="tabs"><a class="on">Log</a></div>
      <div class="offmsg">Jobs can't be started from here. Start the server without <code>--no-manager</code> to turn the manager on.</div></section>`;
  }
  const c = d.current;
  const r = c ? c.record : d.lastRun;
  if (!r) return '<section class="center"></section>';
  const state = c ? 'running' : r.state;
  const cn = r.counters;
  const p = c ? pct(c.itemsDone, c.itemsTotal) : null;
  const lines = d.log.map((l, i) => `<div class="${logLevel(l)}"><span class="ln">${i + 1}</span>${esc(l)}</div>`).join('');
  return `<section class="center">
    <div class="runhead">
      <span class="pill ${state}">${c ? 'Running' : esc(STATE_WORDS[r.state])}</span>
      <div><b>${esc(kindLabel(r.request.kind))}</b> <span class="dim">${c ? `${esc(c.phase)} — ${esc(c.item)}` : `last run · ended ${esc(ago(r.finishedAt))}`}</span></div>
      <div style="display:flex;gap:6px">${c ? `<button class="tb danger">${ico('stop', 12)}Stop</button>` : `<button class="tb">${ico('refresh', 13)}Run again</button>`}</div>
      ${c ? `<div class="meter"><i style="width:${p}%"></i></div>` : ''}
      <div class="chips">
        ${c ? `<span class="chip"><b>${p}%</b> ${c.itemsDone}/${c.itemsTotal} topics</span>` : ''}
        <span class="chip">took <b>${duration(runDuration(r))}</b></span>
        <span class="chip"><b>${cn.llmCalls}</b> LLM calls</span>
        <span class="chip ${cn.errors ? 'bad' : ''}"><b>${cn.errors}</b> errors</span>
        <span class="chip">${esc(r.id)}</span>
      </div>
    </div>
    <div class="tabs"><a class="on" href="#">Log</a><a href="#">${c ? 'Changed so far' : 'What it changed'}</a><a href="#">Record</a></div>
    <div class="term">${lines}${c ? '<div><span class="ln"></span><span class="cursor"></span></div>' : ''}</div>
  </section>`;
}

function side(d) {
  const panes = [];
  if (d.pending.length) {
    panes.push(`<div class="pane"><h2>${ico('inbox', 13)}Pending changes<span class="n">${d.pending.length}</span></h2>
      <div class="pend">${d.pending.map((p) => `<div class="p"><span class="k">${esc(p.kind)}</span><span>${esc(p.text)}</span></div>`).join('')}
      <div style="display:flex;gap:6px;margin-top:6px"><button class="tb primary">Save and rebuild</button><button class="tb">Review</button></div></div></div>`);
  }
  if (d.attention.length) {
    panes.push(`<div class="pane"><h2>${ico('alert', 13)}Needs attention<span class="n">${d.attention.length}</span></h2>
      ${d.attention.map((a) => `<a class="item ${a.bad ? 'bad' : ''}" href="#"><span class="c">${a.count}</span><span>${esc(a.label)}</span><span class="go">${ico('chevron', 13)}</span></a>`).join('')}</div>`);
  }
  if (d.managerOn) {
    panes.push(`<div class="pane"><h2>${ico('clock', 13)}Queue<span class="n">${d.queued.length}</span></h2>
      ${d.queued.length ? d.queued.map((j) => `<div class="item"><span class="c" style="color:var(--faint)">${ico('clock', 13)}</span><span>${esc(kindLabel(j.request.kind))}</span><a class="go" href="#">${ico('x', 13)}</a></div>`).join('') : '<div class="item"><span></span><span class="faint">Nothing waiting</span></div>'}</div>`);
  }
  panes.push(`<div class="pane runs"><h2>${ico('history', 13)}Recent runs<span class="n">${d.runs.length}</span></h2>
    ${d.runs.slice(0, 14).map((r) => `<a class="r" href="#" title="${esc(r.errorMessage || '')}"><span class="sd ${r.state}"></span><span>${esc(kindLabel(r.request.kind))}${r.counters.errors ? ` <span style="color:var(--bad)">· ${r.counters.errors} errors</span>` : ''}</span><span class="when">${esc(clock(r.startedAt))}</span></a>`).join('')}
    <div class="more"><a href="#">All run history</a></div></div>`);
  return `<aside class="stack">${panes.join('')}</aside>`;
}

function statusbar(d) {
  const st = !d.managerOn ? '<span class="st"><i></i>Viewing only</span>'
    : d.current ? `<span class="st"><i class="run"></i>${esc(kindLabel(d.current.record.request.kind))} · ${pct(d.current.itemsDone, d.current.itemsTotal)}%</span>`
      : '<span class="st"><i class="ok"></i>Ready</span>';
  return `<footer class="statusbar">${st}${d.queued.length ? `<span>${d.queued.length} waiting</span>` : ''}
    <span class="gap" style="flex:1"></span>
    <span>v${esc(d.version.build)} · ${esc(d.version.commit)}</span>
    ${d.update ? `<a class="upd" href="#">Update to ${esc(d.update.available)}</a>` : ''}</footer>`;
}

export function render(d) {
  return `${rail()}<div class="work">${toolbar(d)}<div class="split-view">${center(d)}${side(d)}</div></div>${statusbar(d)}`;
}
