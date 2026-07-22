# Manager API

## Why

The manager core (change `extract-manager-core`) made the QB scraper callable: jobs, a queue, cancel, run history. But the only caller is still the CLI, in the same process. To manage the scraper from a browser — and to let a CLI run and a browser share one history — the server needs job endpoints, and the CLI needs to hand its work to a running server instead of racing it for the files on disk.

## What Changes

- The viewer server grows a management API under `/api/manager/`: submit a job, see what's running and queued (with live phase and current item), cancel, and browse run history with per-run logs.
- The server reads `config.properties` for environment and guardrails so it can build the manager core. It MUST NOT serve any config value to the browser; job shape still arrives only in requests. This reverses the old "server never reads config" rule on purpose — the server stays bound to `127.0.0.1`.
- If there is no readable config file, the server still starts as the plain read-only viewer; management endpoints answer with a clear "manager is off" message.
- The CLI can hand its QB job to a running server: a new `qb_manager_url` config key (environment group; empty means "run standalone like today"). When set, the CLI submits the job, shows the same console progress by polling, and Ctrl-C cancels the server-side job. If the server can't be reached or its data folder doesn't match, the CLI warns and runs standalone.
- A lock file guards the data folder so two processes can't run jobs on it at once. Whoever runs a job (server or standalone CLI) holds the lock for that job; a second would-be writer waits and says who it is waiting for. A lock left by a dead process is cleared.
- Production stays as-is: no config key set, no server around — the compiled exe runs standalone exactly like today.
- Still no web UI (change 3) and no config editing over HTTP (decided out of scope).

## Capabilities

### New Capabilities

- `manager-api`: The HTTP endpoints for jobs and run history — what they accept, what they return, request checking, the "manager is off" mode, and the rule that no config value ever goes over the wire.
- `cli-delegation`: How the CLI uses a running server — when it delegates, how progress and cancel work from the terminal, and when it falls back to standalone.
- `single-writer-lock`: The lock file that keeps two processes from writing the QB data folder at once, including stale-lock recovery.

### Modified Capabilities

- `viewer-server`: "The server never reads `config.properties`" becomes "the server may read it for environment and guardrails but never serves its values"; "the server never writes scraper data" becomes "viewer endpoints never write; management jobs write through the manager core only".

## Impact

- **Code**: `bin/viewer_server.dart` builds the manager core when config is available; new `lib/manager/manager_api.dart` (routes) and `lib/manager/data_lock.dart` (lock file); `lib/manager/job_manager.dart` gains a live-status snapshot and takes the lock around each job; CLI delegation client in `lib/manager/` used by `main_repo_scraper.dart`.
- **Config**: one new environment key, `qb_manager_url`. All other keys unchanged.
- **Data on disk**: one new file, the lock (`<qb_data_path>/scraper.lock`), which exists only while a job is running.
- **API**: new `/api/manager/*` routes; every existing viewer route is untouched.
- **Viewer frontend**: no changes yet — the runs page and mod actions come in change 3.
