// Post guide: every mod thread posted or edited since the forum's mod post
// guide, and whether its first post follows the guide. The scraper's scheduled
// runs keep it up to date; this page only reads.

import { el, api, infoButton, shortTime } from '../lib.js';
import { icon } from '../icons.js';
import { pageLayout } from '../frame.js';
import { hashQuery, buildHash } from '../routes.js';

const PAGE_ID = 'post-guide';

/// The copy every scheduled run publishes. A viewer with no data of its own
/// (a fresh clone of the repo) shows this one instead.
const PUBLISHED_REPORT =
  'https://raw.githubusercontent.com/wispborne/StarsectorModRepo/main/post-guide-report.json';

/// The numbers at the top, one per group. Each one shows only those threads.
const SHOWS = [
  ['failed', 'Failed', 'circle-x'],
  ['imperfect', 'Imperfect', 'alert-triangle'],
  ['follows', 'Following guide', 'circle-check'],
  ['unknown', 'Unknown', 'help-circle'],
];
const SHOW_KEYS = new Set(SHOWS.map(([key]) => key));

export async function render({ content, onLeave }) {
  const query = hashQuery(location.hash);
  const view = {
    show: SHOW_KEYS.has(query.get('show')) ? query.get('show') : null,
    q: query.get('q') || '',
    // Guide items the shown threads must all be missing, by id.
    missing: new Set((query.get('missing') || '').split(',').filter(Boolean)),
  };

  const numbers = el('div', { class: 'pl-numbers' });
  const note = el('p', { class: 'pg-note dim' });
  const filterBar = el('div', { class: 'pl-filters pg-filters', role: 'group', 'aria-label': 'Filters' });
  const search = el('input', {
    type: 'search',
    class: 'input pl-search',
    placeholder: 'Search by title or author…',
    'aria-label': 'Search by title or author',
    autocomplete: 'off',
    spellcheck: 'false',
    value: view.q,
  });
  const listSlot = el('div', { class: 'pl-list' }, [el('p', { class: 'empty', text: 'Loading…' })]);
  const main = el('div', { class: 'list-page pl-page' }, [
    numbers,
    el('div', { class: 'pl-toolbar' }, [search, infoButton('About these checks', 'Post guide checks', aboutText)]),
    filterBar,
    note,
    listSlot,
  ]);
  content.append(pageLayout(main));

  let data = null;
  // True while showing the published copy rather than this viewer's own data.
  let published = false;

  const saveAddress = () => {
    if (!/^#\/post-guide(\?|$)/.test(location.hash)) return;
    history.replaceState(null, '', buildHash([PAGE_ID], {
      show: view.show,
      q: view.q,
      missing: [...view.missing].join(','),
    }));
  };

  const draw = () => {
    saveAddress();
    if (!data) return;
    const counts = data.counts || {};
    numbers.replaceChildren(...SHOWS.map(([key, label, iconName]) => el('button', {
      type: 'button',
      class: `pl-number${view.show === key ? ' on' : ''}${counts[key] ? '' : ' zero'}`,
      'aria-pressed': String(view.show === key),
      onclick: () => {
        view.show = view.show === key ? null : key;
        draw();
      },
    }, [
      el('span', { class: 'pl-number-count', text: String(counts[key] ?? 0) }),
      el('span', { class: `pl-number-label pg-label pg-${key}` }, [icon(iconName, 14), label]),
    ])));
    note.replaceChildren([
      published ? 'Published copy' : null,
      `${counts.threads ?? 0} threads`,
      `Since ${data.guideDate}`,
      data.lastPassAt ? `Last checked ${shortTime(data.lastPassAt)}` : 'Not checked',
    ].filter(Boolean).join(' · '));
    drawFilters();

    const words = view.q.toLowerCase();
    const rows = (data.rows || []).filter((row) =>
      (!view.show || row.status === view.show)
      && [...view.missing].every((id) => row.missing.some((m) => m.id === id))
      && (!words || `${row.title} ${row.author} ${row.topicId}`.toLowerCase().includes(words)));
    if (!rows.length) {
      listSlot.replaceChildren(el('p', { class: 'empty', text: 'No results' }));
      return;
    }
    listSlot.replaceChildren(table(rows, { published }));
  };

  // One toggle per guide item, worded like the rows' missing items.
  const drawFilters = () => {
    const items = data.items || [];
    filterBar.replaceChildren(...items.map((item) => {
      const on = view.missing.has(item.id);
      return el('button', {
        type: 'button',
        class: `pl-filter pg-filter ${item.required ? 'pg-failed' : 'pg-imperfect'}${on ? ' on' : ''}`,
        'aria-pressed': String(on),
        title: item.required ? 'Required' : 'Recommended',
        onclick: () => {
          if (on) view.missing.delete(item.id);
          else view.missing.add(item.id);
          draw();
        },
      }, [icon(item.required ? 'circle-x' : 'alert-triangle', 14), item.reason]);
    }));
    if (view.missing.size) {
      filterBar.append(el('button', {
        type: 'button',
        class: 'link-button pl-clear',
        text: 'Clear filters',
        onclick: () => {
          view.missing = new Set();
          draw();
        },
      }));
    }
  };

  let debounce;
  search.addEventListener('input', () => {
    clearTimeout(debounce);
    debounce = setTimeout(() => {
      view.q = search.value.trim();
      draw();
    }, 150);
  });
  onLeave(() => clearTimeout(debounce));

  try {
    data = await api('post-guide');
  } catch (err) {
    listSlot.replaceChildren(el('p', { class: 'error-text', text: err.message }));
    return;
  }
  if (!main.isConnected) return;
  if (data.missing) {
    // No checks saved here: show the published copy instead.
    const hint = data.hint || '';
    data = null;
    try {
      const res = await fetch(PUBLISHED_REPORT, { cache: 'no-cache' });
      if (res.ok) {
        data = await res.json();
        published = true;
      }
    } catch {
      // Offline, or the copy is not there: say so below.
    }
    if (!main.isConnected) return;
    if (!data) {
      listSlot.replaceChildren(el('div', { class: 'pp-missing' }, [
        el('p', { text: 'No posts checked' }),
        el('p', { class: 'dim', text: hint }),
      ]));
      return;
    }
  }
  draw();
}

function aboutText() {
  return [
    el('p', {}, [
      'Checks compare each thread’s first post with the forum’s ',
      el('a', { href: 'https://fractalsoftworks.com/forum/index.php?topic=36046.0', target: '_blank', rel: 'noopener', text: 'mod post guide' }),
      ' and its ',
      el('a', { href: 'https://fractalsoftworks.com/forum/index.php?topic=36265.0', target: '_blank', rel: 'noopener', text: 'rules for posting a new mod' }),
      '. Only threads posted or edited since the guide was published are included.',
    ]),
    el('p', { text: 'Checks run when the LLM is enabled. Code checks the game version in the title and the pictures. The LLM checks the remaining items. Posts are checked again only after an edit.' }),
  ];
}

/// In the published copy the thread's own page here has no data, so the title
/// opens the forum thread instead.
function table(rows, { published = false } = {}) {
  const head = el('tr', {}, [
    el('th', { text: 'Thread' }),
    el('th', { text: 'Author' }),
    el('th', { text: 'Missing items' }),
    el('th', { text: 'Last checked' }),
  ]);
  const body = rows.map((row) => el('tr', {}, [
    el('td', { class: 'pl-title' }, published
      ? [el('a', { href: row.url, target: '_blank', rel: 'noopener', text: row.title }),
        ' ',
        el('span', { class: 'pg-out', 'aria-hidden': 'true' }, [icon('external-link', 14)])]
      : [el('a', { href: `#/posts/topic/${encodeURIComponent(row.topicId)}`, text: row.title }),
        ' ',
        el('a', {
          href: row.url, target: '_blank', rel: 'noopener', class: 'pg-out',
          title: 'Open thread', 'aria-label': 'Open thread',
        }, [icon('external-link', 14)])]),
    el('td', { class: 'pl-author', text: row.author || '' }),
    el('td', {}, missingCell(row)),
    el('td', { class: 'pl-date mono', title: row.checkedAt || null, text: row.checkedAt ? shortTime(row.checkedAt) : '' }),
  ]));
  return el('div', { class: 'table-wrap' }, [
    el('table', { class: 'table pl-table' }, [el('thead', {}, [head]), el('tbody', {}, body)]),
  ]);
}

/// A missing required item has the Failed group's icon, a missing
/// recommendation the Imperfect group's.
function missingCell(row) {
  if (row.status === 'unknown') return [el('span', { class: 'pl-dim', text: 'Unknown' })];
  if (!row.missing.length) {
    return [el('span', { class: 'pg-label pg-follows pg-inline' }, [icon('circle-check', 14), 'Following guide']),
      row.unanswered ? el('span', { class: 'pl-dim', text: ` (${row.unanswered} unknown)` }) : null];
  }
  return [el('ul', { class: 'pg-missing' }, row.missing.map((m) => el('li', {
    class: `pg-label ${m.required ? 'pg-failed' : 'pg-imperfect'}`,
    title: m.required ? 'Required' : 'Recommended',
  }, [icon(m.required ? 'circle-x' : 'alert-triangle', 14), m.reason])))];
}
