// Pieces shared by the topic inspector (#/topics/<id>) and the bundle detail
// page (#/bundle/<id>): the post frame, the rule-based download table, and the
// LLM's mods with their downloads and extras.
//
// The two pages hold the same facts under different field names — the topic
// endpoint serves the resolver's own `DownloadCandidate`, the bundle serves the
// published `AssumedDownloadCandidate`. So each page hands its rows to
// `downloadRow*` first, and everything below works on one plain shape:
//   { url, directUrl, host, fileName, confidence, requiresManualStep, linkText }

import { el, esc, go, noticeDialog } from '../lib.js';
import * as manager from '../manager.js';

// Small forum-ish stylesheet for the sandboxed post frame. Styles the scraped
// bbc_* classes so the post reads like the forum, dark background.
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

/// The three per-topic jobs, as buttons — re-scrape, re-resolve downloads,
/// re-run LLM — for one topic. Callers only render this when the manager is
/// on. Acts on the topic being looked at; the ticked-topics set on the Topics
/// list is left alone. After a job is accepted, goes to the Runs view.
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
      noticeDialog('The job was not started', err.message);
    }
  };
  return el('div', { class: 'topic-actions' }, [
    el('button', { class: 'btn', text: 'Re-scrape', onclick: () => run('rescrapeTopics') }),
    el('button', { class: 'btn', text: 'Re-resolve downloads', onclick: () => run('resolveDownloads') }),
    el('button', { class: 'btn', text: 'Re-run LLM', onclick: () => run('extractLlm') }),
  ]);
}

/// The post's own HTML, in a sandboxed frame so nothing in it can run.
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

/// A URL short enough to sit in a table cell without stacking one character to a
/// line. Keeps the start and the tail — the filename at the end is usually the
/// part worth seeing — and drops the middle. The full URL still rides along as
/// the link and its hover text.
function shortUrl(u, max = 52) {
  const s = String(u || '');
  if (s.length <= max) return s;
  return `${s.slice(0, max - 16)}…${s.slice(-14)}`;
}

/// A link that shows a shortened URL but opens and hovers the full one.
function urlLink(display, href) {
  return el('a', {
    class: 'url-cell',
    href,
    target: '_blank',
    title: href,
    text: display,
  });
}

/// Any long cell text (link text is often a bare URL), shortened for the cell
/// with the full text kept as hover. Returns a node so the title can ride along.
function clampCell(text, max = 40) {
  const s = String(text || '');
  if (!s) return '—';
  if (s.length <= max) return s;
  return el('span', { title: s, text: `${s.slice(0, max - 1)}…` });
}

/// A closed-by-default section for a long list, so the page stays short.
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

/// The images the scraper found in the post.
export function imageList(images) {
  const list = el('ul', { class: 'field-list' });
  for (const img of images) {
    list.append(el('li', {}, [
      el('span', { class: 'field-label', text: img.alt || 'image' }),
      el('a', { class: 'field-value', href: img.originalUrl, target: '_blank', text: img.originalUrl }),
    ]));
  }
  return list;
}

/// Every link in the post, marked as a download, external or internal.
export function linkList(links) {
  const list = el('ul', { class: 'field-list' });
  for (const link of links) {
    list.append(el('li', {}, [
      link.isDownloadable
        ? el('span', { class: 'badge badge-success', text: 'dl' })
        : el('span', { class: 'badge badge-dim', text: link.isExternal ? 'ext' : 'int' }),
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
    return el('p', { class: 'loading', text: 'No rule-based downloads.' });
  }
  const wrap = el('div', { class: 'table-wrapper' });
  const table = el('table', { class: 'dl-table' });
  table.append(el('thead', {}, el('tr', {}, [
    el('th', { text: 'Confidence' }),
    el('th', { text: 'Host' }),
    el('th', { text: 'File name' }),
    el('th', { text: 'Manual?' }),
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

/// Everything the LLM found for this thread: one card per mod. `assumedUrls` is
/// the set of rule-based source URLs, used to mark the downloads the rules
/// missed; pass an empty set to skip that marking.
export function llmModsBlock(mods, assumedUrls) {
  const box = el('div', {});
  for (const mod of mods) box.append(modCard(mod, assumedUrls));
  return box;
}

/// One mod: its name, role, any requires, its image, downloads and extras.
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
  if (mod.image) {
    // Stored as `ext:<url>` (same as the thread thumbnail); strip that marker
    // to get a plain URL the browser can load.
    const src = String(mod.image).replace(/^ext:/, '');
    card.append(el('img', { class: 'llm-mod-image', src, alt: mod.name || 'mod image', loading: 'lazy' }));
  }
  card.append(llmDownloadsTable(mod.downloads || [], assumedUrls));
  if (mod.extras) card.append(extrasBlock(mod.extras));
  return card;
}

export function llmDownloadsTable(downloads, assumedUrls) {
  if (!downloads.length) {
    return el('p', { class: 'loading', text: 'No downloads.' });
  }
  const wrap = el('div', { class: 'table-wrapper' });
  const table = el('table', { class: 'dl-table' });
  table.append(el('thead', {}, el('tr', {}, [
    el('th', { text: 'Kind' }),
    el('th', { text: 'Found by' }),
    el('th', { text: 'Confidence' }),
    el('th', { text: 'Host' }),
    el('th', { text: 'File name' }),
    el('th', { text: 'Manual?' }),
    el('th', { text: 'URL' }),
  ])));
  const tbody = el('tbody');
  for (const d of downloads) {
    const rulesMissed = !assumedUrls.has(normUrl(d.url));
    const tr = el('tr', { class: 'dl-row' + (rulesMissed ? ' llm' : '') });
    tr.append(el('td', {}, kindBadge(d.kind)));
    tr.append(el('td', {}, rulesMissed
      ? el('span', { class: 'badge badge-llm', text: 'llm' })
      : el('span', { class: 'badge badge-secondary', text: 'rules' })));
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
    box.append(el('h3', { text: 'Summary' }));
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
  if (extras.saveCompatibility) {
    list.append(field('Save compatibility', extras.saveCompatibility));
  }
  if (extras.supportLinks && extras.supportLinks.length) {
    const rows = extras.supportLinks.map((s) => el('div', { class: 'support-link' }, [
      el('span', { class: `support-type support-type-${esc(s.type || 'other')}`, text: s.type || 'other' }),
      el('a', { class: 'support-url', href: s.url, target: '_blank', text: s.url }),
    ]));
    list.append(el('li', {}, [
      el('span', { class: 'field-label', text: 'Support links' }),
      el('span', { class: 'field-value' }, [el('div', { class: 'support-links' }, rows)]),
    ]));
  }
  if (list.children.length) {
    box.append(el('h3', { text: 'LLM extras' }));
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
    box.append(el('h3', { text: 'LLM extras' }));
    box.append(el('p', { class: 'loading', text: 'No extras found.' }));
  }
  return box;
}
