// Tests for the run record helpers (web/run_record.js). Run with
// `node --test test/web/run_record_test.mjs`, or through `dart test`
// (web_js_test.dart).

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { queuedAt, startedAt, runTime, endedState, nextWatch } from '../../web/run_record.js';

const waiting = { id: '20260721T153000Z-fullRun', state: 'queued', startedAt: '2026-07-21T15:30:00.123Z' };
const finished = {
  id: '20260721T153000Z-fullRun',
  state: 'completed',
  startedAt: '2026-07-21T15:42:10.000Z',
  finishedAt: '2026-07-21T15:50:00.000Z',
};

test('the queued time is read from the run id', () => {
  assert.equal(queuedAt(waiting), '2026-07-21T15:30:00Z');
  assert.equal(queuedAt(finished), '2026-07-21T15:30:00Z');
});

test('a waiting run with an id that has no time uses startedAt as the queued time', () => {
  assert.equal(queuedAt({ id: 'odd', state: 'queued', startedAt: '2026-07-21T15:30:00Z' }), '2026-07-21T15:30:00Z');
  assert.equal(queuedAt({ id: 'odd', state: 'completed', startedAt: '2026-07-21T15:30:00Z' }), null);
  assert.equal(queuedAt(null), null);
});

test('a waiting run has not started, even though startedAt is set', () => {
  assert.equal(startedAt(waiting), null);
  assert.equal(startedAt(finished), '2026-07-21T15:42:10.000Z');
});

test('lists show the start time, or the queued time while waiting', () => {
  assert.equal(runTime(finished), '2026-07-21T15:42:10.000Z');
  assert.equal(runTime(waiting), '2026-07-21T15:30:00Z');
});

test('only a record saved as ended has an ended state', () => {
  assert.equal(endedState(finished), 'completed');
  assert.equal(endedState({ state: 'interrupted' }), 'interrupted');
  assert.equal(endedState({ state: 'running' }), null);
  assert.equal(endedState({ state: 'queued' }), null);
  assert.equal(endedState(null), null);
});

const running = (id) => ({ on: true, current: { record: { id } }, queued: [] });
const idle = { on: true, current: null, queued: [] };
const offline = { on: false, reason: 'Cannot reach the server.', current: null, queued: [], offline: true };

test('a run that is no longer current has ended', () => {
  assert.deepEqual(nextWatch('a', idle), { watchedId: null, endedId: 'a' });
  assert.deepEqual(nextWatch('a', running('b')), { watchedId: 'b', endedId: 'a' });
  assert.deepEqual(nextWatch('a', running('a')), { watchedId: 'a', endedId: null });
  assert.deepEqual(nextWatch(null, running('a')), { watchedId: 'a', endedId: null });
});

test('a status from a server that could not be reached does not end the run', () => {
  assert.deepEqual(nextWatch('a', offline), { watchedId: 'a', endedId: null });
  assert.deepEqual(nextWatch('a', { on: false, current: null, queued: [] }), { watchedId: 'a', endedId: null });
  // The server comes back with nothing running: now the run has ended.
  assert.deepEqual(nextWatch('a', idle), { watchedId: null, endedId: 'a' });
});
