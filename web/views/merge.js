// #/merge — merge explorer over the saved merges.
//   #/merge                       summary + phase timings
//   #/merge/groups                searchable group list
//   #/merge/groups/<id>           one group's members + merge decisions
//   #/merge/groups/<id>/fields    before and after, field by field
//   #/merge/removals/<kind>       preDedup | sameSource | validation
//   #/merge/changes               what changed between two merges
//
// Single-merge pages share the selected run, defaulting to the newest.

import { api, el, clear, esc, missingPanel, MissingFile, pager, pageSizePreference, go, rawJson, breadcrumbs, expandAllButton } from '../lib.js';
import { withRun, drawPicker, forgetRuns } from './merge_shared.js';
import { groupFields, changesPage } from './merge_compare.js';

export async function render(root, parts, { keepRuns = false } = {}) {
  // Reload saved runs on navigation; picker redraws reuse the list.
  if (!keepRuns) forgetRuns();
  clear(root);

  // Catalog diff has its own pair of pickers rather than single-merge controls.
  const section = parts[0] || 'summary';
  if (section === 'changes') {
    root.append(breadcrumbs([{ label: 'Catalog diff' }]));
    root.append(el('h1', { text: 'Catalog diff' }));
    const diffBody = el('div', {});
    root.append(diffBody);
    return changesPage(diffBody);
  }

  root.append(breadcrumbs([{ label: 'Catalog explorer' }]));
  root.append(el('h1', { text: 'Catalog explorer' }));
  const pickerRow = el('div', {});
  root.append(pickerRow);
  root.append(subnav(parts));
  const body = el('div', {});
  root.append(body);

  drawPicker(pickerRow, () => render(root, parts, { keepRuns: true }));
  if (section === 'groups' && parts[2] === 'fields') return groupFields(body, parts[1]);
  if (section === 'groups' && parts[1] != null) return groupDetail(body, parts[1]);
  if (section === 'groups') return groupsList(body);
  if (section === 'removals') return removalsList(body, parts[1] || 'preDedup');
  return summary(body);
}

function subnav(parts) {
  const section = parts[0] || 'summary';
  const nav = el('div', { class: 'toolbar' });
  const tab = (label, hash, active) =>
    el('a', { class: 'chip' + (active ? ' on' : ''), href: hash, text: label });
  nav.append(
    tab('Summary', '#/merge', section === 'summary'),
    tab('Groups', '#/merge/groups', section === 'groups'),
    tab('Pre-dedup', '#/merge/removals/preDedup', section === 'removals' && (parts[1] || 'preDedup') === 'preDedup'),
    tab('Same-source', '#/merge/removals/sameSource', section === 'removals' && parts[1] === 'sameSource'),
    tab('Validation', '#/merge/removals/validation', section === 'removals' && parts[1] === 'validation')
  );
  return nav;
}

async function summary(body) {
  const data = await api('merge/summary', withRun());
  if (data instanceof MissingFile) return body.append(missingPanel(data));

  const cards = [
    ['Input mods', data.inputCount, ''],
    ['Pre-dedup removals', data.preDedupCount, data.preDedupCount ? 'warning' : ''],
    ['After pre-dedup', data.afterPreDedupCount, ''],
    ['Groups', data.groupCount, ''],
    ['Groups with multiple entries', data.multiMemberGroupCount, ''],
    ['Groups with one entry', data.singletonGroupCount, ''],
    ['Same-source dedup', data.sameSourceDedupCount, data.sameSourceDedupCount ? 'warning' : ''],
    ['Validation removals', data.validationRemovalCount, data.validationRemovalCount ? 'error' : ''],
    ['Final output', data.finalOutputCount, ''],
  ];
  const grid = el('div', { class: 'stat-grid' });
  for (const [label, value, cls] of cards) {
    grid.append(el('div', { class: 'stat-card ' + cls }, [
      el('div', { class: 'label', text: label }),
      el('div', { class: 'value', text: String(value ?? '—') }),
    ]));
  }
  body.append(grid);

  const timings = data.timings || [];
  if (timings.length) {
    body.append(el('h2', { text: 'Phase timings' }));
    const max = Math.max(1, ...timings.map((t) => t.durationMs || 0));
    for (const t of timings) {
      const pct = Math.max(1, Math.min(100, ((t.durationMs || 0) / max) * 100));
      body.append(el('div', { class: 'timing-bar-container' }, [
        el('div', { class: 'timing-bar-label' }, [
          el('span', { text: t.phaseName || '?' }),
          el('span', { text: `${t.durationMs || 0}ms` }),
        ]),
        el('div', { class: 'timing-bar' }, el('div', { class: 'timing-bar-fill', style: `width:${pct.toFixed(1)}%` })),
      ]));
    }
  }
}

