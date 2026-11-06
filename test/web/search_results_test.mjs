// Tests for what the search box shows and which row the keys pick
// (web/search_results.js). Run with `node --test test/web/`, or through
// `dart test` (web_js_test.dart).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  MIN_SEARCH, resultGroups, pickable, stepActive, enterTarget, resultsSentence,
} from '../../web/search_results.js';

const answer = {
  q: 'nex',
  mods: {
    total: 7,
    items: [
      { id: 'nexerelin', name: 'Nexerelin', authors: ['Histidine', 'Zaphide'] },
      { id: 'gone', name: 'Gone', authors: [], takenDown: true },
      { id: 'industrial-evolution', name: 'Industrial.Evolution', authors: ['SirHartley'], detail: 'also called IndEvo' },
    ],
  },
  topics: { total: 1, items: [{ id: '9000', title: '', author: 'Histidine' }] },
  discord: { total: 0, items: [] },
  runs: {
    total: 9,
    items: [{ id: '20261105T230000Z-fetchAndUpdate', kind: 'fetchAndUpdate', state: 'completed', startedAt: '2026-11-05T23:00:00Z' }],
  },
};

test('needs two characters', () => {
  assert.equal(MIN_SEARCH, 2);
});

test('groups come in order, and empty groups are left out', () => {
  const groups = resultGroups(answer);
  assert.deepEqual(groups.map((g) => g.heading), ['Mods', 'Forum topics', 'Runs']);
  assert.deepEqual(resultGroups(null), []);
  assert.deepEqual(resultGroups({ q: 'x', mods: { total: 0, items: [] } }), []);
});

test('each row links to its page and says who made it or why it matched', () => {
  const [mods, topics, runs] = resultGroups(answer);
  assert.deepEqual(mods.rows[0], { href: '#/mods/nexerelin', label: 'Nexerelin', sub: 'Histidine, Zaphide', detail: null });
  assert.equal(mods.rows[1].sub, 'Taken down');
  assert.equal(mods.rows[2].detail, 'also called IndEvo');
  assert.deepEqual(topics.rows[0], { href: '#/posts/topic/9000', label: 'Topic 9000', sub: 'Topic 9000 · Histidine', detail: null });
  assert.deepEqual(runs.rows[0], {
    href: '#/runs/20261105T230000Z-fetchAndUpdate',
    label: 'Fetch and update',
    sub: 'Done · 20261105T230000Z-fetchAndUpdate',
    detail: null,
    time: '2026-11-05T23:00:00Z',
  });
});

test('a Discord thread with no name still has a label', () => {
  const [discord] = resultGroups({ q: 'x', discord: { total: 1, items: [{ id: '1355071745366822950', title: '', author: '' }] } });
  assert.deepEqual(discord.rows[0], {
    href: '#/posts/discord/1355071745366822950', label: 'Thread 1355071745366822950', sub: '', detail: null,
  });
});

test('"See all N" opens the full list with the search filled in, only when some are not shown', () => {
  const [mods, topics, runs] = resultGroups(answer);
  assert.deepEqual(mods.more, { href: '#/mods?q=nex', label: 'See all 7' });
  assert.equal(topics.more, null);
  assert.deepEqual(runs.more, { href: '#/runs', label: 'See all in Run history' });

  const [t, d] = resultGroups({
    q: 'lazy lib',
    topics: { total: 6, items: [{ id: '1', title: 'A' }] },
    discord: { total: 2, items: [{ id: '2', title: 'B' }] },
  });
  assert.equal(t.more.href, '#/posts?q=lazy+lib&kind=topic');
  assert.equal(d.more.href, '#/posts?q=lazy+lib&kind=discord');
  assert.equal(d.more.label, 'See all 2');
});

test('the arrow keys visit every row and "See all" link in order', () => {
  const items = pickable(resultGroups(answer));
  assert.deepEqual(items.map((i) => i.href), [
    '#/mods/nexerelin', '#/mods/gone', '#/mods/industrial-evolution', '#/mods?q=nex',
    '#/posts/topic/9000',
    '#/runs/20261105T230000Z-fetchAndUpdate', '#/runs',
  ]);
  assert.deepEqual(items.map((i) => i.isMore), [false, false, false, true, false, false, true]);
});

test('the highlight wraps round', () => {
  assert.equal(stepActive(-1, 5, 1), 0);
  assert.equal(stepActive(-1, 5, -1), 4);
  assert.equal(stepActive(0, 5, 1), 1);
  assert.equal(stepActive(4, 5, 1), 0);
  assert.equal(stepActive(0, 5, -1), 4);
  assert.equal(stepActive(2, 0, 1), -1);
});

test('Enter opens the highlighted row, else the named page, else the first row', () => {
  const items = pickable(resultGroups(answer));
  assert.equal(enterTarget('nex', items, 2), '#/mods/industrial-evolution');
  assert.equal(enterTarget('nex', items, -1), '#/mods/nexerelin');
  assert.equal(enterTarget('18011', items, -1), '#/posts/topic/18011');
  assert.equal(enterTarget('https://discord.com/channels/1/1355071745366822950', [], -1), '#/posts/discord/1355071745366822950');
  assert.equal(enterTarget('nothing here', [], -1), null);
  // A "See all" link is never the first row.
  assert.equal(enterTarget('x', [{ href: '#/runs', isMore: true }], -1), null);
});

test('a screen reader hears how many rows arrived', () => {
  assert.equal(resultsSentence(resultGroups(answer)), '5 results');
  assert.equal(resultsSentence([]), 'No results');
  assert.equal(resultsSentence(resultGroups({ q: 'x', topics: { total: 1, items: [{ id: '1' }] } })), '1 result');
});
