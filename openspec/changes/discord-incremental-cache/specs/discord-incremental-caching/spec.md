## ADDED Requirements

### Requirement: Saved Discord result cache

The Discord scraper SHALL keep a saved cache, on disk, of the parsed mod result for each thread it has scraped. Each cached entry SHALL be keyed by the thread id and SHALL store the parsed mod together with a change fingerprint for that thread. The fingerprint SHALL be built only from data the thread listing already returns (the thread's last message id, its message count, and its thread timestamp), so building the fingerprint costs no extra API calls.

This cache SHALL be a separate, higher layer from the existing raw-HTTP record/replay cache (`discord_raw_cache.json`); the two SHALL NOT be conflated.

#### Scenario: First run with no cache file

- **WHEN** the Discord scraper runs and no saved Discord result cache file exists
- **THEN** it scrapes every thread fully, parses each into a mod, and writes a cache entry for each thread holding the parsed mod and its fingerprint

#### Scenario: Cache written after a successful run

- **WHEN** a Discord run finishes without error
- **THEN** the saved cache on disk reflects the threads seen this run, each with its current fingerprint and parsed mod

### Requirement: Cache is written as the run goes

The scraper SHALL write the cache to disk as threads are scraped, not only once the whole run has finished. The whole point of this cache is to avoid re-fetching threads, so a run that is interrupted or fails part-way SHALL keep the threads it had already fetched and parsed. Writing MAY be batched (a few threads at a time) rather than on every single thread.

#### Scenario: An interrupted run keeps the threads it fetched

- **WHEN** a Discord run is interrupted or fails after fetching and parsing some threads
- **THEN** the saved cache on disk holds entries for the threads it had already finished, and the next run reuses them instead of fetching them again

#### Scenario: A failed run still saves

- **WHEN** a Discord run ends with an error
- **THEN** the cache is still written before the run gives up, so the work done before the error is not thrown away

### Requirement: Re-fetch only changed threads

On a run where the cache is used, the scraper SHALL list the channel's threads, then for each listed thread compare its current fingerprint to the cached fingerprint. When the fingerprints match, the scraper SHALL reuse the cached parsed mod and SHALL NOT make the per-thread channel-info call, the messages call, or the reaction checks for that thread. When a thread is new, or its fingerprint differs, the scraper SHALL fetch and parse it fully and update its cache entry.

#### Scenario: Unchanged thread is reused

- **WHEN** a listed thread's current fingerprint equals its cached fingerprint
- **THEN** the scraper reuses the cached mod for that thread and makes no per-thread messages or reaction API calls for it

#### Scenario: Changed thread is re-fetched

- **WHEN** a listed thread's current fingerprint differs from its cached fingerprint (for example a new message was posted)
- **THEN** the scraper fetches that thread's messages, re-parses it, and replaces its cache entry with the new mod and new fingerprint

#### Scenario: New thread is fetched

- **WHEN** a listed thread has no cache entry
- **THEN** the scraper fetches and parses it fully and adds a cache entry for it

### Requirement: Drop threads that no longer exist

When a run completes using the cache, the scraper SHALL remove cache entries for threads that were not present in the current channel listing, so mods whose threads were deleted or removed do not linger in later runs' output.

#### Scenario: Deleted thread is dropped

- **WHEN** a thread that had a cache entry is no longer returned by the channel listing
- **THEN** its cache entry is removed and its mod is not included in this run's Discord results

### Requirement: Force a full refresh

The scraper SHALL support a way to ignore the saved cache for a single run (a forced full refresh). On a forced full refresh, every thread SHALL be fetched and parsed fully, and the cache SHALL be rewritten from the fresh results.

#### Scenario: Forced full refresh ignores fingerprints

- **WHEN** a forced full refresh is requested for a run
- **THEN** the scraper fetches and parses every thread regardless of matching fingerprints, and overwrites the cache with the fresh results

### Requirement: Cache is opt-in and does not change output shape

Using the saved Discord result cache SHALL be controlled by configuration and SHALL default to off, so existing runs behave unchanged unless the cache is enabled. When enabled, the mods produced for unchanged threads SHALL be the same as if they had been freshly scraped; enabling the cache SHALL NOT change the shape or content of the merged output for unchanged threads.

#### Scenario: Cache disabled behaves as before

- **WHEN** the Discord result cache is not enabled in configuration
- **THEN** the scraper fetches every thread every run, exactly as it did before this change

#### Scenario: Reused mod matches a fresh scrape

- **WHEN** an unchanged thread's mod is reused from the cache
- **THEN** that mod is identical to what a fresh scrape of the same thread would have produced

### Requirement: Known limit — undetected message edits

The fingerprint is built from the thread's last message id, message count, and timestamp, none of which change when an existing message is edited in place without posting a new message. The scraper SHALL treat such in-place edits as not detected between runs; they SHALL be picked up only on a forced full refresh. This limit SHALL be documented for operators.

#### Scenario: In-place edit is missed until forced refresh

- **WHEN** an existing message in a thread is edited but no new message is posted, so the fingerprint is unchanged
- **THEN** the ordinary cached run reuses the old parsed mod, and the edit is reflected only after a forced full refresh
