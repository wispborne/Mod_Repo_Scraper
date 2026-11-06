## ADDED Requirements

### Requirement: The server serves both viewers
The viewer server SHALL serve the old viewer from `web/` and the new viewer from `web2/` at the same time, on the same port and against the same API. A `--ui` option SHALL choose which viewer is served at `/`: `v1` (the default) for the old viewer, `v2` for the new one. The viewer not chosen SHALL be served under `/v1/` or `/v2/`. A request to `/v1` or `/v2` SHALL redirect to the same address with a trailing slash. Both viewers need this because they load their files by relative address. Any other value of `--ui` SHALL stop the server at startup with a message naming the two allowed values. A `--web2-dir` option SHALL set the new viewer's folder, defaulting to `web2`. When that folder does not exist, the server SHALL still start, serve the old viewer as before, and report at startup that the new viewer is missing. The API routes SHALL NOT change.

#### Scenario: Default start
- **WHEN** the server starts with no `--ui` option
- **THEN** `/` serves the old viewer and `/v2/` serves the new one

#### Scenario: New viewer at the root
- **WHEN** the server starts with `--ui v2`
- **THEN** `/` serves the new viewer and `/v1/` serves the old one

#### Scenario: Address without a trailing slash
- **WHEN** a browser requests `/v2` without a trailing slash
- **THEN** the server redirects to `/v2/`

#### Scenario: Invalid --ui value
- **WHEN** the server is started with `--ui v3`
- **THEN** it does not start and reports that `--ui` must be `v1` or `v2`

#### Scenario: No web2 folder
- **WHEN** the `web2/` folder is missing
- **THEN** the server starts, serves the old viewer at `/`, and it reports at startup that the new viewer was not found

### Requirement: Live reload watches both viewers
When the server is started with `--reload`, open pages SHALL reload when a file changes in either `web/` or `web2/`.

#### Scenario: Editing the new viewer
- **WHEN** a file in `web2/` is saved while the server runs with `--reload`
- **THEN** open pages of the new viewer reload
