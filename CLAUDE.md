# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Dart CLI that scrapes Starsector mod metadata from several sources and produces two outputs consumed by the TriOS launcher:

- `outputs/ModRepo.json` — merged, deduplicated mods from Forum + Discord + Nexus (the "ModRepo" pipeline).
- `outputs/forum-data-bundle.json` — a richer per-topic bundle with images, download links, and optional LLM-extracted facts (the "QB" pipeline).

Both pipelines run from one entry point and are toggled independently in `config.properties`.

## Commands

```bash
dart pub get                       # install deps
dart run bin/scraper_main.dart     # run the scraper (reads config.properties)
dart test                          # run all tests
dart test test/mod_merger_test.dart            # run one test file
dart test --name "substring of test name"      # run tests matching a name
dart analyze                       # lint (see analysis_options.yaml for extra rules)
dart run bin/viewer_server.dart    # local read-only results viewer at http://127.0.0.1:8085
dart compile exe bin/scraper_main.dart -o mod_repo_scraper   # what CI ships
```

### Code generation (dart_mappable)

JSON models use `dart_mappable`. Every `*.dart` model has a generated `*.mapper.dart` sibling that is committed to the repo. After changing any `@MappableClass` model, regenerate:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Do not hand-edit `*.mapper.dart` files — they are overwritten by the build.

## Configuration

Everything is driven by `config.properties` (read by `Common.readConfig()`; fields live on `BotConfig` in `lib/bot/common.dart`). It holds real auth tokens and is **gitignored** — never commit it, and do not paste its contents anywhere external. `config.example.properties` is the committed stand-in: every key with its default and a plain-English note. **Keep it in step** — a key added, renamed or given a new default here means editing that file too, and `Common._recognizedKeys` is the list to check it against. Every key is snake_case and starts with its group prefix (`modrepo_`, `qb_`, `llm_`); only `log_level` is global. Unknown keys are warned about at startup, so a typo or an old (pre-rename) key name is caught right away. Key switches:

- `modrepo_enabled`, `modrepo_forums_enabled`, `modrepo_discord_enabled`, `modrepo_nexus_enabled` — the ModRepo pipeline and its sources.
- `qb_enabled`, `qb_scope` (`new_data` / `all` / `pages` / `topics` / `libraries_only`; camelCase spellings like `newData` also work), `qb_boards` (`main`/`lesser`/`libraries`) — the QB pipeline.
- `modrepo_use_cached` / `qb_use_cached` — replay from the on-disk raw-HTTP caches instead of hitting the network (see Caching below).
- `llm_enabled` and the `llm_*` keys — optional LLM post-extraction (off in production by default).
- `modrepo_merge_debug` — write `merge-debug.json` for the viewer's Merge view.
- `qb_manager_url` — environment. Empty (the default) means the CLI runs the QB job itself, exactly as before. Set (e.g. `http://127.0.0.1:8085`) means it hands the job to that server. Unreachable / manager off / different data folder → warn in plain words and run standalone. Production never sets it.
- `qb_runs_to_keep` — environment. How many runs the history keeps (default 100); older ones are dropped with their log files. 0 keeps everything.

## Architecture

Orchestration lives in `lib/bot/scraper/main_repo_scraper.dart` (`MainRepoScraper.main`), which runs the two pipelines in sequence. The ModRepo pipeline is still inline there; the QB pipeline goes through the manager core in `lib/manager/`.

### Manager core (`lib/manager/`)

The QB pipeline is callable, not just runnable. `main()` turns the config file's job-shape keys into one `JobRequest` and hands it to a `JobManager`; everything else lives in the core. The web API and the browser UI sit over that same core.

