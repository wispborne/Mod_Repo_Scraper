// The list of pending corrections. Pages add to it instead of starting a job;
// one save sends everything as a single `saveCorrections` job. The list lives
// in this tab's sessionStorage: it survives a reload and is gone when the tab
// closes. It is never stored on the server. No DOM here beyond the event, so
// Node can test it (test/web/pending_test.mjs).
//
// An item is { id, kind, label, correction, key? }. `correction` is one entry
// of the job's `corrections` list; `label` is the one line the list shows.
// `key` is set on dependency name changes: the key the server saves the answer
// under (`requirementKey`), which pages use to find the row a change is for.
// It is never sent to the server.

export const PENDING_KEY = 'viewerPendingChanges';
const EVENT = 'pending-changed';

function storage() {
  try { return globalThis.sessionStorage || null; } catch { return null; }
}

// Keep a copy in memory so the list still works when storage is blocked.
let fallback = [];

export function pendingItems() {
  const s = storage();
  if (!s) return [...fallback];
  try {
    const list = JSON.parse(s.getItem(PENDING_KEY) || '[]');
    return Array.isArray(list) ? list.filter((i) => i && i.correction) : [];
  } catch {
    return [];
  }
}

function write(list) {
  fallback = [...list];
  const s = storage();
  if (s) {
    try { s.setItem(PENDING_KEY, JSON.stringify(list)); } catch { /* storage full or blocked */ }
  }
  if (typeof globalThis.dispatchEvent === 'function' && typeof Event === 'function') {
    globalThis.dispatchEvent(new Event(EVENT));
  }
}

/// Identifies a correction regardless of field order.
export function correctionKey(c) {
  let names = c.names ? [...c.names] : [];
  // A pair of names is the same pair either way round.
  if (c.kind === 'sameAuthor' || c.kind === 'differentAuthors') names.sort();
  // A person's names in any order and any capitals are the same person.
  if (c.kind === 'takeDownAuthor') {
    names = names.map((n) => String(n).trim().toLowerCase()).filter(Boolean).sort();
  }
  return JSON.stringify([c.kind, c.modId ?? null, names, c.entry ?? null, c.written ?? null, !!c.forget]);
}

/// Adds an item. Returns false when the same correction is already pending.
/// Restoring a pending takedown cancels both changes. A dependency name change
/// with a `key` replaces any earlier pending change for the same key.
export function addPending({ kind, label, correction, key }) {
  let list = pendingItems();
  const wanted = correctionKey(correction);
  if (list.some((i) => correctionKey(i.correction) === wanted)) return false;

  if (correction.kind === 'matchRequirement' && key) {
    list = list.filter((i) => !(i.correction.kind === 'matchRequirement' && i.key === key));
  }

  if (correction.kind === 'restore') {
    const entry = correction.entry || '';
    const undone = list.findIndex((i) => (
      (i.correction.kind === 'takeDownMod' && i.correction.modId === entry)
      || (i.correction.kind === 'takeDownAuthor' && `author:${(i.correction.names || [])[0]}` === entry)
    ));
    if (undone >= 0) {
      list.splice(undone, 1);
      write(list);
      return true;
    }
  }

  const id = `p${Date.now().toString(36)}${Math.random().toString(36).slice(2, 7)}`;
  const item = { id, kind: kind || correction.kind, label, correction };
  if (key) item.key = key;
  list.push(item);
  write(list);
  return true;
}

export function removePending(id) {
  write(pendingItems().filter((i) => i.id !== id));
}

export function clearPending() {
  write([]);
}

/// Whether a correction like this one is pending.
export function isPending(correction) {
  const key = correctionKey(correction);
  return pendingItems().some((i) => correctionKey(i.correction) === key);
}

/// Calls `fn` whenever the list changes, in this tab or another. Returns a
/// function that stops the calls.
export function onPendingChange(fn) {
  const onStorage = (e) => { if (!e || e.key === PENDING_KEY || e.key === null) fn(); };
  globalThis.addEventListener(EVENT, fn);
  globalThis.addEventListener('storage', onStorage);
  return () => {
    globalThis.removeEventListener(EVENT, fn);
    globalThis.removeEventListener('storage', onStorage);
  };
}

/// The request one save sends.
export function saveRequest(items, publishAfter) {
  return {
    kind: 'saveCorrections',
    corrections: items.map((i) => i.correction),
    publishAfter: !!publishAfter,
  };
}
