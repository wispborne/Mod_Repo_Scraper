// Shared thread, download, and LLM views. Download converters accept resolver
// candidates or published bundle entries and produce the same display shape:
//   { url, directUrl, host, fileName, confidence, requiresManualStep, linkText }

import { api, el, esc, go, MissingFile, noticeDialog } from '../lib.js';
import * as manager from '../manager.js';

// Style scraped bbc_* classes inside the sandboxed post frame.
const FRAME_CSS = `
  * { scrollbar-width: thin; scrollbar-color: rgba(73, 252, 255, 0.3) rgb(24, 26, 30); }
  ::-webkit-scrollbar { width: 12px; height: 12px; }
  ::-webkit-scrollbar-track { background: rgb(24, 26, 30); }
  ::-webkit-scrollbar-thumb { background: rgba(73, 252, 255, 0.28); border-radius: 7px; border: 3px solid rgb(24, 26, 30); }
  ::-webkit-scrollbar-thumb:hover { background: rgba(73, 252, 255, 0.55); }
  body { background: rgb(24, 26, 30); color: rgb(220, 225, 240);
    font-family: 'Segoe UI', system-ui, sans-serif; line-height: 1.5;
    padding: 14px; margin: 0; font-size: 14px; }
  a, a.bbc_link { color: rgb(90, 200, 255); }
  img, img.bbc_img { max-width: 100%; height: auto; }
  table, table.bbc_table { border-collapse: collapse; margin: 8px 0; }
  table.bbc_table td, table.bbc_table th { border: 1px solid rgba(255,255,255,0.15); padding: 4px 8px; }
  .bbc_tt, code, pre { font-family: Consolas, monospace; background: rgba(255,255,255,0.06); padding: 1px 4px; border-radius: 3px; }
  pre { padding: 10px; overflow: auto; }
  blockquote, .quote { border-left: 3px solid rgba(90,200,255,0.5); margin: 8px 0; padding: 4px 12px; background: rgba(255,255,255,0.03); }
  .bbc_spoiler, .spoiler { border: 1px dashed rgba(255,255,255,0.25); padding: 8px; margin: 8px 0; border-radius: 4px; }
  h1,h2,h3 { color: rgb(120, 210, 255); }
`;

/// Jobs for the current topic, independent of the Topics selection. Render only
/// when the manager is on; accepted jobs open Runs.
export function topicActionBar(topicId) {
  const run = async (kind) => {
    try {
      const record = await manager.confirmAndSubmit({
        kind,
        topicIds: [topicId],
        runLlm: true,
      });
      if (record) go('#/runs');
    } catch (err) {
      noticeDialog('Could not start job', err.message);
    }
  };
  return el('div', { class: 'topic-actions' }, [
    el('button', { class: 'btn', text: 'Re-scrape', onclick: () => run('rescrapeTopics') }),
    el('button', { class: 'btn', text: 'Recheck downloads', onclick: () => run('resolveDownloads') }),
    el('button', { class: 'btn', text: 'Re-run LLM', onclick: () => run('extractLlm') }),
  ]);
}

/// The sandbox prevents scripts in scraped HTML from running.
export function postFrame(html) {
  const doc = `<!DOCTYPE html><html><head><meta charset="utf-8"><style>${FRAME_CSS}</style></head><body>${html}</body></html>`;
  const frame = el('iframe', { class: 'post-frame' });
  frame.setAttribute('sandbox', '');
  frame.setAttribute('srcdoc', doc);
  return frame;
}

/// A rule-based download as the topic endpoint serves it.
export function downloadRowFromCandidate(c) {
  return {
    url: c.sourceUrl || '',
    directUrl: c.resolvedUrl || null,
    host: c.sourceHost || '',
    fileName: c.archiveFilename || null,
    confidence: c.confidence || '',
    requiresManualStep: !!c.requiresManualStep,
    linkText: c.linkText || '',
  };
}

/// A rule-based download as the published bundle carries it.
export function downloadRowFromBundle(c) {
  return {
    url: c.originalUrl || '',
    directUrl: c.resolvedDirectUrl || null,
    host: c.sourceHost || '',
    fileName: c.fileName || null,
    confidence: c.confidence || '',
    requiresManualStep: !!c.requiresManualStep,
    linkText: c.linkText || '',
  };
}

