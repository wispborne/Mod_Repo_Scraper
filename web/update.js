// Says when a newer release is out, and updates the server to it.
// The server runs the update script as its own systemd unit, so the script
// outlives the server it replaces. This page only starts it and watches.

import { el, clear, askDialog, noticeDialog } from './lib.js';
import { subscribe } from './manager.js';

const URL = '/api/manager/update';
// Gitea is asked at most every ten minutes by the server, so this is cheap.
const CHECK_MS = 30 * 60 * 1000;
const WATCH_MS = 2000;
const GIVE_UP_MS = 5 * 60 * 1000;

/// The update status, or null when the server did not answer.
async function ask() {
  try {
    const res = await fetch(URL, { headers: { accept: 'application/json' }, cache: 'no-store' });
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

/// Draws the "Update to vN" button under the status chip when there is one.
export function mountUpdateNotice(node) {
  if (!node) return;

  const draw = async () => {
    const s = await ask();
    clear(node);
    if (!s || !s.supported) return;

    if (s.lastUpdate && s.lastUpdate.running) {
      const button = el('button', { class: 'update-button running', text: 'Updating…' });
      button.addEventListener('click', () => watch(s.installed, s.latest));
      node.append(button);
      return;
    }
    if (!s.available) return;

    const button = el('button', {
      class: 'update-button',
      text: `Update to v${s.latest}`,
      title: `This server is on v${s.installed}. v${s.latest} is out.`,
    });
    button.addEventListener('click', offer);
    node.append(button);
  };

  draw();
  setInterval(draw, CHECK_MS);
  // The manager turning on after a restart is the moment a fresh answer is worth having.
  let wasOn = null;
  subscribe((s) => {
    if (wasOn === false && s.on) draw();
    wasOn = s.on;
  });
}

/// Asks first, then starts the update and watches it.
async function offer() {
  const s = await ask();
  if (!s) {
    await noticeDialog('Update', 'The server did not answer. Try again in a moment.');
    return;
  }
  if (!s.canUpdate) {
    await noticeDialog(s.latest ? `Update to v${s.latest}` : 'Update', s.reason);
    return;
  }

  const paras = [
    `This server is on v${s.installed}. Updating downloads v${s.latest} from Gitea and `
      + 'restarts the server.',
    'The viewer stops answering for a minute or so while it restarts. If the new version '
      + 'does not start, the old one is put back.',
  ];
  const failed = lastFailure(s.lastUpdate);
  if (failed) paras.push(`The last update did not go through: ${failed}`);

  const yes = await askDialog({
    title: `Update to v${s.latest}`,
    message: paras.join('\n\n'),
    confirmLabel: 'Update and restart',
  });
  if (!yes) return;

  try {
    const res = await fetch(URL, { method: 'POST' });
    const answer = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(answer.error || `Server returned ${res.status} ${res.statusText}.`);
  } catch (err) {
    await noticeDialog('The update did not start', err.message);
    return;
  }
  watch(s.installed, s.latest);
}

/// The script's last error line, if the last update failed.
function lastFailure(last) {
  if (!last || last.running) return null;
  if (last.died) return 'it stopped without saying how it went.';
  if (last.exitCode === 0 || last.exitCode == null) return null;
  const errors = (last.lines || []).filter((l) => /^(Error|Could not)/.test(l));
  return errors.length ? errors[errors.length - 1] : 'see the log for why.';
}

/// Follows the update until the new build answers, then reloads the page.
function watch(from, to) {
  const line = el('p', { text: 'Downloading and checking the new version…' });
  const log = el('pre', { class: 'raw update-log' });
  const close = el('button', { class: 'btn', text: 'Close' });
  const box = el('dialog', { class: 'ask-dialog update-dialog' }, [
    el('h3', { text: `Updating to v${to}` }),
    line,
    log,
    el('div', { class: 'dialog-buttons' }, [close]),
  ]);

  let stopped = false;
  close.addEventListener('click', () => box.close());
  box.addEventListener('close', () => {
    stopped = true;
    box.remove();
  });
  document.body.append(box);
  box.showModal();

  const showLog = (last) => {
    const lines = (last && last.lines) || [];
    const atBottom = log.scrollHeight - log.scrollTop - log.clientHeight < 8;
    log.textContent = lines.join('\n');
    if (atBottom) log.scrollTop = log.scrollHeight;
  };

  const startedAt = Date.now();
  const step = async () => {
    if (stopped) return;
    const s = await ask();
    if (stopped) return;

    if (!s) {
      line.textContent = 'The server is restarting…';
    } else {
      showLog(s.lastUpdate);
      if (s.installed === to) {
        line.textContent = `Updated to v${to}. Reloading…`;
        setTimeout(() => location.reload(), 1500);
        return;
      }
      const last = s.lastUpdate;
      if (last && !last.running) {
        const failed = lastFailure(last);
        line.textContent = failed
          ? `The update did not go through. The server is on v${s.installed}. ${failed}`
          : `The update finished, but the server is still on v${s.installed}.`;
        close.textContent = 'OK';
        return;
      }
      line.textContent = 'Downloading and checking the new version…';
    }

    if (Date.now() - startedAt > GIVE_UP_MS) {
      line.textContent = 'This is taking longer than it should. The log below is the last '
        + `thing the server said. It was on v${from}.`;
      close.textContent = 'OK';
      return;
    }
    setTimeout(step, WATCH_MS);
  };
  setTimeout(step, WATCH_MS);
}
