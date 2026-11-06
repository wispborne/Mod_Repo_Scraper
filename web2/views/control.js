// The Control page: job buttons in the toolbar, the running (or last) run in
// the centre, and Needs attention, Queue and Recent runs at the side.

import { el, clear, api } from '../lib.js';
import { icon } from '../icons.js';
import { subscribe } from '../status.js';
import { oldViewerAddress } from '../routes.js';
import { pageLayout, sidePanel } from '../frame.js';
import {
  SCOPES, BOARDS, SOURCES, defaultFetchOptions, fetchHasWork, fetchRequest, llmRequest,
  rebuildRequest, publishRequest, scanImagesRequest, matchNamesRequest, describeJob,
} from '../jobs.js';
import { confirmAndStart } from '../actions.js';
import { runPanel, runRow } from '../run_panel.js';

// Job options last for the current visit.
const fetchOptions = defaultFetchOptions();
let llmAll = false;

export function render({ content, toolbar, onLeave }) {
  const main = el('div', { class: 'run-panel' });
  const attention = el('div');
  const queuePanel = el('div');
  const runsBody = el('div', { class: 'rows' }, [el('p', { class: 'empty', text: 'Loading…' })]);
  const runsPanel = sidePanel({
    name: 'Recent runs',
    body: el('div', {}, [
      runsBody,
      el('p', { class: 'side-more' }, [el('a', { href: '#/runs', text: 'View all runs' })]),
    ]),
  });
  content.append(pageLayout(main, [attention, queuePanel, runsPanel]));

  const run = runPanel(main);
  let lastOn = null;
  let lastQueueKey = null;
  let lastCurrent;
  let finishedRuns = [];
  let closeMenus = () => {};

  const loadRuns = async () => {
    try {
      const page = await api('manager/runs', { pageSize: 12 });
      const runs = (page && page.items) || [];
      finishedRuns = runs.filter((r) => r.state !== 'running' && r.state !== 'queued');
      clear(runsBody).append(...(runs.length
        ? runs.map(runRow)
        : [el('p', { class: 'empty', text: 'No runs yet.' })]));
    } catch (err) {
      finishedRuns = [];
      clear(runsBody).append(el('p', { class: 'empty', text: err.message }));
    }
  };

  onLeave(() => closeMenus());
  onLeave(subscribe(async (s) => {
    if (s.on !== lastOn) {
      lastOn = s.on;
      toolbar.actions.replaceChildren();
      closeMenus();
      closeMenus = s.on ? drawJobButtons(toolbar.actions) : () => {};
    }
    if (!s.on) run.off(s);

    const current = s.on && s.current ? s.current : null;
    const currentId = current ? current.record.id : null;
    if (currentId !== lastCurrent) {
      lastCurrent = currentId;
      await loadRuns();
      loadAttention(attention, finishedRuns[0] || null);
    }
    if (s.on) {
      if (current) run.show(current.record, current);
      else run.show(finishedRuns[0] || null, null);
    }

    const queued = s.on ? s.queued || [] : [];
    const key = queued.map((r) => r.id).join(',') + (s.on ? '' : ':off');
    if (key === lastQueueKey) return;
    lastQueueKey = key;
    const queueBody = el('div', { class: 'rows' }, queued.length
      ? queued.map(runRow)
      : [el('p', { class: 'empty', text: s.on ? 'Queue is empty.' : 'Jobs are off.' })]);
    queuePanel.replaceChildren(sidePanel({ name: 'Queue', count: queued.length, body: queueBody }));
  }));
}

// --- Toolbar job buttons ---

