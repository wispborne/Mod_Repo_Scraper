// Catalog explorer: why each group of posts became one mod, for one saved
// merge. A port of the old viewer's Merge view (web/views/merge.js).
//   #/explorer                 the groups, searchable
//   #/explorer/groups/<id>     one group: members, why they joined, the merge
//                              steps, and before and after field by field
//   #/explorer/removals        what was removed, by kind
// The address stores the picked merge as `run`; none means the newest.

import { el, api, pager, pageSizePreference, breadcrumbs, rawJson } from '../lib.js';
import { pageLayout, sidePanel } from '../frame.js';
import { hashQuery, buildHash, kindLabel } from '../routes.js';
import { badge, section, emptyLine, fieldList } from '../post_parts.js';
import { modHref, postHref, postKindWords, foundByWords } from '../mod_words.js';
import { expandAllButton, cellText } from '../diff_parts.js';

const PAGE_ID = 'explorer';

/// The removal lists, in the old viewer's words.
const REMOVALS = [
  ['preDedup', 'Pre-dedup removals', 'preDedupCount'],
  ['sameSource', 'Same-source dedup', 'sameSourceDedupCount'],
  ['validation', 'Validation removals', 'validationRemovalCount'],
];
const REMOVAL_KINDS = new Set(REMOVALS.map(([kind]) => kind));

export function render(ctx) {
  const query = hashQuery(location.hash);
  const run = query.get('run') || '';
  const [section0, id] = ctx.parts;
  if (section0 === 'groups' && id != null) return groupPage(ctx, run, id);
  if (section0 === 'removals') return removalsPage(ctx, run, query);
  if (section0 && section0 !== 'groups') {
    ctx.content.append(pageLayout(el('p', { class: 'error-text', text: `There is no page at #/explorer/${ctx.parts.join('/')}.` })));
    return undefined;
  }
  return groupsPage(ctx, run, query);
}

// --- Shared pieces ---

/// "5 Nov 2026, 20:35 · Rebuild from saved · 1302 mods". Run ids end in the
/// job's kind.
function runLabel(run) {
  const at = run.savedAt ? new Date(run.savedAt) : null;
  const when = at && !Number.isNaN(at.getTime()) ? at.toLocaleString() : run.id;
  const kind = String(run.id || '').split('-').slice(1).join('-');
  const parts = [when];
  if (kind) parts.push(kindLabel(kind));
  if (run.finalCount != null) parts.push(`${run.finalCount} mods`);
  return parts.join(' · ');
}

/// The "Showing" choice of saved merge. Changing it keeps the page and moves
/// the address to the new merge. Draws nothing when no merge is saved, since
/// the latest merge-debug.json is then all there is.
function mergePicker(slot, run, pageParts, params) {
  api('merge/runs').then((data) => {
    const runs = (data && data.items) || [];
    if (!runs.length || !slot.isConnected) return;
    const select = el('select', { class: 'select', 'aria-label': 'Merge to show' });
    select.append(el('option', { value: '', text: `Newest merge (${runLabel(runs[0])})` }));
    for (const r of runs) select.append(el('option', { value: r.id, text: runLabel(r) }));
    select.value = runs.some((r) => r.id === run) ? run : '';
    select.addEventListener('change', () => {
      location.hash = buildHash(pageParts, { ...params, run: select.value, page: null });
    });
    slot.replaceChildren(el('label', { class: 'ex-picker' }, [
      el('span', { class: 'field-label', text: 'Showing' }),
      select,
      el('span', { class: 'dim', text: `${runs.length} merge${runs.length === 1 ? '' : 's'} saved` }),
    ]));
  }).catch(() => {});
}

/// The server's "file is missing" answer, in the old viewer's words.
function missingNote(data) {
  return el('div', { class: 'ex-message' }, [
    el('p', { text: `${data.file} is unavailable` }),
    el('p', { class: 'dim', text: data.hint || 'Run the scraper to produce it.' }),
  ]);
}

