// #/discord/<thread id> — one saved Discord thread: the author's opening
// messages as the Discord scrape saved them, and what the LLM read off them.
// Reached from a ModRepo mod that has a Discord link.

import { api, el, clear, breadcrumbs, go, noticeDialog, rawJson } from '../lib.js';
import * as manager from '../manager.js';
import { fieldList, imageList, llmModsBlock, normUrl } from './extraction_views.js';

/// The job button for this thread. Drawn only when the manager is on;
/// an accepted job opens Runs.
function threadActionBar(threadId) {
  const rerun = async () => {
    try {
      const record = await manager.confirmAndSubmit({
        kind: 'extractLlm',
        discordThreadIds: [threadId],
        runLlm: true,
      });
      if (record) go('#/runs');
    } catch (err) {
      noticeDialog('Could not start job', err.message);
    }
  };
  return el('div', { class: 'topic-actions' }, [
    el('button', { class: 'btn', text: 'Re-run LLM', onclick: rerun }),
  ]);
}

export async function render(root, parts) {
  clear(root);
  const threadId = parts[0];
  const parent = { label: 'Mod Catalog', href: '#/modrepo' };

  let body;
  try {
    body = await api(`discord/${encodeURIComponent(threadId)}`);
  } catch (err) {
    root.append(breadcrumbs([parent, { label: `Discord thread ${threadId}` }]));
    root.append(el('div', { class: 'missing error' }, [
      el('h3', { text: 'Could not load this Discord thread.' }),
      el('p', { text: 'If it has not been saved yet, run Fetch and update with Discord selected.' }),
    ]));
    return;
  }

  const thread = body.thread;
  const name = thread?.name || `Discord thread ${threadId}`;
  root.append(breadcrumbs([parent, { label: name }]));
  root.append(el('h1', { text: name }));

  const status = manager.status() || await manager.refresh();
  if (status && status.on && thread) root.append(threadActionBar(threadId));

  const page = el('div', { class: 'stack' });
  root.append(page);

  if (thread) {
    page.append(fieldList([
      ['Thread id', threadId],
      ['Author', thread.author],
      ['Link', thread.url, thread.url ? el('a', { href: thread.url, target: '_blank', text: thread.url }) : null],
      ['Forum link', thread.forumUrl, thread.forumUrl ? el('a', { href: thread.forumUrl, target: '_blank', text: thread.forumUrl }) : null],
    ]));

    const messages = el('div', { class: 'panel' });
    messages.append(el('h2', { text: `The author's opening messages (${(thread.messages || []).length})` }));
    for (const message of thread.messages || []) {
      messages.append(el('h3', { text: (message.timestamp || '').slice(0, 10) || 'Message' }));
      messages.append(el('pre', { class: 'raw', text: message.content || '(no text)' }));
      const images = (message.images || []).map((image) => ({
        originalUrl: image.url, alt: image.description || image.filename,
      }));
      if (images.length) messages.append(imageList(images, body.pictureCaptions || {}));
      // Files attached to the message. Their addresses stop working about a
      // day after the Discord scrape, so an old one may not open.
      const files = message.files || [];
      if (files.length) {
        messages.append(el('ul', {}, files.map((file) => el('li', {}, [
          'Attached file: ',
          el('a', { href: file.url, target: '_blank', rel: 'noopener', text: file.filename || file.url }),
          file.size ? ` (${Math.round(file.size / 1024)} KB)` : '',
        ]))));
      }
    }
    page.append(messages);
  } else {
    page.append(el('p', { class: 'loading', text: 'Only LLM results are available. The saved thread is missing from discord-posts.json.' }));
  }

  const llm = el('div', { class: 'panel' });
  llm.append(el('h2', { text: 'LLM results' }));
  if (body.llm) {
    llm.append(fieldList([
      ['Is a mod release', body.llm.isMod ? 'yes' : 'no'],
      ['Prompt version', body.llm.promptVersion],
      ['Model', body.llm.model],
      ['Endpoint', body.llm.endpoint],
    ]));
    const ruleUrls = new Set((body.ruleDownloads || []).map((c) => normUrl(c.sourceUrl)));
    llm.append((body.llm.mods || []).length
      ? llmModsBlock(body.llm.mods, ruleUrls)
      : el('p', { class: 'loading', text: 'The LLM found no mods in this thread.' }));
  } else {
    llm.append(el('p', { class: 'loading', text: 'No LLM results saved. Run LLM catch-up to extract mod details from this thread.' }));
  }
  page.append(llm);

  page.append(rawJson(body, 'Raw thread data (JSON)'));
}
