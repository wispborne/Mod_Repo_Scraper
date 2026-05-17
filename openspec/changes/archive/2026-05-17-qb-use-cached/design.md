## Context

The main repo scraper uses `CachingClient` (a `BaseClient` wrapper) to record/replay raw HTTP responses for Discord. The QB scraper currently always hits the network via `ThrottledClient`, which wraps an `http.Client` and adds per-request delay + User-Agent headers. The config property `qb_use_cached` is already read into `BotConfig.qbUseCached` but never checked in the QB pipeline.

`ThrottledClient` accepts an optional `client` parameter in its constructor, making it straightforward to inject a `CachingClient` as the inner client.

## Goals / Non-Goals

**Goals:**
- When `qb_use_cached=true` and a cache file exists, the QB scraper replays cached HTTP responses with zero network I/O.
- When `qb_use_cached=true` and no cache file exists (or `qb_use_cached=false`), all HTTP responses are recorded to a cache file during a live scrape.
- Cache file lives alongside existing QB data at `<qb_data_path>/qb_raw_cache.json`.
- Minimal code changes — reuse existing `CachingClient` as-is.

**Non-Goals:**
- Caching the download resolver's HTTP calls (it has its own fingerprint-based cache already).
- Partial/incremental cache invalidation (the whole cache file is used or regenerated).
- Changing `CachingClient` itself (it already supports the needed record/replay pattern).

## Decisions

### 1. Inject `CachingClient` as `ThrottledClient`'s inner client

**Choice:** Pass a `CachingClient` instance as the `client` parameter of `ThrottledClient`, so the throttle wrapper still adds User-Agent and delay (recording mode) or just User-Agent (replay mode, where delay is moot since no network is hit).

**Alternative considered:** Bypass `ThrottledClient` entirely in replay mode and pass `CachingClient` directly to `QbScraperEngine`. Rejected because `ThrottledClient.get()` adds the User-Agent header, and the URL key used by `CachingClient` includes the full URL — the layer composition works naturally.

### 2. Always record when running live (regardless of `qb_use_cached` flag)

**Choice:** When `qb_use_cached=false`, still wrap with `CachingClient` in recording mode and save the cache. This mirrors what Discord does (`else if (config.useCached)` branch) but extends it — always having a cache file means you can flip the flag to `true` on the next run without a special "first recording run."

**Alternative considered:** Only record when `qb_use_cached=true` (matching Discord's exact 3-branch pattern). Rejected because the user's stated goal is "always cache raw results" so devs can iterate freely.

### 3. Cache file location: `<qb_data_path>/qb_raw_cache.json`

**Choice:** Store inside the QB data directory (e.g., `qb_data/qb_raw_cache.json`), co-located with the other QB artifacts like `mods-index.json` and `assumed-downloads-cache.json`.

**Alternative considered:** Store at project root alongside `discord_raw_cache.json`. Rejected because QB data is already organized under its own directory, and putting the cache there keeps things tidy.

### 4. Wire the logic in `main_repo_scraper.dart`, not inside `QbScraperEngine`

**Choice:** Construct the `CachingClient` and handle save-after-scrape in `main_repo_scraper.dart`'s QB pipeline section, keeping `QbScraperEngine` agnostic to caching. This matches how Discord caching is handled (orchestrator-level concern).

**Alternative considered:** Push caching logic into `QbScraperEngine`. Rejected because the engine shouldn't know about dev-time caching; it just uses whatever client it's given.

## Risks / Trade-offs

- **Cache file size:** The QB scraper can hit hundreds of pages. Cache files may be 10-50 MB. → Acceptable for a dev-only feature; `.gitignore` already covers `qb_data/`.
- **Stale cache:** If the forum changes, cached data is stale. → Expected and desired — the whole point is deterministic replay. Devs delete the cache file to re-record.
- **Replay ordering:** `CachingClient` replays by matching `"GET <url>"` keys with forward scanning. The QB scraper's URL access order is deterministic (same boards, same pagination), so replay will match. → Low risk.
- **ThrottledClient delay in replay mode:** The throttle delay still applies even in replay mode (no network wait, but the artificial delay remains). → Could be skipped by setting `delayMs: 0` when replaying. Worth doing for instant dev iteration.