/// Groups, then one tab per removal list, with counts once the summary arrives.
function sectionTabs(active, run) {
  const tabs = el('div', { class: 'tabs ex-tabs', role: 'group', 'aria-label': 'What to show' });
  const tab = (label, hash, on, countKey) => el('a', {
    class: `tab${on ? ' on' : ''}`,
    href: hash,
    'aria-current': on ? 'page' : null,
    'data-count': countKey,
  }, [label, el('span', { class: 'ex-tab-count' })]);
  tabs.append(tab('Groups', buildHash([PAGE_ID], { run }), active === 'groups', 'multiMemberGroupCount'));
  for (const [kind, label, countKey] of REMOVALS) {
    tabs.append(tab(label, buildHash([PAGE_ID, 'removals'], { run, kind: kind === 'preDedup' ? null : kind }), active === kind, countKey));
  }
  return tabs;
}

/// The merge's numbers and phase timings, as a side panel. Also fills the
/// tabs' counts.
function summaryPanel(slot, run, tabs) {
  api('merge/summary', { run }).then((data) => {
    if (!slot.isConnected || !data || data.missing) return;
    for (const node of tabs.querySelectorAll('[data-count]')) {
      const n = data[node.dataset.count];
      if (n != null) node.querySelector('.ex-tab-count').textContent = ` ${n}`;
    }
    const counts = [
      ['Input mods', data.inputCount, ''],
      ['Pre-dedup removals', data.preDedupCount, data.preDedupCount ? 'warn-text' : ''],
      ['After pre-dedup', data.afterPreDedupCount, ''],
      ['Groups', data.groupCount, ''],
      ['Groups with multiple entries', data.multiMemberGroupCount, ''],
      ['Groups with one entry', data.singletonGroupCount, ''],
      ['Same-source dedup', data.sameSourceDedupCount, data.sameSourceDedupCount ? 'warn-text' : ''],
      ['Validation removals', data.validationRemovalCount, data.validationRemovalCount ? 'failed-text' : ''],
      ['Final output', data.finalOutputCount, ''],
    ];
    const list = el('dl', { class: 'ex-counts' });
    for (const [label, value, cls] of counts) {
      list.append(el('dt', { text: label }), el('dd', { class: `num mono ${cls}`, text: value == null ? '—' : String(value) }));
    }
    const body = [list];
    const timings = data.timings || [];
    if (timings.length) {
      const max = Math.max(1, ...timings.map((t) => t.durationMs || 0));
      body.push(el('h3', { class: 'ex-side-head', text: 'Phase timings' }));
      body.push(el('div', { class: 'ex-timings' }, timings.map((t) => {
        const pct = Math.max(1, Math.min(100, ((t.durationMs || 0) / max) * 100));
        return el('div', { class: 'ex-timing' }, [
          el('span', { text: t.phaseName || '?' }),
          el('span', { class: 'mono dim', text: `${t.durationMs || 0}ms` }),
          el('span', { class: 'ex-timing-bar' }, el('span', { style: `width:${pct.toFixed(1)}%` })),
        ]);
      })));
    }
    slot.replaceChildren(sidePanel({ name: 'This merge', body: el('div', { class: 'ex-side' }, body) }));
  }).catch(() => {});
}

function authorsOf(mod) {
  return ((mod && mod.authorsList) || []).join(', ');
}

/// "by a, b · [Discord] · v0.98a", the old viewer's line for one entry.
function modLine(mod) {
  if (!mod) return '?';
  return `${mod.name || '(empty)'} by ${authorsOf(mod)} [${(mod.sources || []).join(', ')}] v${mod.gameVersionReq || '?'}`;
}

/// Writes the list's state into the address, only while the reader is still
/// on this page.
function saveAddress(pageParts, params) {
  const here = buildHash(pageParts, {});
  const now = location.hash.split('?')[0];
  if (now !== here) return;
  history.replaceState(null, '', buildHash(pageParts, params));
}

// --- The groups ---

