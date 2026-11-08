// Post guide: every mod thread posted or edited since the forum's mod post
// guide, and whether its first post follows the guide. The scraper's scheduled
// runs keep it up to date; this page only reads.

import { el, api, infoButton, shortTime } from '../lib.js';
import { icon } from '../icons.js';
import { pageLayout } from '../frame.js';
import { hashQuery, buildHash } from '../routes.js';
import {
  readChange, lastRead, markAllRead, allMarks, setMark, markOf, needsAction, FOLLOW_UP_DAYS,
} from '../post_guide_marks.js';
import { postFrame } from '../post_parts.js';

const PAGE_ID = 'post-guide';

/// The copy every scheduled run publishes. A viewer with no data of its own
/// (a fresh clone of the repo) shows this one instead.
const PUBLISHED_REPORT =
  'https://raw.githubusercontent.com/wispborne/StarsectorModRepo/main/post-guide-report.json';

/// Holds every saved forum post (`details.<topic id>.contentHtml`). The
/// published copy reads a thread's first post from it, since that viewer has
/// no topic data and the forum does not allow being shown inside another
/// page. About 5 MB to download, so it is fetched once, on the first open.
const PUBLISHED_DETAILS =
  'https://raw.githubusercontent.com/wispborne/StarsectorModRepo/main/mod-catalog-details.json';

/// The numbers at the top, one per group. Each one shows only those threads.
const SHOWS = [
  ['failed', 'Failed', 'circle-x'],
  ['imperfect', 'Imperfect', 'alert-triangle'],
  ['follows', 'Following guide', 'circle-check'],
  ['unknown', 'Unknown', 'help-circle'],
];
/// The reader's own numbers, kept in this browser (post_guide_marks.js):
/// threads new or changed since they last marked everything as read, and
/// failing threads nobody has dealt with.
const OWN_SHOWS = [
  ['unread', 'Unread', 'inbox'],
  ['todo', 'To do', 'list-check'],
];
const SHOW_KEYS = new Set([...SHOWS, ...OWN_SHOWS].map(([key]) => key));
const STATUS_LABELS = Object.fromEntries(SHOWS.map(([key, label]) => [key, label]));

