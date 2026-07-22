# Design — Extract Manager Core

## Context

Today the QB pipeline is a script: `MainRepoScraper.main()` reads `config.properties`, builds the HTTP clients, store, download resolver, and LLM pieces inline, runs once, and exits. The engine underneath is already in good shape for interactive use — `QbScraperEngine.run` takes an `onProgress` callback and an `onTopicSaved` hook, and `ScrapeScope` already supports "just these topic ids." What's missing is a callable core, a job model, and any memory of past runs.

The end goal (across three changes) is *arr-style self-hosted management: a browser UI to pick mods, run actions on them, watch progress, and browse history — with the CLI still working. This change builds only the core. The plan was worked out in an explore session; the key user decisions were: one server (no separate manage flag), jobs run in-process, per-stage reprocess actions, run history is wanted, and config editing stays out of the browser.

## Goals / Non-Goals

**Goals:**

- A `ScraperService` any caller can use: full run, re-scrape topics, re-resolve downloads, re-run LLM extraction, rebuild bundle.
- A `JobManager` that runs one job at a time, reports progress, and can cancel.
- Run history on disk: what was asked, what happened, and a per-run log.
- The CLI keeps today's behavior exactly, but as a thin front over the core.
- A clean line through the config file: environment and guardrails feed the core; job shape is always an explicit request.

**Non-Goals:**

- No HTTP endpoints for jobs, no CLI-to-server delegation, no lock file (change 2).
- No web UI changes (change 3).
- No changes to the ModRepo pipeline (forum/Discord/Nexus merge) beyond it staying callable from `main()` as-is.
- No config editing from anywhere but the file.

## Decisions

### 1. Where the code lives

New `lib/manager/` directory: `scraper_service.dart`, `job_manager.dart`, `run_history_store.dart`, plus a small `job.dart` model file. The QB engine and its helpers stay where they are — the service composes them, it doesn't absorb them. `MainRepoScraper.main()` keeps the ModRepo pipeline block and replaces the QB block with "build a job request from config, hand it to the core."

### 2. The job model: an explicit request, nothing else

A job is a plain value: a kind plus its inputs.

