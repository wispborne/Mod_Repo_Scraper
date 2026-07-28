// #/llm-test — renders llm-test-output.json as a readable report (2.6).

import { api, el, clear, missingPanel, MissingFile, go, noticeDialog, breadcrumbs, expandAllButton } from '../lib.js';
import * as manager from '../manager.js';

export async function render(root) {
  clear(root);
  root.append(breadcrumbs([{ label: 'LLM test report' }]));
  root.append(el('h1', { text: 'LLM Test Report' }));

  // The LLM test is the one job with no other way in — start it here. It tries
  // the prompt on a few topics and writes a fresh report; nothing else is saved.
  const status = manager.status() || await manager.refresh();
  if (status && status.on) {
    root.append(el('div', { class: 'topic-actions' }, [
      el('button', {
        class: 'btn btn-primary',
        text: 'Run LLM test',
        title: 'Try the LLM prompt on a few topics and write a fresh report.',
        onclick: async () => {
          try {
            const record = await manager.confirmAndSubmit({ kind: 'llmTest' });
            if (record) go(`#/runs/${encodeURIComponent(record.id)}`);
          } catch (err) {
            noticeDialog('The job was not started', err.message);
          }
        },
      }),
      el('span', {
        class: 'selection-hint',
        text: 'The report below refreshes once the job finishes.',
      }),
    ]));
  }

  const data = await api('llm-test');
  if (data instanceof MissingFile) {
    root.append(missingPanel(data));
    return;
  }

  root.append(
    el('div', { class: 'stat-grid' }, [
      stat('Generated at', data.generatedAt || '—'),
      stat('Prompt version', data.promptVersion ?? '—'),
      stat('LLM calls', data.callCount ?? '—'),
      stat('Topics', (data.topics || []).length),
    ])
  );

  const topics = data.topics || [];
  if (!topics.length) {
    root.append(el('p', { class: 'loading', text: 'No topics in the report.' }));
    return;
  }

  // The topics go in a box of their own so the button has something to point
  // at. Only the topic blocks open and close together — the folds inside one
  // (the input sent, the raw answer) are not what "all" means here.
  const list = el('div', {});
  for (const t of topics) {
    list.append(topicBlock(t));
  }
  root.append(el('div', { class: 'toolbar' }, [
    expandAllButton(list, ':scope > details'),
  ]));
  root.append(list);
}

function topicBlock(t) {
  const details = el('details', { class: 'panel', style: 'margin-bottom:10px;' });
  const grounded = t.parsedGrounded || {};
  const mods = grounded.mods || [];
  const dlCount = mods.reduce((n, m) => n + ((m.downloads || []).length), 0);
  details.append(
    el('summary', {}, [
      el('strong', { text: `#${t.topicId} — ${t.title || ''}` }),
      ' ',
      el('span', { class: 'badge badge-secondary', text: `${mods.length} mod${mods.length === 1 ? '' : 's'}` }),
      ' ',
      el('span', { class: 'badge badge-secondary', text: `${dlCount} downloads` }),
      t.dropped ? el('span', { class: 'badge badge-warning', text: 'dropped' }) : null,
    ])
  );
  const body = el('div', {});

  if (t.tokenUsage) {
    body.append(el('p', { class: 'field-value', text: t.tokenUsage }));
  }

  if (mods.length) {
    body.append(el('h3', { text: 'Mods (grounded)' }));
    for (const m of mods) body.append(modBlock(m));
  }
  if (t.rulesVsLlm) {
    body.append(el('h3', { text: 'Rules vs LLM' }));
    body.append(el('pre', { class: 'raw', text: typeof t.rulesVsLlm === 'string' ? t.rulesVsLlm : JSON.stringify(t.rulesVsLlm, null, 2) }));
  }

  body.append(collapsedPre('Input sent to the LLM', t.inputSent));
  body.append(collapsedPre('Raw model answer', t.rawAnswer));

  details.append(body);
  return details;
}

function modBlock(mod) {
  const box = el('div', { style: 'margin:6px 0 12px;' });
  const head = el('div', { style: 'margin-bottom:4px;' }, [
    el('strong', { text: mod.name || '(unnamed mod)' }),
    ' ',
    el('span', { class: 'badge badge-secondary', text: mod.role || 'main' }),
  ]);
  if (mod.requires) head.append(' ', el('span', { class: 'field-value', text: `requires ${mod.requires}` }));
  box.append(head);
  if ((mod.downloads || []).length) box.append(downloadsTable(mod.downloads));
  if (mod.extras && Object.keys(mod.extras).length) {
    box.append(el('pre', { class: 'raw', text: JSON.stringify(mod.extras, null, 2) }));
  }
  return box;
}

function downloadsTable(downloads) {
  const wrap = el('div', { class: 'table-wrapper' });
  const table = el('table');
  table.append(el('thead', {}, el('tr', {}, [
    el('th', { text: 'Kind' }),
    el('th', { text: 'Confidence' }),
    el('th', { text: 'Host' }),
    el('th', { text: 'File name' }),
    el('th', { text: 'URL' }),
  ])));
  const tbody = el('tbody');
  for (const d of downloads) {
    const tr = el('tr', { class: 'dl-row' });
    tr.append(el('td', { text: d.kind || 'direct' }));
    tr.append(el('td', { class: 'conf-' + (d.confidence || ''), text: d.confidence || '—' }));
    tr.append(el('td', { text: d.sourceHost || '—' }));
    tr.append(el('td', { text: d.fileName || '—' }));
    tr.append(el('td', {}, el('a', { href: d.resolvedDirectUrl || d.url, target: '_blank', text: d.label ? `${d.label} — ${d.url}` : (d.url || '') })));
    tbody.append(tr);
  }
  table.append(tbody);
  wrap.append(table);
  return wrap;
}

function collapsedPre(label, text) {
  if (!text) return document.createTextNode('');
  return el('details', {}, [
    el('summary', { text: label }),
    el('pre', { class: 'raw', text }),
  ]);
}

function stat(label, value) {
  return el('div', { class: 'stat-card' }, [
    el('div', { class: 'label', text: label }),
    el('div', { class: 'value', text: String(value) }),
  ]);
}