/// Draws the job buttons. Returns a function that closes any open menu and
/// stops listening.
function drawJobButtons(node) {
  const menus = [];
  const closeAll = (except) => {
    for (const m of menus) if (m !== except) m.close();
  };
  const onOutside = (e) => {
    if (!menus.some((m) => m.root.contains(e.target))) closeAll();
  };
  const onKey = (e) => {
    if (e.key === 'Escape') closeAll();
  };
  document.addEventListener('mousedown', onOutside);
  document.addEventListener('keydown', onKey);

  const fetchMain = el('button', {
    type: 'button',
    class: 'button primary split-main',
    onclick: () => confirmAndStart(fetchRequest(fetchOptions)),
  }, [icon('download', 14), 'Fetch and update']);
  const updateFetch = () => {
    const ok = fetchHasWork(fetchOptions);
    fetchMain.disabled = !ok;
    fetchMain.title = ok ? describeJob(fetchRequest(fetchOptions))
      : 'Select at least one board or source. To use saved data, choose Rebuild from saved.';
  };
  const fetchMenu = menuButton({
    label: 'Fetch and update options',
    main: fetchMain,
    primary: true,
    body: () => fetchOptionsPanel(updateFetch),
    onOpen: (m) => closeAll(m),
  });
  updateFetch();

  const llmMain = el('button', {
    type: 'button',
    class: 'button split-main',
    onclick: () => confirmAndStart(llmRequest(llmAll)),
  });
  const updateLlm = () => {
    llmMain.replaceChildren(icon('sparkles', 14), 'Run LLM', el('span', {
      class: llmAll ? 'choice warn-text' : 'choice',
      text: llmAll ? '· All' : '· Only changed',
    }));
    llmMain.title = describeJob(llmRequest(llmAll));
  };
  updateLlm();
  const llmMenu = menuButton({
    label: 'Run LLM options',
    main: llmMain,
    body: () => llmOptionsPanel(updateLlm),
    onOpen: (m) => closeAll(m),
  });

  const rebuild = el('button', {
    type: 'button',
    class: 'button',
    title: describeJob(rebuildRequest()),
    onclick: () => confirmAndStart(rebuildRequest()),
  }, [icon('refresh', 14), 'Rebuild from saved']);
  const publish = el('button', {
    type: 'button',
    class: 'button',
    title: describeJob(publishRequest()),
    onclick: () => confirmAndStart(publishRequest()),
  }, [icon('upload', 14), 'Publish']);

  const more = menuButton({
    label: 'More jobs',
    text: 'More',
    quiet: true,
    body: (close) => el('div', { class: 'menu-list', role: 'menu' }, [
      menuItem('Scan images', describeJob(scanImagesRequest()), () => { close(); confirmAndStart(scanImagesRequest()); }),
      menuItem('Match dependency names', describeJob(matchNamesRequest()), () => { close(); confirmAndStart(matchNamesRequest()); }),
    ]),
    onOpen: (m) => closeAll(m),
  });

  menus.push(fetchMenu, llmMenu, more);
  node.append(fetchMenu.root, llmMenu.root, rebuild, publish, more.root);

  return () => {
    closeAll();
    document.removeEventListener('mousedown', onOutside);
    document.removeEventListener('keydown', onKey);
  };
}

/// A button with a drop-down. With `main`, it is a split button: `main` does
/// the job and the arrow opens the menu. Without it, the whole button opens
/// the menu.
function menuButton({ label, main = null, text = null, primary = false, quiet = false, body, onOpen }) {
  const root = el('div', { class: 'menu-host' });
  const classes = ['button', main ? 'split-arrow' : '', primary ? 'primary' : '', quiet ? 'quiet' : '']
    .filter(Boolean).join(' ');
  const toggle = el('button', {
    type: 'button',
    class: classes,
    'aria-haspopup': 'true',
    'aria-expanded': 'false',
    'aria-label': label,
    title: label,
  }, [text ? el('span', { text }) : null, icon('chevron-down', 14)]);
  const panel = el('div', { class: 'menu', hidden: true });

  const menu = {
    root,
    close() {
      panel.hidden = true;
      toggle.setAttribute('aria-expanded', 'false');
    },
    open() {
      onOpen(menu);
      panel.replaceChildren(body(() => menu.close()));
      panel.hidden = false;
      toggle.setAttribute('aria-expanded', 'true');
      const first = panel.querySelector('input, select, button');
      if (first) first.focus();
    },
  };
  toggle.addEventListener('click', () => (panel.hidden ? menu.open() : menu.close()));
  if (main) root.append(el('div', { class: 'split' }, [main, toggle]));
  else root.append(toggle);
  root.append(panel);
  return menu;
}

function menuItem(text, hint, onclick) {
  return el('button', { type: 'button', class: 'menu-item', role: 'menuitem', onclick }, [
    el('span', { class: 'menu-item-name', text }),
    el('span', { class: 'menu-hint', text: hint }),
  ]);
}

function check(label, checked, onchange) {
  const box = el('input', { type: 'checkbox' });
  box.checked = checked;
  box.addEventListener('change', () => onchange(box.checked));
  return el('label', { class: 'check' }, [box, label]);
}

function toggleIn(list, value, on) {
  const i = list.indexOf(value);
  if (on && i < 0) list.push(value);
  if (!on && i >= 0) list.splice(i, 1);
}

