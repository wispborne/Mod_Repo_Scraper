# viewer-server

## Purpose

Serve the results website from a small local server that reads the output files and never gives away anything secret, so a run's results can be looked at on this machine and stay up to date without a restart.
## Requirements

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

### Requirement: Server-side search, filter, and pagination
List endpoints SHALL accept query parameters for text search, filters, sorting, and pagination, and SHALL return only the requested page of results. A `pageSize` of 0 SHALL mean "every matching row, on one page", and SHALL be given only when a caller asks for it — the built-in answer stays a page at a time. A `pageSize` above the server's cap SHALL be capped, and one that cannot be read as a number SHALL fall back to the built-in page size. The server MUST NOT expose an endpoint that returns `forum-data-bundle.json` or all per-topic details in a single response.

#### Scenario: Paged topic search
- **WHEN** the client requests the topic list with a search term and page number
- **THEN** the response contains only the matching rows for that page plus the total match count

#### Scenario: Everything on one page
- **WHEN** the client asks a list endpoint for `pageSize=0`
- **THEN** every matching row comes back in one response, with `page` and `pageSize` both 0 so the caller knows there is nothing left to page through

#### Scenario: An unreadable or enormous page size
- **WHEN** the client asks for a `pageSize` that is negative, not a number, or larger than the cap
- **THEN** the server uses the built-in page size for the first two and the cap for the third, and never fails the request

### Requirement: Fresh data without server restart
The server SHALL serve data reflecting the files currently on disk. Parsed large files MAY be cached in memory, but the cache MUST be invalidated when the file's modification time changes.

#### Scenario: Scraper run updates the data
- **WHEN** a scraper run rewrites `mods-index.json` while the viewer server is running
- **THEN** the next topic-list request reflects the new file contents

### Requirement: Secrets stay off the wire
The server MAY read `config.properties`, but only to build the manager core's environment and guardrails; it MUST NOT serve any value from it over HTTP (the manager's data path is the one allowed exception). Every file-serving endpoint MUST resolve only files from a fixed allowlist of known output files, plus run logs by run id under the runs folder. Requests for paths outside these SHALL be rejected.

#### Scenario: Arbitrary path is rejected
- **WHEN** a client requests a raw file by a path not on the allowlist (for example `config.properties` or a path containing `..`)
- **THEN** the server responds with an error and does not return file contents

#### Scenario: Config values never appear in responses
- **WHEN** any endpoint is called on a server that read a config file holding tokens and endpoints
- **THEN** no response contains those values

### Requirement: Every list lets the reader choose how many rows a page holds
Every paged list in the viewer SHALL offer a choice of rows per page — including all of them on one page — next to its page buttons. The choice SHALL be one setting for the whole site, remembered in the browser between views and across reloads. With every row on one page, the page buttons SHALL NOT be drawn, and the row SHALL say how many rows are being shown rather than which page of how many.

#### Scenario: Reading a long list in one go
- **WHEN** the user picks "all on one page" on the ModRepo list
- **THEN** every matching mod is shown, no page buttons are drawn, and the row says how many there are

#### Scenario: The choice sticks
- **WHEN** the user picks 250 rows on one list and then opens another list, or reloads the page
- **THEN** that list also shows 250 rows a page

#### Scenario: Changing the size goes back to the first page
- **WHEN** the user is on page 4 and changes the rows per page
- **THEN** the list reloads at the first page, so the rows on screen are the ones the new setting describes
