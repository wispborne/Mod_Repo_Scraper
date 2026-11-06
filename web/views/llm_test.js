// LLM test report: llm-test-output.json as a readable report, and the only
// button that starts an LLM test job.

import { el, api } from '../lib.js';
import { pageLayout } from '../frame.js';
import { subscribe, status } from '../status.js';
import { confirmAndStart } from '../actions.js';
import { badge, section, emptyLine, fold, llmModsBlock, normUrl, when } from '../post_parts.js';
import { expandAllButton } from '../diff_parts.js';

/// The sentence the other pages use when jobs are off.
function managerOffText(s) {
  if (s && s.offline) return 'The server could not be reached. The LLM test cannot be started.';
  return `${(s && s.reason) || 'Job management is disabled on this server.'} Start the viewer with a readable `
    + 'config.properties file (or specify it with --config) and omit --no-manager to enable jobs.';
}

export async function render({ content, toolbar, onLeave }) {
  const startNote = el('div');
  const reportSlot = el('div', {}, [emptyLine('Loading…')]);
  const main = el('div', { class: 'pp-page lt-page' }, [startNote, reportSlot]);
  content.append(pageLayout(main));

  // Update the button and its note when the manager turns on or off.
  let on = null;
  onLeave(subscribe((s) => {
    if (!!s.on === on) return;
    on = !!s.on;
    const button = el('button', {
      type: 'button',
      class: 'button primary',
      text: 'Run LLM test',
      title: 'Test the LLM prompt on a few topics and save a report.',
      onclick: async () => {
        const record = await confirmAndStart({ kind: 'llmTest' });
        if (record) location.hash = `#/runs/${encodeURIComponent(record.id)}`;
      },
    });
    toolbar.actions.replaceChildren(...(on ? [button] : []));
    startNote.replaceChildren(el('p', {
      class: 'lt-note dim',
      text: on ? 'Reload after the test finishes to see the report.' : managerOffText(status()),
    }));
  }));

  let data;
  try {
    data = await api('llm-test');
  } catch (err) {
    reportSlot.replaceChildren(el('p', { class: 'error-text', text: err.message }));
    return;
  }
  if (!main.isConnected) return;
  if (data.missing) {
    reportSlot.replaceChildren(el('div', { class: 'pp-missing' }, [
      el('p', { text: `${data.file} is unavailable` }),
      el('p', { class: 'dim', text: data.hint || 'Run the scraper to produce it.' }),
    ]));
    return;
  }

  const topics = data.topics || [];
  const chip = (label, value) => el('span', { class: 'chip' }, [`${label} `, el('b', { text: String(value) })]);
  const head = el('header', { class: 'pp-head' }, [
    el('div', { class: 'pp-meta' }, [
      chip('Generated at', when(data.generatedAt) || '—'),
      chip('Prompt version', data.promptVersion ?? '—'),
      chip('LLM calls', data.callCount ?? '—'),
      chip('Topics', topics.length),
    ]),
  ]);

  // Expand topic blocks together, leaving nested input and answer folds alone.
  const list = el('div', { class: 'lt-topics' }, topics.map(topicBlock));
  const bar = topics.length ? el('div', { class: 'lt-bar' }, [expandAllButton(list, ':scope > details')]) : null;
  reportSlot.replaceChildren(
    head,
    topics.length
      ? section('Topics', topics.length, [bar, list])
      : el('div', { class: 'pp-sections' }, [emptyLine('No topics in the report.')]),
  );
}

/// How many mods and downloads grounding removed, or null when none.
function droppedWords(dropped) {
  if (!dropped || typeof dropped !== 'object') return null;
  const words = [];
  if (dropped.mods) words.push(`${dropped.mods} mod${dropped.mods === 1 ? '' : 's'}`);
  if (dropped.downloads) words.push(`${dropped.downloads} download${dropped.downloads === 1 ? '' : 's'}`);
  return words.length ? `Dropped ${words.join(' and ')}` : null;
}

function topicBlock(t) {
  const grounded = t.parsedGrounded || {};
  const mods = grounded.mods || [];
  const dlCount = mods.reduce((n, m) => n + ((m.downloads || []).length), 0);
  const dropped = droppedWords(t.dropped);
  const notMod = t.isMod === false || t.isMod === 'false';
  const rules = t.rulesVsLlm;
  const ruleUrls = new Set(((rules && rules.ruleLinks) || []).map(normUrl));

  const body = el('div', { class: 'lt-topic-body' });
  body.append(el('p', { class: 'dim' }, [
    el('a', { href: `#/posts/topic/${encodeURIComponent(t.topicId)}`, text: `Source post page for topic ${t.topicId}` }),
  ]));
  // A call that failed, or an answer that could not be read, has no mods to
  // show; the error says why.
  if (t.error) body.append(el('p', { class: 'error-text', text: `The LLM call failed: ${t.error}` }));
  if (t.tokenUsage) body.append(el('p', { class: 'mono dim', text: t.tokenUsage }));
  if (mods.length) {
    body.append(el('h4', { class: 'pp-subhead', text: 'Mods (grounded)' }));
    body.append(llmModsBlock(mods, ruleUrls));
  }
  if (rules) {
    body.append(fold('Rules vs LLM', el('pre', {
      class: 'pp-pre',
      text: typeof rules === 'string' ? rules : JSON.stringify(rules, null, 2),
    })));
  }
  if (t.inputSent) body.append(fold('Input sent to the LLM', el('pre', { class: 'pp-pre', text: t.inputSent })));
  if (t.rawAnswer) body.append(fold('Raw model answer', el('pre', { class: 'pp-pre', text: t.rawAnswer })));

  return el('details', { class: 'lt-topic' }, [
    el('summary', {}, [
      el('span', { class: 'mono', text: `#${t.topicId}` }),
      el('span', { class: 'lt-title', text: t.title || '' }),
      t.error ? badge('Failed', 'bad') : null,
      t.error ? null : badge(`${mods.length} mod${mods.length === 1 ? '' : 's'}`),
      t.error ? null : badge(`${dlCount} download${dlCount === 1 ? '' : 's'}`),
      notMod ? badge('Not a mod', 'warn') : null,
      dropped ? badge(dropped, 'warn') : null,
    ]),
    body,
  ]);
}
