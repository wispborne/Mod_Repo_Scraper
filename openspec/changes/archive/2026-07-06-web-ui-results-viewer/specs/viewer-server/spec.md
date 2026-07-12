# viewer-server

## ADDED Requirements

### Requirement: Local read-only viewer server
The system SHALL provide a Dart entry point `bin/viewer_server.dart` that starts an HTTP server bound to `127.0.0.1`, serving the static frontend from `web/` and a JSON API over the scraper's output files. Data locations and port SHALL come from command-line flags with defaults matching the current layout (`--port 8085`, `--data-dir new_data`, `--outputs-dir outputs`, `--root-dir .`), never from `config.properties`. The server MUST NOT modify, create, or delete any scraper data file.

#### Scenario: Server starts and serves the UI
- **WHEN** the user runs `dart run bin/viewer_server.dart` with no flags
- **THEN** the server listens on `127.0.0.1:8085`, prints the URL, and serves the viewer home page at `/`

#### Scenario: Custom data directory
- **WHEN** the user passes `--data-dir some_other_dir`
- **THEN** topic and cache endpoints read from that directory instead of `new_data`

#### Scenario: Expected file missing from disk
- **WHEN** an endpoint's backing file does not exist
- **THEN** the response is a well-formed "missing" JSON envelope naming the file, and the server does not crash

#### Scenario: No writes to scraper data
- **WHEN** any API endpoint is called
- **THEN** no file under the scraper's data or output directories is created, modified, or deleted

### Requirement: Server-side search, filter, and pagination
List endpoints SHALL accept query parameters for text search, filters, sorting, and pagination, and SHALL return only the requested page of results. The server MUST NOT expose an endpoint that returns `forum-data-bundle.json` or all per-topic details in a single response.

#### Scenario: Paged topic search
- **WHEN** the client requests the topic list with a search term and page number
- **THEN** the response contains only the matching rows for that page plus the total match count

### Requirement: Fresh data without server restart
The server SHALL serve data reflecting the files currently on disk. Parsed large files MAY be cached in memory, but the cache MUST be invalidated when the file's modification time changes.

#### Scenario: Scraper run updates the data
- **WHEN** a scraper run rewrites `mods-index.json` while the viewer server is running
- **THEN** the next topic-list request reflects the new file contents

### Requirement: Secrets stay off the wire
The server MUST NOT read `config.properties`, and every file-serving endpoint MUST resolve only files from a fixed allowlist of known output files. Requests for paths outside the allowlist SHALL be rejected.

#### Scenario: Arbitrary path is rejected
- **WHEN** a client requests a raw file by a path not on the allowlist (for example `config.properties` or a path containing `..`)
- **THEN** the server responds with an error and does not return file contents
