## 1. Share the comparison code

- [x] 1.1 Pull the row-matching, field-comparing and counting out of `compareMerges` in `lib/viewer/merge_views.dart` into a `compareRows({older, newer, keyOf, fields, labelOf, authorOf})` helper
- [x] 1.2 Make `compareMerges` a thin caller of it, passing `modKey` and the merge field list
- [x] 1.3 Check the existing merge comparison tests pass with no changes to them — that is what says the merge behaviour is untouched

## 2. Bundle snapshots

- [x] 2.1 Add `lib/manager/bundle_snapshot_store.dart`: save (drop `contentHtml`, add `contentFingerprint`, gzip, `bundles/<run id>.json.gz`), list newest first with size and headline counts, read one by id, trim to `qb_bundles_to_keep`
- [x] 2.2 Add `qb_bundles_to_keep` to `BotConfig`, `Common._recognizedKeys` and `config.example.properties` (default 20, 0 keeps everything)
- [x] 2.3 Save a snapshot from `ScraperService._rebuildBundle()`, so every kind that publishes leaves one without knowing about snapshots
- [x] 2.4 Test: a snapshot holds no post HTML, carries a fingerprint per detail, and the fingerprint changes when the post text does
- [x] 2.5 Test: the trim drops only the oldest snapshots, never a run that has not ended, never a file outside `bundles/`, and never a data, cache or output file
- [x] 2.6 Test: a missing or unreadable snapshot reads back as missing, not as a crash
- [x] 2.7 Test: a job kind that publishes no bundle leaves no snapshot

## 3. Web API

- [x] 3.1 `GET /api/bundle/runs` — list saved bundle snapshots (id, time, size, headline counts)
- [x] 3.2 `GET /api/bundle/compare?a=&b=` — added / gone / changed / same-count, keyed by topic id, searchable and paged, cached in memory by the two ids
- [x] 3.3 Add `lib/viewer/bundle_views.dart` with the bundle field list and the per-field comparing, including the "the post text changed" wording
- [x] 3.4 Test: comparing a snapshot with itself reports nothing added, gone or changed
- [x] 3.5 Test: a re-scrape that only moved `scrapedAt` counts as unchanged
- [x] 3.6 Test: no bundle endpoint returns a whole snapshot, and none serves a config value

## 4. Frontend

- [x] 4.1 Add `web/views/bundle_compare.js`: pick two runs, counts, searchable paged lists, with the page-size box like every other list
- [x] 4.2 Add a what-changed tab and a run picker to `web/views/bundle.js`
- [x] 4.3 Say plainly on the page that the old post text is not kept, so nobody hunts for a before-and-after that was never saved
- [x] 4.4 Add the "what this run changed" link to `web/views/run.js`, shown only when that run has a snapshot and an older one exists
- [x] 4.5 Check the page reads fine with the manager off

## 5. Finish

- [x] 5.1 Update `CLAUDE.md`: `bundles/`, the new config key, and the shared comparison helper
- [x] 5.2 Run `dart test` and check the whole suite passes
- [x] 5.3 Run two real QB jobs and compare their bundles by hand
