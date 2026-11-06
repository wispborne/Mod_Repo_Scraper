// Tests for which two runs the What changed page compares
// (web/change_sides.js). Run with `node --test test/web/change_sides_test.mjs`,
// or through `dart test` (web_js_test.dart).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  WORKING, tabFrom, nearestRun, runBefore, settleSides, openFrom, openParam,
} from '../../web/change_sides.js';

// Newest first, as the server lists them. Real ids from one day of runs:
// the cron's catalog and mod details snapshots come from two different runs.
const facts = [
  { id: '20261105T203544Z-rebuildFromSaved', savedAt: '2026-11-05T20:35:51Z' },
  { id: '20261105T073912Z-fullRun', savedAt: '2026-11-05T07:40:02Z' },
  { id: '20261105T060304Z-rebuildFromSaved', savedAt: '2026-11-05T07:32:50Z' },
  { id: '20261105T042645Z-fetchAndUpdate', savedAt: '2026-11-05T04:52:29Z' },
];
const mods = [
  { id: '20261105T203544Z-rebuildFromSaved', savedAt: '2026-11-05T20:35:49Z' },
  { id: '20261105T070002Z-scrapeAndMerge', savedAt: '2026-11-05T07:39:02Z' },
  { id: '20261105T060304Z-rebuildFromSaved', savedAt: '2026-11-05T07:32:48Z' },
  { id: '20261105T042645Z-fetchAndUpdate', savedAt: '2026-11-05T04:52:27Z' },
];
const working = { id: WORKING, updatedAt: '2026-11-05T21:00:00Z' };

test('the tab defaults to Facts', () => {
  assert.equal(tabFrom('mods'), 'mods');
  assert.equal(tabFrom('facts'), 'facts');
  assert.equal(tabFrom(''), 'facts');
  assert.equal(tabFrom('merge'), 'facts');
});

test('the nearest run is the one saved nearest in time, before or after', () => {
  assert.equal(nearestRun(mods, '2026-11-05T07:40:02Z'), '20261105T070002Z-scrapeAndMerge');
  // A catalog saved a minute before the cron's mod details finds them.
  assert.equal(nearestRun(facts, '2026-11-05T07:39:02Z'), '20261105T073912Z-fullRun');
  assert.equal(nearestRun(mods, '2026-01-01T00:00:00Z'), '20261105T042645Z-fetchAndUpdate');
  assert.equal(nearestRun(mods, '2027-01-01T00:00:00Z'), '20261105T203544Z-rebuildFromSaved');
  assert.equal(nearestRun([], '2026-01-01T00:00:00Z'), null);
});

test('the run before', () => {
  assert.equal(runBefore(facts, '20261105T073912Z-fullRun'), '20261105T060304Z-rebuildFromSaved');
  assert.equal(runBefore(facts, '20261105T042645Z-fetchAndUpdate'), null);
  assert.equal(runBefore(facts, 'unknown'), null);
  assert.equal(runBefore(facts, WORKING), facts[0].id);
});

test('with nothing picked, the newest run is compared with the one before it', () => {
  const s = settleSides({ runs: facts, working });
  assert.deepEqual([s.a, s.b], [facts[1].id, facts[0].id]);
  assert.deepEqual(s.moved, []);
  assert.equal(s.nothing, false);
});

test('a link naming only the newer run compares it with the run before it', () => {
  const s = settleSides({ runs: facts, working, b: '20261105T073912Z-fullRun' });
  assert.deepEqual([s.a, s.b], ['20261105T060304Z-rebuildFromSaved', '20261105T073912Z-fullRun']);
});

test('two picked runs are kept, in either order', () => {
  let s = settleSides({ runs: facts, a: facts[3].id, b: facts[1].id });
  assert.deepEqual([s.a, s.b], [facts[3].id, facts[1].id]);
  s = settleSides({ runs: facts, a: facts[0].id, b: facts[2].id });
  assert.deepEqual([s.a, s.b], [facts[0].id, facts[2].id]);
});

test('the same run on both sides compares it with the run before it', () => {
  const s = settleSides({ runs: facts, a: facts[1].id, b: facts[1].id });
  assert.deepEqual([s.a, s.b], [facts[2].id, facts[1].id]);
});

test('the oldest run as the newer side is compared with the run after it, and said so', () => {
  const s = settleSides({ runs: facts, b: facts[3].id });
  assert.deepEqual([s.a, s.b], [facts[3].id, facts[2].id]);
  assert.deepEqual(s.moved, [{ side: 'b', from: facts[3].id, why: 'oldest', to: facts[2].id }]);
  // The only run kept is compared with the data on disk.
  const one = settleSides({ runs: [facts[0]], working, b: facts[0].id });
  assert.deepEqual(one.moved, [{ side: 'b', from: facts[0].id, why: 'oldest', to: WORKING }]);
});

test('the data on disk is the newer side on Facts, compared with the newest run', () => {
  const s = settleSides({ runs: facts, working, b: WORKING });
  assert.deepEqual([s.a, s.b], [facts[0].id, WORKING]);
  const picked = settleSides({ runs: facts, working, a: facts[2].id, b: WORKING });
  assert.deepEqual([picked.a, picked.b], [facts[2].id, WORKING]);
});

