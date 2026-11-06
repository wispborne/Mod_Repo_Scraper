## ADDED Requirements

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
