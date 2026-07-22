# qb-raw-http-caching

## Purpose

Keep a copy of every page the forum scrape fetched, so a later run can be replayed from disk at full speed without touching the forum again.
## Requirements
### Requirement: QB scraper records raw HTTP responses to a cache file
The system SHALL save all raw HTTP responses made during QB board scraping and topic scraping to a JSON cache file at `<qb_data_path>/qb_raw_cache.json` after every live (non-replaying) scrape run.

#### Scenario: First run with no existing cache
- **WHEN** the QB pipeline runs live (cache file does not exist)
- **THEN** all HTTP request/response pairs are recorded in memory and written to `<qb_data_path>/qb_raw_cache.json` after the scrape completes

#### Scenario: Live run overwrites stale cache
- **WHEN** the QB pipeline runs live and an old cache file already exists
- **THEN** the old cache file is overwritten with the new recording

### Requirement: QB scraper replays cached responses when qb_use_cached is true
When `qb_use_cached=true` in config and a cache file exists, the system SHALL replay cached HTTP responses instead of making network calls for all QB board and topic scraping requests.

#### Scenario: Replay from existing cache
- **WHEN** `qb_use_cached` is `true` AND `<qb_data_path>/qb_raw_cache.json` exists
- **THEN** the QB scraper uses the cached HTTP responses and makes zero network requests for board/topic scraping

#### Scenario: Cache enabled but file missing
- **WHEN** `qb_use_cached` is `true` AND `<qb_data_path>/qb_raw_cache.json` does not exist
- **THEN** the QB scraper runs live, records all responses, and saves the cache file for the next run

### Requirement: Replay mode skips throttle delay
When replaying from cache, the system SHALL set the throttle delay to zero so cached responses are returned instantly without artificial delays.

#### Scenario: No artificial delay during replay
- **WHEN** the QB scraper is operating in replay mode
- **THEN** `ThrottledClient` is configured with `delayMs: 0` so responses are returned without waiting

### Requirement: Download resolver HTTP calls are not cached by this mechanism
The `CachingClient` SHALL only wrap the `ThrottledClient` used for board/topic scraping. The download resolver's separate `http.Client` is unaffected.

#### Scenario: Download resolver still uses live HTTP
- **WHEN** the QB scraper is operating in replay mode
- **THEN** the download resolver's HTTP client is not wrapped in `CachingClient` and continues to use its own fingerprint-based cache independently

### Requirement: Cache file is not saved during replay
When replaying, the system SHALL NOT overwrite the cache file with replay data.

#### Scenario: Replay does not write cache
- **WHEN** the QB scraper completes a replay run
- **THEN** no write occurs to `qb_raw_cache.json`
