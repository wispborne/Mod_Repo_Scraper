// Settings: every setting in config.properties, in four groups, plus this
// browser's own settings. Edits stay on the page until saved; saving asks
// first and lists each change. Secrets are never sent to the browser: the
// page only knows whether each one is set.

import { el, clear, api, noticeDialog, showDialog } from '../lib.js';
import { refresh, notificationsWanted, setNotificationsWanted } from '../status.js';
import { pageLayout } from '../frame.js';

const MASK = '•••';

export async function render({ content, toolbar, guardLeave }) {
  const main = el('div', { class: 'settings' }, [el('p', { class: 'empty', text: 'Loading…' })]);
  content.append(pageLayout(main));

  // key -> { type: 'set', value } | { type: 'reset' } | { type: 'clear' }
  const edits = new Map();
  let data = null;
  let resultNote = null;

  const saveButton = el('button', { type: 'button', class: 'button primary', disabled: true });
  const discardButton = el('button', { type: 'button', class: 'button', text: 'Discard', disabled: true });
  toolbar.actions.append(saveButton, discardButton);

  guardLeave(() => (edits.size ? 'Discard unsaved changes?' : null));

  const drawButtons = () => {
    saveButton.replaceChildren(edits.size ? `Save changes (${edits.size})` : 'Save changes');
    saveButton.disabled = edits.size === 0;
    discardButton.disabled = edits.size === 0;
  };
  drawButtons();

  const load = async () => {
    try {
      data = await api('manager/settings');
    } catch (err) {
      data = null;
      clear(main).append(
        el('div', { class: 'note' }, [
          el('h2', { class: 'panel-heading', text: 'Viewing only' }),
          el('p', { text: `${err.message} Settings can only be changed while jobs are on. Start the viewer with a readable config.properties file (or specify it with --config) and omit --no-manager to enable jobs.` }),
        ]),
        browserSection(),
      );
      toolbar.actions.replaceChildren();
      return;
    }
    draw();
  };

  const draw = () => {
    clear(main);
    if (resultNote) main.append(resultNote);
    main.append(el('p', { class: 'settings-intro dim', text: `Settings from ${data.file}. Changes take effect with the next job.` }));
    for (const group of data.groups) {
      const rows = data.settings.filter((s) => s.group === group.id);
      if (!rows.length) continue;
      main.append(el('section', { class: 'settings-group' }, [
        el('h2', { class: 'panel-heading settings-heading', text: group.label }),
        ...rows.map((s) => settingRow(s)),
      ]));
    }
    main.append(browserSection());
  };

  const changed = (row) => {
    resultNote = null;
    drawButtons();
    if (row) row.classList.toggle('edited', true);
  };

  /// One setting: its key and note on the left, its value on the right.
  function settingRow(s) {
    const row = el('div', { class: 'setting' });
    const markEdited = () => row.classList.toggle('edited', edits.has(s.key));
    const status = el('div', { class: 'setting-status' });
    const drawStatus = () => {
      const edit = edits.get(s.key);
      const parts = [];
      if (edit && edit.type === 'reset') parts.push(el('span', { class: 'warn-text', text: `Resets to the default (${s.default || 'empty'}) when saved.` }));
      else if (edit && edit.type === 'clear') parts.push(el('span', { class: 'warn-text', text: 'Clears when saved.' }));
      else if (s.differs && !edit && s.group !== 'secret') {
        parts.push(el('span', { class: 'tag tag-idle', text: 'Changed from default' }));
        parts.push(el('button', {
          type: 'button',
          class: 'link-button',
          text: 'Reset to default',
          title: `The default is ${s.default || 'empty'}.`,
          onclick: () => {
            edits.set(s.key, { type: 'reset' });
            changed(row);
            drawStatus();
          },
        }));
      }
      if (edit) {
        parts.push(el('button', {
          type: 'button',
          class: 'link-button',
          text: 'Undo',
          onclick: () => {
            edits.delete(s.key);
            drawButtons();
            draw();
          },
        }));
      }
      if (s.restart) parts.push(el('span', { class: 'dim', text: 'Takes effect after a restart.' }));
      status.replaceChildren(...parts);
      markEdited();
    };

    const onValue = (value) => {
      if (value === (s.value ?? '')) edits.delete(s.key);
      else edits.set(s.key, { type: 'set', value });
      changed(null);
      drawStatus();
    };

    row.append(
      el('div', { class: 'setting-name' }, [
        el('code', { class: 'setting-key', text: s.key }),
        s.note ? el('p', { class: 'setting-note' }, noteParts(s.note)) : null,
      ]),
      el('div', { class: 'setting-value' }, [valueInput(s, onValue, () => {
        edits.set(s.key, { type: 'clear' });
        changed(row);
        drawStatus();
      }), status]),
    );
    drawStatus();
    return row;
  }

  /// Shows the pending value when the setting has an unsaved edit.
  function valueInput(s, onValue, onClear) {
    const edit = edits.get(s.key);
    const shown = edit && edit.type === 'set' ? edit.value : (s.value ?? '');

    if (s.group === 'secret') {
      const box = el('input', {
        type: 'password',
        class: 'input',
        placeholder: 'New value',
        autocomplete: 'off',
        'aria-label': `New value for ${s.key}`,
      });
      if (edit && edit.type === 'set') box.value = edit.value;
      box.addEventListener('input', () => {
        if (box.value) onValue(box.value);
        else { edits.delete(s.key); drawButtons(); }
      });
      return el('div', { class: 'secret' }, [
        el('span', { class: s.isSet ? 'secret-state' : 'secret-state dim', text: s.isSet ? 'Set' : 'Not set' }),
        box,
        s.isSet ? el('button', { type: 'button', class: 'button quiet', text: 'Clear', onclick: onClear }) : null,
      ]);
    }
    if (s.kind === 'bool') {
      const box = el('input', { type: 'checkbox', 'aria-label': s.key });
      box.checked = shown === 'true';
      const word = el('span', { text: box.checked ? 'On' : 'Off' });
      box.addEventListener('change', () => {
        word.textContent = box.checked ? 'On' : 'Off';
        onValue(box.checked ? 'true' : 'false');
      });
      return el('label', { class: 'check' }, [box, word]);
    }
    if (s.kind === 'choice') {
      const select = el('select', { class: 'select', 'aria-label': s.key });
      const choices = s.choices || [];
      if (!choices.includes(shown)) select.append(el('option', { value: shown, text: shown || '(empty)' }));
      for (const c of choices) select.append(el('option', { value: c, text: c }));
      select.value = shown;
      select.addEventListener('change', () => onValue(select.value));
      return select;
    }
    const box = el('input', {
      type: s.kind === 'int' ? 'number' : 'text',
      class: 'input',
      min: s.kind === 'int' && s.min != null ? String(s.min) : null,
      step: s.kind === 'int' ? '1' : null,
      placeholder: s.default ? `Default: ${s.default}` : '',
      spellcheck: 'false',
      autocomplete: 'off',
      'aria-label': s.key,
    });
    box.value = shown;
    const hint = el('p', { class: 'setting-hint warn-text', hidden: true });
    box.addEventListener('input', () => {
      // A hidden user name or password cannot be kept by editing around it.
      const stillMasked = s.masked && box.value.includes(MASK);
      hint.hidden = !stillMasked || box.value === s.value;
      hint.textContent = 'Type the whole address again, including the user name and password.';
      onValue(box.value);
    });
    return el('div', { class: 'value-box' }, [box, hint]);
  }

  /// This browser's own settings, kept in the browser.
  function browserSection() {
    const box = el('input', { type: 'checkbox', 'aria-label': 'Notify me when a run ends' });
    box.checked = notificationsWanted();
    const note = el('p', { class: 'setting-hint dim' });
    const drawNote = () => {
      const permission = typeof Notification === 'undefined' ? 'unsupported' : Notification.permission;
      note.textContent = permission === 'unsupported'
        ? 'This browser does not support notifications.'
        : permission === 'denied' && box.checked
          ? 'Notifications are blocked for this site in the browser settings.'
          : '';
      note.hidden = !note.textContent;
    };
    box.addEventListener('change', async () => {
      setNotificationsWanted(box.checked);
      if (box.checked && typeof Notification !== 'undefined' && Notification.permission === 'default') {
        try { await Notification.requestPermission(); } catch { /* Permission request failed. */ }
      }
      drawNote();
    });
    drawNote();
    return el('section', { class: 'settings-group' }, [
      el('h2', { class: 'panel-heading settings-heading', text: 'This browser' }),
      el('div', { class: 'setting' }, [
        el('div', { class: 'setting-name' }, [
          el('span', { class: 'setting-label', text: 'Run notifications' }),
          el('p', { class: 'setting-note', text: 'Show a silent notification when a run finishes or fails. This setting is saved in this browser only.' }),
        ]),
        el('div', { class: 'setting-value' }, [
          el('label', { class: 'check' }, [box, 'Notify me when a run ends']),
          note,
        ]),
      ]),
    ]);
  }

  discardButton.addEventListener('click', () => {
    edits.clear();
    drawButtons();
    draw();
  });

  saveButton.addEventListener('click', async () => {
    if (!edits.size || !data) return;
    if (!(await confirmChanges(data, edits))) return;
    const body = { set: {}, reset: [], clearSecrets: [] };
    for (const [key, edit] of edits) {
      if (edit.type === 'set') body.set[key] = edit.value;
      else if (edit.type === 'reset') body.reset.push(key);
      else body.clearSecrets.push(key);
    }
    let answer;
    try {
      const res = await fetch('/api/manager/settings', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(body),
      });
      answer = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(answer.error || `Server returned ${res.status} ${res.statusText}.`);
    } catch (err) {
      await noticeDialog('Could not save settings', err.message);
      return;
    }
    edits.clear();
    drawButtons();
    resultNote = savedNote(answer);
    refresh();
    await load();
  });

  await load();
}

