// Tests for the viewer's pending corrections list (web/pending.js). Run
// with `node --test test/web/pending_test.mjs`, or through `dart test`
// (web_js_test.dart).

import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';

// A stand-in for the browser's sessionStorage and events.
const stored = new Map();
globalThis.sessionStorage = {
  getItem: (k) => (stored.has(k) ? stored.get(k) : null),
  setItem: (k, v) => stored.set(k, String(v)),
  removeItem: (k) => stored.delete(k),
};
const target = new EventTarget();
globalThis.addEventListener = target.addEventListener.bind(target);
globalThis.removeEventListener = target.removeEventListener.bind(target);
globalThis.dispatchEvent = target.dispatchEvent.bind(target);

const {
  pendingItems, addPending, removePending, clearPending, isPending, onPendingChange, saveRequest,
  correctionKey, PENDING_KEY,
} = await import('../../web/pending.js');

beforeEach(() => stored.clear());

const takeDown = (modId) => ({ label: `Take down "${modId}"`, correction: { kind: 'takeDownMod', modId } });

test('items are kept in sessionStorage under the key the toolbar reads', () => {
  assert.equal(PENDING_KEY, 'viewerPendingChanges');
  addPending(takeDown('a'));
  assert.equal(JSON.parse(stored.get(PENDING_KEY)).length, 1);
  assert.equal(pendingItems()[0].label, 'Take down "a"');
});

test('the same correction is only added once', () => {
  assert.equal(addPending(takeDown('a')), true);
  assert.equal(addPending(takeDown('a')), false);
  assert.equal(pendingItems().length, 1);
});

test('a pair of names is the same pair either way round', () => {
  addPending({ label: 'x', correction: { kind: 'sameAuthor', names: ['Histidine', 'histidine_my'] } });
  assert.equal(addPending({ label: 'y', correction: { kind: 'sameAuthor', names: ['histidine_my', 'Histidine'] } }), false);
  assert.equal(
    correctionKey({ kind: 'differentAuthors', names: ['b', 'a'] }),
    correctionKey({ kind: 'differentAuthors', names: ['a', 'b'] }),
  );
});

test('restoring a takedown that is still pending cancels both', () => {
  addPending(takeDown('a'));
  addPending({ label: 'Take down "Tidal"', correction: { kind: 'takeDownAuthor', names: ['Tidal', 'tidal5590'] } });
  addPending({ label: 'Restore "a"', correction: { kind: 'restore', entry: 'a' } });
  addPending({ label: 'Restore "Tidal"', correction: { kind: 'restore', entry: 'author:Tidal' } });
  assert.deepEqual(pendingItems(), []);
});

test('a restore of a saved entry is added', () => {
  addPending({ label: 'Restore "b"', correction: { kind: 'restore', entry: 'b' } });
  assert.equal(pendingItems().length, 1);
  assert.equal(isPending({ kind: 'restore', entry: 'b' }), true);
});

test('remove, clear, and the change event', () => {
  let calls = 0;
  const stop = onPendingChange(() => { calls += 1; });
  addPending(takeDown('a'));
  addPending(takeDown('b'));
  removePending(pendingItems()[0].id);
  assert.deepEqual(pendingItems().map((i) => i.correction.modId), ['b']);
  clearPending();
  assert.deepEqual(pendingItems(), []);
  stop();
  addPending(takeDown('c'));
  assert.equal(calls, 4);
});

test('a broken stored list reads as empty', () => {
  stored.set(PENDING_KEY, '{not json');
  assert.deepEqual(pendingItems(), []);
  stored.set(PENDING_KEY, JSON.stringify([{ label: 'no correction' }]));
  assert.deepEqual(pendingItems(), []);
});

test('the save request carries every correction in order', () => {
  addPending(takeDown('a'));
  addPending({ label: 'm', correction: { kind: 'matchRequirement', written: 'Lazy Lib', modId: 'lazylib' } });
  assert.deepEqual(saveRequest(pendingItems(), true), {
    kind: 'saveCorrections',
    corrections: [
      { kind: 'takeDownMod', modId: 'a' },
      { kind: 'matchRequirement', written: 'Lazy Lib', modId: 'lazylib' },
    ],
    publishAfter: true,
  });
});
