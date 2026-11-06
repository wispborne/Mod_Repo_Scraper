// The Update link in the status bar. The server runs the update script in a separate systemd unit
// so it keeps running during the server restart. This page starts the script
// and checks its progress.

import { el, clear, askDialog, noticeDialog, showDialog } from './lib.js';
import { subscribe } from './status.js';

const URL = '/api/manager/update';
// The server asks Gitea at most every five minutes, so this is cheap.
const CHECK_MS = 2 * 60 * 1000;
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

/// Draws "Update to vN" in `node` when a newer release is out.
export function mountUpdateLink(node) {
  const draw = async () => {
    const s = await ask();
    clear(node);
    if (!s || !s.supported) return;

    if (s.lastUpdate && s.lastUpdate.running) {
      node.append(el('button', {
        type: 'button',
        class: 'link-button',
        text: 'Updating…',
        onclick: () => watch(s.installed, s.latest),
      }));
      return;
    }
    if (!s.available) return;
    node.append(el('button', {
      type: 'button',
      class: 'link-button',
      text: `Update to v${s.latest}`,
      title: `Installed: v${s.installed}. Available: v${s.latest}.`,
      onclick: offer,
    }));
  };

  draw();
  setInterval(draw, CHECK_MS);
  // Browsers slow down timers in a hidden tab, so check when it is shown again.
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') draw();
  });
  // Check for updates when the manager comes back after a restart.
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
    await noticeDialog('Update', 'No response from the server. Try again shortly.');
    return;
  }
  if (!s.canUpdate) {
    await noticeDialog(s.latest ? `Update to v${s.latest}` : 'Update', s.reason);
    return;
  }

  const paras = [
    `This server is on v${s.installed}. Updating downloads v${s.latest} from Gitea and `
      + 'restarts the server.',
    'The viewer is unavailable for about a minute during the restart. If the new version '
      + 'does not start, the old version is restored.',
  ];
  const failed = lastFailure(s.lastUpdate);
  if (failed) paras.push(`The last update failed: ${failed}`);

  const yes = await askDialog({
    title: `Update to v${s.latest}`,
    message: paras.join('\n\n'),
    confirmLabel: 'Update and restart',
  });
  if (!yes) return;

  try {
    const res = await fetch(URL, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: '{}',
    });
    const answer = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(answer.error || `Server returned ${res.status} ${res.statusText}.`);
  } catch (err) {
    await noticeDialog('Update failed to start', err.message);
    return;
  }
  watch(s.installed, s.latest);
}

/// The script's last error line, if the last update failed.
function lastFailure(last) {
  if (!last || last.running) return null;
  if (last.died) return 'the update stopped without reporting a result.';
  if (last.exitCode === 0 || last.exitCode == null) return null;
  const errors = (last.lines || []).filter((l) => /^(Error|Could not)/.test(l));
  return errors.length ? errors[errors.length - 1] : 'see the log for details.';
}

/// Follows the update until the new build answers, then reloads the page.
function watch(from, to) {
  const line = el('p', { text: 'Downloading and checking the new version…' });
  const log = el('pre', { class: 'log update-log' });
  const close = el('button', { type: 'button', class: 'button', text: 'Close' });
  const box = el('dialog', { class: 'dialog update-dialog' }, [
    el('h2', { text: `Updating to v${to}` }),
    line,
    log,
    el('div', { class: 'dialog-buttons' }, [close]),
  ]);

  // The dialog stays open on another page, so the update is followed to
  // the end and the page reloads onto the new build.
  let stopped = false;
  const shut = showDialog(box, () => {
    stopped = true;
  }, { stayOnPageChange: true });
  close.addEventListener('click', () => shut());

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
          ? `Update failed. The server is on v${s.installed}. ${failed}`
          : `The update finished, but the server is still on v${s.installed}.`;
        close.textContent = 'OK';
        return;
      }
      line.textContent = 'Downloading and checking the new version…';
    }

    if (Date.now() - startedAt > GIVE_UP_MS) {
      line.textContent = 'The update is taking longer than expected. The log below shows the latest '
        + `server response. The server was on v${from}.`;
      close.textContent = 'OK';
      return;
    }
    setTimeout(step, WATCH_MS);
  };
  setTimeout(step, WATCH_MS);
}
