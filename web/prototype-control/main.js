// PROTOTYPE — throwaway. Switches between the Control page variants.
import { loadData, kindLabel, pct } from './data.js';
import * as A from './variant-a.js';
import * as B from './variant-b.js';
import * as C from './variant-c.js';
import * as D from './variant-d.js';

const VARIANTS = { A, B, C, D };
const KEYS = Object.keys(VARIANTS);
const STATES = [['running', 'Running'], ['idle', 'Idle'], ['off', 'Manager off']];

function params() {
  const q = new URLSearchParams(location.search);
  const v = KEYS.includes(q.get('variant')) ? q.get('variant') : 'D';
  const s = STATES.some(([k]) => k === q.get('state')) ? q.get('state') : 'running';
  return { v, s };
}

function setParams(next) {
  const q = new URLSearchParams(location.search);
  for (const [k, val] of Object.entries(next)) q.set(k, val);
  history.replaceState(null, '', `${location.pathname}?${q}`);
  draw();
}

let styleEl;

async function draw() {
  const { v, s } = params();
  const variant = VARIANTS[v];
  const data = await loadData(s);

  if (!styleEl) { styleEl = document.createElement('style'); document.head.append(styleEl); }
  styleEl.textContent = variant.css;
  const root = document.getElementById('root');
  root.className = `variant-${v}`;
  root.innerHTML = variant.render(data);

  // The tab title says what is happening, as the requirements ask.
  if (data.current) {
    const c = data.current;
    document.title = `▶ ${kindLabel(c.record.request.kind)} ${pct(c.itemsDone, c.itemsTotal)}% · Viewer`;
  } else if (data.lastRun) {
    document.title = `${data.lastRun.state === 'failed' ? '✗ Failed' : '✓ Done'} · Viewer`;
  } else {
    document.title = 'Viewer';
  }

  const bar = document.getElementById('proto-bar');
  bar.innerHTML = '';
  const btn = (text, on, fn, cls = '') => {
    const b = document.createElement('button');
    b.textContent = text; b.className = `${cls} ${on ? 'on' : ''}`; b.onclick = fn;
    bar.append(b);
  };
  const i = KEYS.indexOf(v);
  btn('←', false, () => setParams({ variant: KEYS[(i + KEYS.length - 1) % KEYS.length] }));
  const label = document.createElement('span');
  label.className = 'label';
  label.textContent = `${v} — ${variant.name}`;
  bar.append(label);
  btn('→', false, () => setParams({ variant: KEYS[(i + 1) % KEYS.length] }));
  const sep = document.createElement('span'); sep.className = 'sep'; bar.append(sep);
  for (const [k, text] of STATES) btn(text, k === s, () => setParams({ state: k }));
}

document.addEventListener('keydown', (e) => {
  const t = e.target;
  if (t.closest?.('input, textarea, [contenteditable]')) return;
  const { v } = params();
  const i = KEYS.indexOf(v);
  if (e.key === 'ArrowLeft') setParams({ variant: KEYS[(i + KEYS.length - 1) % KEYS.length] });
  if (e.key === 'ArrowRight') setParams({ variant: KEYS[(i + 1) % KEYS.length] });
});

// Folds and "Options" toggles inside the variants.
document.addEventListener('click', (e) => {
  const t = e.target.closest('[data-toggle]');
  if (!t) return;
  const target = document.getElementById(t.dataset.toggle);
  if (target) target.hidden = !target.hidden;
  t.setAttribute('aria-expanded', String(!target?.hidden));
});

draw();