function groupsPage({ content, toolbar, onLeave }, run, query) {
  const view = {
    q: query.get('q') || '',
    // Groups with one entry are hidden unless asked for, as in the old viewer.
    multiOnly: query.get('all') !== '1',
    page: Math.max(0, (parseInt(query.get('page'), 10) || 1) - 1),
    pageSize: pageSizePreference(),
  };

  const pickerSlot = el('div', { class: 'ex-picker-row' });
  const tabs = sectionTabs('groups', run);
  const search = el('input', {
    type: 'search',
    class: 'input pl-search',
    placeholder: 'Search member name or author…',
    'aria-label': 'Search groups',
    autocomplete: 'off',
    spellcheck: 'false',
    value: view.q,
  });
  const multi = el('button', { type: 'button', class: 'pl-filter' }, ['Groups with multiple entries']);
  const countLine = el('p', { class: 'ml-count', 'aria-live': 'polite' });
  const listSlot = el('div', {}, [el('p', { class: 'empty pl-message', text: 'Loading…' })]);
  const sideSlot = el('div');
  const main = el('div', { class: 'list-page ex-page' }, [
    pickerSlot,
    tabs,
    el('div', { class: 'pl-toolbar ex-toolbar' }, [search, multi, countLine]),
    listSlot,
  ]);
  content.append(pageLayout(main, [sideSlot]));
  mergePicker(pickerSlot, run, [PAGE_ID], { q: view.q, all: view.multiOnly ? null : '1' });
  summaryPanel(sideSlot, run, tabs);

  const foldAll = expandAllButton(listSlot, 'details.ex-group');
  toolbar.actions.replaceChildren(foldAll);

  const drawMulti = () => {
    multi.classList.toggle('on', view.multiOnly);
    multi.setAttribute('aria-pressed', String(view.multiOnly));
  };
  multi.addEventListener('click', () => {
    view.multiOnly = !view.multiOnly;
    view.page = 0;
    load();
  });

  let debounce;
  search.addEventListener('input', () => {
    clearTimeout(debounce);
    debounce = setTimeout(() => {
      view.q = search.value.trim();
      view.page = 0;
      load();
    }, 250);
  });
  onLeave(() => clearTimeout(debounce));

  let ticket = 0;
  const load = async () => {
    const mine = ++ticket;
    drawMulti();
    saveAddress([PAGE_ID], {
      run,
      q: view.q,
      all: view.multiOnly ? null : '1',
      page: view.page > 0 ? view.page + 1 : null,
    });
    let data;
    try {
      data = await api('merge/groups', {
        run, q: view.q, multiOnly: view.multiOnly, page: view.page, pageSize: view.pageSize,
      });
    } catch (err) {
      if (mine !== ticket) return;
      countLine.textContent = '';
      listSlot.replaceChildren(el('p', { class: 'error-text pl-message', text: err.message }));
      foldAll.refresh();
      return;
    }
    if (mine !== ticket) return;
    if (data.missing) {
      countLine.textContent = '';
      listSlot.replaceChildren(missingNote(data));
      foldAll.refresh();
      return;
    }
    const items = data.items || [];
    countLine.textContent = data.total === 1 ? '1 group' : `${data.total} groups`;
    listSlot.replaceChildren(
      items.length
        ? el('div', { class: 'ex-groups' }, items.map((g) => groupFold(g, run)))
        : el('p', { class: 'empty pl-message', text: 'No groups match.' }),
      pager(data.page, data.pageSize, data.total, (p) => {
        view.page = p;
        load();
        tabs.scrollIntoView({ block: 'nearest' });
      }, (size) => {
        view.pageSize = size;
        view.page = 0;
        load();
      }),
    );
    foldAll.refresh();
  };
  load();
}

/// One group as a fold: its first member's name, then its members and the
/// reasons they matched.
function groupFold(g, run) {
  const members = g.members || [];
  const primary = (members[0] && members[0].name) || '(empty)';
  const href = buildHash([PAGE_ID, 'groups', String(g.groupIndex)], { run });
  const matches = g.matchEntries || [];
  return el('details', { class: 'ex-group' }, [
    el('summary', {}, [
      el('a', { class: 'mono', href, text: `Group #${g.groupIndex}` }),
      el('span', { class: 'ex-group-name', text: primary }),
      badge(`${g.memberCount} members`),
    ]),
    el('div', { class: 'ex-group-body' }, [
      el('ul', { class: 'ex-members' }, members.map((m) => el('li', { text: modLine(m) }))),
      matches.length ? el('h4', { class: 'pp-subhead', text: 'Match reasons' }) : null,
      matches.length ? el('ul', { class: 'ex-reasons' }, matches.map((mm) => el('li', {}, matchReason(mm)))) : null,
    ]),
  ]);
}

