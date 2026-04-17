## 1. Separate HTTP clients

- [x] 1.1 Change `QbDownloadResolver` to accept an `http.Client` instead of `ThrottledClient`. Update constructor, `_resolveLink`, `_followRedirect`, `_resolveGitHubReleasesPage`, `_resolveGoogleDrive`, and `_resolveMediaFire` to use the new client.
- [x] 1.2 Update `QbScraperEngine` to create an unthrottled `http.Client` (with 30s timeout) and pass it to `QbDownloadResolver` while keeping `ThrottledClient` for forum scrapers.
- [x] 1.3 Update `qb_smoke_test.dart` and `qb_download_smoke_test.dart` to wire the new client parameter.

## 2. Concurrent link resolution

- [x] 2.1 In `QbDownloadResolver.resolveForTopic()`, replace the sequential `for` loop (lines 201-206) with `Future.wait(externalLinks.map(_resolveLink))`, collecting non-null results after all futures complete.
- [x] 2.2 Verify post-processing (`_extractFilenames`, `_inferFilenames`, `_filterNonArchives`, `_dedup`) still runs correctly after concurrent resolution (it operates on the collected list, so no change expected).

## 3. Pipelined topic loop

- [x] 3.1 Extract the per-topic processing block (lines 224-284 in `scraper_engine.dart`: HTML processing, detail save, `onTopicSaved` callback, index bookkeeping) into a private async method `_processTopicDetail`.
- [x] 3.2 Restructure the topic loop: after each `await topicScraper.scrapeTopic()`, launch `_processTopicDetail` as a non-awaited `Future` and add it to a bounded pending list (max 3).
- [x] 3.3 When the pending list is full, `await` the oldest future before starting the next forum fetch. After the loop, `await Future.wait(pending)` to drain.
- [x] 3.4 Ensure `currentJob.processedTopics`, `currentJob.errors`, and `indexMap` updates happen inside each future (safe in single-isolate Dart).

## 4. Verification

- [ ] 4.1 Run the existing smoke test (`bin/qb_smoke_test.dart`) with a small scope (e.g., 5 topics) and confirm output matches expectations.
- [x] 4.2 Add a timing comparison log line at the end of `run()` showing wall-clock time, to make speedup observable.
