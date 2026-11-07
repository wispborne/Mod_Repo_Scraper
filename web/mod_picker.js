// The mod chooser: a search box over our mods for matching a written name to
// one or more mods. The Dependency matching page shows it in a row, and the
// mod page under the requirement being matched.
// Its styles are the dn-* rules in dependency_names.css.
// `looseKey` and `findMods` use no DOM, so Node can test them
// (test/web/mod_helpers_test.mjs).

import { el, clear } from './lib.js';
import { icon } from './icons.js';

/// How many mods the picker shows at once.
const SUGGESTION_COUNT = 8;

/// Letters and digits only, in lower case, for matching names loosely.
export function looseKey(text) {
  return String(text || '').toLowerCase().replace(/[^a-z0-9]/g, '');
}

/// Common words ignored when matching mod names.
const FILLER_WORDS = new Set([
  'a', 'an', 'the', 'of', 'and', 'or', 'by', 'for', 'with', 'mod', 'mods', 'version', 'other', 'any', 'all', 'that',
]);

/// Splits a name into lowercase words for matching. Removes apostrophes and
/// common words. Removes words starting with a digit or with "v" followed by
/// a digit. Removes a final "s" from words longer than three characters.
/// "Scy Nation's" and "SCY Nation" produce the same words.
export function nameWords(text) {
  return String(text || '').toLowerCase().replace(/['’]/g, '')
    .split(/[^a-z0-9]+/)
    .filter((w) => w && !FILLER_WORDS.has(w) && !/^v?\d/.test(w))
    .map((w) => (w.length > 3 && w.endsWith('s') ? w.slice(0, -1) : w));
}

/// Scores a match against a mod's name and id. Lower scores come first.
/// Returns -1 for no match. Name and id comparisons ignore case and
/// characters other than letters and digits.
/// 0: exact name or id.
/// 1: the name or id starts with the search text.
/// 2: every search word occurs in the name or id, with at least half as many
///    distinct search words as distinct words in the mod's name.
/// 3: the name or id contains the search text.
/// 4: the search text contains the name or id, which must have at least four
///    letters or digits.
/// 5: each search word starts a word in the name or id.
function fit(mod, q, words) {
  const { name, id, own, ownList, nameCount } = prepared(mod);
  if (name === q || id === q) return 0;
  if (name.startsWith(q) || id.startsWith(q)) return 1;
  if (words.length && words.every((w) => own.has(w)) && new Set(words).size * 2 >= nameCount) return 2;
  if (name.includes(q) || id.includes(q)) return 3;
  if ((name.length >= 4 && q.includes(name)) || (id.length >= 4 && q.includes(id))) return 4;
  if (words.length && words.every((w) => ownList.some((o) => o.startsWith(w)))) return 5;
  return -1;
}

/// Each mod's name and id worked out for matching, kept so a search over
/// every mod does not split every name into words again.
const preparedMods = new WeakMap();

function prepared(mod) {
  let ready = preparedMods.get(mod);
  if (!ready) {
    const nameOnly = new Set(nameWords(mod.name));
    const own = new Set([...nameOnly, ...nameWords(mod.id)]);
    ready = {
      name: looseKey(mod.name),
      id: looseKey(mod.id),
      own,
      ownList: [...own],
      nameCount: nameOnly.size,
    };
    preparedMods.set(mod, ready);
  }
  return ready;
}

/// Returns mods matching `text`, best matches first. Equal matches are
/// sorted by name length, shortest first. Names of equal length are sorted
/// alphabetically.
function rankMods(mods, text, worst) {
  const q = looseKey(text);
  if (!q) return [];
  const words = nameWords(text);
  const ranked = [];
  for (const mod of mods) {
    const rank = fit(mod, q, words);
    if (rank >= 0 && rank <= worst) ranked.push([rank, mod]);
  }
  ranked.sort((a, b) => a[0] - b[0]
    || String(a[1].name).length - String(b[1].name).length
    || String(a[1].name).localeCompare(String(b[1].name)));
  return ranked.map(([, mod]) => mod);
}

/// Our mods that fit `text`, for the picker's search, best first.
export function findMods(mods, text) {
  return rankMods(mods, text, 5);
}

/// Returns suggested matches for a dependency name, best matches first.
/// Includes exact matches and names or ids starting with the search text.
/// Also includes matches containing every search word, with at least half as
/// many distinct search words as distinct words in the mod's name. The
/// picker's search also includes partial matches.
export function suggestMods(mods, written) {
  if (!nameWords(written).length || looseKey(written).length < 3) return [];
  return rankMods(mods, written, 2);
}

/// Each chooser's result list needs its own id.
let chooserCount = 0;

/// A search box over our mods with a tick box per result, the chosen mods as
/// chips, and, with two or more chosen, "All of these" / "Any of these".
/// Shown inline on the Dependency matching page and on the mod page. `mods`
/// is a list of { id, name }; a mod may also have an `author` field. `written`
/// is the first search. `selected` holds the ids chosen at the start, and
/// `anyOne` whether any one of them is enough.
///
/// Match calls `onPick(mods, { anyOne })` with the chosen mods; `anyOne` is
/// only true with two or more. Cancel and Escape call `onCancel()`. Returns
/// the element and a `focus()` that puts the cursor in the search box.
export function modChooser({ written, mods = [], selected = [], anyOne = false, onPick, onCancel }) {
  const listId = `dn-picks-${++chooserCount}`;
  const byId = new Map(mods.map((mod) => [mod.id, mod]));
  const chosen = selected.map((id) => byId.get(id)).filter(Boolean);
  let any = anyOne;

  const input = el('input', {
    type: 'text',
    class: 'input dn-input',
    autocomplete: 'off',
    spellcheck: 'false',
    role: 'combobox',
    'aria-autocomplete': 'list',
    'aria-controls': listId,
    'aria-expanded': 'false',
  });
  const list = el('ul', {
    class: 'dn-picks', id: listId, role: 'listbox', 'aria-multiselectable': 'true', hidden: true,
  });
  const note = el('p', { class: 'dn-hint', hidden: true });
  const chips = el('div', { class: 'dn-chosen' });
  const choice = el('fieldset', { class: 'dn-any', hidden: true });
  let shown = [];
  let active = -1;

  const cancel = el('button', { type: 'button', class: 'button', text: 'Cancel', onclick: () => onCancel() });
  const match = el('button', {
    type: 'button',
    class: 'button primary',
    text: 'Match',
    onclick: () => {
      if (chosen.length) onPick([...chosen], { anyOne: any && chosen.length > 1 });
    },
  });
  const element = el('div', { class: 'dn-chooser' }, [
    el('label', { class: 'dn-field' }, [el('span', { class: 'dn-label', text: 'Search mods' }), input]),
    note,
    list,
    chips,
    choice,
    el('div', { class: 'dn-chooser-buttons' }, [cancel, match]),
  ]);

  const isChosen = (mod) => chosen.some((m) => m.id === mod.id);
  const optionId = (i) => `${listId}-${i}`;

  /// The chosen mods as chips, the "All of these / Any of these" choice when
  /// there are two or more, and the Match button's state.
  const drawChosen = () => {
    chips.replaceChildren(...chosen.map((mod) => el('span', { class: 'chip dn-chip' }, [
      mod.name,
      el('button', {
        type: 'button',
        class: 'dn-chip-x',
        'aria-label': `Remove ${mod.name}`,
        title: 'Remove',
        onclick: () => toggle(mod),
      }, [icon('x', 12)]),
    ])));
    choice.hidden = chosen.length < 2;
    const radio = (value, label) => el('label', { class: 'dn-radio' }, [
      el('input', {
        type: 'radio',
        name: `${listId}-any`,
        checked: any === value,
        onchange: () => { any = value; },
      }),
      label,
    ]);
    choice.replaceChildren(radio(false, 'All of these'), radio(true, 'Any of these'));
    match.disabled = !chosen.length;
  };

  const toggle = (mod) => {
    const at = chosen.findIndex((m) => m.id === mod.id);
    if (at >= 0) chosen.splice(at, 1);
    else chosen.push(mod);
    drawChosen();
    [...list.querySelectorAll('.dn-pick')].forEach((li, n) => {
      const on = shown[n] ? isChosen(shown[n]) : false;
      li.setAttribute('aria-selected', String(on));
      const box = li.querySelector('input');
      if (box) box.checked = on;
    });
  };

  const highlight = (i) => {
    active = i;
    [...list.querySelectorAll('.dn-pick')].forEach((li, n) => li.classList.toggle('on', n === i));
    if (i >= 0) input.setAttribute('aria-activedescendant', optionId(i));
    else input.removeAttribute('aria-activedescendant');
  };

  const suggest = () => {
    const found = mods.length ? findMods(mods, input.value) : [];
    shown = found.slice(0, SUGGESTION_COUNT);
    clear(list);
    note.hidden = true;
    if (!shown.length) {
      list.hidden = true;
      input.setAttribute('aria-expanded', 'false');
      highlight(-1);
      if (!mods.length) {
        note.textContent = 'No mods available.';
        note.title = 'The mod list comes from the last website build.';
        note.hidden = false;
      } else if (looseKey(input.value)) {
        note.textContent = 'No results found.';
        note.title = '';
        note.hidden = false;
      }
      return;
    }
    shown.forEach((mod, i) => {
      const on = isChosen(mod);
      const li = el('li', {
        id: optionId(i),
        role: 'option',
        class: 'dn-pick',
        'aria-selected': String(on),
      }, [
        el('input', { type: 'checkbox', tabindex: '-1', 'aria-hidden': 'true', checked: on }),
        el('span', { class: 'dn-pick-name' }, [
          mod.name,
          mod.author ? el('span', { class: 'dn-pick-author', text: ` by ${mod.author}` }) : null,
        ]),
        el('code', { class: 'dn-id', text: mod.id }),
      ]);
      li.addEventListener('mousedown', (e) => {
        e.preventDefault();
        highlight(i);
        toggle(mod);
      });
      list.append(li);
    });
    const more = found.length - shown.length;
    if (more > 0) {
      list.append(el('li', {
        class: 'dn-pick-more', role: 'presentation', title: 'Type more to narrow your search.', text: `${more} more results`,
      }));
    }
    list.hidden = false;
    input.setAttribute('aria-expanded', 'true');
    highlight(0);
  };

  input.addEventListener('input', suggest);
  input.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowDown' && shown.length) {
      e.preventDefault();
      highlight((active + 1) % shown.length);
    } else if (e.key === 'ArrowUp' && shown.length) {
      e.preventDefault();
      highlight((active - 1 + shown.length) % shown.length);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      // Enter ticks the highlighted mod. Ctrl+Enter, or Enter with nothing
      // highlighted, presses Match.
      if ((e.ctrlKey || e.metaKey || active < 0) && chosen.length) match.click();
      else if (active >= 0 && shown[active]) toggle(shown[active]);
    } else if (e.key === 'Escape') {
      e.preventDefault();
      e.stopPropagation();
      onCancel();
    }
  });

  drawChosen();
  // Start from the written name itself: it often finds the mod straight away.
  input.value = written;
  suggest();
  return {
    element,
    focus() {
      input.focus();
      input.select();
    },
  };
}