test('the data on disk is never the older side', () => {
  const s = settleSides({ runs: facts, working, a: WORKING, b: facts[1].id });
  assert.deepEqual([s.a, s.b], [facts[2].id, facts[1].id]);
});

test('one saved run is enough when the data on disk can be the other side', () => {
  const one = [facts[0]];
  assert.deepEqual(settleSides({ runs: one, working }), { a: facts[0].id, b: WORKING, moved: [], nothing: false });
  const named = settleSides({ runs: one, working, b: facts[0].id });
  assert.deepEqual([named.a, named.b], [facts[0].id, WORKING]);
  assert.equal(settleSides({ runs: one }).nothing, true);
  assert.equal(settleSides({ runs: [] , working }).nothing, true);
});

test('on Mods, the data on disk is replaced by the newest run, and said so', () => {
  const s = settleSides({ runs: mods, a: mods[2].id, b: WORKING, otherRuns: facts });
  assert.deepEqual([s.a, s.b], [mods[2].id, mods[0].id]);
  assert.deepEqual(s.moved, [{ side: 'b', from: WORKING, why: 'working', to: mods[0].id }]);
});

test('a run with no snapshot on this tab is replaced by the nearest one', () => {
  // Switching from Facts (060304Z against the cron's 073912Z full run) to Mods.
  const s = settleSides({
    runs: mods, a: '20261105T060304Z-rebuildFromSaved', b: '20261105T073912Z-fullRun', otherRuns: facts,
  });
  assert.deepEqual([s.a, s.b], ['20261105T060304Z-rebuildFromSaved', '20261105T070002Z-scrapeAndMerge']);
  assert.deepEqual(s.moved, [{
    side: 'b',
    from: '20261105T073912Z-fullRun',
    why: 'otherTab',
    nearest: '20261105T070002Z-scrapeAndMerge',
    to: '20261105T070002Z-scrapeAndMerge',
  }]);
  // And back the other way, from Mods to Facts.
  const back = settleSides({
    runs: facts, working, a: '20261105T060304Z-rebuildFromSaved', b: '20261105T070002Z-scrapeAndMerge', otherRuns: mods,
  });
  assert.deepEqual([back.a, back.b], ['20261105T060304Z-rebuildFromSaved', '20261105T073912Z-fullRun']);
});

test('a stand-in that lands on the other side moves on to the run before it', () => {
  // 073912Z's nearest catalog is 070002Z, which is already the newer side.
  const s = settleSides({
    runs: mods, a: '20261105T073912Z-fullRun', b: '20261105T070002Z-scrapeAndMerge', otherRuns: facts,
  });
  assert.deepEqual([s.a, s.b], ['20261105T060304Z-rebuildFromSaved', '20261105T070002Z-scrapeAndMerge']);
  assert.equal(s.moved[0].to, '20261105T060304Z-rebuildFromSaved');
  // The note can say where the nearest run went.
  assert.equal(s.moved[0].nearest, '20261105T070002Z-scrapeAndMerge');
});

test('two runs nearest the same run: the nearest is kept on one side, and the note says so', () => {
  // Two merge-only runs a minute apart, both nearest the oldest full run.
  const full = [
    { id: '20261106T080000Z-fullRun', savedAt: '2026-11-06T08:30:00Z' },
    { id: '20261105T080000Z-fullRun', savedAt: '2026-11-05T08:30:00Z' },
  ];
  const merges = [
    { id: '20261105T090100Z-mergeModRepo', savedAt: '2026-11-05T09:01:10Z' },
    { id: '20261105T090000Z-mergeModRepo', savedAt: '2026-11-05T09:00:10Z' },
  ];
  const s = settleSides({ runs: full, a: merges[1].id, b: merges[0].id, otherRuns: merges });
  assert.deepEqual([s.a, s.b], [full[1].id, full[0].id]);
  const olderNote = s.moved.find((m) => m.side === 'a');
  const newerNote = s.moved.find((m) => m.side === 'b');
  assert.equal(olderNote.nearest, full[1].id);
  assert.equal(olderNote.to, full[1].id);
  // The newer run's nearest is the older side, so it moved on; the note must
  // not claim the run a day later is the nearest.
  assert.equal(newerNote.nearest, full[1].id);
  assert.equal(newerNote.to, full[0].id);
  assert.ok(!s.moved.some((m) => m.why === 'oldest'));
});

test('a run no longer kept is replaced, and said so', () => {
  const s = settleSides({ runs: facts, a: 'old-run', b: facts[0].id, otherRuns: mods });
  assert.deepEqual([s.a, s.b], [facts[1].id, facts[0].id]);
  assert.deepEqual(s.moved, [{ side: 'a', from: 'old-run', why: 'gone', to: facts[1].id }]);
});

test('open rows go to and from the address', () => {
  assert.deepEqual([...openFrom('topic:1;name:abc|de,fg')], ['topic:1', 'name:abc|de,fg']);
  assert.deepEqual([...openFrom('')], []);
  assert.equal(openFrom('all'), 'all');
  assert.equal(openParam([], ['topic:1']), '');
  assert.equal(openParam(['topic:1'], ['topic:1', 'topic:2']), 'topic:1');
  assert.equal(openParam(['topic:1', 'topic:2'], ['topic:1', 'topic:2']), 'all');
  // One row open out of one is named, so the link still names it after a refresh.
  assert.equal(openParam(['topic:1'], ['topic:1']), 'topic:1');
});
