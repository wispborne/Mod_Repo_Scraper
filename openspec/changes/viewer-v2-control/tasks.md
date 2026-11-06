## 1. Run LLM: All (server)

- [x] 1.1 Add `answeredAt` to `LlmStoreEntry`: set on every new answer, kept when a fingerprint is moved, read as null from old files
- [x] 1.2 Add `llmRereadAll` to `JobRequest` and regenerate the mapper
- [x] 1.3 Give `PostExtractor` a re-read cut-off: an answer older than it, or with no time, is out of date and is never moved to a new fingerprint
- [x] 1.4 In "All" mode, walk forum topics and Discord threads as one list, oldest answer first, with the job's start as the cut-off
- [x] 1.5 Tests: new answers carry a time, old files read, "Only changed" is unchanged, "All" re-reads everything under the limit, and a capped "All" run is carried on by the next one

## 2. Needs attention counts (server)

- [x] 2.1 `lib/viewer/attention.dart`: the six counts from saved files, leaving out a count whose file is missing
- [x] 2.2 `GET /api/attention` in `lib/viewer/api.dart`
- [x] 2.3 Tests: all zero, a missing file, and each count from a small fixture

## 3. Control page (web2)

- [x] 3.1 `web2/jobs.js`: the request for each job button and the sentence each confirm dialog shows (no DOM)
- [x] 3.2 Toolbar job buttons: split buttons with option panels for "Fetch and update" and "Run LLM", plain "Rebuild from saved" and "Publish", and a "More" menu
- [x] 3.3 Sending jobs: confirm dialog, the server's own message on refusal, refresh the status after
- [x] 3.4 Run panel: running job or last run, counters, progress, Stop, Run again, and Log, What it changed and Record tabs
- [x] 3.5 Live log that keeps scroll position and selection, updated with each status poll
- [x] 3.6 Needs attention panel from `/api/attention` and the last run's errors, requested again when a run ends
- [x] 3.7 Queue and Recent runs panels, with a link to Run history
- [x] 3.8 Viewing only mode and narrow-screen layout

## 4. Checks and docs

- [x] 4.1 Node test for `web2/jobs.js`
- [x] 4.2 Check in the browser: the buttons and their options, the confirm sentences, a live run (faked in the page), the last run, the log's scroll, Needs attention, manager off, and phone width
- [x] 4.3 Update `CLAUDE.md`: "Run LLM: All", `answeredAt`, `/api/attention`, and the Control page
- [x] 4.4 Run `dart test` and fix anything that fails
