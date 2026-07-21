# Extract Manager Core

## Why

The QB scraper can only be run as a one-shot program: all the setup lives inline in `MainRepoScraper.main()`, and the only way to say what a run should do is to edit `config.properties`. We want to manage the scraper from a browser as well — pick mods, reprocess them, watch runs, look back at old runs — while keeping the CLI working like today. That needs a core that both the CLI and a future web manager can call, plus a record of every run. This change builds that core; the web API and UI come in follow-up changes.

## What Changes

- Pull the QB pipeline setup out of `MainRepoScraper.main()` into a `ScraperService` class with named operations: full run, re-scrape chosen topics, re-resolve downloads for chosen topics, re-run LLM extraction for chosen topics, and rebuild the bundle.
- Add a `JobManager` that runs jobs one at a time, reports progress, and supports cancel.
- Add a run history store: every job gets a record (what was asked for, when, how it went, counters, errors) and its own log file. Saved as the run goes, per the house rule.
- Split the config file's role: it keeps holding environment (tokens, paths, endpoints) and guardrails (spend caps, throttle delays), but job shape (scope, boards, LLM on/off) becomes an explicit job request. The CLI turns its config keys into a request, so today's "edit the file, run the exe" workflow is unchanged.
- The `llm_reprocess_only` and `llm_test_mode` config switches become job kinds the CLI requests, instead of special branches in `main()`. The config keys keep working.
- Per-topic reprocess operations always fetch live (still throttled, still recorded to the raw cache) — they never replay old HTML, even when `qb_use_cached=true`. Full runs keep honoring `qb_use_cached`.
- The ModRepo pipeline (forum/Discord/Nexus merge) is out of scope and stays as it is.

## Capabilities

### New Capabilities

- `scraper-jobs`: What a job is — an explicit, fully-described request (kind, topics, scope, LLM on/off); the available job kinds; how jobs run one at a time with progress and cancel; and the rule that the config file supplies environment and guardrails but never job shape.
- `run-history`: A durable record of every run — request, timestamps, outcome, counters, per-run log — written incrementally so an interrupted run still leaves an honest record.

### Modified Capabilities

<!-- No requirement-level changes to existing capabilities. The QB pipeline's
     behavior (pipelined scraping, download resolution, LLM extraction, bundle
     publishing, raw caching) stays the same; this change moves where the code
     lives and how a run is asked for. -->

## Impact

- **Code**: `lib/bot/scraper/main_repo_scraper.dart` shrinks a lot; new files for the service, job manager, and run history store (likely under `lib/manager/`). `bin/scraper_main.dart` becomes a thin front over the core. `ScrapeJob` in `lib/bot/scraper/qb/models/scrape_job.dart` grows into (or is replaced by) the job/run record model.
- **Config**: `BotConfig` keys keep their names; what changes is who reads them. Environment and guardrail keys feed the service; job-shape keys are only read by the CLI to build its default request.
- **Data on disk**: new run history files under `qb_data` (an index plus per-run logs). Existing stores, caches, and outputs are untouched.
- **Viewer**: no changes yet. The runs page that reads the new history files comes with the web UI change; noted here so the viewer-sync rule isn't missed.
- **Follow-up changes**: (2) management API on the server + CLI delegation with a lock file, (3) web UI for selection, actions, progress, and history.
