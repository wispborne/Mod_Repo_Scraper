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
  correctionKey, heldBackNameChanges, PENDING_KEY,
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

test('a person taken down twice, in another order or other capitals, is one change', () => {
  assert.equal(addPending({ label: 'x', correction: { kind: 'takeDownAuthor', names: ['Tidal', 'tidal5590'] } }), true);
  assert.equal(addPending({ label: 'y', correction: { kind: 'takeDownAuthor', names: ['TIDAL5590', ' tidal '] } }), false);
  assert.equal(pendingItems().length, 1);
  // The names are sent as they were typed.
  assert.deepEqual(pendingItems()[0].correction.names, ['Tidal', 'tidal5590']);
});

test('a dependency name change keeps its key beside the correction, not inside it', () => {
  addPending({
    label: 'm',
    key: 'lazylib',
    correction: { kind: 'matchRequirement', written: 'Lazy Lib', modId: 'lazylib' },
  });
  const [item] = pendingItems();
  assert.equal(item.key, 'lazylib');
  assert.equal('key' in item.correction, false);
  assert.deepEqual(saveRequest(pendingItems(), false).corrections, [
    { kind: 'matchRequirement', written: 'Lazy Lib', modId: 'lazylib' },
  ]);
});

test('a new dependency name change replaces a pending one for the same key', () => {
  addPending(takeDown('a'));
  addPending({ label: 'one', key: 'lazylib', correction: { kind: 'matchRequirement', written: 'Lazy Lib', modId: 'lazylib' } });
  addPending({ label: 'other', key: 'nex', correction: { kind: 'matchRequirement', written: 'Nex', modId: null } });
  assert.equal(
    addPending({ label: 'two', key: 'lazylib', correction: { kind: 'matchRequirement', written: 'LazyLib v3', modId: null } }),
    true,
  );
  assert.deepEqual(pendingItems().map((i) => i.label), ['Take down "a"', 'other', 'two']);
  // The same change again is not added twice.
  assert.equal(
    addPending({ label: 'two again', key: 'lazylib', correction: { kind: 'matchRequirement', written: 'LazyLib v3', modId: null } }),
    false,
  );
  assert.equal(pendingItems().length, 3);
});

test('a person with a name being taken off offers no choice of published name, and the other way round', () => {
  const remove = (name) => ({ label: `Take "${name}" off its person`, correction: { kind: 'removeAuthorName', names: [name] } });
  const publish = (name) => ({ label: `Publish the person as "${name}"`, correction: { kind: 'publishAuthorAs', names: [name] } });
  const row = ['Alpha', 'beta_7'];

  assert.deepEqual(heldBackNameChanges(row), { publish: false, remove: false });

  addPending(remove('alpha'));
  assert.deepEqual(heldBackNameChanges(row), { publish: true, remove: false });
  // Another person is not affected.
  assert.deepEqual(heldBackNameChanges(['Gamma', 'delta']), { publish: false, remove: false });

  clearPending();
  addPending(publish('beta_7'));
  assert.deepEqual(heldBackNameChanges(row), { publish: false, remove: true });

  // Other kinds of change hold nothing back.
  clearPending();
  addPending({ label: 'same', correction: { kind: 'sameAuthor', names: ['Alpha', 'Gamma'] } });
  assert.deepEqual(heldBackNameChanges(row), { publish: false, remove: false });
});
