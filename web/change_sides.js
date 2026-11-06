// Which two saved runs the What changed page compares. No DOM here, so Node
// can test it (test/web/change_sides_test.mjs).
//
// The Mods tab compares catalog snapshots (`/api/merge/runs`) and the Facts
// tab mod details snapshots (`/api/bundle/runs`). Most runs save both under
// the same run id, but not all, so a run picked on one tab may have nothing
// to show on the other.

/// The data on disk right now. It can only be the newer side, and only on the
/// Facts tab: a merge writes nothing until it finishes.
export const WORKING = 'working';

export const TABS = ['mods', 'facts'];

/// The tab named in the address, or the Facts tab.
export function tabFrom(text) {
  return TABS.includes(text) ? text : 'facts';
}

const timeOf = (run) => {
  const t = Date.parse(run && run.savedAt);
  return Number.isNaN(t) ? null : t;
};

/// The run in `runs` saved nearest in time to `at`, before or after; the
/// earlier of two equally near. Null for an empty list. A cron run saves its
/// catalog a minute before its mod details, under a different run id, so the
/// nearest run is usually the other half of the same update.
export function nearestRun(runs, at) {
  if (!runs.length) return null;
  const when = Date.parse(at);
  if (Number.isNaN(when)) return runs[0].id;
  let best = null;
  let bestGap = Infinity;
  for (const r of runs) {
    const t = timeOf(r);
    if (t == null) continue;
    const gap = Math.abs(t - when);
    if (gap < bestGap || (gap === bestGap && t < timeOf(best))) {
      best = r;
      bestGap = gap;
    }
  }
  return (best || runs[0]).id;
}

/// The run saved just before `id` in `runs` (newest first), or null when `id`
/// is the oldest or unknown. For the data on disk, returns the newest run.
export function runBefore(runs, id) {
  if (id === WORKING) return runs.length ? runs[0].id : null;
  const at = runs.findIndex((r) => r.id === id);
  return at >= 0 && at + 1 < runs.length ? runs[at + 1].id : null;
}

/// Selects the older side `a` and newer side `b` for one tab.
///
/// `runs` are that tab's saved runs, newest first. `working` is the data on
/// disk (an object) or null; pass null on the Mods tab. `otherRuns` are the
/// other tab's runs, used to find a replacement for a run this tab has no
/// snapshot of: the run saved nearest in time to it.
///
/// Returns `{ a, b, moved, nothing }`. `nothing` is true when there is not
/// enough to compare. `moved` lists each side that could not be kept:
/// `{ side, from, to, why }`, where `why` is 'otherTab' (that run has no
/// snapshot on this tab), 'gone' (no longer kept), 'working' (the data on
/// disk is not offered on this tab) or 'oldest' (the run picked as the newer
/// side is the oldest kept, so there is no earlier one to compare it with; it
/// is shown as the older side instead).
///
/// An 'otherTab' entry also carries `nearest`, the run saved nearest to
/// `from`. It differs from `to` when that run was already the other side.
/// For 'oldest', `from` is the run picked and `to` the run now on the newer
/// side; `from` is on the older side.
export function settleSides({ runs, working = null, a = '', b = '', otherRuns = [] }) {
  const ids = new Set(runs.map((r) => r.id));
  if (!runs.length || (runs.length < 2 && !working)) {
    return { a: '', b: '', moved: [], nothing: true };
  }
  const moved = [];
  const standIn = (side, id) => {
    const other = otherRuns.find((r) => r.id === id);
    if (other) {
      const nearest = nearestRun(runs, other.savedAt);
      moved.push({ side, from: id, why: 'otherTab', nearest });
      return nearest;
    }
    moved.push({ side, from: id, why: 'gone' });
    return '';
  };

  let newer = b || '';
  // A newer side the reader picked and this tab has: it is only ever moved
  // for being the oldest run kept, which needs a note of its own.
  const pickedNewer = newer && newer !== WORKING && ids.has(newer) ? newer : '';
  if (newer === WORKING && !working) {
    moved.push({ side: 'b', from: WORKING, why: 'working' });
    newer = '';
  } else if (newer && newer !== WORKING && !ids.has(newer)) {
    newer = standIn('b', newer);
  }
  if (!newer) newer = runs.length > 1 || !working ? runs[0].id : WORKING;

  // The data on disk is never the older side.
  let older = a === WORKING ? '' : (a || '');
  if (older && !ids.has(older)) older = standIn('a', older);
  if (!older || older === newer) {
    older = runBefore(runs, newer);
    if (!older) {
      // The newer side is the oldest run kept: compare it with the run after
      // it, or with the data on disk when it is the only run.
      const at = runs.findIndex((r) => r.id === newer);
      older = newer;
      newer = at > 0 ? runs[at - 1].id : WORKING;
      if (pickedNewer && pickedNewer === older) {
        moved.push({ side: 'b', from: pickedNewer, why: 'oldest' });
      }
    }
  }

  for (const m of moved) m.to = m.side === 'a' ? older : newer;
  return { a: older, b: newer, moved, nothing: false };
}

/// The rows to open, from the address's `open` value: keys joined by ";", or
/// "all". Returns a Set, or the string 'all'.
export function openFrom(text) {
  const value = String(text || '').trim();
  if (value === 'all') return 'all';
  return new Set(value.split(';').map((k) => k.trim()).filter(Boolean));
}

/// The address's `open` value for the open rows. Empty when none are open,
/// "all" when every row on the page is.
export function openParam(openKeys, allKeys) {
  const open = [...openKeys].filter(Boolean);
  if (!open.length) return '';
  if (allKeys.length > 1 && allKeys.every((k) => open.includes(k))) return 'all';
  return open.join(';');
}
