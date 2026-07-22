# viewer-server (delta)

## MODIFIED Requirements

### Requirement: Local read-only viewer server
The system SHALL provide a Dart entry point `bin/viewer_server.dart` that starts an HTTP server bound to `127.0.0.1`, serving the static frontend from `web/` and a JSON API over the scraper's output files. Data locations and port SHALL come from command-line flags with defaults matching the current layout (`--port 8085`, `--data-dir qb_data`, `--outputs-dir outputs`, `--root-dir .`). Viewer endpoints MUST NOT modify, create, or delete any scraper data file; the only writes the server ever makes go through the manager core, as jobs requested on the management API.

#### Scenario: Server starts and serves the UI
- **WHEN** the user runs `dart run bin/viewer_server.dart` with no flags
- **THEN** the server listens on `127.0.0.1:8085`, prints the URL, and serves the viewer home page at `/`

#### Scenario: Custom data directory
- **WHEN** the user passes `--data-dir some_other_dir`
- **THEN** topic and cache endpoints read from that directory instead of the default

#### Scenario: Expected file missing from disk
- **WHEN** an endpoint's backing file does not exist
- **THEN** the response is a well-formed "missing" JSON envelope naming the file, and the server does not crash

#### Scenario: Viewer endpoints never write
- **WHEN** any viewer (non-manager) API endpoint is called
- **THEN** no file under the scraper's data or output directories is created, modified, or deleted

### Requirement: Secrets stay off the wire
The server MAY read `config.properties`, but only to build the manager core's environment and guardrails; it MUST NOT serve any value from it over HTTP (the manager's data path is the one allowed exception). Every file-serving endpoint MUST resolve only files from a fixed allowlist of known output files, plus run logs by run id under the runs folder. Requests for paths outside these SHALL be rejected.

#### Scenario: Arbitrary path is rejected
- **WHEN** a client requests a raw file by a path not on the allowlist (for example `config.properties` or a path containing `..`)
- **THEN** the server responds with an error and does not return file contents

#### Scenario: Config values never appear in responses
- **WHEN** any endpoint is called on a server that read a config file holding tokens and endpoints
- **THEN** no response contains those values