/// Why two entries matched: the reason labels and the scores behind them.
function matchReason(mm) {
  const reasons = mm.reasons || [];
  const parts = [
    el('strong', { text: (mm.outerMod && mm.outerMod.name) || '?' }),
    ' ↔ ',
    el('strong', { text: (mm.innerMod && mm.innerMod.name) || '?' }),
    ': ',
  ];
  const scores = (...pairs) => {
    const words = pairs.filter(([, v]) => v != null).map(([k, v]) => `${k} ${v}`);
    if (words.length) parts.push(el('span', { class: 'dim', text: ` ${words.join(' ')} ` }));
  };
  if (reasons.includes('sameId')) {
    parts.push(badge('Same permanent id', 'strong'));
    parts.push(el('span', { class: 'dim', text: ' their posts already shared an id, so this join was made first ' }));
  }
  if (reasons.includes('nameAndAuthor')) {
    parts.push(badge('Name+Author', 'strong'));
    scores(['name', mm.nameScore], ['author', mm.authorScore]);
  }
  if (reasons.includes('strippedNameAndAuthor')) {
    parts.push(badge('Name+Author (version stripped)', 'strong'));
    if (mm.outerStrippedName != null) {
      parts.push(el('span', { class: 'dim', text: ` "${mm.outerStrippedName}" ↔ "${mm.innerStrippedName}"` }));
    }
    scores(
      ['name', mm.strippedNameScore],
      ['ratio', mm.strippedNameLengthRatio == null ? null : `${(mm.strippedNameLengthRatio * 100).toFixed(0)}%`],
      ['author', mm.authorScore],
    );
  }
  if (reasons.includes('nameAndDownload')) {
    parts.push(badge('Name+Same download', 'strong'));
    scores(['name', mm.nameScore]);
  }
  if (reasons.includes('forumUrl')) {
    parts.push(badge('Forum URL'));
    scores(['topic', mm.matchedForumTopicId]);
  }
  return parts;
}

// --- Removals ---

function removalsPage({ content, onLeave }, run, query) {
  const kind = REMOVAL_KINDS.has(query.get('kind')) ? query.get('kind') : 'preDedup';
  const view = {
    q: query.get('q') || '',
    page: Math.max(0, (parseInt(query.get('page'), 10) || 1) - 1),
    pageSize: pageSizePreference(),
  };
  const kindParam = kind === 'preDedup' ? null : kind;

  const pickerSlot = el('div', { class: 'ex-picker-row' });
  const tabs = sectionTabs(kind, run);
  const search = el('input', {
    type: 'search',
    class: 'input pl-search',
    placeholder: 'Search name or author…',
    'aria-label': 'Search removals',
    autocomplete: 'off',
    spellcheck: 'false',
    value: view.q,
  });
  const countLine = el('p', { class: 'ml-count', 'aria-live': 'polite' });
  const listSlot = el('div', {}, [el('p', { class: 'empty pl-message', text: 'Loading…' })]);
  const sideSlot = el('div');
  content.append(pageLayout(el('div', { class: 'list-page ex-page' }, [
    pickerSlot,
    tabs,
    el('div', { class: 'pl-toolbar ex-toolbar' }, [search, countLine]),
    listSlot,
  ]), [sideSlot]));
  mergePicker(pickerSlot, run, [PAGE_ID, 'removals'], { kind: kindParam, q: view.q });
  summaryPanel(sideSlot, run, tabs);

  let debounce;
  search.addEventListener('input', () => {
    clearTimeout(debounce);
    debounce = setTimeout(() => {
      view.q = search.value.trim();
      view.page = 0;
      load();
    }, 250);
  });
  onLeave(() => clearTimeout(debounce));

  let ticket = 0;
  const load = async () => {
    const mine = ++ticket;
    saveAddress([PAGE_ID, 'removals'], {
      run,
      kind: kindParam,
      q: view.q,
      page: view.page > 0 ? view.page + 1 : null,
    });
    let data;
    try {
      data = await api('merge/removals', { run, kind, q: view.q, page: view.page, pageSize: view.pageSize });
    } catch (err) {
      if (mine !== ticket) return;
      countLine.textContent = '';
      listSlot.replaceChildren(el('p', { class: 'error-text pl-message', text: err.message }));
      return;
    }
    if (mine !== ticket) return;
    if (data.missing) {
      countLine.textContent = '';
      listSlot.replaceChildren(missingNote(data));
      return;
    }
    const items = data.items || [];
    countLine.textContent = data.total === 1 ? '1 entry' : `${data.total} entries`;
    listSlot.replaceChildren(
      items.length ? removalsTable(kind, items) : el('p', { class: 'empty pl-message', text: 'No entries.' }),
      pager(data.page, data.pageSize, data.total, (p) => {
        view.page = p;
        load();
        tabs.scrollIntoView({ block: 'nearest' });
      }, (size) => {
        view.pageSize = size;
        view.page = 0;
        load();
      }),
    );
  };
  load();
}

