// #/bundle — Mod Details: the mod-catalog-details.json browser and the thread page.
//   #/bundle              bundle meta + searchable, paged entries
//   #/bundle/<topicId>    working thread data and a card preview
//   #/bundle/changes      what changed between two saved bundles

import {
  api, el, clear, missingPanel, MissingFile, pager, pageSizePreference, go,
  rawJson, hashQuery, buildHash, replaceHash, breadcrumbs,
} from '../lib.js';
import * as manager from '../manager.js';
import { changesPage } from './bundle_compare.js';
import { render as renderHistory } from './topic_history.js';
import { takeDownThreadButton } from './takedowns.js';
import {
  postFrame, imageList, linkList, fieldList, fold, assumedTable, llmModsBlock,
  downloadRowFromCandidate, normUrl, topicActionBar, topicStaleness,
  rebuildBundleButton,
} from './extraction_views.js';

const state = { q: '', page: 0, pageSize: pageSizePreference() };

export async function render(root, parts) {
  clear(root);

  // The diff page lives in the sidebar as "Details diff".
  if (parts[0] === 'changes') {
    root.append(breadcrumbs([{ label: 'Details diff' }]));
    root.append(el('h1', { text: 'Details diff' }));
    return changesPage(root);
  }
  if (parts[1] === 'history') {
    return renderHistory(root, parts[0], {
      parent: { label: 'Mod Details', href: '#/bundle' },
    });
  }
  if (parts.length) return entry(root, parts[0]);

  root.append(breadcrumbs([{ label: 'Mod Details' }]));
  root.append(el('h1', { text: 'Mod Details' }));
  root.append(el('p', { class: 'run-when', text: 'Saved forum posts, download links, and LLM results. Select a topic to inspect its data.' }));

  // Search and page ride in the URL, so a reload or the back button brings the
  // same list back.
  const query = hashQuery();
  state.q = (query.get('q') || '').trim();
  state.page = Math.max(0, parseInt(query.get('page'), 10) || 0);
  state.pageSize = pageSizePreference();

  const meta = await api('bundle/meta');
  if (meta instanceof MissingFile) return root.append(missingPanel(meta));
  if (meta.meta) {
    const m = meta.meta;
    root.append(el('div', { class: 'stat-grid' }, [
      stat('Updated at', meta.updatedAt || '—'),
      stat('Topics', m.totalMods ?? '—'),
      stat('Topics with post data', m.totalDetails ?? '—'),
      stat('Topics with rule-based downloads', m.totalAssumedDownloadEntries ?? '—'),
      stat('Placeholders', m.placeholderDetailCount ?? '—'),
    ]));
  }

  const toolbar = el('div', { class: 'toolbar' });
  const search = el('input', { type: 'search', placeholder: 'Search title, author or thread id…', value: state.q });
  let d;
  search.addEventListener('input', () => {
    clearTimeout(d);
    d = setTimeout(() => { state.q = search.value.trim(); state.page = 0; load(); }, 250);
  });
  toolbar.append(search);
  root.append(toolbar);
  const results = el('div', {});
  root.append(results);

  function syncUrl() {
    replaceHash(buildHash(['bundle'], { q: state.q, page: state.page || '' }));
  }

  async function load() {
    syncUrl();
    clear(results).append(el('div', { class: 'loading', text: 'Loading…' }));
    const data = await api('bundle/mods', { q: state.q, page: state.page, pageSize: state.pageSize });
    clear(results);
    if (data instanceof MissingFile) return results.append(missingPanel(data));

    const wrap = el('div', { class: 'table-wrapper' });
    const table = el('table');
    table.append(el('thead', {}, el('tr', {}, [
      el('th', { text: 'Title' }), el('th', { text: 'Author' }),
      el('th', { text: 'Game version' }), el('th', { text: 'Post saved' }),
      el('th', { text: 'Rule-based downloads' }),
    ])));
    const tb = el('tbody');
    for (const row of data.items) {
      const idx = row.index || {};
      const dl = (row.assumedDownloads || []).length;
      tb.append(el('tr', { class: 'clickable', onclick: () => go(`#/bundle/${idx.topicId}`) }, [
        el('td', { text: idx.title || '(untitled)' }),
        el('td', { text: idx.author || '' }),
        el('td', { text: idx.gameVersion || '—' }),
        el('td', { text: row.detail ? 'yes' : 'no' }),
        el('td', { class: 'num', text: String(dl) }),
      ]));
    }
    table.append(tb);
    wrap.append(table);
    results.append(wrap);
    if (!data.items.length) results.append(el('p', { class: 'loading', text: 'No topics match your search.' }));
    results.append(pager(data.page, data.pageSize, data.total,
      (p) => { state.page = p; load(); },
      (size) => { state.pageSize = size; state.page = 0; load(); }));
  }
  load();
}

