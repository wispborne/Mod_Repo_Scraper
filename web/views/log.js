// #/log — ModRepo.log viewer with text filter and jump-to-end (4.7).

import { api, el, clear, missingPanel, MissingFile } from '../lib.js';

const state = { q: '', tail: 500 };

export async function render(root) {
  clear(root);
  root.append(el('h1', { text: 'Run Log (ModRepo.log)' }));

  const toolbar = el('div', { class: 'toolbar' });
  const search = el('input', { type: 'search', placeholder: 'Filter lines…', value: state.q });
  let d;
  search.addEventListener('input', () => {
    clearTimeout(d);
    d = setTimeout(() => { state.q = search.value.trim(); load(); }, 250);
  });
  const tail = el('input', { type: 'text', value: String(state.tail), style: 'min-width:80px;', title: 'Show last N lines (0 = all)' });
  tail.addEventListener('change', () => { state.tail = parseInt(tail.value, 10) || 0; load(); });
  const jump = el('button', { class: 'chip', text: 'Jump to end ↓', onclick: () => window.scrollTo(0, document.body.scrollHeight) });
  toolbar.append(search, el('span', { class: 'field-label', text: 'tail' }), tail, jump);
  root.append(toolbar);

  const info = el('p', { class: 'field-value' });
  const box = el('div', { class: 'raw', style: 'max-height:74vh;overflow:auto;' });
  root.append(info, box);

  async function load() {
    clear(box).append(el('div', { class: 'loading', text: 'Loading…' }));
    const data = await api('log', { q: state.q, tail: state.tail });
    clear(box);
    if (data instanceof MissingFile) {
      info.textContent = '';
      box.append(missingPanel(data));
      return;
    }
    info.textContent = `${data.returned} of ${data.total} matching lines shown`;
    for (const line of data.lines) {
      box.append(el('div', { class: 'log-line', text: line }));
    }
    if (!data.lines.length) box.append(el('p', { class: 'loading', text: 'No matching lines.' }));
  }

  load();
}