const groupsState = { q: '', multiOnly: true, page: 0, pageSize: pageSizePreference() };

async function groupsList(body) {
  // A ModRepo detail link may have stashed a mod name to search for.
  const pending = sessionStorage.getItem('mergeGroupSearch');
  if (pending != null) {
    groupsState.q = pending;
    groupsState.page = 0;
    sessionStorage.removeItem('mergeGroupSearch');
  }
  const toolbar = el('div', { class: 'toolbar' });
  const search = el('input', { type: 'search', placeholder: 'Search member name or author…', value: groupsState.q });
  let d;
  search.addEventListener('input', () => {
    clearTimeout(d);
    d = setTimeout(() => { groupsState.q = search.value.trim(); groupsState.page = 0; load(); }, 250);
  });
  const multi = el('span', {
    class: 'chip' + (groupsState.multiOnly ? ' on' : ''),
    text: 'Multiple entries only',
    onclick: () => { groupsState.multiOnly = !groupsState.multiOnly; multi.classList.toggle('on'); groupsState.page = 0; load(); },
  });
  const results = el('div', {});
  const foldAll = expandAllButton(results, 'details.panel');
  toolbar.append(search, multi, foldAll);
  body.append(toolbar);
  body.append(results);

  async function load() {
    clear(results).append(el('div', { class: 'loading', text: 'Loading…' }));
    const data = await api('merge/groups', withRun({
      q: groupsState.q, multiOnly: groupsState.multiOnly, page: groupsState.page, pageSize: groupsState.pageSize,
    }));
    clear(results);
    if (data instanceof MissingFile) return results.append(missingPanel(data));
    for (const g of data.items) {
      const primary = (g.members[0] && g.members[0].name) || '(empty)';
      const card = el('details', { class: 'panel', style: 'margin-bottom:8px;' });
      card.append(el('summary', {}, [
        el('a', { href: `#/merge/groups/${g.groupIndex}`, text: `Group #${g.groupIndex}` }),
        ` — ${primary} `,
        el('span', { class: 'badge badge-secondary', text: `${g.memberCount} members` }),
      ]));
      const inner = el('div', {});
      const memberPosts = g.memberSourcePosts || [];
      g.members.forEach((m, i) => {
        inner.append(el('div', { class: 'field-value', style: 'padding:2px 0;' }, [
          `${m.name || '(empty)'} — ${(m.authorsList || []).join(', ')} [${(m.sources || []).join(', ')}] v${m.gameVersionReq || '?'}`,
          ...sourcePostLinks(memberPosts[i]),
        ]));
      });
      const matches = g.matchEntries || [];
      if (matches.length) {
        inner.append(el('h3', { text: 'Match reasons' }));
        for (const mm of matches) {
          inner.append(el('div', { class: 'field-value', html: matchReason(mm) }));
        }
      }
      card.append(inner);
      results.append(card);
    }
    if (!data.items.length) results.append(el('p', { class: 'loading', text: 'No groups match.' }));
    foldAll.refresh();
    results.append(pager(data.page, data.pageSize, data.total,
      (p) => { groupsState.page = p; load(); },
      (size) => { groupsState.pageSize = size; groupsState.page = 0; load(); }));
  }
  load();
}

