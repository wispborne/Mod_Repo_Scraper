## Why

The QB scraper processes hundreds of forum topics from external sources but has no per-item error isolation. A single bad URL, malformed HTML element, or unexpected null crashes the entire scraping process. This was triggered by `Invalid URL encoding` on one Bitbucket URL, but the same class of problem exists across the QB download resolver, scraper engine, and mod index scraper.

## What Changes

- **QB download resolver**: Add safe URL decode helper for `Uri.decodeFull` calls; wrap `Future.wait` in `resolveForTopic` with per-URL error handling.
- **QB scraper engine**: Add per-topic try-catch in the pipelined batch loop and around `Future.wait(pending)` so one topic failure doesn't crash the job.
- **QB mod index scraper**: Add per-post try-catch in category extraction loop.
- **All sites**: Log warnings for skipped items so problems are visible without halting the pipeline.

## Capabilities

### New Capabilities

- `scraper-error-isolation`: Per-item error isolation across the QB scraper package — any single topic/URL/post processing failure is caught, logged, and skipped.

### Modified Capabilities

- `qb-download-resolution`: URL parsing and resolution must gracefully handle malformed data instead of throwing unhandled exceptions.

## Impact

- **Code**: `lib/bot/scraper/qb/download_resolver.dart`, `lib/bot/scraper/qb/scraper_engine.dart`, `lib/bot/scraper/qb/mod_index_scraper.dart`
- **Behavior**: Individual item failures are logged as warnings and skipped. The scraper completes its full run and produces output for all topics that succeeded. No change to output format.
