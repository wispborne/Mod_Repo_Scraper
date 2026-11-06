## Why

The new viewer's frame is in place (`viewer-v2-shell`), but its first page, Control, is still a placeholder. Control is the page the viewer opens on and the one used most: it starts jobs, shows the run in progress, and lists what needs attention. `docs/viewer-redesign-requirements.md` describes it under **Operate → Control**. It also asks for a "Run LLM: All" choice, which the server cannot do yet.

## What Changes

- The Control page of the new viewer is built:
  - **Job buttons in the toolbar.** "Fetch and update" (the most prominent), "Run LLM", "Rebuild from saved" and "Publish". "Fetch and update" and "Run LLM" each have a drop-down for their options, using today's defaults. A "More" menu holds "Scan images" and "Match dependency names". Every job requires confirmation in a dialog that describes the job in one sentence.
  - **The run panel** in the centre: the running job with its progress, live counters (errors, LLM calls), Stop, and tabs for its Log, what it changed, and its Record. When nothing runs, the panel shows the last run with "Run again".
  - **Side panels:** Needs attention, Queue (with a way to see each waiting job) and Recent runs.
  - **Needs attention** lists only items with a count above zero, each linking to where it can be fixed: unmatched dependency names, undecided author pairs, takedown entries that excluded nothing or whose mod came back under a new id, posts with no LLM answer, the last run's errors, and mods with no download. The panel is hidden when there are none.
  - With the manager off, the page says "Viewing only" and how to turn the manager on, and shows no job buttons.
- **"Run LLM: All"** is a new option on the LLM catch-up job. It reads every forum topic and Discord thread again, oldest saved answer first, up to the per-run LLM call limit. The next "All" run continues from where a run reached the limit. "Only changed" stays the default and works as today.
- Saved LLM answers now record when they were made. Answers saved before this have no time and count as the oldest.
- A new read-only route, `GET /api/attention`, gives the Needs attention counts.
- The Pending changes panel is not part of this change. It comes with the corrections pages, which are the first thing to write pending changes.

## Capabilities

### New Capabilities
- `viewer-v2-control`: the new viewer's Control page.

### Modified Capabilities
- `scraper-jobs`: the LLM catch-up job can read every post again ("All").
- `qb-llm-post-extraction`: saved answers record when they were made.
- `viewer-server`: a read-only route gives the Needs attention counts.

## Impact

- `lib/manager/job.dart` (new request field, regenerated mapper), `lib/manager/scraper_service.dart` (the pass in "All" mode), `lib/bot/scraper/qb/llm/extraction_store.dart` and `post_extractor.dart` (answer time, re-read check).
- `lib/viewer/api.dart` and a new `lib/viewer/attention.dart` for the counts.
- `web2/views/control.js`, a new `web2/jobs.js` (job requests and their confirm sentences, no DOM), `web2/style.css`.
- Tests for the "All" pass, the answer time, the attention counts, and the job sentences.
- The old viewer is not changed.
