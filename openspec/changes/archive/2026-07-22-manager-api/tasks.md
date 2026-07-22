# Tasks — Manager API

## 1. Lock file

- [x] 1.1 Create `lib/manager/data_lock.dart`: take/release `<qb_data_path>/scraper.lock` (pid, label, start time as JSON); wait-and-retry when held by a live process, logging the holder once; delete and proceed when the pid is dead (Windows `tasklist` / POSIX signal-0 check).
- [x] 1.2 Wire it into `JobManager`: take the lock before each job runs, release in the same `finally` that completes the job — so completed, failed, and cancelled all release.
- [x] 1.3 Tests: second manager on the same folder waits; lock gone after a job throws; stale lock with a dead pid is cleared and logged.

## 2. Live status in JobManager

- [x] 2.1 Add an in-memory status snapshot (run id, phase, current item, done/total) updated by the reporter wrapper that already feeds history; expose it next to `currentRun` and `queuedRuns`.
- [x] 2.2 Test: snapshot reflects the latest phase and item during a run and clears when the run ends.

## 3. Management API

- [x] 3.1 Create `lib/manager/manager_api.dart` with the routes: `GET /status`, `POST /jobs`, `POST /jobs/cancel`, `GET /runs` (paged, newest first), `GET /runs/<id>`, `GET /runs/<id>/log?tail=N`. Decode bodies with `JobRequestMapper.fromMap`; answer with the mapper maps.
- [x] 3.2 Request checking: 400 with a plain-words reason for unparseable bodies, unknown kinds, and per-topic kinds with no topic ids; 404 for unknown run ids; refused requests never reach the queue or history.
- [x] 3.3 Build status by hand from a short field list (manager on/off, absolute data path, current run + snapshot, queue). Add the test that a configured server's status response carries nothing from the config file beyond the data path.
- [x] 3.4 In `bin/viewer_server.dart`: try to read `config.properties`; when readable, build environment, guardrails, service, history store, and manager, call their `load()`s, and mount the routes; when not, mount a handler that answers 503 "manager is off" on every manager route. Warn at startup when `--data-dir` and `qb_data_path` differ. Keep binding to `127.0.0.1` only.
- [x] 3.5 Tests over the routes with a fake service: submit answers right away with the queued record; cancel while running and while idle; runs list pages newest first; log tail returns only that run's lines; viewer-only mode answers 503 on manager routes while viewer routes still work.

## 4. CLI delegation

- [x] 4.1 Add the `qb_manager_url` environment key to `BotConfig` and the known-keys list; empty means standalone.
- [x] 4.2 Create the delegation client in `lib/manager/`: probe `GET /status`; compare the server's absolute data path with the CLI's resolved `qb_data_path`; on unreachable / manager off / path mismatch, warn in plain words and hand back "run standalone".
- [x] 4.3 Delegated run loop: submit the job, poll status about once a second, drive `ConsoleRunReporter` from the snapshot, print the usual summary at the end; on failure, exit non-zero and print the record's error plus the log tail from the server.
- [x] 4.4 Ctrl-C during a delegated run: first interrupt posts cancel and keeps polling until the record settles; second interrupt exits.
- [x] 4.5 Wire into `main_repo_scraper.dart`: when `qb_manager_url` is set, run the QB job through the delegation client, otherwise exactly as now. ModRepo pipeline stays local in both cases.
- [x] 4.6 Tests with a fake server: delegates when everything matches; falls back with a warning on each of the three fallback reasons; cancel path settles the record.

## 5. End-to-end check and docs

- [x] 5.1 By hand: start the server, submit a small job with `curl`, watch `/status`, cancel one, browse `/runs`, then run the CLI delegated and standalone against the same folder and confirm both runs sit in one history.
- [x] 5.2 Run the full test suite; existing tests pass unchanged.
- [x] 5.3 Update `CLAUDE.md` and `README.md`: the manager routes, `qb_manager_url`, the lock file, and the viewer's new "manager on/off" startup behavior.