/// Which source post a listing came from, and who found it, as small links:
/// a forum topic opens its thread page, a Discord thread the LLM's answer.
/// Merges saved before listings existed have no posts and show nothing.
export function sourcePostLinks(posts, { long = false } = {}) {
  const nodes = [];
  for (const post of posts || []) {
    if (!post || !post.id) continue;
    const where = post.kind === 'forum' ? `topic ${post.id}`
      : post.kind === 'discord' ? `Discord thread ${post.id}`
        : `${post.kind} ${post.id}`;
    const href = post.kind === 'forum' ? `#/topics/${encodeURIComponent(post.id)}`
      : post.kind === 'discord' ? `#/discord/${encodeURIComponent(post.id)}` : null;
    const by = post.foundBy === 'llm' ? 'found by the LLM'
      : post.foundBy === 'rulesAndLlm' ? 'rules, joined by the LLM' : 'found by the rules';
    const label = post.llmModName ? `${where} · "${post.llmModName}"` : where;
    nodes.push(' ');
    nodes.push(href ? el('a', { class: 'chip', href, text: label, title: by }) : el('span', { class: 'chip', text: label, title: by }));
    if (long) nodes.push(el('span', { class: 'loading', text: ` ${by}` }));
  }
  return nodes;
}

function matchReason(mm) {
  const parts = [];
  const reasons = mm.reasons || [];
  const outer = (mm.outerMod && mm.outerMod.name) || '?';
  const inner = (mm.innerMod && mm.innerMod.name) || '?';
  parts.push(`<strong>${esc(outer)}</strong> ↔ <strong>${esc(inner)}</strong>: `);
  if (reasons.includes('nameAndAuthor')) {
    parts.push(`<span class="badge badge-primary">Name+Author</span> `);
    if (mm.nameScore != null) parts.push(`name ${mm.nameScore} `);
    if (mm.authorScore != null) parts.push(`author ${mm.authorScore} `);
  }
  if (reasons.includes('strippedNameAndAuthor')) {
    parts.push(`<span class="badge badge-primary">Name+Author (version stripped)</span> `);
    if (mm.outerStrippedName != null) parts.push(`"${esc(mm.outerStrippedName)}" ↔ "${esc(mm.innerStrippedName)}" `);
    if (mm.strippedNameScore != null) parts.push(`name ${mm.strippedNameScore} `);
    if (mm.strippedNameLengthRatio != null) parts.push(`ratio ${(mm.strippedNameLengthRatio * 100).toFixed(0)}% `);
    if (mm.authorScore != null) parts.push(`author ${mm.authorScore} `);
  }
  if (reasons.includes('nameAndDownload')) {
    parts.push(`<span class="badge badge-primary">Name+Same download</span> `);
    if (mm.nameScore != null) parts.push(`name ${mm.nameScore} `);
  }
  if (reasons.includes('forumUrl')) {
    parts.push(`<span class="badge badge-secondary">Forum URL</span> `);
    if (mm.matchedForumTopicId) parts.push(`topic ${esc(mm.matchedForumTopicId)} `);
  }
  return parts.join('');
}

async function groupDetail(body, id) {
  body.append(el('a', { class: 'back-link', href: '#/merge/groups', text: '‹ Back to groups' }));
  const data = await api(`merge/groups/${encodeURIComponent(id)}`, withRun());
  if (data instanceof MissingFile) return body.append(missingPanel(data));
  if (data.error) return body.append(el('div', { class: 'missing error' }, el('h3', { text: data.error })));

  const group = data.group || {};
  const decision = data.decision;
  body.append(el('h2', { text: `Group #${group.groupIndex}` }));
  body.append(el('div', { class: 'toolbar' }, [
    el('a', {
      class: 'chip',
      href: `#/merge/groups/${encodeURIComponent(id)}/fields`,
      text: 'Compare fields →',
    }),
  ]));

  body.append(el('h3', { text: 'Members' }));
  const memberPosts = group.memberSourcePosts || [];
  (group.members || []).forEach((m, i) => {
    body.append(el('div', { class: 'panel', style: 'margin-bottom:6px;' }, [
      el('strong', { text: m.name || '(empty)' }),
      el('div', { class: 'field-value', text: `by ${(m.authorsList || []).join(', ')} · [${(m.sources || []).join(', ')}] · v${m.gameVersionReq || '?'}` }),
      el('div', { class: 'field-value' }, sourcePostLinks(memberPosts[i], { long: true })),
    ]));
  });

  if (decision && (decision.steps || []).length) {
    body.append(el('h3', { text: 'Merge decisions' }));
    let i = 1;
    for (const step of decision.steps) {
      const box = el('div', { class: 'panel', style: 'margin-bottom:6px;' });
      box.append(el('div', {}, [
        `Step ${i++}: `,
        el('span', { class: 'badge badge-primary', text: reasonLabel(step.reason) }),
        ` priority → ${step.doesRightHavePriority ? 'right' : 'left'}`,
      ]));
      box.append(el('div', { class: step.doesRightHavePriority ? 'field-value' : 'conf-high', text: `left: ${modLine(step.left)}` }));
      box.append(el('div', { class: step.doesRightHavePriority ? 'conf-high' : 'field-value', text: `right: ${modLine(step.right)}` }));
      box.append(el('div', { class: 'badge badge-secondary', text: `result: ${step.result && step.result.name || '?'}` }));
      body.append(box);
    }
  } else {
    body.append(el('p', { class: 'loading', text: 'No merge steps recorded.' }));
  }

  body.append(rawJson(data, 'Raw group data (JSON)'));
}

