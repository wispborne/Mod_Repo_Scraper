// What the reader of the Post guide page has already looked at and dealt
// with. Kept in this browser's localStorage only: nothing is sent to the
// server, so it works on the published copy too. No DOM here, so Node can
// test it (test/web/post_guide_marks_test.mjs).
//
// Two things are kept:
// - what every thread looked like when the reader last pressed "Mark all as
//   read" (READ_KEY). A thread missing from it is new; one whose status or
//   missing items differ has changed.
// - a mark per thread the reader dealt with by hand (MARKS_KEY): `contacted`
//   (the author was told) or `ignored`. Any thread can be marked. A mark
//   covers only the required items missing when it was made. If anything
//   else required goes missing, or a contacted author still has items
//   missing after FOLLOW_UP_DAYS, the thread needs action again.

export const READ_KEY = 'viewerPostGuideRead';
export const MARKS_KEY = 'viewerPostGuideMarks';
export const FOLLOW_UP_DAYS = 7;
const DAY_MS = 24 * 60 * 60 * 1000;

// Copies in memory, so the page still works for the visit when storage is
// blocked.
const memory = new Map();

function storage() {
  try { return globalThis.localStorage || null; } catch { return null; }
}

function readJson(key) {
  const s = storage();
  let text = memory.get(key) ?? null;
  if (s) {
    try { text = s.getItem(key); } catch { /* blocked: use the copy */ }
  }
  if (!text) return null;
  try { return JSON.parse(text); } catch { return null; }
}

function writeJson(key, value) {
  const text = JSON.stringify(value);
  memory.set(key, text);
  const s = storage();
  if (!s) return;
  try { s.setItem(key, text); } catch { /* blocked or full: the copy will do */ }
}

/// One thread as the reader saw it: its status and every missing item.
export function threadState(row) {
  return [row.status, ...(row.missing || []).map((m) => m.id).sort()].join(',');
}

const requiredMissing = (row) => (row.missing || []).filter((m) => m.required).map((m) => m.id);

/// What the reader saw last time they marked everything as read, or null
/// when they never have. `{ at, threads: { <topic id>: <state> } }`.
export function lastRead() {
  const saved = readJson(READ_KEY);
  if (!saved || typeof saved.threads !== 'object' || !saved.threads) return null;
  return saved;
}

/// 'new' when the thread was not there when the reader last marked
/// everything as read (or they never have), 'changed' when its status or
/// missing items differ, null otherwise. `was` is its old status.
export function readChange(row, read = lastRead()) {
  const before = read?.threads?.[String(row.topicId)];
  if (before == null) return { change: 'new', was: null };
  if (before === threadState(row)) return { change: null, was: null };
  return { change: 'changed', was: String(before).split(',')[0] };
}

/// Remembers every thread as it is now. A mark made while a thread had items
/// missing is dropped once it has none: if it misses one again later, it
/// needs a fresh look. A mark on a thread that had nothing missing stays.
export function markAllRead(rows, now = new Date()) {
  writeJson(READ_KEY, {
    at: now.toISOString(),
    threads: Object.fromEntries(rows.map((row) => [String(row.topicId), threadState(row)])),
  });
  const marks = allMarks();
  const fixed = new Set(rows
    .filter((row) => row.status === 'follows' && hadMissing(marks[String(row.topicId)]))
    .map((row) => String(row.topicId)));
  if (!fixed.size) return;
  writeJson(MARKS_KEY, Object.fromEntries(Object.entries(marks).filter(([id]) => !fixed.has(id))));
}

// Marks saved before any thread could be marked were all on failed threads.
const hadMissing = (mark) => mark != null && ['failed', 'imperfect', undefined].includes(mark.status);

/// Every mark, by topic id.
export function allMarks() {
  const saved = readJson(MARKS_KEY);
  return saved && typeof saved === 'object' && !Array.isArray(saved) ? saved : {};
}

/// Marks [row] as `contacted` or `ignored`, or takes its mark off with null.
export function setMark(row, kind, now = new Date()) {
  const marks = allMarks();
  const id = String(row.topicId);
  if (kind === 'contacted' || kind === 'ignored') {
    marks[id] = { kind, on: now.toISOString(), status: row.status, missing: requiredMissing(row) };
  } else {
    delete marks[id];
  }
  writeJson(MARKS_KEY, marks);
}

/// The mark on [row] and whether it still holds. Null when the thread has no
/// mark. `due` is set when it needs action again: `changed` when a required
/// item went missing since the mark, `time` when a contacted author has had
/// FOLLOW_UP_DAYS and the thread still has items missing.
export function markOf(row, marks = allMarks(), now = new Date()) {
  const mark = marks[String(row.topicId)];
  if (!mark || (mark.kind !== 'contacted' && mark.kind !== 'ignored')) return null;
  const covered = new Set(Array.isArray(mark.missing) ? mark.missing : []);
  const on = new Date(mark.on);
  let due = null;
  if (requiredMissing(row).some((id) => !covered.has(id))) due = 'changed';
  else if (mark.kind === 'contacted' && (row.missing || []).length
    && !(now - on < FOLLOW_UP_DAYS * DAY_MS)) due = 'time';
  return { kind: mark.kind, on: mark.on, due };
}

/// True for a failed thread nobody has dealt with, and for any marked thread
/// whose mark no longer holds.
export function needsAction(row, marks = allMarks(), now = new Date()) {
  const mark = markOf(row, marks, now);
  if (mark) return mark.due != null;
  return row.status === 'failed';
}