function removalsTable(kind, items) {
  const name = (mod) => (mod && mod.name) || '(empty)';
  let headings;
  let rows;
  if (kind === 'validation') {
    headings = ['Mod', 'Authors', 'Reason'];
    rows = items.map((e) => el('tr', {}, [
      el('td', { text: name(e.mod) }),
      el('td', { text: authorsOf(e.mod) }),
      el('td', {}, [badge(e.reason || '', 'bad')]),
    ]));
  } else {
    headings = ['Kept', 'Discarded', 'Detail'];
    rows = items.map((e) => {
      const detail = kind === 'sameSource'
        ? `${e.source || ''} · v${e.keptGameVersion || '?'} vs v${e.discardedGameVersion || '?'}`
        : `${e.reason || ''} · richness ${e.keptRichness ?? '?'} vs ${e.discardedRichness ?? '?'}`;
      return el('tr', {}, [
        el('td', { title: modLine(e.kept), text: name(e.kept) }),
        el('td', { title: modLine(e.discarded), text: name(e.discarded) }),
        el('td', {}, [
          el('span', { class: 'dim', text: detail }),
          e.wasSafetyBlocked ? badge('Safety blocked', 'warn') : null,
        ]),
      ]);
    });
  }
  return el('div', { class: 'table-wrap' }, [
    el('table', { class: 'table ex-table ex-removals' }, [
      el('thead', {}, el('tr', {}, headings.map((h) => el('th', { text: h })))),
      el('tbody', {}, rows),
    ]),
  ]);
}

// --- One group ---

const PRIORITY_REASONS = {
  indexSource: 'Mod index source',
  higherGameVersion: 'Higher game version',
  fallback: 'Fallback',
};