- `job.dart` — `JobKind` (`fullRun`, `rescrapeTopics`, `resolveDownloads`, `extractLlm`, `llmCoveragePass`, `llmTest`, `rebuildBundle`), `JobRequest` (what to do), `RunRecord` / `RunCounters` / `RunState` (what happened). `dart_mappable`, so `job.mapper.dart` is generated.
- `scraper_settings.dart` — the config split made real. **Environment** (`qb_data_path`, LLM endpoint/model/keys) and **guardrails** (`llm_max_topics`, `qb_delay_ms`, `llm_timeout_seconds`) go into the service's constructor; **job shape** (`qb_scope`, `qb_boards`, page limits, `qb_use_cached`, `llm_enabled`, `llm_reprocess_only`, `llm_test_mode`) is read only by the CLI, to build its request. The service must never read a job-shape key.
- `scraper_service.dart` — one method per job kind, composing the existing QB pieces. Builds the store, resolver, probe cache and LLM store once; builds the forum HTTP client per job. `fullRun` honours the request's `replayAllowed`; **per-topic kinds always fetch live**, even when `qb_use_cached=true`. Each per-topic kind drops exactly one cache layer's entries for the chosen topics (`QbDownloadResolver.dropTopics`, `DownloadableProbeCache.dropUrls`, `LlmExtractionStore.dropTopics`) and nothing else.
- `job_manager.dart` — a queue, one job at a time, wired to the service, the history store and a reporter. `cancelCurrent()` sets a flag the service checks between topics.
- `run_history_store.dart` — `<qb_data_path>/runs/runs-index.json` plus `runs/<run id>.log`. Written on start, on every state change, and every 10 progress reports; anything still saying `running` at startup becomes `interrupted`. Log capture hooks `DebugTree.extraAppenders` while a run is active — safe because only one job runs at a time. Only the newest `qb_runs_to_keep` runs (default 100, 0 keeps everything) are kept; the rest are dropped on save, log files included, since the logs are what fill the folder. **Only the paperwork goes** — the record and the run's own log. Scraped data (mods index, detail files, every cache, the bundle) all live outside `runs/` and are never touched; a test pins this. The log file named by a record is only deleted if it ends in `.log` and really sits in `runs/`, because that name is read back from a file on disk and this is the one place that deletes anything. The trim happens **after** merging in the other program's runs from disk and before writing — the other way round, a run just dropped would be read straight back as one this copy had never heard of. A run that hasn't ended is never dropped.
- `run_reporter.dart` — `RunReporter` (`phase`, `progress`, `log`). `progress` also carries the run's totals so far (`errors`, `llmCalls`) for the jobs that can count them as they go; leaving one out means "no news", not zero, so a job that can't count something never wipes what is already known (the scrape leaves `errors` alone — the engine only reports failures at the end). This is what makes spending visible while a run is live and honest on a run that dies: the counters ride the same every-10-reports save as everything else. Pinned by `test/manager/live_counters_test.dart`. `ConsoleRunReporter` drives `ConsoleProgressBar` and sends log lines to timber, which is what keeps CLI output identical. `LogRunReporter` is the server's: no bar, but its lines still go to timber, which is how `RunLogCapture` gets them. **Never give the server the silent reporter** — its `log()` drops everything, so a browsed run shows counters with no reasons ("1 error", no word of what went wrong). Pinned by a test. The service talks only to this interface, never to the console.
- `data_lock.dart` — `<qb_data_path>/scraper.lock` (pid, `server`/`cli` label, start time). `JobManager` takes it before each job and releases it in the same `finally`, so completed, failed and cancelled all release. A lock held by a live process is waited for (logged once); one whose pid is dead is cleared and logged. A delegating CLI never takes it — the server holds it for the job.
- `manager_api.dart` — the routes under `/api/manager/`: `GET /status`, `POST /jobs`, `POST /jobs/cancel`, `GET /runs`, `GET /runs/<id>`, `GET /runs/<id>/log?tail=N`. Bodies decode with `JobRequestMapper.fromMap`; answers are the mapper maps. `ManagerApi.offHandler(reason)` is the 503 "manager is off" stand-in. **Status is built by hand from four fields** (`managerOn`, `dataPath`, `current`, `queued`) — a test pins that list, because no config value may ever reach the browser. The data path is the one allowed exception; `cli-delegation` needs it.
- `delegation_client.dart` — `ManagerDelegate`: probe `/status`, compare data paths (`p.equals`), submit, poll once a second and drive `ConsoleRunReporter` from the snapshot, print the usual summary (plus the log tail on failure). Returns null when the job should run locally instead, having said why.

`JobManager` takes a `JobRunner` (the interface `ScraperService` implements), so tests can stand in a fake job. `RunHistoryStore.save()` merges in any run on disk it hasn't heard of before writing — two processes each hold their own copy of the index in memory, so writing it as-is would drop the other's runs. Reading works the same way round: `records` and `byId` check the index file's timestamp and size first and re-read when it has changed, so a long-lived server shows runs another program started without being restarted (it would otherwise show the history as of its own startup — worst at the moment you go looking). Runs this copy started (`_ourRunIds`) are kept from memory on that re-read, because ours are only saved every tenth report and the file would wind our own live run backwards.

`llm_test_mode` and `llm_reprocess_only` are no longer branches in `main()` — they pick the `llmTest` and `llmCoveragePass` job kinds. The config keys are unchanged.

