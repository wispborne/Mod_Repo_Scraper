## 1. Pin today's behaviour first

- [x] 1.1 Write a test that runs the ModRepo pipeline end to end from small fake source caches and checks the files written (`ModRepo.json`, `merge-debug.json`), so the move out of `main()` can be judged against it
- [x] 1.2 Write a test that a debug-off run writes neither file

## 2. Job kinds and settings

- [x] 2.1 Add `mergeModRepo` and `scrapeAndMerge` to `JobKind` in `lib/manager/job.dart`
- [x] 2.2 Add the merge fields to `JobRequest`: which sources, forum page counts, whether to replay the Discord raw cache, `keepAllGameVersions`, `collectMergeDebug` — with `JobRequest.mergeModRepo()` and `JobRequest.scrapeAndMerge()` factories
- [x] 2.3 Regenerate `job.mapper.dart` (`dart run build_runner build --delete-conflicting-outputs`)
- [x] 2.4 Add `ModRepoEnvironment` and `ModRepoGuardrails` to `lib/manager/scraper_settings.dart`, with `fromConfig` factories reading only environment and guardrail keys
- [x] 2.5 Test: a `JobRequest` round-trips through the mapper with the new fields, and no merge field names a path or a token

## 3. Snapshot store

- [x] 3.1 Add `lib/manager/merge_snapshot_store.dart`: save (gzip, no indentation, `merges/<run id>.json.gz`), list newest first with headline counts, read one by id, trim to `modrepo_merges_to_keep`
- [x] 3.2 Add `modrepo_merges_to_keep` to `BotConfig`, `Common._recognizedKeys` and `config.example.properties` (default 20, 0 keeps everything)
- [x] 3.3 Test: the trim drops only the oldest snapshots, never a run that has not ended, never a file outside `merges/`, and never a data, cache or output file
- [x] 3.4 Test: a missing or unreadable snapshot reads back as missing, not as a crash

## 4. The ModRepo service

- [x] 4.1 Add `lib/manager/modrepo_service.dart` implementing `JobRunner` for the two merge kinds, moving the scrape-and-merge code out of `main_repo_scraper.dart` as it goes
- [x] 4.2 Report phases (each source, merge, save) and merged-so-far counts through `RunReporter`
- [x] 4.3 Check the cancel token between sources and between merge phases; a cancelled run writes no output and no snapshot, and says so in the log
- [x] 4.4 Skip a requested source with no token, logging why, without failing the job
- [x] 4.5 Write `ModRepo.json`, `merge-debug.json` and the snapshot on success
- [x] 4.6 Add `JobRouter implements JobRunner` sending each request to the QB or the ModRepo service by kind, and give `JobManager` the router
- [x] 4.7 Test: a cancelled merge leaves `ModRepo.json` untouched but keeps source caches already written
- [x] 4.8 Test: `mergeModRepo` makes no network request

## 5. CLI hands the job over

- [x] 5.1 Replace the inline ModRepo block in `MainRepoScraper.main` with a request built from config plus a submit, mirroring `_runQbThroughManager`
- [x] 5.2 Let a merge job delegate to `qb_manager_url` on the same terms as the QB job
- [x] 5.3 Check the tests from section 1 still pass unchanged

## 6. Web API

- [x] 6.1 `GET /api/merge/runs` — list saved merges (id, time, headline counts)
- [x] 6.2 Make the existing merge endpoints take an optional `run` id, defaulting to the newest and falling back to `merge-debug.json`
- [x] 6.3 `GET /api/merge/groups/<id>/fields` — the per-field before-and-after table, with the winning source derived from the recorded merge steps and "couldn't tell" where it cannot be pinned down
- [x] 6.4 `GET /api/merge/compare?a=&b=` — added / gone / changed / same-count, keyed by forum topic then normalized name and authors, searchable and paged, cached in memory by the two ids
- [x] 6.5 Let the manager API accept the two new job kinds
- [x] 6.6 Test: no merge endpoint returns a whole snapshot, and none serves a config value
- [x] 6.7 Test: comparing a merge with itself reports nothing added, gone or changed

## 7. Frontend

- [x] 7.1 Add a run picker to every merge page in `web/views/merge.js`, kept while moving between the merge views
- [x] 7.2 Add the before-and-after page, reachable from a group
- [x] 7.3 Add the what-changed page: pick two merges, counts, searchable paged lists
- [x] 7.4 Add `describeJob` sentences for the two merge kinds in `web/manager.js`, saying plainly what a scraping merge will do
- [x] 7.5 Add the start-a-merge panel to `web/views/runs.js`, redrawn only when the manager goes on or off
- [x] 7.6 Check that with the manager off the merge views read fine and draw no buttons

## 8. Finish

- [x] 8.1 Update `CLAUDE.md`: the ModRepo pipeline is no longer inline, the two new job kinds, `merges/`, the new config key
- [x] 8.2 Run `dart test` and check the whole suite passes — 374 tests, all passing
- [x] 8.3 Run the viewer against real data and walk the three new views by hand — the server was run against two real merges and every new endpoint checked, but nobody has clicked through the pages in a browser yet
