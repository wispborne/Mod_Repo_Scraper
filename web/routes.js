// The viewer's pages and addresses. No DOM here, so Node can test it
// (test/web/routes_test.mjs).

/// The nav rail, in order.
export const NAV = [
  {
    group: 'Operate',
    items: [
      { id: 'control', label: 'Control', icon: 'gauge' },
      { id: 'runs', label: 'Run history', icon: 'history' },
      { id: 'settings', label: 'Settings', icon: 'settings' },
    ],
  },
  {
    group: 'Correct',
    items: [
      { id: 'takedowns', label: 'Takedowns', icon: 'eye-off' },
      { id: 'author-aliases', label: 'Author aliases', icon: 'users' },
      { id: 'dependency-names', label: 'Dependency names', icon: 'link' },
    ],
  },
  {
    group: 'Investigate',
    items: [
      { id: 'mods', label: 'Mods', icon: 'box' },
      { id: 'posts', label: 'Source posts', icon: 'list' },
      { id: 'changes', label: 'What changed', icon: 'compare' },
      { id: 'explorer', label: 'Catalog explorer', icon: 'merge' },
      { id: 'llm-test', label: 'LLM test report', icon: 'flask' },
      { id: 'files', label: 'Files', icon: 'files' },
    ],
  },
];

export const DEFAULT_PAGE = 'control';

const ALL = NAV.flatMap((g) => g.items);

/// The path part of `#/runs/123?x=1` as ['runs', '123'].
export function hashParts(hash) {
  const path = String(hash || '').replace(/^#\/?/, '').split('?')[0];
  return path ? path.split('/').map(decodePart) : [];
}

/// Decodes one part of an address. A broken `%` escape, as in
/// `#/mods/50%off`, is kept as written instead of throwing.
function decodePart(part) {
  try {
    return decodeURIComponent(part);
  } catch {
    return part;
  }
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

/// Maps an old viewer address, such as `#/topics/123` or `#/bundle/changes`,
/// to its new address so bookmarks still work. Returns null for an address
/// this viewer already uses.
export function movedAddress(hash) {
  const parts = hashParts(hash);
  const query = hashQuery(hash);
  const keep = (...keys) => Object.fromEntries(keys.map((k) => [k, query.get(k)]));
  const [first, second, third] = parts;
  const topicId = (id) => id != null && /^\d+$/.test(id);

  switch (first) {
    case 'home':
      return buildHash(['control']);
    case 'topics':
    case 'bundle':
      if (second === 'changes') return buildHash(['changes'], { tab: 'facts', ...keep('a', 'b', 'q') });
      if (topicId(second)) {
        return buildHash(third === 'history' ? ['posts', 'topic', second, 'history'] : ['posts', 'topic', second]);
      }
      return buildHash(['posts'], keep('q'));
    case 'discord':
      return second ? buildHash(['posts', 'discord', second]) : buildHash(['posts']);
    case 'modrepo':
      return buildHash(['mods'], keep('q'));
    case 'merge':
      if (second === 'changes') return buildHash(['changes'], { tab: 'mods', ...keep('a', 'b', 'q') });
      if (second === 'groups' && third != null) return buildHash(['explorer', 'groups', third], keep('run'));
      if (second === 'removals') return buildHash(['explorer', 'removals'], { kind: third, ...keep('run') });
      return buildHash(['explorer'], keep('run'));
    case 'log':
      return buildHash(['files']);
    case 'requirement-names':
      return buildHash(['dependency-names']);
    default:
      return null;
  }
}

/// The page identified by an address or id, or null. A forum address or
/// topic id opens the topic's source post page. A Discord address or id
/// (too long to be a topic id) opens the thread's page. A run id opens the run.
/// Other text returns null, and the search box shows matching results.
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

  // Run ids are the start time and the job kind: 20261105T230000Z-fetchAndUpdate.
  if (/^\d{8}T\d{6}Z-[A-Za-z]+$/.test(words)) return `#/runs/${words}`;
  return null;
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
  // A run stopped by a server restart.
  if (ended === 'interrupted') return `✗ Interrupted · ${pageName} · ${viewer}`;
  return `${pageName} · ${viewer}`;
}
