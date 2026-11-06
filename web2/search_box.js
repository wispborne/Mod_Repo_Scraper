// The search box in the toolbar, and the matches shown under it as you type.
//
// It follows the combobox pattern: the box is a combobox, the matches are a
// listbox of options grouped by kind, and the highlighted option is named by
// aria-activedescendant, so focus never leaves the box. Each option is a
// real link, so a click, a middle-click or "open in new tab" all work.

import { el, clear, api, shortTime } from './lib.js';
import { icon } from './icons.js';
import { MIN_SEARCH, resultGroups, pickable, stepActive, enterTarget, resultsSentence } from './search_results.js';
import { searchRoute } from './routes.js';

const WAIT_MS = 150;
const PER_KIND = 5;

let boxes = 0;

/// Builds the search form. Returns `{ form, input }`; the caller puts the
/// form in the toolbar and focuses `input` for "/".
export function searchBox() {
  const base = `search-${++boxes}`;
  const listId = `${base}-results`;

  const input = el('input', {
    type: 'search',
    class: 'search-input',
    placeholder: 'Search…',
    title: 'A name, an author, an id, or a forum or Discord address',
    'aria-label': 'Search',
    autocomplete: 'off',
    spellcheck: 'false',
    role: 'combobox',
    'aria-autocomplete': 'list',
    'aria-expanded': 'false',
    'aria-controls': listId,
  });
  const panel = el('div', { class: 'search-panel', id: listId, role: 'listbox', 'aria-label': 'Search results' });
  panel.hidden = true;
  // Announce the result count without moving focus.
  const said = el('div', { class: 'search-said', role: 'status', 'aria-live': 'polite' });
  const form = el('form', { class: 'search', role: 'search' }, [
    icon('search', 14),
    input,
    el('kbd', { class: 'search-key', text: '/', title: 'Press / to search', 'aria-hidden': 'true' }),
    panel,
    said,
  ]);

  let items = [];       // every option, in arrow-key order
  let options = [];     // their elements
  let active = -1;      // the highlighted option, or -1
  let shownFor = null;  // the search text for the displayed results
  let asked = 0;        // request number used to ignore older responses
  let timer = null;
  let pending = null;   // { text, promise } for the pending request

  const isOpen = () => !panel.hidden;

  const open = () => {
    if (isOpen()) return;
    panel.hidden = false;
    input.setAttribute('aria-expanded', 'true');
  };

  const close = () => {
    panel.hidden = true;
    input.setAttribute('aria-expanded', 'false');
    highlight(-1);
  };

  function highlight(index, { scroll = true } = {}) {
    if (options[active]) options[active].setAttribute('aria-selected', 'false');
    active = index;
    const option = options[active];
    if (!option) {
      input.removeAttribute('aria-activedescendant');
      return;
    }
    option.setAttribute('aria-selected', 'true');
    input.setAttribute('aria-activedescendant', option.id);
    if (scroll) option.scrollIntoView({ block: 'nearest' });
  }

  function optionFor(item, index) {
    const id = `${base}-option-${index}`;
    const parts = item.isMore
      ? [el('span', { class: 'search-more-label', text: item.label })]
      : [
          el('span', { class: 'search-row-top' }, [
            el('span', { class: 'search-label', text: item.label }),
            item.time ? el('span', { class: 'search-time', text: shortTime(item.time) }) : null,
          ]),
          item.sub ? el('span', { class: 'search-sub', text: item.sub }) : null,
          item.detail ? el('span', { class: 'search-detail', text: item.detail }) : null,
        ];
    const option = el('a', {
      id,
      href: item.href,
      class: item.isMore ? 'search-option search-more' : 'search-option',
      role: 'option',
      tabindex: '-1',
      'aria-selected': 'false',
    }, parts);
    option.addEventListener('mousemove', () => {
      if (active !== index) highlight(index, { scroll: false });
    });
    option.addEventListener('click', (e) => {
      // Let the browser handle new tabs and new windows.
      if (e.button !== 0 || e.ctrlKey || e.metaKey || e.shiftKey || e.altKey) return;
      e.preventDefault();
      goTo(item.href);
    });
    return option;
  }

  function draw(groups) {
    clear(panel);
    items = pickable(groups);
    options = [];
    active = -1;
    input.removeAttribute('aria-activedescendant');
    if (!groups.length) {
      panel.append(el('div', { class: 'search-empty', role: 'presentation', text: 'No results' }));
      return;
    }
    let index = 0;
    for (const group of groups) {
      const headingId = `${base}-${group.key}`;
      const box = el('div', { class: 'search-group', role: 'group', 'aria-labelledby': headingId }, [
        el('div', { class: 'search-heading', id: headingId, role: 'presentation', text: group.heading }),
      ]);
      const count = group.rows.length + (group.more ? 1 : 0);
      for (let i = 0; i < count; i += 1) {
        const option = optionFor(items[index], index);
        options.push(option);
        box.append(option);
        index += 1;
      }
      panel.append(box);
    }
  }

  function showError(message) {
    clear(panel);
    items = [];
    options = [];
    active = -1;
    panel.append(el('div', { class: 'search-empty failed-text', role: 'presentation', text: message }));
    said.textContent = message;
  }

  /// Searches for `text` immediately. Resolves when results are displayed
  /// or ignored because a newer search has started.
  function ask(text) {
    clearTimeout(timer);
    timer = null;
    if (pending && pending.text === text) return pending.promise;
    const mine = ++asked;
    const promise = api('search', { q: text, limit: PER_KIND })
      .then((answer) => {
        if (mine !== asked) return;
        const groups = resultGroups(answer);
        shownFor = text;
        draw(groups);
        said.textContent = resultsSentence(groups);
        if (document.activeElement === input) open();
      })
      .catch((err) => {
        if (mine !== asked) return;
        shownFor = null;
        showError(err.message);
        if (document.activeElement === input) open();
      })
      .finally(() => {
        if (pending && pending.promise === promise) pending = null;
      });
    pending = { text, promise };
    return promise;
  }

  function goTo(href) {
    close();
    input.blur();
    if (location.hash !== href) location.hash = href;
  }

  /// Enter opens the highlighted option. If none is highlighted, it tries
  /// an address or id, then the first match, waiting for results if needed.
  async function enter() {
    const text = input.value.trim();
    if (active >= 0 && items[active]) return goTo(items[active].href);
    const named = searchRoute(text);
    if (named) return goTo(named);
    if (text.length < MIN_SEARCH) return;
    if (shownFor !== text) await ask(text);
    // Ignore results if the search text changed while waiting.
    if (input.value.trim() !== text || shownFor !== text) return;
    const target = enterTarget(text, items, -1);
    if (target) goTo(target);
  }

  input.addEventListener('input', () => {
    clearTimeout(timer);
    // New text: Enter should not open a row picked for the old text.
    highlight(-1);
    const text = input.value.trim();
    if (text.length < MIN_SEARCH) {
      // Ignore any pending response.
      asked += 1;
      pending = null;
      shownFor = null;
      said.textContent = '';
      close();
      clear(panel);
      items = [];
      options = [];
      return;
    }
    timer = setTimeout(() => ask(text), WAIT_MS);
  });

  input.addEventListener('focus', () => {
    if (shownFor && shownFor === input.value.trim()) open();
  });

  input.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      if (!items.length) return;
      e.preventDefault();
      open();
      highlight(stepActive(active, items.length, e.key === 'ArrowDown' ? 1 : -1));
    } else if (e.key === 'Enter') {
      e.preventDefault();
      enter();
    } else if (e.key === 'Escape') {
      // The first Escape closes the matches; the next clears the box as usual.
      if (!isOpen()) return;
      e.preventDefault();
      e.stopPropagation();
      close();
    } else if (e.key === 'Tab') {
      close();
    }
  });

  // Enter is handled above. This catches a submit from anything else.
  form.addEventListener('submit', (e) => {
    e.preventDefault();
    enter();
  });

  // Keep the focus in the box while an option is pressed.
  panel.addEventListener('mousedown', (e) => {
    if (e.button === 0) e.preventDefault();
  });

  // A click anywhere else, or focus moving out of the box, closes the matches.
  document.addEventListener('pointerdown', (e) => {
    if (isOpen() && !form.contains(e.target)) close();
  });
  form.addEventListener('focusout', (e) => {
    if (!form.contains(e.relatedTarget)) close();
  });
  window.addEventListener('hashchange', close);

  return { form, input };
}
