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
- **WHEN** the user picks "all on one page" on the Mods list
- **THEN** every matching mod is shown, no page buttons are drawn, and the row says how many there are

#### Scenario: The choice sticks
- **WHEN** the user picks 250 rows on one list and then opens another list, or reloads the page
- **THEN** that list also shows 250 rows a page

#### Scenario: Changing the size goes back to the first page
- **WHEN** the user is on page 4 and changes the rows per page
- **THEN** the list reloads at the first page, so the rows on screen are the ones the new setting describes

### Requirement: Counts of what needs attention
The server SHALL answer `GET /api/attention` with counts read from saved files: dependency names that matched no mod, suggested author pairs not yet decided, takedown entries that excluded nothing, taken-down mods that came back under a new id, saved posts with no LLM answer (forum topics that are not placeholders, and Discord threads), and published mods with no download. A count whose file is missing SHALL be left out of the answer. The route SHALL NOT write anything.

#### Scenario: Nothing needs attention
- **WHEN** every file is present and nothing needs attention
- **THEN** every count in the answer is 0

#### Scenario: A file is missing
- **WHEN** `requirement-names-report.json` does not exist
- **THEN** the answer has no dependency name count, and the other counts are still given

### Requirement: The config file is read again before each job
Before starting each job, the server SHALL check whether `config.properties` has changed since it was last read and, if so, read it again and use the new settings for that job and subsequent jobs. A running job SHALL keep the settings it started with. A file that cannot be read SHALL leave the last good settings in use and SHALL be logged. `qb_data_path` and `log_level` SHALL take effect only after a restart.

#### Scenario: A limit changed between jobs
- **WHEN** `llm_max_topics` is changed from 200 to 300 while no job runs, and a job starts
- **THEN** that job uses 300, without the server restarting

#### Scenario: Changed during a job
- **WHEN** the file is changed while a job runs
- **THEN** that job keeps its settings, and the next job uses the new ones

### Requirement: One list of source posts
The server SHALL answer `GET /api/posts` with forum topics and Discord threads in one paged list, with search, a kind filter, the data quality filters (no download found, no LLM answer, placeholder) and filters by outcome, sorting, and the usual page size rules. Each row SHALL carry its kind, id, title, author, last post date, download count, whether it has an LLM answer, whether it is a placeholder, its outcome code and how many mods it gave. The answer SHALL also carry the data quality counts over every saved post, regardless of the filters.

#### Scenario: Both kinds
- **WHEN** the client asks for `kind=all` with no filters
- **THEN** the rows include forum topics and Discord threads, and `total` counts both

#### Scenario: Counts do not follow the filter
- **WHEN** the client asks with `filters=noDownload`
- **THEN** `counts` are the same as with no filter

### Requirement: What happened to a source post
The server SHALL answer `GET /api/posts/outcome` for a forum topic or a Discord thread with the result of the last build: the mods it became, a Collection page, left out (with the reason when the build saved one), pointing to another post, taken down, or not in the last build. The answer SHALL include one plain sentence saying so. The route SHALL be read-only.

#### Scenario: A post with several mods
- **WHEN** the client asks about topic 34161, which became four mods
- **THEN** `outcome` is `mods`, `mods` lists the four, and `line` starts "Became 4 mods:"

#### Scenario: Unknown post
- **WHEN** the client asks about a topic that is in no build
- **THEN** `outcome` is `notInBuild` and `line` says it is not in the last build

### Requirement: Mods over HTTP
The server SHALL answer `GET /api/mods` with every mod in the last build as a paged, searchable, filterable list; `GET /api/mods/<id>` with one mod's catalog record, published record, source posts (with how each joined, when the build recorded it), the source of each fact, old ids that lead to it, its takedown status and its unmatched requirements; and `GET /api/mods/<id>/history` with the saved runs in which the mod changed and which fields changed. An id that only leads to another mod SHALL answer with the mod it leads to. A Collection's id SHALL answer as a Collection. The routes SHALL only read data.

#### Scenario: A moved id
- **WHEN** the client asks for an old id that now leads to another mod
- **THEN** the answer says `moved` and names the mod it leads to

#### Scenario: Where a fact came from
- **WHEN** the client asks for a mod whose mod version came from its Discord thread
- **THEN** the mod version's source names that Discord thread and its LLM name

### Requirement: The build records where each fact came from
When the website is built, the source of each chosen fact SHALL be saved for every mod in `<qb_data_path>/fact-sources.json`, with the build's time. The file SHALL never be published, and SHALL be read only when its build time matches the catalog's.

#### Scenario: After a rebuild
- **WHEN** Rebuild from saved finishes
- **THEN** `fact-sources.json` has an entry for every mod, with the same build time as the catalog

### Requirement: Search over HTTP
The server SHALL answer `GET /api/search?q=` with up to a few matches of each kind — mods (by name, nickname, author or permanent id), forum topics (by id or title), Discord threads (by id or name) and runs (by id) — best matches first, with the total number of matches of each kind. Searches with fewer than two characters SHALL return empty groups. The route SHALL be read-only.

#### Scenario: A nickname
- **WHEN** the client searches "IndEvo"
- **THEN** Industrial.Evolution is among the mods, with a note that it is also called IndEvo

#### Scenario: Runs with the manager off
- **WHEN** the manager is off
- **THEN** the runs group is empty and the other groups still return results

### Requirement: One viewer, and the former addresses
The server SHALL serve the viewer from `web/` at `/`. A request for `/v1` or `/v2`, or for any path under `/v1/` or `/v2/`, SHALL be redirected to the same path without that prefix, preserving the query string. A path that only starts with those letters, such as `/v2x/`, SHALL NOT be redirected.

#### Scenario: A bookmark from when two viewers were served
- **WHEN** the browser asks for `/v2/` with `#/runs` after it
- **THEN** the server redirects to `/`, and the browser opens `/#/runs`

#### Scenario: A file under the old prefix
- **WHEN** the browser asks for `/v1/style.css`
- **THEN** the server redirects to `/style.css`

### Requirement: Live reload watches the viewer
When the server is started with `--reload`, open pages SHALL reload when a file in `web/` changes.

#### Scenario: Editing the viewer
- **WHEN** a file in `web/` is saved while the server runs with `--reload`
- **THEN** open pages of the viewer reload

