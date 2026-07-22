# manager-api

## ADDED Requirements

### Requirement: Job endpoints on the server
The server SHALL offer, under `/api/manager/`: submit a job (`POST /jobs`, body is a `JobRequest` in its mapper shape, answered right away with the queued run record), see status (`GET /status`: whether the manager is on, the absolute data path, the current run with live phase and current item, and the queued runs), and cancel the current job (`POST /jobs/cancel`). Jobs submitted over HTTP SHALL run through the same `JobManager` and appear in the same run history as CLI runs.

#### Scenario: Submit and watch a job
- **WHEN** a client posts an `extractLlm` request for topics 123 and 456
- **THEN** the answer is the queued run record, and `GET /status` then shows that run with its live counters, phase, and current item while it runs

#### Scenario: Submitting does not wait for the run
- **WHEN** a job that will take minutes is posted
- **THEN** the response arrives right away with the record in state queued or running

#### Scenario: Cancel over HTTP
- **WHEN** a client posts to `/jobs/cancel` while a job is running
- **THEN** the job stops between topics, its record says cancelled, and everything already saved stays saved

#### Scenario: Cancel with nothing running
- **WHEN** a client posts to `/jobs/cancel` while the queue is empty
- **THEN** the answer says in plain words that nothing was running, and nothing breaks

### Requirement: Bad requests are refused with a reason
The server SHALL answer 400 with a plain-words reason when a job body does not parse, names an unknown kind, or asks for a per-topic kind (`rescrapeTopics`, `resolveDownloads`, `extractLlm`) with no topic ids. A refused request SHALL NOT appear in run history.

#### Scenario: Per-topic job with no topics
- **WHEN** a client posts a `rescrapeTopics` request with an empty topic list
- **THEN** the answer is 400 saying topic ids are needed, and no run is recorded

### Requirement: Run history over HTTP
The server SHALL serve run history: `GET /runs` (newest first, paged like the viewer's other lists), `GET /runs/<id>` (one record), and `GET /runs/<id>/log?tail=N` (that run's own log, defaulting to the last 200 lines). Unknown run ids get a 404 with a plain message.

#### Scenario: Browsing past runs
- **WHEN** a client asks for the first page of runs after several jobs have run
- **THEN** it gets those runs newest first, each with kind, request, state, times, and counters

#### Scenario: Reading one run's log
- **WHEN** a client asks for the log of a finished run with `tail=50`
- **THEN** it gets the last 50 lines of that run's log file and nothing from any other run

### Requirement: The manager can be off, the viewer never is
When the server starts without a readable `config.properties`, it SHALL still serve the viewer exactly as before, and every `/api/manager/` route SHALL answer 503 with a plain-words JSON message saying the manager is off and why. When the manager is on but the viewer's `--data-dir` differs from the config's `qb_data_path`, the server SHALL warn at startup.

#### Scenario: Viewer-only start
- **WHEN** the server starts in a folder with no `config.properties`
- **THEN** the viewer pages and viewer API work as before, and `GET /api/manager/status` answers 503 saying the manager is off

#### Scenario: Viewer and manager pointed at different folders
- **WHEN** the server starts with `--data-dir a` while the config says `qb_data_path=b`
- **THEN** a startup warning names both folders

### Requirement: No config value goes over the wire
Management responses SHALL be built from an explicit short list of fields. Beyond the absolute data path, no key or value from `config.properties` — tokens, endpoints, models, limits — SHALL appear in any response. The server SHALL keep binding to `127.0.0.1` only.

#### Scenario: Status carries no secrets
- **WHEN** a client reads `GET /status` on a fully configured server
- **THEN** the response contains no token, key, endpoint URL, or model name from the config file