/// One toggle button each: a press sets the mark, a second press clears it.
const MARK_CHOICES = [
  ['contacted', 'Contacted author', 'mail'],
  ['ignored', 'Ignore', 'eye-off'],
];

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
  const readAll = el('button', {
    type: 'button',
    class: 'button quiet',
    text: 'Mark all as read',
    onclick: () => {
      if (!data) return;
      markAllRead(data.rows || []);
      draw();
    },
  });
  const listSlot = el('div', { class: 'pl-list' }, [el('p', { class: 'empty', text: 'Loading…' })]);
  const main = el('div', { class: 'list-page pl-page' }, [
    numbers,
    el('div', { class: 'pl-toolbar' }, [
      search,
      readAll,
      infoButton('About these checks', 'Post guide checks', aboutText),
    ]),
    filterBar,
    note,
    listSlot,
  ]);
  content.append(pageLayout(main));

  let data = null;
  // True while showing the published copy rather than this viewer's own data.
  let published = false;

  // Threads whose first post is open under their row, kept while the page is.
  const open = new Set();
  // Each thread's first post HTML (null when there is none), by topic id.
  const posts = new Map();
  let publishedDetails = null;
  const loadPost = (topicId) => {
    if (!posts.has(topicId)) {
      const loading = published
        ? (publishedDetails ??= fetch(PUBLISHED_DETAILS)
          .then((res) => (res.ok ? res.json() : Promise.reject(new Error(`HTTP ${res.status}`))))
          .then((json) => json.details || {}))
          .then((details) => details[String(topicId)]?.contentHtml || null)
        : api(`topics/${encodeURIComponent(topicId)}`).then((body) => body?.detail?.contentHtml || null);
      // A failed download is tried again on the next open.
      posts.set(topicId, loading.catch((err) => {
        posts.delete(topicId);
        if (published) publishedDetails = null;
        throw err;
      }));
    }
    return posts.get(topicId);
  };

  const saveAddress = () => {
    if (!/^#\/post-guide(\?|$)/.test(location.hash)) return;
    history.replaceState(null, '', buildHash([PAGE_ID], {
      show: view.show,
      q: view.q,
      missing: [...view.missing].join(','),
    }));
  };

  // The numbers at the top. Also redrawn alone when a mark changes, so the
  // row the reader just marked stays in the list until the next filter.
  const drawNumbers = () => {
    const rows = data.rows || [];
    const read = lastRead();
    const marks = allMarks();
    const counts = {
      ...(data.counts || {}),
      unread: rows.filter((row) => readChange(row, read).change).length,
      todo: rows.filter((row) => needsAction(row, marks)).length,
    };
    const button = ([key, label, iconName]) => el('button', {
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
    ]);
    numbers.replaceChildren(
      ...OWN_SHOWS.map(button),
      el('span', { class: 'pg-divider', 'aria-hidden': 'true' }),
      ...SHOWS.map(button),
    );
    readAll.title = read ? `Last marked ${shortTime(read.at)}` : '';
  };

  const draw = () => {
    saveAddress();
    if (!data) return;
    const counts = data.counts || {};
    drawNumbers();
    note.replaceChildren([
      published ? 'Published copy' : null,
      `${counts.threads ?? 0} threads`,
      `Since ${data.guideDate}`,
      data.lastPassAt ? `Last checked ${shortTime(data.lastPassAt)}` : 'Not checked',
    ].filter(Boolean).join(' · '));
    drawFilters();

    const words = view.q.toLowerCase();
    const read = lastRead();
    const marks = allMarks();
    const shown = (row) => {
      if (view.show === 'unread') return readChange(row, read).change != null;
      if (view.show === 'todo') return needsAction(row, marks);
      return !view.show || row.status === view.show;
    };
    const rows = (data.rows || []).filter((row) =>
      shown(row)
      && [...view.missing].every((id) => row.missing.some((m) => m.id === id))
      && (!words || `${row.title} ${row.author} ${row.topicId}`.toLowerCase().includes(words)));
    if (!rows.length) {
      listSlot.replaceChildren(el('p', { class: 'empty', text: 'No results' }));
      return;
    }
    listSlot.replaceChildren(table(rows, { published, read, onMark: drawNumbers, open, loadPost }));
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
    el('p', { text: 'Unread shows threads that are new or changed since you last pressed Mark all as read.' }),
    el('p', { text: `To do shows failed threads with no action set. A thread marked Contacted author comes back after ${FOLLOW_UP_DAYS} days if it still has missing items. Any marked thread comes back if another required item goes missing.` }),
    el('p', { text: 'Unread, To do and Action are saved in this browser only.' }),
  ];
}

/// In the published copy the thread's own page here has no data, so the title
/// opens the forum thread instead.
///
/// A click anywhere on a row that is not a link or button opens the thread's
/// first post under it, and a second click shuts it. The arrow in front of
/// the title does the same from the keyboard.
function table(rows, {
  published = false, read = null, onMark = () => {}, open = new Set(), loadPost,
} = {}) {
  const head = el('tr', {}, [
    el('th', { text: 'Thread' }),
    el('th', { text: 'Author' }),
    el('th', { text: 'Missing items' }),
    el('th', { text: 'Action' }),
    el('th', { text: 'Last checked' }),
  ]);
  const body = el('tbody');
  for (const row of rows) {
    const tr = threadRow(row, { published, read, onMark });
    let preview = null;
    const toggle = el('button', { type: 'button', class: 'pg-toggle' });
    const show = (isOpen) => {
      toggle.replaceChildren(icon(isOpen ? 'chevron-down' : 'chevron-right', 16));
      toggle.setAttribute('aria-expanded', String(isOpen));
      toggle.title = isOpen ? 'Hide post' : 'Show post';
      toggle.setAttribute('aria-label', toggle.title);
      tr.classList.toggle('open', isOpen);
      if (isOpen && !preview) {
        preview = postRow(row, loadPost);
        tr.after(preview);
      } else if (!isOpen && preview) {
        preview.remove();
        preview = null;
      }
    };
    const flip = () => {
      const isOpen = !open.has(row.topicId);
      if (isOpen) open.add(row.topicId);
      else open.delete(row.topicId);
      show(isOpen);
    };
    toggle.addEventListener('click', flip);
    tr.addEventListener('click', (event) => {
      if (event.target.closest('a, button, input, select, textarea')) return;
      // Selecting a title to copy it is not a click on the row.
      if (String(globalThis.getSelection?.() || '')) return;
      flip();
    });
    tr.firstChild.prepend(toggle);
    body.append(tr);
    show(open.has(row.topicId));
  }
  return el('div', { class: 'table-wrap' }, [
    el('table', { class: 'table pl-table' }, [el('thead', {}, [head]), body]),
  ]);
}

