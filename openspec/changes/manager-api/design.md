# Design — Manager API

## Context

Change `extract-manager-core` landed the core: `JobRequest`/`RunRecord` (dart_mappable), `ScraperService.runJob`, `JobManager` (queue of one, `submit` returns the finished record, `cancelCurrent`), `RunHistoryStore` (`runs-index.json` + per-run logs, interrupted-marking on load), and the `RunReporter` interface. The CLI already goes through all of it. The viewer server is still a separate, deliberately read-only process that never reads `config.properties`.

This change connects them: job endpoints on the server, a CLI that can hand its job over, and a lock so the two processes can't write the data folder at once. Web UI is change 3.

## Goals / Non-Goals

**Goals:**

- Everything a browser (or `curl`) needs to run and watch jobs: submit, status with live phase/current item, cancel, history, logs.
- The CLI can use a running server, with the same console feel, and falls back to standalone when it can't.
- Exactly one process writes the QB data folder at a time, enforced, not assumed.
- The read-only viewer experience is unchanged, including when no config file exists.

**Non-Goals:**

- No web UI changes (change 3 adds the runs page and mod action buttons).
- No config values over HTTP, no config editing, no auth (localhost-only stays the boundary).
- No remote access story. If that ever comes, it starts with auth, not with this change.
- ModRepo pipeline untouched: the CLI always runs it locally, delegated or not.

## Decisions

### 1. Routes live under `/api/manager/`, speak the mapper shapes

New routes, mounted next to the existing viewer API in the same server:

- `GET  /api/manager/status` — is the manager on, the absolute data path, the current run (record plus live phase/current item), and the queue.
- `POST /api/manager/jobs` — body is a `JobRequest` map (decoded with `JobRequestMapper.fromMap`). Returns the queued `RunRecord`. Rejected with 400 and a plain-words reason when the kind is unknown, a per-topic kind has no topic ids, or the body doesn't parse.
- `POST /api/manager/jobs/cancel` — cancels the current job (the existing between-topics cancel). No-op with a clear answer when nothing is running.
- `GET  /api/manager/runs` — history, newest first, paged like the viewer's list endpoints.
- `GET  /api/manager/runs/<id>` — one record.
- `GET  /api/manager/runs/<id>/log?tail=N` — that run's log text (default: last 200 lines).

Requests and responses are the dart_mappable maps of the core's own types — no second wire model to keep in sync. `submit` already returns a future for the *finished* run; the route responds with the queued record immediately instead of holding the connection open.

### 2. Live status is in-memory, not in the record

`RunRecord` carries what's worth keeping (counters, states, times). Phase and current item are only interesting while a run is live, so `JobManager` gets a small in-memory snapshot — phase, current item, done/total — updated by the same reporter wrapper that already feeds the history store. `GET status` merges the snapshot onto the current record. Nothing new is persisted.

### 3. No config, no manager — the viewer keeps working

The server tries to read `config.properties` at startup. If it's there, it builds `ScraperEnvironment.fromConfig` + `ScraperGuardrails.fromConfig`, the service, the store, and the manager, and mounts the routes live. If not, the viewer runs exactly as today and every `/api/manager/` route answers 503 with a plain JSON message ("The manager is off: no readable config.properties"). So a checkout without secrets still gets the read-only viewer, and the CLI can tell "server there, manager off" apart from "no server".

One wrinkle: the viewer's `--data-dir` flag and the config's `qb_data_path` can disagree. When the manager is on, the manager core uses `qb_data_path`; if the flag points elsewhere the server logs a warning at startup, because the viewer would then be browsing different data than the manager is writing.

### 4. Nothing from the config file goes over the wire

The status payload is built by hand from a short list of fields (manager on/off, data path, run records, queue). No route ever serializes `BotConfig`, `ScraperEnvironment`, or `LlmSettings`. The data path itself is fine to expose — it's a folder name on the user's own machine, and the CLI needs it (decision 6). A test pins this: the status response contains no key or value from the config file beyond the data path.

### 5. Delegation is opt-in via one key, with fallback

New environment key `qb_manager_url`. Empty (the default) means the CLI runs standalone, exactly like today — so production CI never changes behavior by surprise, which was the user's main worry about config. When set (typically `http://127.0.0.1:8085`), the CLI:

1. Calls `GET /api/manager/status`.
2. If unreachable, manager off, or the data paths don't match: warn in plain words and run standalone. The lock makes the fallback safe even if the server starts a job later.
3. Otherwise: submit the job, poll status once a second, and drive the normal `ConsoleRunReporter` from the live snapshot — same bar, same phases.
4. On Ctrl-C: post cancel, keep polling until the record settles, report "cancelled, kept N topics". A second Ctrl-C just exits.
5. When the run ends: print the same summary as a local run; on failure, fetch and print the log tail so the user isn't sent hunting.

Alternative considered: always probe the default port and delegate when something answers. Rejected — delegation changing behavior because some server happened to be running is exactly the "acting in unexpected ways" the config split was meant to prevent.

### 6. The CLI checks it's talking about the same data

`status` returns the server's absolute data path. The CLI resolves its own `qb_data_path` to absolute and compares. Different paths → warn and run standalone. This catches the easy mistake (server started in another checkout or with another config) before any job runs against the wrong folder.

### 7. One lock file, held per job, owned by `JobManager`

`<qb_data_path>/scraper.lock`, JSON: pid, a short label ("server" / "cli"), and the start time. Both the server and the standalone CLI run jobs through `JobManager`, so the lock lives there — acquired before a job starts, released when it ends, on the failure path too.

- Lock exists and its pid is alive: wait, log "waiting for the lock held by <label> (pid N)" once, retry every few seconds. Queue semantics already mean "wait your turn"; this extends that across processes.
- Lock exists and its pid is dead: the process died mid-run (history already marks that run interrupted). Delete the lock with a log line and carry on.
- A delegating CLI never touches the lock — the server holds it for the job.

Alternative considered: hold the lock for the whole server lifetime. Rejected — it would make "server idle, run the CLI standalone" impossible, which is a workflow worth keeping.

## Risks / Trade-offs

- [Anything on localhost can start jobs that cost money] → Accepted knowingly (user keeps it internal); the boundary stays `127.0.0.1`, and guardrails cap LLM spend per run regardless of caller.
- [The "server never reads config" rule is weakened] → Replaced with the narrower testable rule: read for environment and guardrails, never serve. The delta spec rewrites the requirement rather than deleting it.
- [Pid reuse could make a stale lock look alive] → Rare on a single-user machine and the cost is a wait, not corruption. Not worth more machinery.
- [Polling misses log lines during delegated runs] → By design; the bar plus final summary is the CLI experience, and the full log is one endpoint away. Revisit only if it annoys in practice.
- [Two servers pointed at one data folder] → The lock serializes their jobs, so data stays safe; the second server is merely useless. Startup logs the data path to make the mistake visible.

## Migration Plan

1. Purely additive: new routes, new key, new lock file. Nothing existing changes shape.
2. Rollback: unset `qb_manager_url` (CLI is standalone again) and ignore the manager routes. The lock file deletes itself with the process.

## Open Questions

- Should `POST /jobs` refuse a request identical to one already queued? Leaning no for v1 — the queue is visible, and dedupe rules invite surprises.
- Should the delegated CLI also mirror server log lines live (not just the bar)? Leaning no — tail-on-failure covers the need; streaming is UI-change territory.