async function entry(root, topicId) {
  return renderThreadPage(root, topicId, {
    parent: { label: 'Mod Details', href: '#/bundle' },
  });
}

// Shared Topics/Bundle thread page using on-disk data, with a rebuild action
// when the published bundle is behind.
export async function renderThreadPage(root, topicId, { parent } = {}) {
  clear(root);
  const up = parent || { label: 'Topics', href: '#/topics' };

  const data = await api(`topics/${encodeURIComponent(topicId)}`);
  if (data instanceof MissingFile) {
    root.append(breadcrumbs([up, { label: `Topic ${topicId}` }]));
    return root.append(missingPanel(data));
  }
  if (!data || data.error) {
    root.append(breadcrumbs([up, { label: `Topic ${topicId}` }]));
    root.append(el('p', {
      class: 'loading',
      text: (data && data.error) || 'No data saved for this thread.',
    }));
    return;
  }

  const title = (data.index && data.index.title) || `Topic ${topicId}`;
  root.append(breadcrumbs([up, { label: title }]));

  const status = manager.status() || await manager.refresh();
  const managerOn = !!(status && status.on);

  renderEntry(root, {
    index: data.index || {},
    detail: data.detail,
    downloads: (data.assumedDownloads || []).map(downloadRowFromCandidate),
    llm: data.llm,
    pictureCaptions: data.pictureCaptions || {},
    discordThreads: data.discordThreads || [],
    raw: data,
    topicId: Number(topicId),
    managerOn,
    staleness: await topicStaleness(topicId, data.index || {}, data.detail),
    // Keep history breadcrumbs under the originating list.
    historyBase: parent && parent.href === '#/bundle' ? 'bundle' : 'topics',
  });
}

/// Warns when saved thread data is absent from or newer than the bundle.
function stalenessBanner(staleness, managerOn) {
  if (!staleness || staleness.state === 'current') return null;

  let heading;
  let detail;
  switch (staleness.state) {
    case 'stale':
      heading = 'Mod details are out of date.';
      detail = `Thread scraped ${stamp(staleness.scrapedAt)}; details built `
        + `${stamp(staleness.builtAt)}. Rebuild mod details to include these changes.`;
      break;
    case 'absent':
      heading = 'This thread is not in the built mod details.';
      detail = 'This page shows locally saved data. Rebuild mod details to update the output files.';
      break;
    default: // noBundle
      heading = 'Mod details have not been built yet.';
      detail = 'This page shows locally saved data. Rebuild mod details to create the output files.';
  }

  const banner = el('div', { class: 'notice-banner' }, [
    el('div', { class: 'notice-text' }, [
      el('strong', { text: heading }),
      el('div', { text: detail }),
    ]),
  ]);
  if (managerOn) banner.append(rebuildBundleButton());
  return banner;
}

// Shared thread layout: extracted data, details, images, the forum post, raw data.
function renderEntry(root, entry) {
  const {
    index: idx, detail, downloads, llm, raw, topicId, managerOn, staleness,
    historyBase, pictureCaptions, discordThreads = [],
  } = entry;
  const mods = (llm && llm.mods) || [];

  const page = el('div', { class: 'thread' });

  page.append(el('h1', { text: idx.title || `Topic ${topicId}` }));

  const controls = el('div', { class: 'thread-controls' });
  if (idx.topicUrl) {
    controls.append(el('a', {
      class: 'btn', href: idx.topicUrl, target: '_blank', text: 'Open on the forum ↗',
    }));
  }
  controls.append(el('a', {
    class: 'btn',
    href: `#/${historyBase || 'topics'}/${encodeURIComponent(topicId)}/history`,
    text: 'History',
    title: 'Every run that changed this thread.',
  }));
  if (managerOn) {
    controls.append(topicActionBar(topicId));
    // Drawn once the catalog says which mods come from this thread.
    takeDownThreadButton(`forum:${topicId}`).then((button) => {
      if (button) controls.append(button);
    }).catch(() => {});
  }
  if (controls.children.length) page.append(controls);

  const banner = stalenessBanner(staleness, managerOn);
  if (banner) page.append(banner);

  page.append(extractedPanel(llm, mods, downloads));
  page.append(detailsPanel(idx, detail));
  page.append(imagesPanel(detail, discordThreads, pictureCaptions));
  page.append(postPanel(detail));
  if (raw) page.append(rawJson(raw, 'Raw thread data (JSON)'));

  root.append(page);
}