- `fullRun` — scope (newData / all / pages / topics / librariesOnly), boards, page limits, LLM on/off, replay allowed yes/no.
- `rescrapeTopics` — topic ids. Fetches the pages fresh, re-parses, re-resolves, re-extracts (the same chain `onTopicSaved` runs today), then rebuilds the bundle.
- `resolveDownloads` — topic ids. Drops those topics' entries from the download-candidates cache and the probe cache, then re-resolves from the stored posts.
- `extractLlm` — topic ids. Drops those topics' entries from the LLM extraction cache, then re-extracts from the stored posts.
- `llmCoveragePass` — the existing "walk the whole store, extract anything missing" pass (today's `llm_reprocess_only`).
- `llmTest` — today's `llm_test_mode` trial run.
- `rebuildBundle` — reassemble `forum-data-bundle.json` from the stores.

Why this split: it matches the three cache layers (raw HTML, download results, LLM results), so each action invalidates exactly one layer's entries for the chosen topics and nothing more. The UI later gets one button per kind.

The existing `ScrapeJob` class stays as the engine's internal progress carrier; the new job model wraps it rather than replacing it, so the engine doesn't change.

### 3. Config split: environment / guardrails / job shape

The config file currently mixes three kinds of keys. The code boundary makes the split real:

- **Environment** — tokens, API keys and endpoints, `qb_data_path`, `log_level`. Read by the service at construction. No job can override them.
- **Guardrails** — `llm_max_topics`, `qb_delay_ms`, the lesser-board page cap. Also read by the service; they bind every job no matter who asked. A run stopped by a guardrail records that in its history entry.
- **Job shape** — `qb_scope`, `qb_boards`, page limits, `qb_use_cached`, `llm_enabled`, `llm_reprocess_only`, `llm_test_mode`. Only the CLI reads these, to build its default job request. The service never sees the config file's job-shape keys; it only sees requests.

Rule stated once, enforced by the types: **the service's constructor takes environment and guardrails; its methods take a job request.** Nothing about a future server run can be changed by editing the config file, except environment and guardrails — which is what a person would expect.

`llm_enabled` is two facts: "are LLM keys configured" (environment — decides whether LLM operations are possible at all) and "should this run extract" (job shape — a field on `fullRun`). The CLI sets the field from the config key, so behavior is unchanged.

Key names do not change. Alternative considered: rename keys to make the groups visible (e.g. `env_`, `limit_` prefixes). Rejected for now — the recent `config-key-cleanup` change already settled names, and a rename adds churn with no behavior gain.

### 4. Per-topic operations always fetch live

`qb_use_cached=true` replays recorded HTML. That's right for reruns of the whole pipeline, and wrong for "reprocess this mod" — the point of reprocessing is fresh data. So: `rescrapeTopics` always uses a live (throttled, recording) client, regardless of the config flag. `fullRun` keeps honoring the flag through its `replay allowed` field, which the CLI sets from `qb_use_cached`. The service builds its HTTP client per job, not per process, so the two modes don't fight.

### 5. One job at a time, cancel between topics

`JobManager` holds a queue and runs jobs strictly one at a time — the file stores assume a single writer, and nothing about scraping a forum politely wants parallel runs. Cancel is cooperative: the manager sets a flag the service checks between topics (and between LLM calls). Everything is already saved incrementally, so a cancelled job keeps its finished work and its history entry says `cancelled`.

Alternative considered: allow parallel jobs of "safe" kinds (e.g. `rebuildBundle` during a scrape). Rejected — the safety analysis isn't worth it for a single-user tool; the queue is simpler to reason about and to test.

### 6. Run history: an index plus per-run logs

Under `qb_data/runs/`:

- `runs-index.json` — one entry per run: id, kind, the full request (topic ids, scope), state (queued / running / completed / failed / cancelled), start and end times, counters (topics done / total, errors, LLM calls made), error message if any, and the log file name.
- `runs/<id>.log` — that run's log lines only.

Run ids are `<UTC timestamp>-<kind>` (e.g. `20260721T153000Z-rescrapeTopics`) — sortable, readable, unique enough for one machine. The index is rewritten on every state change and every N progress updates (same discipline as the other stores), so a crash leaves the run marked `running` with its last counters; on next startup the manager marks any `running` entries as `interrupted`. Storing the full request makes "run this again" free later.

Why not one file per run for the record too: the index stays small (a few KB per run), and one file is much easier for the future runs page to read and page through.

### 7. Progress goes through one small interface

A `RunReporter` interface with `progress(done, total, item)`, `phase(name)`, and `log(line)`. The console progress bar implements it for the CLI; the run history store implements it for persistence; the future server adds a status-object implementation. The service reports only to the interface — it doesn't know who's listening. This replaces the direct `ConsoleProgressBar` wiring in `main()`.

### 8. Logging stays global, log capture is per-run

Timber/`Logger.root` are process-global today. Rather than rework logging, the run history store subscribes to log output for the duration of a run and copies lines into the run's log file. Good enough while only one job runs at a time — which decision 5 guarantees. If parallel jobs ever happen, this is the piece to revisit.

## Risks / Trade-offs

- [The extraction quietly changes behavior] → The CLI path is kept behavior-identical on purpose: same config keys, same order of operations, same outputs. Existing tests must pass unchanged; add service-level tests that pin the per-kind cache-invalidation behavior (which cache entries each job kind drops and which it must not touch).
- [Cancel leaves half-processed state] → Everything already saves incrementally and re-runs safely; cancel just stops between topics. The history entry records how far it got.
- [Run history grows forever] → Entries are small; logs are the bulk. Ship without pruning but note it; a "keep last N runs" sweep is a natural follow-up once the UI shows history.
- [`running` entries left behind by crashes] → Marked `interrupted` at next manager startup, so history never shows a run as live when it isn't.
- [CLI and a future server writing at once] → Out of scope here (single process only), handled by the lock file in change 2. Until then nothing new makes this worse than today.

## Migration Plan

1. Land the core with the CLI as its only caller. No data formats change; the only new files on disk are under `qb_data/runs/`.
2. Rollback is deleting `qb_data/runs/` and reverting the code — no store or cache migrations to undo.

## Open Questions

- Should `llmTest` runs appear in run history? Leaning yes (they're runs, and history is for testing too), with their kind making them easy to filter out later.
- Does `rescrapeTopics` rebuild the bundle every time, or only on request? Leaning every time — it's cheap relative to a scrape, and a reprocess whose results don't show up in the bundle would look like a bug from the UI.
