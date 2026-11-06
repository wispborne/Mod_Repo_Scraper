// Search result display and keyboard selection for GET /api/search.
// No DOM dependency, so Node can test these helpers
// (test/web2/search_results_test.mjs).

import { buildHash, kindLabel, searchRoute } from './routes.js';

/// Shorter text than this is not sent to the server.
export const MIN_SEARCH = 2;

const STATE_WORDS = {
  running: 'Running',
  queued: 'Waiting',
  completed: 'Done',
  failed: 'Failed',
  cancelled: 'Stopped',
  interrupted: 'Interrupted',
};

/// Search result groups in display order. Empty groups are omitted.
/// Each row is `{ href, label, sub, detail, time }`; `more` is the link to
/// the full list, or null when every match is already shown.
export function resultGroups(answer) {
  if (!answer) return [];
  const q = answer.q || '';
  const groups = [
    {
      key: 'mods',
      heading: 'Mods',
      row: (m) => ({
        href: buildHash(['mods', m.id]),
        label: m.name || m.id,
        sub: m.takenDown ? 'Taken down' : (m.authors || []).join(', '),
        detail: m.detail || null,
      }),
      more: (total) => ({ href: buildHash(['mods'], { q }), label: `See all ${total}` }),
    },
    {
      key: 'topics',
      heading: 'Forum topics',
      row: (t) => ({
        href: buildHash(['posts', 'topic', t.id]),
        label: t.title || `Topic ${t.id}`,
        sub: [`Topic ${t.id}`, t.author].filter(Boolean).join(' · '),
        detail: t.detail || null,
      }),
      more: (total) => ({ href: buildHash(['posts'], { q, kind: 'topic' }), label: `See all ${total}` }),
    },
    {
      key: 'discord',
      heading: 'Discord threads',
      row: (t) => ({
        href: buildHash(['posts', 'discord', t.id]),
        label: t.title || `Thread ${t.id}`,
        sub: t.author || '',
        detail: t.detail || null,
      }),
      more: (total) => ({ href: buildHash(['posts'], { q, kind: 'discord' }), label: `See all ${total}` }),
    },
    {
      key: 'runs',
      heading: 'Runs',
      row: (r) => ({
        href: buildHash(['runs', r.id]),
        label: kindLabel(r.kind),
        sub: [STATE_WORDS[r.state] || r.state, r.id].filter(Boolean).join(' · '),
        detail: null,
        time: r.startedAt || null,
      }),
      // Run history lists every run; it has no search of its own.
      more: () => ({ href: '#/runs', label: 'See all in Run history' }),
    },
  ];

  const out = [];
  for (const g of groups) {
    const found = answer[g.key] || {};
    const items = found.items || [];
    if (!items.length) continue;
    const total = Number(found.total) || items.length;
    out.push({
      key: g.key,
      heading: g.heading,
      total,
      rows: items.map(g.row),
      more: total > items.length ? g.more(total) : null,
    });
  }
  return out;
}

/// Every row and "See all" link in the order the arrow keys visit them.
export function pickable(groups) {
  const list = [];
  for (const g of groups) {
    for (const row of g.rows) list.push({ ...row, group: g.key, isMore: false });
    if (g.more) list.push({ ...g.more, group: g.key, isMore: true });
  }
  return list;
}

/// The highlighted position after an arrow key. -1 is the box itself, with
/// nothing highlighted. Down from the last goes back to the first, and Up
/// from nothing goes to the last.
export function stepActive(current, count, delta) {
  if (!count) return -1;
  if (current < 0) return delta > 0 ? 0 : count - 1;
  return (current + delta + count) % count;
}

/// Enter opens the highlighted row. If none is highlighted, it tries a
/// forum or Discord address or a topic, thread or run id, then the first row.
/// Returns null when there is no destination.
export function enterTarget(text, items, active) {
  if (active >= 0 && items[active]) return items[active].href;
  const route = searchRoute(text);
  if (route) return route;
  const first = items.find((item) => !item.isMore);
  return first ? first.href : null;
}

/// The result count announced by a screen reader.
export function resultsSentence(groups) {
  const shown = groups.reduce((n, g) => n + g.rows.length, 0);
  if (!shown) return 'No results';
  return shown === 1 ? '1 result' : `${shown} results`;
}