// What the LLM and the download rules pulled out of the thread.
function extractedPanel(llm, mods, downloads) {
  const found = el('div', { class: 'panel' });
  found.append(el('h2', { text: 'Extracted data' }));

  // A download the LLM lists whose post URL is not in the rule-based list is
  // one the rules missed — set apart in the table.
  const ruleUrls = new Set(downloads.map((d) => normUrl(d.url)));
  if (mods.length) {
    found.append(el('h3', { text: `Mods found by LLM (${mods.length})` }));
    found.append(llmModsBlock(mods, ruleUrls));
  } else {
    found.append(el('h3', { text: 'Mods found by LLM' }));
    // Distinguish missing results, non-mod classification, and an empty mod list.
    let msg;
    if (!llm) {
      msg = 'No LLM results saved for this thread.';
    } else if (llm.isMod === false) {
      msg = 'The LLM classified this thread as not a downloadable mod.';
    } else {
      msg = 'The LLM returned no mods for this thread.';
    }
    found.append(el('p', { class: 'loading', text: msg }));
  }
  if (llm) found.append(llmSourceLine(llm));

  found.append(el('h3', { text: `Rule-based downloads (${downloads.length})` }));
  found.append(assumedTable(downloads));
  return found;
}

function detailsPanel(idx, detail) {
  const fields = el('div', { class: 'panel' });
  fields.append(el('h2', { text: 'Details' }));
  const cols = el('div', { class: 'field-cols' });

  const thumb = thumbUrl(idx.thumbnailPath);
  const threadCol = el('div', {});
  threadCol.append(el('h3', { text: 'Thread' }));
  threadCol.append(fieldList([
    ['Topic ID', idx.topicId],
    ['Author', idx.author],
    ['Game version', idx.gameVersion],
    ['Category', idx.category],
    ['Replies', idx.replies],
    ['Views', idx.views],
    ['Created', idx.createdDate],
    ['Last post', idx.lastPostDate],
    ['Last post by', idx.lastPostBy],
    ['In mod index', idx.inModIndex == null ? null : (idx.inModIndex ? 'yes' : 'no')],
    ['Archived mod index', idx.isArchivedModIndex ? 'yes' : null],
    ['Mod index lines', (idx.indexLines ?? []).length
      ? idx.indexLines.map((l) => [l.name, l.author ? `by ${l.author}` : null,
          l.gameVersion ? `[${l.gameVersion}]` : null, `in ${l.category}`]
          .filter(Boolean).join(' ')).join('; ')
      : null],
    ['Work in progress', idx.isWip ? 'yes' : null],
    ['Source board', idx.sourceBoard],
    ['Scraped at', stamp(idx.scrapedAt)],
    ['Thumbnail', thumb, thumb
      ? el('a', { href: thumb, target: '_blank', text: thumb }) : null],
  ]));

  const postCol = el('div', {});
  postCol.append(el('h3', { text: 'First post' }));
  if (detail) {
    // Omit shared fields unless the post value differs from the thread.
    const differs = (v, threadValue) => (v && v !== threadValue ? v : null);
    postCol.append(fieldList([
      ['Title', differs(detail.title, idx.title)],
      ['Author', differs(detail.author, idx.author)],
      ['Game version', differs(detail.gameVersion, idx.gameVersion)],
      ['Category', differs(detail.category, idx.category)],
      ['Author title', detail.authorTitle],
      ['Author post count', detail.authorPostCount],
      ['Author avatar', detail.authorAvatarPath],
      ['Posted', detail.postDate],
      ['Last edited', detail.lastEditDate],
      ['Placeholder', detail.isPlaceholderDetail ? 'yes' : null],
      ['Scraped at', stamp(detail.scrapedAt)],
    ]));
  } else {
    postCol.append(el('p', { class: 'loading', text: 'No post saved for this thread.' }));
  }

  cols.append(threadCol, postCol);
  fields.append(cols);
  return fields;
}

