# Tasks — Manager Web UI

## 1. Shared manager module

- [x] 1.1 Create `web/manager.js`: the status poller (once a second while a run is live or queued, every five seconds idle, paused on hidden tab) with subscribe/unsubscribe; remembers the last status including "manager off".
- [x] 1.2 Add job submitting to it: POST helper that surfaces the API's own plain-words message on 400/503, plus the shared confirm step that describes kind, topic count, and cost in kind.
- [x] 1.3 Add the selected-topics set: add/remove/clear, count, and a change event the views listen to.

## 2. Header status chip

- [x] 2.1 Add the chip to `web/index.html` next to the nav; `manager.js` renders it from the poller: running (kind, N/M, thin progress line), ready, or "viewing only". Clicking it goes to `#/runs`.
- [x] 2.2 Style it in `web/style.css`, matching the existing look.

## 3. Runs view

- [x] 3.1 Create `web/views/runs.js`: current run (bar, phase, item, cancel with confirm), queue, and past runs newest first with the existing `pager` — kind, start time, duration, state, counters, guardrail badge, link to detail.
- [x] 3.2 Create `web/views/run.js` (`#/runs/<id>`): full record with the stored request shown readably, the log tail with "show more", live refresh of both while the run is live, and the "run again" button posting the stored request.
- [x] 3.3 Add the start-a-job panel to the runs view: full run form (scope dropdown, board checkboxes, LLM checkbox, defaults visible), coverage pass, rebuild bundle. No replay option.
- [x] 3.4 Manager-off rendering: one calm sentence saying how to turn the manager on; no forms or buttons.
- [x] 3.5 Register the view: nav entry and routes in `web/app.js` (`runs`, `runs/<id>`).

## 4. Topic actions

- [x] 4.1 In `web/views/topics.js`: row checkboxes wired to the shared set, plus the selection bar (count, re-scrape, re-resolve downloads, re-run LLM, clear). Selection survives paging and search; submit clears it and goes to `#/runs`. Nothing renders when the manager is off.
- [x] 4.2 In `web/views/topic.js`: the same three actions for the one topic, without touching the selection set.

## 5. Check it end to end and close out

- [x] 5.1 By hand against a live server: select topics across pages and run each per-stage action; start a full run from the form; cancel from the browser; watch the chip from another view; open a failed run's log; "run again"; then start the server without a config file and confirm every action surface reads as viewing-only.
- [x] 5.2 By hand: CLI-delegated run appears live in the browser chip and Runs view while the console shows its usual bar — the whole point, seen working once.
- [x] 5.3 Update `README.md` and `CLAUDE.md` with the browser workflow, and remove the "runs page comes in a later change" notes left in the earlier changes' docs.
