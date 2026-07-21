## 1. Config

- [ ] 1.1 Add an enable flag (default off) for the Discord result cache to `BotConfig` in `lib/bot/common.dart` and read it in `Common.readConfig()`.
- [ ] 1.2 Add a force-full-refresh flag for Discord to `BotConfig` and `readConfig()`.
- [ ] 1.3 Add both keys, documented and defaulting to off, to `config.properties`.

## 2. Cache store and model

- [ ] 2.1 Define a fingerprint type holding a thread's last message id, message count, and thread timestamp, with an equality check.
- [ ] 2.2 Create a `DiscordResultCache` store that reads/writes a versioned `discord_cache.json` mapping thread id → { fingerprint, ScrapedMod }, using `dart_mappable` for serialization.
- [ ] 2.3 Run `dart run build_runner build --delete-conflicting-outputs` to generate the `*.mapper.dart` sibling for any new `@MappableClass` model, and commit it.
- [ ] 2.4 On read/parse error or version mismatch, log and behave as if the cache were empty (fall back to full scrape).

## 3. Fingerprint from the thread listing

- [ ] 3.1 Add a pure function that builds a fingerprint from a listed `Channel` (thread), using only fields the listing already returns — no extra API call.
- [ ] 3.2 Confirm `_getThreads` exposes the lightweight per-thread metadata (last message id, message count, timestamp) before the per-thread `_getChannel` step.

## 4. Incremental scraping in DiscordReader

- [ ] 4.1 When the cache is enabled, list threads, then for each thread compare its current fingerprint to the cached one.
- [ ] 4.2 For matching threads, reuse the cached `ScrapedMod` and skip the per-thread `_getChannel`, `_getMessages`, and reaction checks.
- [ ] 4.3 For new or changed threads, fetch and parse fully (existing path) and update the cache entry with the new mod and fingerprint.
- [ ] 4.4 Build the run's Discord result from the current listing (reused + freshly scraped), and drop cache entries for threads no longer listed.
- [ ] 4.5 Honor the force-full-refresh flag: fetch every thread regardless of fingerprint and rewrite the cache.
- [ ] 4.6 Write the cache to disk as the run goes (in small batches, as `LlmExtractionStore` and `DownloadableProbeCache` do), not just at the end, so a run that is interrupted or fails keeps the threads it already fetched. Save once more at the end, on the failure path too.

## 5. Wiring

- [ ] 5.1 Pass the new config through to `DiscordReader.readAllMessages` from the Discord job in `lib/bot/scraper/main_repo_scraper.dart`, keeping the existing raw-HTTP `CachingClient` decision separate and unchanged.
- [ ] 5.2 Log per run how many threads were reused from cache vs. freshly scraped, alongside the existing API-call count.

## 6. Tests

- [ ] 6.1 Unit-test the fingerprint function and equality (changed message id, changed count, unchanged).
- [ ] 6.2 Unit-test the cache store round-trip and the version-mismatch/parse-error fallback.
- [ ] 6.3 Test incremental behavior: unchanged thread is reused (no messages/reaction calls), changed thread is re-fetched, new thread is fetched, deleted thread is dropped.
- [ ] 6.4 Test force-full-refresh fetches all threads and rewrites the cache.
- [ ] 6.5 Test that cache disabled reproduces today's full-scrape behavior.

## 7. Docs

- [ ] 7.1 Document the two new config keys and the known limit (in-place edits need a forced full refresh) in `CLAUDE.md`'s Caching section and near the config keys.
- [ ] 7.2 Note the new `discord_cache.json` as a derived cache in the caching-model description, distinct from `discord_raw_cache.json`.
