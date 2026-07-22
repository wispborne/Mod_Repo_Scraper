# Design — Manager Web UI

## Context

The frontend is a small no-build app: `app.js` is a hash router over view modules that each export `render(root, parts)`, with shared helpers in `lib.js` (`el`, `api`, `pager`, envelopes for missing files). The server side is done: `/api/manager/status` (with live phase/item), `/jobs`, `/jobs/cancel`, `/runs`, `/runs/<id>`, `/runs/<id>/log?tail=N`, plus 503 "manager is off" everywhere when there's no config. Error messages from the API are already plain words meant for people.

This is the last of the three changes. The earlier user decisions that shape it: per-stage actions (not one blanket "reprocess"), run history worth browsing, nothing inherited invisibly from the config file, and no config editing in the browser.

## Goals / Non-Goals

**Goals:**

- Start, watch, cancel, and re-run jobs from the browser, with per-stage actions on selected topics.
- Live progress anywhere in the UI, not just on the Runs view.
- History that is pleasant to read: what ran, why, how far it got, what it cost, what it logged.
- Read-only viewing stays complete and calm when the manager is off.

**Non-Goals:**

- No server or API changes. If the UI wants something the API lacks, that's a new proposal, not a quiet addition.
- No config editing, no auth, no remote access.
- No frontend framework, bundler, or dependency — the plain-modules style stays.
- No ModRepo pipeline actions.

## Decisions

### 1. One poller, shared by everything

A single module (`web/manager.js`) owns polling `GET /api/manager/status`: about once a second while a run is live or queued, every five seconds when idle, paused when the tab is hidden. Views and the header chip subscribe to it. This keeps "how often do we poll" in one place — the alternative, each view polling on its own, triples the requests and lets cadences drift apart.

The same module wraps job submitting (POST, surface the API's own plain-words error on 400/503) so every button behaves the same way.

### 2. The header chip is the always-on window

A small chip in the header, on every view: idle ("manager ready"), running ("Re-scraping topics — 12/40", with a thin progress line), or off ("viewing only"). Clicking it goes to the Runs view. This is the *arr feel in one element — you never wonder whether something is running.

### 3. Runs view: live on top, history below

`#/runs` shows three stacked parts: the current run (live bar, phase, current item, cancel button), the queue, and past runs — newest first, paged with the existing `pager`, each row showing kind, when, how long, state, counters, and a guardrail badge when one cut the run short. Rows link to `#/runs/<id>`.

The detail page shows the full record — including the stored request, which is what makes **run again** honest: the button posts exactly that request and jumps to the new run. The log is fetched with the default tail, a "show more" widens it, and while the run is live the log refetches on the poller's beat.

### 4. Start-a-job panel: the form is the default, spelled out

The whole-store kinds get a small form on the Runs view: full run (scope dropdown, board checkboxes, "ask the LLM" checkbox), coverage pass, rebuild bundle. Defaults are visible in the form itself — scope `newData`, main + libraries boards, LLM on when the server has it configured — so "what will this do" is answered by looking, never by knowing the config file. That was the point of the config split, carried into the UI.

`replayAllowed` is not in the form. A browser button always means fresh data; replay stays a developer flag for the CLI.

### 5. Topic selection lives in the manager module, not the view

Checkboxes on the Topics list rows and a "N selected — re-scrape · re-resolve downloads · re-run LLM · clear" bar. The selected set lives in `manager.js`, not in the view, so it survives paging, searching, and switching views; it's cleared on submit (the job now owns those topics) or by hand. The single-topic page gets the same three buttons for its one id without touching the selection set.

Per-stage buttons post the matching kinds (`rescrapeTopics`, `resolveDownloads`, `extractLlm`) with `runLlm: true` — the server ignores LLM work when no LLM is configured, and the guardrails cap it when it isn't. No "select all matching my search" in v1; selection is what you can see and tick.

### 6. Confirm by describing, in plain words

Every job button opens one shared confirm step that says what will actually happen — "Re-scrape 3 topics fresh from the forum, then re-resolve their downloads and re-run LLM extraction. This makes network requests and may spend LLM budget." — with the topic count and kind filled in. One honest sentence, not a legal wall. Submitting from the confirm posts the job and jumps to the Runs view.

### 7. Manager-off is a state, not an error

When status says the manager is off (503), the chip says "viewing only", the Runs view explains in one sentence how to turn it on (start the server where `config.properties` lives), and the action UI on Topics doesn't render. Nothing red, nothing broken — read-only viewing is a fully supported way to run the server, not a degraded one.

## Risks / Trade-offs

- [A second browser tab can act too — two tabs, two people, one queue] → That's what the queue and the visible current run are for; the API already serializes everything. No client-side locking.
- [Polling logs while a run is live re-reads the file each beat] → Tail default keeps it cheap; the log endpoint already caps what it returns. Fine at this scale.
- [Selection set can go stale (topic removed by a newer scrape)] → Submitting stale ids just yields "no such topic" log lines in the run; harmless, visible, self-explaining.
- [No websockets means up to a second of lag] → Chosen on purpose; at scraper timescales (seconds per topic) polling is indistinguishable and much simpler than a push channel.

## Migration Plan

Frontend-only, additive. Ship it; if it misbehaves, the old views are untouched and the API is unaffected. Nothing to roll back on disk.

## Open Questions

- Should the runs list offer filters (by kind, by state) right away? Leaning no — newest-first with badges is probably enough until real history builds up and says otherwise.
- Should "run again" be offered on failed runs only, or on every run? Leaning every run — re-running a completed job is a legitimate "check for updates on these topics".