/// Shows the save result at the top of the page.
function savedNote(answer) {
  const lines = ['Saved. The next job uses the new settings.'];
  if (answer.jobRunning) lines.push('The running job keeps the settings it started with.');
  if ((answer.restartNeeded || []).length) {
    lines.push(`These take effect after a restart: ${answer.restartNeeded.join(', ')}.`);
  }
  return el('div', { class: 'saved-note', role: 'status' }, lines.map((text) => el('p', { text })));
}

/// The dialog that lists each change before saving. Resolves true to save.
function confirmChanges(data, edits) {
  return new Promise((resolve) => {
    const byKey = new Map(data.settings.map((s) => [s.key, s]));
    const items = [...edits].map(([key, edit]) => {
      const s = byKey.get(key) || {};
      const old = s.group === 'secret' ? (s.isSet ? 'set' : 'not set') : (s.value || 'empty');
      const next = edit.type === 'reset'
        ? `default (${s.default || 'empty'})`
        : edit.type === 'clear'
          ? 'cleared'
          : s.group === 'secret' ? 'changed' : (edit.value || 'empty');
      return el('li', {}, [
        el('code', { text: key }),
        el('span', { class: 'change-old', text: old }),
        el('span', { class: 'change-arrow', 'aria-hidden': 'true', text: '→' }),
        el('span', { class: 'change-new', text: next }),
      ]);
    });
    const yes = el('button', { type: 'button', class: 'button primary', text: 'Save' });
    const no = el('button', { type: 'button', class: 'button', text: 'Cancel' });
    const box = el('dialog', { class: 'dialog' }, [
      el('h2', { text: edits.size === 1 ? 'Save 1 change?' : `Save ${edits.size} changes?` }),
      el('ul', { class: 'change-list' }, items),
      el('div', { class: 'dialog-buttons' }, [no, yes]),
    ]);
    const shut = showDialog(box, (value) => resolve(value === true));
    yes.addEventListener('click', () => shut(true));
    no.addEventListener('click', () => shut(false));
    yes.focus();
  });
}

/// A note's text, with `names in backticks` shown as code.
function noteParts(note) {
  return String(note).split(/(`[^`\n]+`)/).filter(Boolean).map((part) => (
    part.length > 2 && part.startsWith('`') && part.endsWith('`')
      ? el('code', { text: part.slice(1, -1) })
      : part
  ));
}
