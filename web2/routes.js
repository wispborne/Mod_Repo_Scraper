// The new viewer's pages and addresses. No DOM here, so Node can test it
// (test/web2/routes_test.mjs).

/// The nav rail, in order. `old` is the matching page in the old viewer, used
/// by pages that are not built yet; null when the old viewer has none.
export const NAV = [
  {
    group: 'Operate',
    items: [
      { id: 'control', label: 'Control', icon: 'gauge', old: 'runs' },
      { id: 'runs', label: 'Run history', icon: 'history', old: 'runs' },
      { id: 'settings', label: 'Settings', icon: 'settings', old: null },
    ],
  },
  {
    group: 'Correct',
    items: [
      { id: 'takedowns', label: 'Takedowns', icon: 'eye-off', old: 'takedowns' },
      { id: 'author-aliases', label: 'Author aliases', icon: 'users', old: 'author-aliases' },
      { id: 'dependency-names', label: 'Dependency names', icon: 'link', old: 'dependency-names' },
    ],
  },
  {
    group: 'Investigate',
    items: [
      { id: 'mods', label: 'Mods', icon: 'box', old: 'modrepo' },
      { id: 'posts', label: 'Source posts', icon: 'list', old: 'topics' },
      { id: 'changes', label: 'What changed', icon: 'compare', old: 'merge/changes' },
      { id: 'explorer', label: 'Catalog explorer', icon: 'merge', old: 'merge' },
      { id: 'llm-test', label: 'LLM test report', icon: 'flask', old: 'llm-test' },
      { id: 'files', label: 'Files', icon: 'files', old: 'files' },
    ],
  },
];

export const DEFAULT_PAGE = 'control';

const ALL = NAV.flatMap((g) => g.items);

/// The path part of `#/runs/123?x=1` as ['runs', '123'].
export function hashParts(hash) {
  const path = String(hash || '').replace(/^#\/?/, '').split('?')[0];
  return path ? path.split('/').map(decodeURIComponent) : [];
}

/// The query part of `#/runs?page=2` as URLSearchParams.
export function hashQuery(hash) {
  const h = String(hash || '');
  const at = h.indexOf('?');
  return new URLSearchParams(at < 0 ? '' : h.slice(at + 1));
}

/// `#/runs?page=2` from ['runs'] and { page: 2 }. Empty values are left out.
export function buildHash(parts, params = {}) {
  const query = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v == null || v === '') continue;
    query.set(k, String(v));
  }
  const q = query.toString();
  return `#/${parts.map(encodeURIComponent).join('/')}${q ? `?${q}` : ''}`;
}

/// The nav entry a page belongs to. A detail page (`#/runs/<id>`) belongs to
/// the entry its first part names. Null for an address that names no page.
export function navEntryFor(parts) {
  const id = parts.length ? parts[0] : DEFAULT_PAGE;
  return ALL.find((item) => item.id === id) || null;
}

/// Where the old viewer is served, seen from the new viewer's own address.
/// The new viewer at `/v2/` means the old one is at `/`; the new viewer at `/`
/// means the old one is at `/v1/`.
export function oldViewerBase(pathname) {
  return /^\/v2(\/|$)/.test(String(pathname || '')) ? '/' : '/v1/';
}

/// A page of the old viewer, such as `takedowns` or `topics?q=lazy`.
export function oldViewerAddress(pathname, route) {
  return `${oldViewerBase(pathname)}#/${route}`;
}

/// Where a search goes, or null for an empty search. A forum address or
/// topic id opens the topic's source post page, and a Discord address or id
/// (too long to be a topic id) opens the thread's. Those come back as a hash
/// in this viewer (`#/posts/topic/18011`). Other text comes back as a route in
/// the old viewer (`topics?q=…`), which searches the old Topics list.
export function searchRoute(text) {
  const words = String(text || '').trim();
  if (!words) return null;

  const forum = words.match(/fractalsoftworks\.com\/forum\/index\.php\?topic=(\d+)/i);
  if (forum) return `#/posts/topic/${forum[1]}`;

  const discord = words.match(/discord(?:app)?\.com\/channels\/\d+\/(\d+)/i);
  if (discord) return `#/posts/discord/${discord[1]}`;

  if (/^\d+$/.test(words)) {
    // Forum topic ids are short; Discord ids are 17 digits or more.
    return words.length >= 15 ? `#/posts/discord/${words}` : `#/posts/topic/${words}`;
  }
  return `topics?q=${encodeURIComponent(words)}`;
}

/// Job labels shown in the viewer.
export const KIND_LABELS = {
  fetchAndUpdate: 'Fetch and update',
  rebuildFromSaved: 'Rebuild from saved',
  publishOutputs: 'Publish',
  llmCoveragePass: 'Run LLM',
  describePictures: 'Scan images',
  matchRequirements: 'Match dependency names',
  rescrapeTopics: 'Re-scrape topics',
  extractLlm: 'Re-run LLM',
  resolveDownloads: 'Recheck downloads',
  mergeModRepo: 'Merge from saved files',
  scrapeAndMerge: 'Scrape then merge',
  rebuildBundle: 'Rebuild mod details',
  fullRun: 'Full run',
  takeDown: 'Take down',
  restoreTakedown: 'Restore',
  setAuthorAliases: 'Change author aliases',
  setRequirementNames: 'Change dependency names',
  saveCorrections: 'Save corrections',
  llmTest: 'LLM test',
};

export function kindLabel(kind) {
  return KIND_LABELS[kind] || kind || 'Job';
}

/// Whole-number percentage, or null when the total is not known yet.
export function percent(done, total) {
  if (!total) return null;
  return Math.max(0, Math.min(100, Math.floor((done / total) * 100)));
}

/// The browser tab's title. `ended` is the state of a run this page saw end,
/// or null.
export function tabTitle({ pageName, current, ended }) {
  const viewer = 'Mod Repo Viewer';
  if (current) {
    const pct = percent(current.itemsDone, current.itemsTotal);
    const kind = kindLabel(current.record && current.record.request && current.record.request.kind);
    return `▶ ${kind}${pct == null ? '' : ` ${pct}%`} · ${viewer}`;
  }
  if (ended === 'completed') return `✓ Done · ${pageName} · ${viewer}`;
  if (ended === 'failed') return `✗ Failed · ${pageName} · ${viewer}`;
  return `${pageName} · ${viewer}`;
}
