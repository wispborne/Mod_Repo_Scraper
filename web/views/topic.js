// #/topics/<id> — topic inspector: rendered post beside extraction results
// (2.4 + 2.5).

import { api, el, clear, errorPanel } from '../lib.js';
import * as manager from '../manager.js';
import {
  postFrame, imageList, linkList, fieldList, fold, assumedTable, llmModsBlock,
  downloadRowFromCandidate, normUrl, topicActionBar,
} from './extraction_views.js';

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
  if (status && status.on) root.append(topicActionBar(Number(id)));

  const split = el('div', { class: 'split' });
  split.append(buildPostColumn(index, detail));
  split.append(buildExtractionColumn(assumed, llm));
  root.append(split);
}

function buildPostColumn(index, detail) {
  const col = el('div', { class: 'panel' });
  col.append(el('h2', { text: 'Post' }));

  col.append(fieldList([
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
  ]));

  if (detail && detail.contentHtml) {
    col.append(postFrame(detail.contentHtml));
  } else {
    col.append(el('p', { class: 'loading', text: 'No post HTML on disk (detail missing or placeholder).' }));
  }

  if (detail && detail.images && detail.images.length) {
    col.append(fold(`Images (${detail.images.length})`, imageList(detail.images)));
  }

  if (detail && detail.links && detail.links.length) {
    col.append(fold(`Links (${detail.links.length})`, linkList(detail.links)));
  }

  return col;
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
    col.append(llmModsBlock(mods, assumedUrls));
  } else {
    col.append(
      el('div', { class: 'missing', style: 'text-align:left;padding:12px;margin-bottom:12px;' }, [
        el('strong', { text: 'No LLM extraction for this topic.' }),
        el('div', { class: 'field-value', text: 'Only the rule-based downloads below are available.' }),
      ])
    );
  }

  col.append(el('h3', { text: `Rule-based downloads (${assumed.length})` }));
  col.append(assumedTable(assumed.map(downloadRowFromCandidate)));

  return col;
}