### ModRepo pipeline (Forum / Discord / Nexus → merge → ModRepo.json)

- Scrapers: `forum_scraper.dart`, `discord_reader.dart`, `nexus_reader.dart`. Forum and Nexus run through `_loadOrRun` (per-source `<name>_cache.json`); Discord uses a raw-HTTP `CachingClient` (`discord_raw_cache.json`).
- Merge: `mod_merger.dart` — buckets by forum `topic=<id>`, then a trigram index narrows candidates, then subsequence fuzzy match (`fuzzy/fuzzy.dart`) + author aliases (`mod_repo_utils.dart`), then same-source dedup / merge / validate. Optional `MergeDebugCollector` records why each group formed, written to `merge-debug.json`.
- Model: `scraped_mod.dart` (`ScrapedMod`, `ModSource`, `ModUrlType`, `Image`).

### QB pipeline (`lib/bot/scraper/qb/`)

Adapted from a separate C# project (theRoastSuckling's QBMBAMM); its scraper was ported, but this repo is the consumer's fork. Flow driven by `QbScraperEngine.run(scope, onTopicSaved:)`:

1. `mod_index_scraper.dart` / `board_scraper.dart` walk the configured forum boards for topic summaries.
2. `topic_scraper.dart` + `html_processor.dart` fetch and parse each topic page.
3. `download_resolver.dart` turns links into download candidates using host-specific rules (Google Drive, Dropbox, MediaFire, GitHub, forum attachments…); cached in `assumed-downloads-cache.json`.
4. Results are persisted incrementally by `json_data_store.dart` into `qb_data_path` as `mods-index.json` plus `mods/<id>/detail.json`.
5. `bundle_publisher.dart` assembles `forum-data-bundle.json` from the store + resolver + LLM store.

Scraping is pipelined: `onTopicSaved` runs download resolution (and LLM extraction) per topic as it is saved, rather than in separate passes.

### QB LLM extraction (`lib/bot/scraper/qb/llm/`, optional)

When `llm_enabled=true`, `PostExtractor` sends each post once to any OpenAI-compatible chat endpoint (`openai_client.dart` / `llm_client.dart`, prompt in `prompt.dart`) to pull out facts the rules miss: extra downloads, changelog, mod version, support links, license, and optional summaries. `post_reducer.dart` trims post HTML first. Results are cached in `llm-extraction-cache.json` via `extraction_store.dart`, so re-runs only pay for new/changed posts.

Coverage is over the **store**, not over this run's scrape. `ScraperService._llmCoveragePass` walks the whole mods index after the scrape and calls `extractForTopic` on every stored topic, so a topic that was scraped before the LLM was switched on still gets picked up. Topics scraped this run were already extracted inside the pipelined `onTopicSaved` loop and come back as free store hits in the pass, so they are not paid for twice — that rests on `extractForTopic` doing its freshness check *before* `_reserveSlot()`. `llm_max_topics` caps live calls per run (not topics visited), so a big backlog can be worked through in bounded chunks; each run resumes where the last stopped, and logs how many topics still have no results.

Two special modes, now job kinds rather than branches: `llm_reprocess_only` → `llmCoveragePass` (the same coverage pass, minus the scrape, then rebuild the bundle) and `llm_test_mode` → `llmTest` (small non-persisting trial → `llm-test-output.json`).

### Caching model (important)

Two independent cache layers — do not conflate them:

- **Raw-HTTP caches** (`CachingClient`): `discord_raw_cache.json`, `<qb_data_path>/qb_raw_cache.json`. When `use_cached`/`qb_use_cached` and the file exists, the client *replays* recorded responses (`isReplaying == true`) and the throttle delay drops to 0. Caches are only re-saved when not replaying. When recording, each response is written to the file as it arrives (one JSON object per line), so an interrupted run keeps what it fetched; `CachingClient.fromFile` also reads the older "one big JSON list" format.
- **Derived caches**: per-source `<name>_cache.json` (ModRepo), `assumed-downloads-cache.json`, `link-downloadable-cache.json` (per-URL "is this a direct download?" probe results), `llm-extraction-cache.json`. These store processed results so pipeline stages can re-run without recomputation. Note the `link-downloadable-cache.json` probes are live network HEAD/GET calls that bypass the raw-HTTP replay layer, so without this cache every topic re-probes the network even when `qb_use_cached=true`.

A third thing on disk, neither cache nor output: `<qb_data_path>/runs/` — `runs-index.json` plus one log file per run (see the manager core above). It follows the same save-as-you-go rule. A fourth, which is neither: `<qb_data_path>/scraper.lock`, which exists only while a job is running (see `data_lock.dart`).