/// The row under a thread holding its first post, as the scraper saved it.
function postRow(row, loadPost) {
  const cell = el('td', { colspan: '5' }, [el('p', { class: 'pl-dim', text: 'Loading…' })]);
  loadPost(row.topicId).then((html) => {
    cell.replaceChildren(html
      ? postFrame(html)
      : el('p', { class: 'pl-dim', text: 'Post not found' }));
  }, (err) => {
    cell.replaceChildren(el('p', { class: 'error-text', text: err.message }));
  });
  return el('tr', { class: 'pg-preview' }, [cell]);
}

function threadRow(row, { published, read, onMark }) {
  return el('tr', { class: 'pg-row' }, [
    el('td', { class: 'pl-title' }, [...(published
      ? [el('a', { href: row.url, target: '_blank', rel: 'noopener', text: row.title }),
        ' ',
        el('span', { class: 'pg-out', 'aria-hidden': 'true' }, [icon('external-link', 14)])]
      : [el('a', { href: `#/posts/topic/${encodeURIComponent(row.topicId)}`, text: row.title }),
        ' ',
        el('a', {
          href: row.url, target: '_blank', rel: 'noopener', class: 'pg-out',
          title: 'Open thread', 'aria-label': 'Open thread',
        }, [icon('external-link', 14)])]), readTag(row, read)]),
    el('td', { class: 'pl-author', text: row.author || '' }),
    el('td', { class: 'pg-missing-cell' }, missingCell(row)),
    actionCell(row, onMark),
    el('td', { class: 'pl-date mono', title: row.checkedAt || null, text: row.checkedAt ? shortTime(row.checkedAt) : '' }),
  ]);
}

/// "New" for a thread the reader has not seen, "Changed" for one whose
/// status or missing items moved since they last marked everything as read.
function readTag(row, read) {
  const { change, was } = readChange(row, read);
  if (!change) return null;
  return el('span', {
    class: 'tag tag-running pl-tag',
    text: change === 'new' ? 'New' : 'Changed',
    title: was ? `Was: ${STATUS_LABELS[was] || was}` : null,
  });
}

/// What the reader did about a thread. Saved in this browser as soon as it is
/// picked; the cell redraws itself and the numbers, not the list. The buttons
/// always show on a failed or marked thread, and on the others only while the
/// pointer is on the row, so the failed ones stand out.
function actionCell(row, onMark) {
  const cell = el('td', { class: 'pg-action' });
  const fill = () => {
    const mark = markOf(row);
    cell.classList.toggle('pg-on-hover', row.status !== 'failed' && !mark);
    const buttons = el('div', { class: 'pg-mark-buttons' }, MARK_CHOICES.map(([kind, label, iconName]) => {
      const on = mark?.kind === kind;
      return el('button', {
        type: 'button',
        class: `pg-mark-button${on ? ' on' : ''}`,
        title: label,
        'aria-label': label,
        'aria-pressed': String(on),
        onclick: () => {
          setMark(row, on ? null : kind);
          fill();
          onMark();
        },
      }, [icon(iconName, 16)]);
    }));
    cell.replaceChildren(...[buttons, mark ? markNote(mark) : null].filter(Boolean));
  };
  fill();
  return cell;
}

function markNote(mark) {
  if (!mark.due) return el('div', { class: 'pl-dim pg-mark-note', text: shortTime(mark.on) });
  return el('div', {
    class: 'pg-label pg-imperfect pg-mark-note',
    title: mark.due === 'time'
      ? `Not fixed ${FOLLOW_UP_DAYS} days after ${shortTime(mark.on)}`
      : `More is missing since ${shortTime(mark.on)}`,
  }, [icon('clock', 14), 'Follow up']);
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