function fetchOptionsPanel(changed) {
  const scope = el('select', { class: 'select' });
  for (const [value, label] of SCOPES) {
    const option = el('option', { value, text: label });
    if (value === fetchOptions.scope) option.selected = true;
    scope.append(option);
  }
  const note = el('p', {
    class: 'menu-note warn-text',
    text: 'Select at least one board or source. To use saved data, choose Rebuild from saved.',
  });
  const update = () => {
    scope.disabled = fetchOptions.boards.length === 0;
    note.hidden = fetchHasWork(fetchOptions);
    changed();
  };
  scope.addEventListener('change', () => { fetchOptions.scope = scope.value; update(); });

  const panel = el('div', { class: 'menu-form' }, [
    el('label', { class: 'field' }, [el('span', { class: 'field-label', text: 'Forum scope' }), scope]),
    el('div', { class: 'field' }, [
      el('span', { class: 'field-label', text: 'Boards' }),
      ...BOARDS.map(([value, label]) => check(label, fetchOptions.boards.includes(value), (on) => {
        toggleIn(fetchOptions.boards, value, on);
        update();
      })),
    ]),
    el('div', { class: 'field' }, [
      el('span', { class: 'field-label', text: 'Also fetch' }),
      ...SOURCES.map(([value, label]) => check(label, fetchOptions.sources.includes(value), (on) => {
        toggleIn(fetchOptions.sources, value, on);
        update();
      })),
    ]),
    el('div', { class: 'field' }, [
      el('span', { class: 'field-label', text: 'LLM' }),
      check('Extract mod details from new and changed posts', fetchOptions.runLlm, (on) => {
        fetchOptions.runLlm = on;
        update();
      }),
    ]),
    note,
  ]);
  update();
  return panel;
}

function llmOptionsPanel(changed) {
  const choice = (value, label, hint) => {
    const radio = el('input', { type: 'radio', name: 'llm-scope' });
    radio.checked = llmAll === value;
    radio.addEventListener('change', () => {
      if (radio.checked) llmAll = value;
      changed();
    });
    return el('label', { class: 'radio' }, [radio, el('span', { class: 'radio-text' }, [
      el('span', { text: label }),
      el('span', { class: 'menu-hint', text: hint }),
    ])]);
  };
  return el('div', { class: 'menu-form' }, [
    choice(false, 'Only changed', 'Posts with no answer, or whose post or prompt changed.'),
    choice(true, 'All', 'Every post again, oldest answer first. The per-run call limit still applies.'),
  ]);
}

// --- Side panels ---


/// The Needs attention items, in order. `where` is the old viewer page that
/// fixes each one, until the new page is built.
const ATTENTION = [
  { key: 'unmatchedDependencyNames', label: 'Dependency names not matched', where: 'dependency-names' },
  { key: 'authorPairsToDecide', label: 'Author pairs to decide', where: 'author-aliases' },
  { key: 'takedownsExcludedNothing', label: 'Takedowns that excluded nothing', where: 'takedowns', warn: true },
  { key: 'takedownsReturned', label: 'Taken-down mods back under a new id', where: 'takedowns', warn: true },
  { key: 'postsWithoutLlmAnswer', label: 'Posts with no LLM answer', where: 'topics?filters=noLlmExtraction' },
  {
    key: 'modsWithoutDownload',
    label: 'Mods with no download',
    where: 'topics?filters=noDownload',
    hint: 'The old viewer has no list of these mods. This opens its topics with no download found.',
  },
];

async function loadAttention(node, lastRun) {
  let counts = {};
  try {
    counts = (await api('attention')) || {};
  } catch {
    counts = {};
  }
  const items = [];
  const errors = lastRun && lastRun.counters && lastRun.counters.errors;
  if (errors) {
    items.push({
      label: 'Errors in the last run',
      count: errors,
      bad: true,
      href: oldViewerAddress(location.pathname, `runs/${encodeURIComponent(lastRun.id)}`),
    });
  }
  for (const a of ATTENTION) {
    const n = counts[a.key];
    if (typeof n === 'number' && n > 0) {
      items.push({ label: a.label, count: n, warn: a.warn, hint: a.hint, href: oldViewerAddress(location.pathname, a.where) });
    }
  }
  if (!items.length) {
    node.replaceChildren();
    return;
  }
  node.replaceChildren(sidePanel({
    name: 'Needs attention',
    count: items.length,
    body: el('div', { class: 'rows' }, items.map((item) => el('a', {
      class: ['row', 'attention', item.bad ? 'bad' : '', item.warn ? 'warn' : ''].filter(Boolean).join(' '),
      href: item.href,
      title: item.hint || null,
    }, [
      el('span', { class: 'attention-count', text: String(item.count) }),
      el('span', { class: 'row-main', text: item.label }),
      icon('chevron-right', 14),
    ]))),
  }));
}
