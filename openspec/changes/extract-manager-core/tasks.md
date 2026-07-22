# Tasks — Extract Manager Core

## 1. Job model and reporter

- [x] 1.1 Create `lib/manager/job.dart`: job kinds enum, a job request class per the spec (kind, topic ids, scope, boards, page limits, LLM on/off, replay allowed), and a run record class (id, request, state, times, counters, guardrail stop, error, log file name). Use `dart_mappable` and regenerate mappers.
- [x] 1.2 Create the `RunReporter` interface (`progress`, `phase`, `log`) plus a console implementation that wraps `ConsoleProgressBar` and a test/fake implementation.

## 2. Run history store

- [x] 2.1 Create `lib/manager/run_history_store.dart`: load/save `runs/runs-index.json` under the data path, add-or-update a record, and write on start, on every state change, and every N progress updates.
- [x] 2.2 Add per-run log capture: while a run is active, copy log lines to `runs/<run id>.log` (subscribe to the existing logging output; one job at a time makes this safe).
- [x] 2.3 On store startup, mark any record still `running` as `interrupted`.
- [x] 2.4 Tests: record written at start; counters saved mid-run; failed run keeps its error message; interrupted marking works; two runs get separate log files.

## 3. Cache-entry removal per topic

- [x] 3.1 Add "drop entries for these topic ids" to the download-candidates cache (`download_resolver.dart`) and the probe cache (`downloadable_probe_cache.dart`).
- [x] 3.2 Add "drop entries for these topic ids" to the LLM extraction store (`extraction_store.dart`).
- [x] 3.3 Tests: dropping topic 123 leaves topic 456's entries byte-identical; each drop touches only its own cache file.

## 4. ScraperService

- [x] 4.1 Create `lib/manager/scraper_service.dart`. Constructor takes environment + guardrails (split out of `BotConfig` or passed as a narrowed view) and builds the store, resolver, probe cache, and LLM pieces once. It must not read job-shape config keys.
- [x] 4.2 Move the QB `fullRun` path out of `main()`: build the HTTP client per job (replay allowed honors the request; otherwise live + recording), run the engine with the per-topic `onTopicSaved` chain, then the LLM coverage pass and bundle rebuild, reporting through `RunReporter`.
- [x] 4.3 Implement `rescrapeTopics`: always-live client, engine scope `topics` with the requested ids, full per-topic chain, bundle rebuild at the end.
- [x] 4.4 Implement `resolveDownloads` and `extractLlm`: drop the topics' entries in the right cache (tasks 3.x), re-run that stage from stored details, save, rebuild bundle.
- [x] 4.5 Implement `llmCoveragePass`, `llmTest`, and `rebuildBundle` by moving the existing code paths out of `main()`.
- [x] 4.6 Add the cooperative cancel check between topics and between LLM calls.
- [x] 4.7 Tests: job shape comes only from the request (config scope ignored); guardrail cap recorded on the run; per-topic jobs bypass replay; each kind drops only its own layer.

## 5. JobManager

- [x] 5.1 Create `lib/manager/job_manager.dart`: queue in arrival order, one job running at a time, wires each job to the service, the history store, and a reporter; exposes current status and cancel.
- [x] 5.2 Tests: second job waits for the first; cancel stops between items, keeps saved work, and records `cancelled` with the right counters.

## 6. CLI rewiring

- [x] 6.1 In `main_repo_scraper.dart`, replace the inline QB block: build a job request from the config keys (`qb_scope`, `qb_boards`, page limits, `qb_use_cached`, `llm_enabled`; `llm_reprocess_only` → `llmCoveragePass`; `llm_test_mode` → `llmTest`) and run it through the manager with the console reporter. ModRepo pipeline block stays as-is.
- [x] 6.2 Compare a before/after run end to end (cached replay is fine for this): same outputs, same console feel, plus the new `runs/` files.
- [x] 6.3 Run the full test suite and fix any fallout; existing tests must pass without edits to their expectations.

## 7. Docs

- [x] 7.1 Update `CLAUDE.md` and `README.md`: the manager core, the job kinds, the config split (environment / guardrails / job shape), and the new `runs/` files. Note that the viewer's runs page comes in a later change.