export function normUrl(u) {
  return String(u || '').trim().toLowerCase()
    .replace(/^https?:\/\//, '').replace(/\/+$/, '');
}

/// Shortens a URL in the middle, keeping the host and filename visible.
function shortUrl(u, max = 52) {
  const s = String(u || '');
  if (s.length <= max) return s;
  return `${s.slice(0, max - 16)}…${s.slice(-14)}`;
}

/// Displays a shortened URL; the link and tooltip retain the full address.
function urlLink(display, href) {
  return el('a', {
    class: 'url-cell',
    href,
    target: '_blank',
    title: href,
    text: display,
  });
}

/// Shortens cell text and keeps the full value in its title.
function clampCell(text, max = 40) {
  const s = String(text || '');
  if (!s) return '—';
  if (s.length <= max) return s;
  return el('span', { title: s, text: `${s.slice(0, max - 1)}…` });
}

export function fold(label, content) {
  return el('details', { class: 'fold' }, [
    el('summary', { text: label }),
    content,
  ]);
}

export function field(label, value) {
  return el('li', {}, [
    el('span', { class: 'field-label', text: label }),
    el('span', { class: 'field-value', text: String(value) }),
  ]);
}

/// A list of label/value pairs; anything empty is left out. A pair may carry a
/// third item, a node to show instead of plain text.
export function fieldList(rows) {
  const list = el('ul', { class: 'field-list' });
  for (const [label, value, node] of rows) {
    if (node) {
      list.append(el('li', {}, [
        el('span', { class: 'field-label', text: label }),
        el('span', { class: 'field-value' }, [node]),
      ]));
      continue;
    }
    if (value == null || value === '') continue;
    list.append(field(label, value));
  }
  return list;
}

/// The images the scraper found in the post, each with everything saved about
/// what the model saw in it (`captions` is keyed by the picture's address).
export function imageList(images, captions = {}) {
  const list = el('ul', { class: 'field-list' });
  for (const img of images) {
    const value = el('span', { class: 'field-value' }, [
      el('a', { href: img.originalUrl, target: '_blank', text: img.originalUrl }),
    ]);
    const seen = captions[img.originalUrl];
    if (seen) value.append(pictureSeen(seen));
    list.append(el('li', {}, [
      el('span', { class: 'field-label', text: img.alt || 'image' }),
      value,
    ]));
  }
  return list;
}

const FIT_BADGES = {
  good: ['badge-success', 'Good card picture'],
  okay: ['badge-warning', 'Okay card picture'],
  poor: ['badge-error', 'Not a card picture'],
};

/// One saved picture entry: its kind, card fit and description, or why it
/// could not be read, then which model looked, where, when and with which
/// version of the caption prompt.
function pictureSeen(seen) {
  const box = el('div', { class: 'change-note' });
  if (seen.caption) {
    const [fitClass, fitText] = FIT_BADGES[seen.fit] || ['badge-dim', `Fit: ${seen.fit || 'not saved'}`];
    box.append(
      el('span', { class: 'badge badge-llm', text: seen.kind || 'other' }), ' ',
      el('span', { class: `badge ${fitClass}`, text: fitText }), ' ',
      seen.caption,
    );
  } else if (seen.unreadable) {
    box.append(el('span', { class: 'badge badge-error', text: 'unreadable' }), ' ',
      `The model's server could not read it: ${seen.unreadable}`);
  }
  const facts = [];
  if (seen.model) facts.push(seen.model);
  if (seen.endpoint) facts.push(seen.endpoint);
  if (seen.at) facts.push(new Date(seen.at).toLocaleString());
  if (seen.v != null) {
    facts.push(seen.current === false
      ? `caption prompt v${seen.v} (old; it will be looked at again)`
      : `caption prompt v${seen.v}`);
  }
  if (facts.length) box.append(el('div', { class: 'picture-seen-facts', text: facts.join(' · ') }));
  return box;
}

/// Every link in the post, marked as a download, external or internal.
export function linkList(links) {
  const list = el('ul', { class: 'field-list' });
  for (const link of links) {
    list.append(el('li', {}, [
      link.isDownloadable
        ? el('span', { class: 'badge badge-success', text: 'download' })
        : el('span', { class: 'badge badge-dim', text: link.isExternal ? 'external' : 'internal' }),
      el('a', { class: 'field-value', href: link.url, target: '_blank', text: link.text || link.url }),
    ]));
  }
  return list;
}

export function roleBadge(role) {
  const cls = { main: 'badge-primary', addon: 'badge-llm', separate: 'badge-secondary', variant: 'badge-secondary' }[role] || 'badge-dim';
  return el('span', { class: 'badge ' + cls, text: role || 'main' });
}

export function kindBadge(kind) {
  const cls = { direct: 'badge-secondary', mirror: 'badge-dim', trios: 'badge-primary' }[kind] || 'badge-dim';
  return el('span', { class: 'badge ' + cls, text: kind || 'direct' });
}

/// The rule-based downloads, in the plain shape above.
export function assumedTable(rows) {
  if (!rows.length) {
    return el('p', { class: 'loading', text: 'No downloads found by rules.' });
  }
  const wrap = el('div', { class: 'table-wrapper' });
  const table = el('table', { class: 'dl-table' });
  table.append(el('thead', {}, el('tr', {}, [
    el('th', { text: 'Confidence' }),
    el('th', { text: 'Host' }),
    el('th', { text: 'File name' }),
    el('th', { text: 'Extra step required' }),
    el('th', { text: 'Link text' }),
    el('th', { text: 'Source URL' }),
  ])));
  const tbody = el('tbody');
  for (const r of rows) {
    const tr = el('tr');
    tr.append(el('td', { class: 'conf-' + (r.confidence || ''), text: r.confidence || '—' }));
    tr.append(el('td', { text: r.host || '—' }));
    tr.append(el('td', {}, clampCell(r.fileName)));
    tr.append(el('td', { text: r.requiresManualStep ? 'yes' : '' }));
    tr.append(el('td', {}, clampCell(r.linkText)));
    const url = r.url || r.directUrl || '';
    tr.append(el('td', {}, url ? urlLink(shortUrl(url), r.directUrl || r.url) : '—'));
    tbody.append(tr);
  }
  table.append(tbody);
  wrap.append(table);
  return wrap;
}

/// Marks downloads absent from assumedUrls as found only by the LLM.
export function llmModsBlock(mods, assumedUrls) {
  const box = el('div', {});
  for (const mod of mods) box.append(modCard(mod, assumedUrls));
  return box;
}

export function modCard(mod, assumedUrls) {
  const card = el('div', { class: 'llm-mod' });
  const head = el('div', { class: 'llm-mod-head' }, [
    el('span', { class: 'llm-mod-name', text: mod.name || '(unnamed mod)' }),
    ' ',
    roleBadge(mod.role),
  ]);
  if (mod.requires) {
    head.append(' ', el('span', { class: 'field-value', text: `requires ${mod.requires}` }));
  }
  card.append(head);
  // Other names the post uses for the mod; the public site's search matches on them.
  if ((mod.nicknames || []).length) {
    card.append(fieldList([['Also called', mod.nicknames.join(', ')]]));
  }
  if (mod.image) {
    // Stored as `ext:<url>` (same as the thread thumbnail); strip that marker
    // to get a plain URL the browser can load.
    const src = String(mod.image).replace(/^ext:/, '');
    card.append(el('img', { class: 'llm-mod-image', src, alt: mod.name || 'mod image', loading: 'lazy' }));
  }
  card.append(llmDownloadsTable(mod.downloads || [], assumedUrls));
  if (mod.extras) card.append(extrasBlock(mod.extras));
  // Show the LLM's description anchors; the site builder uses these to slice
  // the author's text from a shared thread.
  const anchors = mod.descriptionAnchors;
  if (anchors && anchors.startsWith && anchors.endsWith) {
    card.append(fieldList([
      ['Description starts with', `"${anchors.startsWith}"`],
      ['Description ends with', `"${anchors.endsWith}"`],
    ]));
  }
  return card;
}

export function llmDownloadsTable(downloads, assumedUrls) {
  if (!downloads.length) {
    return el('p', { class: 'loading', text: 'No downloads listed for this mod.' });
  }
  const wrap = el('div', { class: 'table-wrapper' });
  const table = el('table', { class: 'dl-table' });
  table.append(el('thead', {}, el('tr', {}, [
    el('th', { text: 'Kind' }),
    el('th', { text: 'Found by' }),
    el('th', { text: 'Confidence' }),
    el('th', { text: 'Host' }),
    el('th', { text: 'File name' }),
    el('th', { text: 'Extra step required' }),
    el('th', { text: 'URL' }),
  ])));
  const tbody = el('tbody');
  for (const d of downloads) {
    const rulesMissed = !assumedUrls.has(normUrl(d.url));
    const tr = el('tr', { class: 'dl-row' + (rulesMissed ? ' llm' : '') });
    tr.append(el('td', {}, kindBadge(d.kind)));
    tr.append(el('td', {}, rulesMissed
      ? el('span', { class: 'badge badge-llm', text: 'LLM' })
      : el('span', { class: 'badge badge-secondary', text: 'Rules' })));
    tr.append(el('td', { class: 'conf-' + (d.confidence || ''), text: d.confidence || '—' }));
    tr.append(el('td', { text: d.sourceHost || '—' }));
    tr.append(el('td', {}, clampCell(d.fileName)));
    tr.append(el('td', { text: d.requiresManualStep ? 'yes' : '' }));
    const display = d.label ? `${d.label} — ${shortUrl(d.url)}` : shortUrl(d.url);
    tr.append(el('td', {}, d.url ? urlLink(display, d.resolvedDirectUrl || d.url) : '—'));
    tbody.append(tr);
  }
  table.append(tbody);
  wrap.append(table);
  return wrap;
}

export function extrasBlock(extras) {
  const box = el('div', {});

  // Generated plain-English summary (the model's own words), shown first.
  const summary = extras.summary;
  const hasSummary = !!(summary && (summary.sentence || summary.paragraph));
  if (hasSummary) {
    box.append(el('h3', { text: 'LLM summary' }));
    if (summary.sentence) {
      box.append(el('p', { class: 'llm-summary-sentence', text: summary.sentence }));
    }
    if (summary.paragraph) {
      box.append(el('p', { class: 'llm-summary-paragraph', text: summary.paragraph }));
    }
  }

  // Fields copied word-for-word from the post.
  const list = el('ul', { class: 'field-list' });
  if (extras.version) {
    list.append(field('Mod version', extras.version));
  }
  if (extras.license) {
    list.append(field('License', extras.license));
  }
  if (extras.sourceCode) {
    list.append(el('li', {}, [
      el('span', { class: 'field-label', text: 'Source code' }),
      el('span', { class: 'field-value' }, [
        el('a', { href: extras.sourceCode, target: '_blank', text: extras.sourceCode }),
      ]),
    ]));
  }
  // Each save question: the short answer, then the post's own words.
  const saveRow = (label, answer, words) => {
    if (!words) return;
    const short = { yes: 'Yes', no: 'No', depends: 'Depends' }[answer];
    list.append(field(label, short ? `${short} — ${words}` : words));
  };
  saveRow('Adding to a save', extras.canAdd, extras.saveCompatibility);
  // One row per update note, each naming the release it was written for.
  for (const note of extras.updateNotes || []) {
    saveRow(note.version ? `Updating to ${note.version}` : 'Updating',
      note.answer, note.quote);
  }
  saveRow('Removing from a save', extras.canRemove, extras.removalCompatibility);
  if (extras.needs && extras.needs.length) {
    list.append(field('Needs', extras.needs.join(', ')));
  }
  // What the author says about using AI tools: yes or no with their words,
  // then each use as the model sorted it, then the tools the post names.
  const aiUse = extras.aiUse;
  // No aiUse at all means the post was read before the prompt asked, so the
  // row is left out; an aiUse with no answer means it was read and says nothing.
  if (aiUse && aiUse.usesAi == null) {
    list.append(field('AI use', 'Not stated in the post'));
  } else if (aiUse) {
    list.append(field('AI use', `${aiUse.usesAi ? 'Yes' : 'No'} — ${aiUse.quote}`));
    const uses = (aiUse.uses || []).map((use) => {
      const notes = [use.how, use.extent, use.optional ? 'optional' : null].filter(Boolean);
      return notes.length ? `${use.area} (${notes.join(', ')})` : use.area;
    });
    if (uses.length) list.append(field('AI used for', uses.join(' · ')));
    if ((aiUse.tools || []).length) list.append(field('AI tools named', aiUse.tools.join(', ')));
  }
  if (extras.supportLinks && extras.supportLinks.length) {
    const rows = extras.supportLinks.map((s) => el('div', { class: 'support-link' }, [
      el('span', { class: `support-type support-type-${esc(s.type || 'other')}`, text: s.type || 'other' }),
      s.label ? el('span', { class: 'support-label', text: s.label }) : null,
      el('a', { class: 'support-url', href: s.url, target: '_blank', text: s.url }),
    ]));
    list.append(el('li', {}, [
      el('span', { class: 'field-label', text: 'Support links' }),
      el('span', { class: 'field-value' }, [el('div', { class: 'support-links' }, rows)]),
    ]));
  }
  if (list.children.length) {
    box.append(el('h3', { text: 'Extracted details' }));
    box.append(list);
  }

  const changelog = extras.changelog;
  const hasChangelog = !!(changelog && (changelog.link || (changelog.entries && Object.keys(changelog.entries).length)));
  if (hasChangelog) {
    box.append(el('h3', { text: 'Changelog' }));
    if (changelog.link) {
      box.append(el('p', {}, el('a', { href: changelog.link, target: '_blank', text: changelog.link })));
    }
    if (changelog.entries) {
      for (const [ver, text] of Object.entries(changelog.entries)) {
        box.append(el('details', {}, [
          el('summary', { text: ver }),
          el('pre', { class: 'raw', text }),
        ]));
      }
    }
  }

  if (!hasSummary && !list.children.length && !hasChangelog) {
    box.append(el('h3', { text: 'Extracted details' }));
    box.append(el('p', { class: 'loading', text: 'No additional details found.' }));
  }
  return box;
}

// --- Bundle staleness and rebuild action, shared with topic history ---

/// Whether the published bundle reflects this thread's saved data.
///   noBundle — nothing published yet
///   absent   — a bundle exists, but this thread isn't in it
///   stale    — this thread was scraped after the bundle was built
///   current  — the bundle is up to date for this thread
export function bundleStaleness({ index, detail, builtAt, inBundle, hasBundle }) {
  if (!hasBundle) return { state: 'noBundle' };
  if (!inBundle) return { state: 'absent' };
  const builtMs = new Date(builtAt).getTime();
  const scraped = [index.scrapedAt, detail && detail.scrapedAt]
    .filter(Boolean)
    .map((s) => new Date(s).getTime())
    .filter((n) => !Number.isNaN(n));
  const newest = scraped.length ? Math.max(...scraped) : 0;
  if (newest && !Number.isNaN(builtMs) && newest > builtMs) {
    return { state: 'stale', scrapedAt: new Date(newest).toISOString(), builtAt };
  }
  return { state: 'current' };
}

/// Compare saved thread data with the published bundle, if available.
export async function topicStaleness(topicId, index, detail) {
  const [meta, presence] = await Promise.all([
    api('bundle/meta').catch(() => null),
    api('bundle/mods', { q: String(topicId), pageSize: 500 }).catch(() => null),
  ]);
  const inBundle = !!(presence && !(presence instanceof MissingFile)
    && (presence.items || [])
      .some((r) => String((r.index || {}).topicId) === String(topicId)));
  const builtAt = (meta && !(meta instanceof MissingFile) && meta.meta)
    ? meta.meta.generatedAt
    : null;

  return bundleStaleness({
    index: index || {},
    detail,
    builtAt,
    inBundle,
    hasBundle: !!builtAt,
  });
}

/// The "Rebuild mod details" button, wherever unpublished changes are pointed out.
export function rebuildBundleButton() {
  return el('button', {
    class: 'btn btn-primary',
    text: 'Rebuild mod details',
    onclick: async () => {
      try {
        const record = await manager.confirmAndSubmit({ kind: 'rebuildBundle' });
        if (record) go(`#/runs/${encodeURIComponent(record.id)}`);
      } catch (err) {
        noticeDialog('Could not start job', err.message);
      }
    },
  });
}
