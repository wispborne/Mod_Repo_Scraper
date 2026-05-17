## 1. Wire CachingClient into QB pipeline

- [x] 1.1 In `main_repo_scraper.dart`, construct the QB cache file path as `File('${config.qbDataPath}/qb_raw_cache.json')`
- [x] 1.2 Add caching client logic before `ThrottledClient` construction: if `qbUseCached && cache exists` → load `CachingClient.fromFile`; otherwise create `CachingClient(http.Client())` in recording mode
- [x] 1.3 Pass the `CachingClient` (or recording client) as the `client` parameter to `ThrottledClient`
- [x] 1.4 When replaying, set `ThrottledClient(delayMs: 0, client: cachingClient)` to skip artificial delays

## 2. Save cache after live scrape

- [x] 2.1 After `qbEngine.run()` completes, check if the inner client is a `CachingClient` that is not replaying
- [x] 2.2 If recording, call `cachingClient.saveToFile(qbCacheFile.path)` to persist the raw HTTP cache
- [x] 2.3 Log a message indicating cache save (or replay skip) for observability

## 3. Verify and test

- [x] 3.1 Run with `qb_use_cached=false` (or `true` with no cache file) and confirm `qb_raw_cache.json` is created in the QB data directory
- [x] 3.2 Run with `qb_use_cached=true` and confirm zero network calls are made — scraper replays instantly from cache
- [x] 3.3 Confirm download resolver still operates independently (not wrapped by CachingClient)
- [x] 3.4 Confirm replay mode does not overwrite the existing cache file
