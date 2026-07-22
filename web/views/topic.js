// #/topics/<id> — topic inspector: rendered post beside extraction results
// (2.4 + 2.5).

import { api, el, clear, esc, errorPanel, go } from '../lib.js';
import * as manager from '../manager.js';

// Small forum-ish stylesheet for the sandboxed post frame (D8). Styles the
// scraped bbc_* classes so the post reads like the forum, dark background.
const FRAME_CSS = `
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

export async function render(root, parts) {
  const id = parts[0];
  clear(root);
  root.append(el('a', { class: 'back-link', href: '#/topics', text: '‹ Back to topics' }));

  const data = await api(`topics/${encodeURIComponent(id)}`);
  if (data.error) {
    root.append(errorPanel(new Error(data.error)));
    return;
  }

  const index = data.index || {};
  const detail = data.detail;
  const assumed = data.assumedDownloads || [];
  const llm = data.llm;

  root.append(
    el('h1', { text: index.title || (detail && detail.title) || `Topic ${id}` })
  );
  if (index.topicUrl) {
    root.append(
      el('p', {}, el('a', { href: index.topicUrl, target: '_blank', text: 'Open on the forum ↗' }))
    );
  }

  const status = manager.status() || await manager.refresh();
  if (status && status.on) root.append(actionBar(Number(id)));

  const split = el('div', { class: 'split' });
  split.append(buildPostColumn(index, detail));
  split.append(buildExtractionColumn(assumed, llm));
  root.append(split);
}

// The same three per-stage actions as the Topics list, for this one topic. The
// ticked-topics set on the list is left alone — this acts on what you are
// looking at, nothing else.
function actionBar(topicId) {
  const run = async (kind) => {
    try {
      const record = await manager.confirmAndSubmit({
        kind,
        topicIds: [topicId],
        runLlm: true,
      });
      if (record) go('#/runs');
    } catch (err) {
      window.alert(err.message);
    }
  };
  return el('div', { class: 'topic-actions' }, [
    el('button', { class: 'btn', text: 'Re-scrape', onclick: () => run('rescrapeTopics') }),
    el('button', { class: 'btn', text: 'Re-resolve downloads', onclick: () => run('resolveDownloads') }),
    el('button', { class: 'btn', text: 'Re-run LLM', onclick: () => run('extractLlm') }),
  ]);
}

function buildPostColumn(index, detail) {
  const col = el('div', { class: 'panel' });
  col.append(el('h2', { text: 'Post' }));

  col.append(indexFields(index, detail));

  if (detail && detail.contentHtml) {
    const doc = `<!DOCTYPE html><html><head><meta charset="utf-8"><style>${FRAME_CSS}</style></head><body>${detail.contentHtml}</body></html>`;
    const frame = el('iframe', { class: 'post-frame' });
    frame.setAttribute('sandbox', '');
    frame.setAttribute('srcdoc', doc);
    col.append(frame);
  } else {
    col.append(el('p', { class: 'loading', text: 'No post HTML on disk (detail missing or placeholder).' }));
  }

  if (detail && detail.images && detail.images.length) {
    col.append(el('h3', { text: `Images (${detail.images.length})` }));
    const list = el('ul', { class: 'field-list' });
    for (const img of detail.images) {
      list.append(el('li', {}, [
        el('span', { class: 'field-label', text: img.alt || 'image' }),
        el('a', { class: 'field-value', href: img.originalUrl, target: '_blank', text: img.originalUrl }),
      ]));
    }
    col.append(list);
  }

  if (detail && detail.links && detail.links.length) {
    col.append(el('h3', { text: `Links (${detail.links.length})` }));
    const list = el('ul', { class: 'field-list' });
    for (const link of detail.links) {
      list.append(el('li', {}, [
        link.isDownloadable
          ? el('span', { class: 'badge badge-success', text: 'dl' })
          : el('span', { class: 'badge badge-dim', text: link.isExternal ? 'ext' : 'int' }),
        el('a', { class: 'field-value', href: link.url, target: '_blank', text: link.text || link.url }),
      ]));
    }
    col.append(list);
  }

  return col;
}

function indexFields(index, detail) {
  const list = el('ul', { class: 'field-list' });
  const rows = [
    ['Author', index.author || (detail && detail.author)],
    ['Game version', index.gameVersion || (detail && detail.gameVersion)],
    ['Category', index.category],
    ['Replies', index.replies],
    ['Views', index.views],
    ['Created', index.createdDate],
    ['Last post', index.lastPostDate],
    ['Last post by', index.lastPostBy],
    ['WIP', index.isWip ? 'yes' : null],
    ['Placeholder', detail && detail.isPlaceholderDetail ? 'yes' : null],
  ];
  for (const [label, value] of rows) {
    if (value == null || value === '') continue;
    list.append(el('li', {}, [
      el('span', { class: 'field-label', text: label }),
      el('span', { class: 'field-value', text: String(value) }),
    ]));
  }
  return list;
}

function buildExtractionColumn(assumed, llm) {
  const col = el('div', { class: 'panel' });
  col.append(el('h2', { text: 'Extraction' }));

  // A download the LLM lists whose post URL is not in the rule-based
  // assumedDownloads is one the rules missed — set apart in the table.
  const assumedUrls = new Set((assumed || []).map((c) => normUrl(c.sourceUrl)));
  const mods = (llm && llm.mods) || [];

  // The LLM can judge a thread to not be a downloadable mod. When it does, the
  // thread is only still here because its title carries a game-version tag —
  // show that so the reader knows why it was kept.
  if (llm && llm.isMod === false) {
    col.append(
      el('div', { class: 'missing', style: 'text-align:left;padding:12px;margin-bottom:12px;' }, [
        el('strong', { text: 'The LLM did not think this thread is a mod.' }),
        el('div', { class: 'field-value', text: 'It was kept because its title has a game-version tag.' }),
      ])
    );
  }

  if (mods.length) {
    col.append(el('h3', { text: `LLM mods (${mods.length})` }));
    for (const mod of mods) col.append(modCard(mod, assumedUrls));
  } else {
    col.append(
      el('div', { class: 'missing', style: 'text-align:left;padding:12px;margin-bottom:12px;' }, [
        el('strong', { text: 'No LLM extraction for this topic.' }),
        el('div', { class: 'field-value', text: 'Only the rule-based downloads below are available.' }),
      ])
    );
  }

  col.append(el('h3', { text: `Rule-based downloads (${assumed.length})` }));
  col.append(assumedTable(assumed));

  return col;
}

function normUrl(u) {
  return String(u || '').trim().toLowerCase()
    .replace(/^https?:\/\//, '').replace(/\/+$/, '');
}

// One mod: its name, role, any requires, its downloads, and its extras.
function modCard(mod, assumedUrls) {
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

function roleBadge(role) {
  const cls = { main: 'badge-primary', addon: 'badge-llm', separate: 'badge-secondary', variant: 'badge-secondary' }[role] || 'badge-dim';
  return el('span', { class: 'badge ' + cls, text: role || 'main' });
}

function kindBadge(kind) {
  const cls = { direct: 'badge-secondary', mirror: 'badge-dim', trios: 'badge-primary' }[kind] || 'badge-dim';
  return el('span', { class: 'badge ' + cls, text: kind || 'direct' });
}

function llmDownloadsTable(downloads, assumedUrls) {
  if (!downloads.length) {
    return el('p', { class: 'loading', text: 'No downloads.' });
  }
  const wrap = el('div', { class: 'table-wrapper' });
  const table = el('table');
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
    tr.append(el('td', { text: d.fileName || '—' }));
    tr.append(el('td', { text: d.requiresManualStep ? 'yes' : '' }));
    tr.append(el('td', {}, el('a', {
      href: d.resolvedDirectUrl || d.url,
      target: '_blank',
      text: d.label ? `${d.label} — ${d.url}` : d.url,
    })));
    tbody.append(tr);
  }
  table.append(tbody);
  wrap.append(table);
  return wrap;
}

function assumedTable(candidates) {
  if (!candidates.length) {
    return el('p', { class: 'loading', text: 'No rule-based downloads.' });
  }
  const wrap = el('div', { class: 'table-wrapper' });
  const table = el('table');
  table.append(el('thead', {}, el('tr', {}, [
    el('th', { text: 'Confidence' }),
    el('th', { text: 'File name' }),
    el('th', { text: 'Manual?' }),
    el('th', { text: 'Source URL' }),
  ])));
  const tbody = el('tbody');
  for (const c of candidates) {
    const tr = el('tr');
    tr.append(el('td', { class: 'conf-' + (c.confidence || ''), text: c.confidence || '—' }));
    tr.append(el('td', { text: c.archiveFilename || '—' }));
    tr.append(el('td', { text: c.requiresManualStep ? 'yes' : '' }));
    tr.append(el('td', {}, el('a', {
      href: c.resolvedUrl || c.sourceUrl,
      target: '_blank',
      text: c.sourceUrl || c.resolvedUrl || '',
    })));
    tbody.append(tr);
  }
  table.append(tbody);
  wrap.append(table);
  return wrap;
}

function extrasBlock(extras) {
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

function field(label, value) {
  return el('li', {}, [
    el('span', { class: 'field-label', text: label }),
    el('span', { class: 'field-value', text: String(value) }),
  ]);
}