async function groupPage({ content }, run, id) {
  const listHref = buildHash([PAGE_ID], { run });
  const crumbs = el('div');
  const drawCrumbs = (label) => crumbs.replaceChildren(breadcrumbs([
    { label: 'Catalog explorer', href: listHref },
    { label },
  ]));
  drawCrumbs(`Group #${id}`);
  const main = el('div', { class: 'pp-page' }, [crumbs, emptyLine('Loading…')]);
  const sideSlot = el('div');
  content.append(pageLayout(main, [sideSlot]));
  const gone = () => !main.isConnected;

  const fields = api(`merge/groups/${encodeURIComponent(id)}/fields`, { run }).catch((err) => ({ error: err.message }));
  let data;
  try {
    data = await api(`merge/groups/${encodeURIComponent(id)}`, { run });
  } catch (err) {
    if (gone()) return;
    main.replaceChildren(crumbs, el('p', { class: 'error-text', text: err.message }));
    return;
  }
  if (gone()) return;
  if (data.missing) {
    main.replaceChildren(crumbs, missingNote(data));
    return;
  }
  if (data.error) {
    main.replaceChildren(crumbs, el('p', { class: 'error-text', text: data.error }));
    return;
  }

  const group = data.group || {};
  const decision = data.decision;
  const members = group.members || [];
  const memberPosts = group.memberSourcePosts || [];
  const merged = (decision && decision.finalResult) || members[0] || {};
  drawCrumbs(`Group #${group.groupIndex} · ${merged.name || '(empty)'}`);

  const modLine0 = el('p', { class: 'pp-outcome' });
  const head = el('header', { class: 'pp-head' }, [
    el('h2', { class: 'pp-title', text: merged.name || '(empty)' }),
    el('div', { class: 'pp-meta' }, [
      el('span', { class: 'chip id', text: `Group #${group.groupIndex}` }),
      el('span', { class: 'chip' }, [el('b', { text: String(members.length) }), members.length === 1 ? ' entry' : ' entries']),
    ]),
    modLine0,
  ]);

  const memberSection = section('Members', members.length, members.map((m, i) => memberCard(m, memberPosts[i])));
  const matches = group.matchEntries || [];
  const matchSection = section('Match reasons', matches.length || null, matches.length
    ? [el('ul', { class: 'ex-reasons' }, matches.map((mm) => el('li', {}, matchReason(mm))))]
    : [emptyLine(members.length > 1 ? 'No match reasons recorded.' : 'Nothing to match: this group has one entry.')]);
  const steps = (decision && decision.steps) || [];
  const stepSection = section('Merge decisions', steps.length || null, steps.length
    ? [stepsTable(steps)]
    : [emptyLine('No merge steps recorded.')]);
  const fieldsSlot = el('div', {}, [section('Before and after', null, [emptyLine('Loading…')])]);

  main.replaceChildren(
    crumbs,
    head,
    el('div', { class: 'pp-sections' }, [memberSection, matchSection, stepSection, fieldsSlot]),
    el('div', { class: 'raw-slot' }, [rawJson(data, 'Raw group data (JSON)')]),
  );

  sideSlot.replaceChildren(sidePanel({
    name: 'Merged result',
    body: el('div', { class: 'pp-side-body' }, [fieldList([
      ['Name', merged.name],
      ['Authors', authorsOf(merged)],
      ['Sources', (merged.sources || []).join(', ')],
      ['Game version', merged.gameVersionReq],
      ['Mod version', merged.modVersion],
      ['Categories', (merged.categories || []).join(', ')],
    ])]),
  }));

  fields.then((answer) => {
    if (gone()) return;
    fieldsSlot.replaceChildren(fieldsSection(answer));
  });
  modsOfPosts(memberPosts).then((mods) => {
    if (gone() || !mods.length) return;
    modLine0.replaceChildren(...modLinks(mods));
  });
}

/// One member: its line, then each source post it came from, linked to that
/// post's page where it has one.
function memberCard(m, posts) {
  const card = el('article', { class: 'ex-member' }, [
    el('strong', { class: 'ex-member-name', text: m.name || '(empty)' }),
    el('div', { class: 'dim', text: `by ${authorsOf(m)} · [${(m.sources || []).join(', ')}] · v${m.gameVersionReq || '?'}` }),
  ]);
  const links = [];
  for (const post of posts || []) {
    if (!post || !post.id) continue;
    const href = postHref(post);
    const where = `${postKindWords(post.kind)} ${post.id}`;
    const label = post.llmModName ? `${where} · "${post.llmModName}"` : where;
    links.push(el('li', {}, [
      href ? el('a', { href, text: label }) : el('span', { text: label }),
      post.foundBy ? el('span', { class: 'dim', text: ` · ${foundByWords(post.foundBy)}` }) : null,
    ]));
  }
  // Merges saved before listings existed name no posts.
  if (links.length) card.append(el('ul', { class: 'ex-posts' }, links));
  return card;
}

/// Each merge step: which rule decided it, which side won, and the result.
function stepsTable(steps) {
  const rows = steps.map((step, i) => {
    const rightWins = !!step.doesRightHavePriority;
    const side = (mod, wins) => el('td', { class: wins ? 'ex-wins' : '' }, [
      modLine(mod),
      wins ? el('span', { class: 'ex-wins-mark', text: ' priority' }) : null,
    ]);
    return el('tr', {}, [
      el('td', { class: 'num mono', text: String(i + 1) }),
      el('td', {}, [badge(PRIORITY_REASONS[step.reason] || step.reason || '?', 'strong')]),
      side(step.left, !rightWins),
      side(step.right, rightWins),
      el('td', { text: (step.result && step.result.name) || '?' }),
    ]);
  });
  return el('div', { class: 'table-wrap' }, [
    el('table', { class: 'table ex-table' }, [
      el('thead', {}, el('tr', {}, ['Step', 'Rule', 'Left', 'Right', 'Result'].map((h) => el('th', { text: h })))),
      el('tbody', {}, rows),
    ]),
  ]);
}

