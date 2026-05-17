## Why

The QB scraper always hits the network for board pages and topic details, making iteration on scraping logic slow and subject to rate limiting. The main repo scraper already supports a `use_cached` flag that records raw HTTP responses and replays them on subsequent runs. The QB scraper needs the same capability via its existing `qb_use_cached` config property (already read into `BotConfig` but never wired up).

## What Changes

- Wrap the QB scraper's HTTP client (`ThrottledClient`) with `CachingClient` when `qb_use_cached` is enabled, mirroring the Discord scraper pattern.
- Always save raw HTTP responses to a cache file (`qb_raw_cache.json`) after a live QB scrape run.
- When `qb_use_cached` is true and the cache file exists, replay cached responses instead of making network calls.
- The download resolver's existing fingerprint-based cache (`assumed-downloads-cache.json`) is unaffected — it already avoids redundant resolution and operates independently.

## Capabilities

### New Capabilities
- `qb-raw-http-caching`: Integrate `CachingClient` into the QB scraper pipeline so that all board-page and topic-detail HTTP requests are recorded and replayable via the `qb_use_cached` config flag.

### Modified Capabilities

(none — no existing spec-level requirements change)

## Impact

- **Code**: `main_repo_scraper.dart` (QB pipeline section), `ThrottledClient` (must accept a delegate client or be bypassed), `CachingClient` (no changes expected — already generic).
- **Config**: `qb_use_cached` property in `config.properties` (already exists, just not wired).
- **Files**: New cache artifact `qb_raw_cache.json` written to the output/cache directory.
- **Behavior**: When `qb_use_cached=true` and cache exists, the QB scraper runs instantly with no network I/O. When cache doesn't exist, it records while scraping live (same as Discord pattern).