**Everything that costs money or network time is saved as the run goes, not at the end.** A run killed with Ctrl-C, or one that dies part-way, must not throw away the work it already did — the next run should pick up where it left off. So: `mods-index.json` is written every 10 topics (it names the `detail.json` files, which are written per topic — an unsaved index orphans them and the next run re-scrapes them all), `assumed-downloads-cache.json` every 10 resolved topics, `link-downloadable-cache.json` every 10 probes, `llm-extraction-cache.json` every 5 topics or 5 seconds. Each also gets a final save at the end, on the failure path too. Keep it that way when adding a cache: the only end-of-run writes should be *derived outputs* (`ModRepo.json`, `forum-data-bundle.json`, `merge-debug.json`), which can always be rebuilt from the caches. The ModRepo per-source caches (`<name>_cache.json`) are still all-or-nothing.

### Results viewer (`bin/viewer_server.dart`, `lib/viewer/`, `web/`)

A local `shelf` server that serves the static `web/` frontend, a JSON API (`lib/viewer/api.dart`, `data_access.dart`) over the output files, and — when a config file can be read — the management API. Binds to `127.0.0.1` only. Viewer endpoints never write; the only writes are jobs on the management API. When output/bundle shapes change, keep this viewer in sync. Default dirs: `--data-dir qb_data`, `--outputs-dir outputs`, `--root-dir .`; also `--config config.properties` and `--no-manager`.

The old "the server never reads `config.properties`" rule is now narrower: it **may** read it, for the manager's environment and guardrails, and **must never serve** any of its values (the data path excepted). No route serializes `BotConfig`, `ScraperEnvironment` or `LlmSettings`.

`lib/viewer/server_app.dart` (`buildServerHandler`) composes the parts. It picks the `api/manager` subtree off *before* the router/cascade rather than mounting it — a mounted handler's 404 ("no run by that name") is read as "no such route" and falls through to the static files, losing the reason.

The server plants a console log tree and bridges the `logging` package (`Common.initTimberForConsole` / `Common.bridgeLoggingToTimber`); without that, `RunLogCapture` would write empty per-run logs for server-started jobs.

#### Frontend (`web/`, no build step, plain ES modules)

`app.js` is a hash router over view modules that each export `render(root, parts)`; shared DOM/fetch helpers are in `lib.js`.

`web/manager.js` is the only place the frontend talks to `/api/manager/`. It owns three things:

- **The status poller.** One shared `GET /status` loop — about a second while a run is live or queued, five seconds idle, stopped while the tab is hidden. Views call `subscribe(fn)` and drop the subscription on `hashchange`; nothing else polls. `refresh()` returns the in-flight ask rather than starting a second one, so a view that loads mid-beat still gets a real answer instead of `null`.
- **Sending jobs.** `submitJob` / `cancelCurrent` / `confirmAndSubmit`, plus `describeJob` — the one plain sentence every confirm box shows. A refusal is re-thrown carrying **the server's own message**: those are already written for people, so never wrap them in wording of our own. UI-started jobs always send `replayAllowed: false`.
- **The ticked topics.** The selection set lives here, not in the view, so it survives paging, searching and switching views. Cleared on submit.

`mountHeaderChip()` draws the always-on status chip in the top bar (`#status-chip` in `index.html`).

Two views read all this: `views/runs.js` (live run, queue, history, start-a-job form) and `views/run.js` (`#/runs/<id>`: record, log tail, run again). Two gotchas worth keeping: the start-a-job form is only redrawn when the manager goes on or off — redrawing it on the poller's beat would wipe what the user just picked — and the log route's "no log file" answer arrives as a `MissingFile` from `lib.js`'s `api()`, not as a body field.

**Manager off is a mode, not an error.** When status says off, the chip says "viewing only", the Runs view explains how to turn it on in one sentence, and Topics renders no tick boxes and no buttons — the page reads exactly as the read-only viewer always has.

## Conventions

- **Plain English** in all user-facing copy (viewer text, FAQ, docs) and in explanations. Avoid jargon.
- `analysis_options.yaml` enforces `avoid_print` (use the `timber`/`logging` helpers, not `print`), required return types, and prefer-final/const rules.
- Spec-driven changes live under `openspec/` (`specs/` are current capabilities, `changes/` are proposals). Use the `opsx:*` skills to propose/apply/archive changes here.
- For any Starsector game/API/modding question, use the `starsector-knowledge` skill — never answer from memory, since the API changes between game versions.
