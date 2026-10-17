// #/discord/<thread id> — one saved Discord thread: the author's opening
// messages as the Discord scrape saved them, and what the LLM read off them.
// Reached from a ModRepo mod that has a Discord link.

import { api, el, clear, breadcrumbs, rawJson } from '../lib.js';
import { fieldList, llmModsBlock, normUrl } from './extraction_views.js';

export async function render(root, parts) {
  clear(root);
  const threadId = parts[0];
  const parent = { label: 'ModRepo', href: '#/modrepo' };

  let body;
  try {
    body = await api(`discord/${encodeURIComponent(threadId)}`);
  } catch (err) {
    root.append(breadcrumbs([parent, { label: `Discord thread ${threadId}` }]));
    root.append(el('div', { class: 'missing error' }, [
      el('h3', { text: 'Nothing saved for this Discord thread.' }),
      el('p', { text: 'A Discord scrape saves the thread, and the next LLM catch-up reads it.' }),
    ]));
    return;
  }

  const thread = body.thread;
  const name = thread?.name || `Discord thread ${threadId}`;
  root.append(breadcrumbs([parent, { label: name }]));
  root.append(el('h1', { text: name }));

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
      for (const image of message.images || []) {
        messages.append(el('a', { href: image.url, target: '_blank', text: image.filename || image.url }));
      }
    }
    page.append(messages);
  } else {
    page.append(el('p', { class: 'loading', text: 'The thread itself is not in discord-posts.json any more; only the LLM answer is left.' }));
  }

  const llm = el('div', { class: 'panel' });
  llm.append(el('h2', { text: 'Mods the LLM found' }));
  if (body.llm) {
    llm.append(fieldList([
      ['Is a mod release', body.llm.isMod ? 'yes' : 'no'],
      ['Prompt version', body.llm.promptVersion],
      ['Model', body.llm.model],
      ['Asked through', body.llm.endpoint],
    ]));
    const ruleUrls = new Set((body.ruleDownloads || []).map((c) => normUrl(c.sourceUrl)));
    llm.append((body.llm.mods || []).length
      ? llmModsBlock(body.llm.mods, ruleUrls)
      : el('p', { class: 'loading', text: 'The LLM found no mods in this thread.' }));
  } else {
    llm.append(el('p', { class: 'loading', text: 'The LLM has not read this thread yet. The next LLM catch-up reads it.' }));
  }
  page.append(llm);

  page.append(rawJson(body, 'Raw thread data (JSON)'));
}
