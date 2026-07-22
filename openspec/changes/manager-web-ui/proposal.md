# Manager Web UI

## Why

The manager core and its HTTP API are done: jobs can be started, watched, cancelled, and browsed with `curl`. What's missing is the part the whole effort was for — doing it from a browser. This change gives the viewer frontend the *arr-style management experience: pick mods and act on them, watch runs live, and look back through history.

## What Changes

- A new **Runs** view in the frontend: the current run with a live progress bar, the queue, a cancel button, and past runs newest first — each opening into a detail page with the full record, its log, and a "run this again" button.
- A **start-a-job panel** on the Runs view for the whole-store kinds: full run (scope, boards, LLM on/off), LLM coverage pass, and rebuild bundle. Every job is spelled out and confirmed before it is sent — nothing is inherited invisibly from the config file, per the config split.
- **Topic selection and actions** on the Topics view: checkboxes, a "N selected" bar that survives paging and view switches, and per-stage buttons — re-scrape, re-resolve downloads, re-run LLM — that post the matching per-topic job kinds. The same buttons appear on a single topic's page for acting on just that one.
- A small **status chip in the header**, on every view: what's running and how far along, or "manager off — viewing only". One shared poller feeds it and the Runs view (about once a second while something runs, slower when idle).
- When the manager is off (no config file), all action UI explains itself instead of failing: the viewer stays fully usable read-only.
- UI-started jobs never use replay mode — the browser buttons always mean fresh data. Replay stays a CLI/config concern.
- No config editing in the browser (decided out of scope), and no changes to the server API — the UI consumes `/api/manager/*` as shipped in the `manager-api` change.

## Capabilities

### New Capabilities

- `runs-page`: The Runs view, the run detail page with logs and run-again, the start-a-job panel, and the always-visible status chip with its shared poller.
- `topic-actions`: Selecting topics in the viewer and posting per-stage jobs for them, including the single-topic case and the manager-off behavior.

### Modified Capabilities

<!-- None. The server API is unchanged; the existing viewer read-only
     capabilities keep their requirements. The new UI behavior is additive and
     covered by the two new capabilities. -->

## Impact

- **Code**: new `web/views/runs.js` and `web/views/run.js`; a shared `web/manager.js` (status poller, job submitting, confirm helper); edits to `web/app.js` (nav + routes), `web/views/topics.js` and `web/views/topic.js` (selection + action bars), `web/index.html` / `web/style.css` (header chip, action styling). No build step — stays plain JS modules.
- **Server**: none.
- **Docs**: README and CLAUDE.md gain the browser workflow; this also closes the loop on the "runs page comes later" notes left in the previous two changes.