// --- Before and after ---

function memberHeading(member) {
  const sources = (member.sources || []).join(', ') || '?';
  return `${member.name || '(no name)'} [${sources}]`;
}

/// Which entry a value came from.
function fromBadge(row, members) {
  const from = row.from || [];
  switch (row.verdict) {
    case 'one': {
      const member = members[from[0]];
      const sources = member ? (member.sources || []).join(', ') : '';
      return badge(sources ? `from ${sources}` : (member && member.name) || `entry ${from[0]}`, 'strong');
    }
    case 'agreed': return badge('sources agree', 'good');
    case 'empty': return badge('empty');
    default: return badge('source unknown', 'warn');
  }
}

/// A list or map can take entries from several sources, so each entry says
/// where it came from.
function fromCell(row, members) {
  if (row.kind === 'scalar') return el('td', {}, [fromBadge(row, members)]);
  const entries = row.entries || [];
  if (!entries.length) return el('td', {}, [badge('empty')]);
  return el('td', {}, entries.map((entry) => el('div', { class: 'ex-entry' }, [
    el('span', { text: `${entry.key != null ? `${entry.key}: ${entry.value}` : entry.value} ` }),
    fromBadge(entry, members),
  ])));
}

function fieldsSection(data) {
  if (!data || data.error) {
    return section('Before and after', null, [el('p', { class: 'failed-text', text: (data && data.error) || 'Could not load the fields.' })]);
  }
  if (data.missing) return section('Before and after', null, [missingNote(data)]);
  const members = data.members || [];
  const head = el('tr', {}, [
    el('th', { text: 'Field' }),
    ...members.map((m) => el('th', { title: memberHeading(m), text: memberHeading(m) })),
    el('th', { text: 'Final value' }),
    el('th', { text: 'Source' }),
  ]);
  const rows = (data.rows || []).map((row) => el('tr', {}, [
    el('td', { class: 'mono', text: row.field }),
    ...(row.values || []).map((v) => el('td', { class: 'ex-value', text: cellText(v.value) })),
    el('td', { class: 'ex-value ex-final', text: cellText(row.final) }),
    fromCell(row, members),
  ]));
  return section('Before and after', null, [
    el('p', {
      class: 'dim',
      text: data.wasMerged
        ? `${members.length} entries merged into one mod. Each row shows the source values, final value, and contributing sources.`
        : 'One entry; no merge needed. These are its values.',
    }),
    el('div', { class: 'table-wrap' }, [
      el('table', { class: 'table ex-table ex-fields' }, [el('thead', {}, head), el('tbody', {}, rows)]),
    ]),
  ]);
}

// --- The mod the group became ---

/// The mods the last build made from these posts, found through each post's
/// outcome. Posts every member shares come first; failing that, any of them.
async function modsOfPosts(memberPosts) {
  const posts = [];
  for (const list of memberPosts) {
    for (const post of list || []) {
      const href = post && postHref(post);
      if (!href) continue;
      const kind = post.kind === 'discord' ? 'discord' : 'topic';
      if (!posts.some((p) => p.kind === kind && p.id === String(post.id))) posts.push({ kind, id: String(post.id) });
    }
  }
  if (!posts.length) return [];
  const answers = await Promise.all(posts.slice(0, 12).map((p) => api('posts/outcome', p).catch(() => null)));
  const byId = new Map();
  const perPost = [];
  for (const answer of answers) {
    const mods = (answer && answer.mods) || [];
    perPost.push(new Set(mods.map((m) => m.id)));
    for (const m of mods) if (m && m.id && !byId.has(m.id)) byId.set(m.id, m);
  }
  const shared = [...byId.keys()].filter((modId) => perPost.every((ids) => ids.has(modId)));
  return (shared.length ? shared : [...byId.keys()]).map((modId) => byId.get(modId));
}

function modLinks(mods) {
  const label = mods.length === 1 ? 'Mod page: ' : 'These posts are in: ';
  const nodes = [el('span', { class: 'dim', text: label })];
  mods.forEach((m, i) => {
    if (i) nodes.push(', ');
    nodes.push(el('a', { href: modHref(m.id), text: m.name || m.id }));
  });
  return [el('span', {}, nodes)];
}
