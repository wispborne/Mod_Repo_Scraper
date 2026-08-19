// About: where this comes from, how often, what the AI does, and how to get
// something fixed.
//
// A reader — and more to the point, a mod author who finds their mod listed
// here — needs one page that answers all of that plainly.

import {
  breadcrumbs, clear, el, formatDay, modList, PROBLEM_REPORT_BASE,
} from '../lib.js';

export async function render(root) {
  let collectedOn = null;
  try {
    collectedOn = (await modList()).generatedAt;
  } catch {
    collectedOn = null;
  }

  document.title = 'About — Starmodder';
  clear(root);
  root.append(breadcrumbs([{ label: 'About' }]));
  root.append(el('div', { class: 'stack' }, [
    el('div', { class: 'page-head' }, [
      el('h1', { text: 'About Starmodder' }),
      el('span', {
        class: 'sub',
        text: 'What this is, where the data comes from, and how to get '
          + 'something fixed.',
      }),
    ]),

    section('What this is', [
      'Starmodder lists every Starsector mod posted on the Starsector forum, '
        + 'the Unofficial Starsector Discord and Nexus Mods, in one place.',
      'It is read-only. There are no accounts, no comments and no ratings. '
        + 'Nothing you do here is sent anywhere — every page is built in your '
        + 'own browser from a few files on this site.',
    ]),

    section('Where the data comes from', [
      'A program reads the mod threads on the forum, the mod channels on '
        + 'Discord and the Starsector pages on Nexus Mods, and puts the three '
        + 'together. Nothing here is written by us: the names, descriptions, '
        + 'pictures, downloads and changelogs are the authors\' own words and '
        + 'files, and every link goes to where they put them.',
      collectedOn
        ? `It runs twice a day. The data on show was collected ${
          formatDay(collectedOn)}.`
        : 'It runs twice a day.',
    ]),

    section('What "AI" means here', [
      'Where a mod\'s post has no short description in it, a language model is '
        + 'asked to write one sentence from the post. Those, and only those, '
        + 'are marked with an AI badge and shown in a different colour.',
      'Untick "AI summaries" in the bar at the top and they disappear '
        + 'completely — no gap, no placeholder. The choice is kept in your '
        + 'browser and holds between visits.',
      'The same model also picks facts out of a post: the mod version, the '
        + 'changelog, the license, and where the code is kept. Those are '
        + 'copied from the post, not written.',
    ]),

    section('How releases are worked out', [
      'A release means a mod\'s version actually moved forward — not that '
        + 'somebody replied to its thread.',
      'The version is read off the post, and the reading is noisy, so four '
        + 'rules stand between it and the feed. A reading has to hold for two '
        + 'runs before it is believed. A believed version never moves '
        + 'backwards. A version that matches the game\'s own version is thrown '
        + 'out, because the two get confused. And where the thread title names '
        + 'a version, a new version that disagrees with it is dropped.',
      'The first version we ever believe for a mod is never announced as a '
        + 'release, or every mod would be announced at once the day it was '
        + 'first seen.',
    ]),

    section('Something wrong? Want your mod taken down?', [
      'All of this is collected by a machine off other people\'s posts, so '
        + 'some of it will be wrong. Every mod page has a link at the foot for '
        + 'saying so, and it arrives naming the mod.',
      'If you wrote a mod listed here and would rather it was not, say so and '
        + 'it will be taken off. No reason needed.',
    ]),

    el('p', {}, [
      el('a', {
        class: 'btn btn-primary',
        href: PROBLEM_REPORT_BASE,
        target: '_blank',
        rel: 'noopener nofollow',
        text: 'Report a problem',
      }),
    ]),
  ]));
}

function section(title, paragraphs) {
  return el('section', { class: 'panel' }, [
    el('h2', { text: title }),
    ...paragraphs.map((text) => el('p', { class: 'about-line', text })),
  ]);
}
