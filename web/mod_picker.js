// The mod picker: a dialog with a search box over our mods. The Dependency
// names page and the mod page both use it to match a written name to a mod.
// Its styles are the dn-* rules in dependency_names.css.
// `looseKey` and `findMods` use no DOM, so Node can test them
// (test/web/mod_helpers_test.mjs).

import { el, clear, showDialog } from './lib.js';

/// How many mods the picker shows at once.
const SUGGESTION_COUNT = 8;

/// Letters and digits only, in lower case, for matching names loosely.
export function looseKey(text) {
  return String(text || '').toLowerCase().replace(/[^a-z0-9]/g, '');
}

/// Our mods whose name or id holds `text`, best first: the same name, then
/// names starting with it, then names holding it, then names the text holds
/// (for a spelling with a version on the end).
export function findMods(mods, text) {
  const q = looseKey(text);
  if (!q) return [];
  const ranked = [];
  for (const mod of mods) {
    const name = looseKey(mod.name);
    const id = looseKey(mod.id);
    let rank = -1;
    if (name === q || id === q) rank = 0;
    else if (name.startsWith(q) || id.startsWith(q)) rank = 1;
    else if (name.includes(q) || id.includes(q)) rank = 2;
    else if ((name.length >= 4 && q.includes(name)) || (id.length >= 4 && q.includes(id))) rank = 3;
    if (rank >= 0) ranked.push([rank, mod]);
  }
  ranked.sort((a, b) => a[0] - b[0] || String(a[1].name).localeCompare(String(b[1].name)));
  return ranked.map(([, mod]) => mod);
}

/// Opens the picker. `mods` is a list of { id, name }. `written` is the name
/// being matched: it is the heading and the first search. `facts` is the line
/// under the heading. `current` is the id it is already matched to by hand,
/// which cannot be picked again. `onPick(mod)` is called with the chosen mod,
/// then the dialog closes.
export function openModPicker({ written, facts = '', mods = [], current = null, onPick }) {
  const input = el('input', {
    type: 'text',
    class: 'input dn-input',
    placeholder: 'Mod name or id',
    autocomplete: 'off',
    spellcheck: 'false',
    role: 'combobox',
    'aria-label': 'Mod',
    'aria-autocomplete': 'list',
    'aria-controls': 'dn-picks',
    'aria-expanded': 'false',
  });
  const list = el('ul', { class: 'dn-picks', id: 'dn-picks', role: 'listbox', hidden: true });
  const note = el('p', { class: 'dn-hint', hidden: true });
  let shown = [];
  let active = -1;

  const cancel = el('button', { type: 'button', class: 'button', text: 'Cancel' });
  const box = el('dialog', { class: 'dialog dn-dialog' }, [
    el('div', { class: 'dn-eyebrow', text: 'Match a dependency name' }),
    el('h2', { text: written }),
    facts ? el('p', { class: 'dn-dialog-facts', text: facts }) : null,
    el('label', { class: 'dn-field' }, [
      el('span', { class: 'dn-hint', text: 'Type part of a mod\'s name or id and pick it from the list.' }),
      input,
    ]),
    note,
    list,
    el('p', {
      class: 'dn-hint dn-pending-note',
      text: 'This is added to the pending changes. Nothing is written until you save them.',
    }),
    el('div', { class: 'dialog-buttons' }, [cancel]),
  ]);
  const shut = showDialog(box, () => {});
  cancel.addEventListener('click', () => shut(false));

  const usable = (mod) => mod.id !== current;
  const choose = (mod) => {
    if (!usable(mod)) return;
    onPick(mod);
    shut(true);
  };
  const highlight = (i) => {
    active = i;
    [...list.children].forEach((li, n) => li.classList.toggle('on', n === i));
    if (i >= 0) input.setAttribute('aria-activedescendant', `dn-pick-${i}`);
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
        note.textContent = 'The mod list comes from the last website build. There is no build yet.';
        note.hidden = false;
      } else if (looseKey(input.value)) {
        note.textContent = 'No mod in the catalog matches.';
        note.hidden = false;
      }
      return;
    }
    shown.forEach((mod, i) => {
      const ok = usable(mod);
      const li = el('li', {
        id: `dn-pick-${i}`,
        role: 'option',
        class: `dn-pick${ok ? '' : ' disabled'}`,
        'aria-disabled': ok ? null : 'true',
      }, [
        el('span', { class: 'dn-pick-name', text: mod.name }),
        el('code', { class: 'dn-id', text: ok ? mod.id : `${mod.id} · current match` }),
      ]);
      li.addEventListener('mousedown', (e) => { e.preventDefault(); choose(mod); });
      list.append(li);
    });
    const more = found.length - shown.length;
    if (more > 0) {
      list.append(el('li', {
        class: 'dn-pick-more', role: 'presentation', text: `${more} more. Keep typing to narrow it down.`,
      }));
    }
    list.hidden = false;
    input.setAttribute('aria-expanded', 'true');
    highlight(shown.findIndex(usable));
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
      if (active >= 0 && shown[active]) choose(shown[active]);
    }
  });

  // Start from the written name itself: it often finds the mod straight away.
  input.value = written;
  suggest();
  input.focus();
  input.select();
}