// Every picture from the author's posts and the joined Discord threads, one
// group per post.
function imagesPanel(detail, discordThreads, pictureCaptions) {
  const groups = [];
  if (detail && (detail.images || []).length) {
    groups.push([el('h3', { text: `First post (${detail.images.length})` }), detail.images]);
  }
  for (const [i, extra] of (detail?.extraPosts || []).entries()) {
    if ((extra.images || []).length) {
      groups.push([el('h3', { text: `Author’s post ${i + 2} (${extra.images.length})` }), extra.images]);
    }
  }
  for (const thread of discordThreads) {
    const images = (thread.images || []).map((image) => ({
      originalUrl: image.url, alt: image.description || image.filename,
    }));
    groups.push([el('h3', {}, [
      'Discord thread: ',
      el('a', { href: `#/discord/${encodeURIComponent(thread.threadId)}`, text: thread.name }),
      ` (${images.length})`,
    ]), images]);
  }

  const panel = el('div', { class: 'panel' });
  const count = groups.reduce((n, [, images]) => n + images.length, 0);
  panel.append(el('h2', { text: `Images (${count})` }));
  if (!groups.length) {
    panel.append(el('p', { class: 'loading', text: 'No pictures saved for this thread.' }));
  }
  for (const [heading, images] of groups) {
    panel.append(heading);
    panel.append(images.length
      ? imageList(images, pictureCaptions)
      : el('p', { class: 'loading', text: 'No pictures in this thread.' }));
  }
  return panel;
}

// The author's opening run as the forum showed it, with each post's links.
function postPanel(detail) {
  const post = el('div', { class: 'panel' });
  post.append(el('h2', { text: 'Forum post' }));
  if (detail && detail.contentHtml) {
    post.append(postFrame(detail.contentHtml));
  } else {
    post.append(el('p', { class: 'loading', text: 'No post text saved for this thread.' }));
  }
  if (detail && (detail.links || []).length) {
    post.append(fold(`Links (${detail.links.length})`, linkList(detail.links)));
  }

  // Later opening posts contribute downloads and facts, but not the description.
  for (const [i, extra] of (detail?.extraPosts || []).entries()) {
    post.append(el('h3', { text: `Author’s post ${i + 2}` }));
    const when = [extra.postDate, extra.lastEditDate && `last edited ${extra.lastEditDate}`]
      .filter(Boolean).join(' · ');
    if (when) post.append(el('p', { class: 'change-note', text: when }));
    if (extra.contentHtml) post.append(postFrame(extra.contentHtml));
    if ((extra.links || []).length) {
      post.append(fold(`Links (${extra.links.length})`, linkList(extra.links)));
    }
  }
  return post;
}

// Older results may lack model and endpoint metadata.
function llmSourceLine(llm) {
  let text;
  if (llm.model && llm.endpoint) text = `Model: ${llm.model} · Endpoint: ${llm.endpoint}`;
  else if (llm.model) text = `Model: ${llm.model}`;
  else if (llm.endpoint) text = `Endpoint: ${llm.endpoint}`;
  else text = 'Model and endpoint not recorded.';
  return el('p', { class: 'llm-source', text });
}

// Timestamps arrive as ISO strings; drop the noise for reading.
function stamp(value) {
  if (!value) return null;
  return String(value).replace('T', ' ').replace(/(\.\d+)?Z$/, ' UTC');
}

// Turns a stored thumbnail into a URL an <img> can actually load: drops the
// `ext:` marker, then rewrites Imgur page links to their direct-image form.
function thumbUrl(path) {
  return imgurDirect(stripExt(path));
}

function stripExt(path) {
  if (!path) return null;
  return path.startsWith('ext:') ? path.slice(4) : path;
}

// `imgur.com/<id>` (and `.png`/`m.imgur.com` variants) is an HTML page, not the
// image — the file itself lives on `i.imgur.com`. Rewrite those to the direct
// link, adding `.png` when the link has no extension. Album (`/a/…`) and
// gallery (`/gallery/…`) links have no single image, so they pass through.
function imgurDirect(url) {
  if (!url) return url;
  const m = url.match(/^https?:\/\/(?:www\.|m\.)?imgur\.com\/([A-Za-z0-9]+)(\.[A-Za-z0-9]+)?(?:[?#].*)?$/);
  if (!m) return url;
  return `https://i.imgur.com/${m[1]}${m[2] || '.png'}`;
}

function stat(label, value) {
  return el('div', { class: 'stat-card' }, [
    el('div', { class: 'label', text: label }),
    el('div', { class: 'value', text: String(value) }),
  ]);
}
