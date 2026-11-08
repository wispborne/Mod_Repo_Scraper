// The parts of a diff that need no page: plain names for fields, the keys
// that changed inside two values, and which words changed between two texts.
// No DOM here, so Node can test it (test/web/diff_words_test.mjs).

/// Plain names for the catalog's own field names. The Facts tab's fields
/// already arrive in plain words and pass through unchanged.
const FIELD_LABELS = {
  authorsList: 'authors',
  modVersion: 'mod version',
  gameVersionReq: 'game version',
  urls: 'links',
  // The first and last words of a mod's description in a shared post.
  startsWith: 'start',
  endsWith: 'end',
};

/// A field name as the page shows it: "modVersion" becomes "mod version".
export function fieldLabel(field) {
  const name = String(field ?? '');
  if (FIELD_LABELS[name]) return FIELD_LABELS[name];
  if (/\s/.test(name)) return name;
  return name.replace(/([a-z0-9])([A-Z])/g, '$1 $2').toLowerCase();
}

const isPlainObject = (v) => v != null && typeof v === 'object' && !Array.isArray(v);
const same = (a, b) => JSON.stringify(a ?? null) === JSON.stringify(b ?? null);

/// The keys that changed between two maps: [{ name, before, after }], in
/// the order the keys first appear. Keys with the same value are left out.
function changedKeysOf(before, after) {
  const keys = [...new Set([...Object.keys(before), ...Object.keys(after)])];
  return keys
    .filter((k) => !same(before[k], after[k]))
    .map((k) => ({ name: fieldLabel(k), before: before[k], after: after[k] }));
}

/// How an entry in a list of maps is named: its name, area, label or address.
function entryName(entry, index) {
  for (const key of ['name', 'area', 'label', 'version', 'url']) {
    if (typeof entry[key] === 'string' && entry[key]) return entry[key];
  }
  return `#${index + 1}`;
}

/// What changed inside two values, when that is easier to read than both
/// whole values. Returns a list of { name, before, after }, or null when the
/// two whole values should be shown as they are.
///
/// Two maps give the keys that changed. Two lists of maps of the same length
/// are compared entry by entry, each changed key named after its entry
/// ("Mikohime 28 — kind").
export function changedInside(before, after) {
  if (isPlainObject(before) && isPlainObject(after)) {
    const lines = changedKeysOf(before, after);
    return lines.length ? lines : null;
  }
  if (Array.isArray(before) && Array.isArray(after) && before.length === after.length && before.length
      && before.every(isPlainObject) && after.every(isPlainObject)) {
    const lines = [];
    before.forEach((was, i) => {
      const now = after[i];
      const name = entryName(now, i);
      for (const line of changedKeysOf(was, now)) {
        lines.push({ ...line, name: before.length === 1 ? line.name : `${name} — ${line.name}` });
      }
    });
    return lines.length ? lines : null;
  }
  return null;
}

/// Words kept on each side of a change when the text between changes is cut.
const CONTEXT = 6;
/// Above this many word pairs the comparison is skipped as too slow.
const MAX_PAIRS = 250000;

const words = (text) => String(text).match(/\S+\s*/g) || [];

/// Which words changed between two texts, for marking them on the page.
/// Returns { before, after }, each a list of { text, changed } pieces, where
/// a piece with `gap: true` stands for unchanged words that were cut out.
/// Returns null when the texts are too short, too long or too different for
/// marked words to help; the page then shows the two texts whole.
export function wordChanges(before, after) {
  if (typeof before !== 'string' || typeof after !== 'string') return null;
  const a = words(before);
  const b = words(after);
  if (Math.max(a.length, b.length) < 6 || a.length * b.length > MAX_PAIRS) return null;

  // Longest common run of words, compared without their spacing.
  const key = (w) => w.trim();
  const n = a.length;
  const m = b.length;
  const table = Array.from({ length: n + 1 }, () => new Uint16Array(m + 1));
  for (let i = n - 1; i >= 0; i--) {
    for (let j = m - 1; j >= 0; j--) {
      table[i][j] = key(a[i]) === key(b[j])
        ? table[i + 1][j + 1] + 1
        : Math.max(table[i + 1][j], table[i][j + 1]);
    }
  }
  const common = table[0][0];
  // Mostly different texts: marking nearly every word helps nobody.
  if (common < Math.max(n, m) / 3) return null;

  const was = [];
  const now = [];
  let i = 0;
  let j = 0;
  while (i < n || j < m) {
    if (i < n && j < m && key(a[i]) === key(b[j])) {
      was.push({ text: a[i], changed: false });
      now.push({ text: b[j], changed: false });
      i++;
      j++;
    } else if (j < m && (i >= n || table[i][j + 1] >= table[i + 1][j])) {
      now.push({ text: b[j], changed: true });
      j++;
    } else {
      was.push({ text: a[i], changed: true });
      i++;
    }
  }
  return { before: shorten(join(was)), after: shorten(join(now)) };
}

/// Joins neighbouring pieces that are both changed or both unchanged.
function join(pieces) {
  const out = [];
  for (const p of pieces) {
    const last = out[out.length - 1];
    if (last && last.changed === p.changed) last.text += p.text;
    else out.push({ ...p });
  }
  return out;
}

/// Cuts long unchanged stretches down to a few words beside each change.
function shorten(pieces) {
  const out = [];
  pieces.forEach((p, index) => {
    if (p.changed) {
      out.push(p);
      return;
    }
    const w = words(p.text);
    const first = index === 0;
    const last = index === pieces.length - 1;
    const keep = (first || last ? 1 : 2) * CONTEXT;
    if (w.length <= keep + 2) {
      out.push(p);
      return;
    }
    if (!first) out.push({ text: w.slice(0, CONTEXT).join(''), changed: false });
    out.push({ text: '… ', changed: false, gap: true });
    if (!last) out.push({ text: w.slice(-CONTEXT).join(''), changed: false });
  });
  return out;
}