function reasonLabel(reason) {
  return { indexSource: 'Mod index source', higherGameVersion: 'Higher game version', fallback: 'Fallback' }[reason] || reason || '?';
}

function modLine(m) {
  if (!m) return '?';
  return `${m.name || '(empty)'} by ${(m.authorsList || []).join(', ')} [${(m.sources || []).join(', ')}] v${m.gameVersionReq || '?'}`;
}

const removalsState = {};

async function removalsList(body, kind) {
  const st = (removalsState[kind] ||= { q: '', page: 0, pageSize: pageSizePreference() });
  const toolbar = el('div', { class: 'toolbar' });
  const search = el('input', { type: 'search', placeholder: 'Search name or author…', value: st.q });
  let d;
  search.addEventListener('input', () => {
    clearTimeout(d);
    d = setTimeout(() => { st.q = search.value.trim(); st.page = 0; load(); }, 250);
  });
  toolbar.append(search);
  body.append(toolbar);
  const results = el('div', {});
  body.append(results);

  async function load() {
    clear(results).append(el('div', { class: 'loading', text: 'Loading…' }));
    const data = await api('merge/removals',
      withRun({ kind, q: st.q, page: st.page, pageSize: st.pageSize }));
    clear(results);
    if (data instanceof MissingFile) return results.append(missingPanel(data));

    const wrap = el('div', { class: 'table-wrapper' });
    const table = el('table');
    if (kind === 'validation') {
      table.append(el('thead', {}, el('tr', {}, [el('th', { text: 'Mod' }), el('th', { text: 'Authors' }), el('th', { text: 'Reason' })])));
      const tb = el('tbody');
      for (const e of data.items) {
        tb.append(el('tr', {}, [
          el('td', { text: (e.mod && e.mod.name) || '(empty)' }),
          el('td', { text: (e.mod && (e.mod.authorsList || []).join(', ')) || '' }),
          el('td', {}, el('span', { class: 'badge badge-error', text: e.reason || '' })),
        ]));
      }
      table.append(tb);
    } else {
      table.append(el('thead', {}, el('tr', {}, [el('th', { text: 'Kept' }), el('th', { text: 'Discarded' }), el('th', { text: 'Detail' })])));
      const tb = el('tbody');
      for (const e of data.items) {
        const detail = kind === 'sameSource'
          ? `${e.source || ''} · v${e.keptGameVersion || '?'} vs v${e.discardedGameVersion || '?'}${e.wasSafetyBlocked ? ' · SAFETY BLOCKED' : ''}`
          : `${e.reason || ''} · richness ${e.keptRichness ?? '?'} vs ${e.discardedRichness ?? '?'}`;
        tb.append(el('tr', {}, [
          el('td', { text: (e.kept && e.kept.name) || '(empty)' }),
          el('td', { text: (e.discarded && e.discarded.name) || '(empty)' }),
          el('td', { text: detail }),
        ]));
      }
      table.append(tb);
    }
    wrap.append(table);
    results.append(wrap);
    if (!data.items.length) results.append(el('p', { class: 'loading', text: 'No entries.' }));
    results.append(pager(data.page, data.pageSize, data.total,
      (p) => { st.page = p; load(); },
      (size) => { st.pageSize = size; st.page = 0; load(); }));
  }
  load();
}
