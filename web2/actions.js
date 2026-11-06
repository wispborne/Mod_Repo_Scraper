// Starting and stopping jobs. Every job asks first in a dialog. When the
// server refuses, its own message is shown as it is.

import { askDialog, noticeDialog } from './lib.js';
import { refresh } from './status.js';
import { describeJob, confirmLabel } from './jobs.js';
import { kindLabel } from './routes.js';

async function post(path, body) {
  const res = await fetch(`/api/manager${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body || {}),
  });
  const answer = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(answer.error || `Server returned ${res.status} ${res.statusText}.`);
  return answer;
}

/// Confirms and starts the job. Returns the new run's record, or null if the
/// user cancels or the server refuses.
export async function confirmAndStart(request) {
  const yes = await askDialog({
    title: kindLabel(request.kind),
    message: describeJob(request),
    confirmLabel: confirmLabel(request),
  });
  if (!yes) return null;
  try {
    const record = await post('/jobs', request);
    refresh();
    return record;
  } catch (err) {
    await noticeDialog('Could not start job', err.message);
    return null;
  }
}

/// Confirms before asking the server to stop only this run.
export async function confirmAndStop(record) {
  const yes = await askDialog({
    title: `Stop ${kindLabel(record.request && record.request.kind)}?`,
    message: 'The run stops between topics. Data already saved is kept.',
    confirmLabel: 'Stop run',
  });
  if (!yes) return;
  try {
    await post('/jobs/cancel', { runId: record.id });
    refresh();
  } catch (err) {
    await noticeDialog('Could not stop run', err.message);
  }
}
