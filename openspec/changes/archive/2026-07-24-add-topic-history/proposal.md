## Why

The bundle diff page answers "what did this run change?" across all topics, but there is no way to ask the other question: "what has happened to *this topic* over time?" When a download link looks wrong or an LLM answer looks stale, the person debugging wants that topic's story — which runs touched it, and what each one changed. The snapshots that can answer this are already saved (`qb_data/bundles/`, one per publishing run); nobody reads them one topic at a time yet.

## What Changes

- A new per-topic history page in the viewer, reached from the thread page. It shows a log, newest first, of the runs whose saved bundle changed that topic — like a git log for one file.
- Each log entry collapses to a plain-words summary of what changed ("post text, downloads, last post") and expands to the full diff. List fields (downloads, LLM facts) diff item by item — added, removed, and changed entries — not as two JSON blobs.
- When the topic's on-disk data is newer than the published bundle, the log starts with an "on disk now, not published" entry, with the existing Rebuild bundle button.
- A new viewer API route that builds one topic's history by walking the kept snapshots, with its own small cache (the existing two-slot snapshot cache is sized for the compare page and would thrash).
- History only reaches as far as the kept snapshots (`qb_bundles_to_keep`, default 500 — about eight months on the production schedule). The page says where history ends. No scraper changes, no new files on disk.

## Capabilities

### New Capabilities

- `topic-history`: one topic's history across the saved bundle snapshots — the server side that builds it and the page that shows it, including how the page is reached and what it says when there is nothing to show.

### Modified Capabilities

<!-- none — the bundle-comparison and bundle-run-history requirements are unchanged; this reads what they already save -->

## Impact

- `lib/viewer/bundle_views.dart` — a topic-history builder beside `compareBundles`, reusing `topicsOf`, `bundleFields` and `changedFields`.
- `lib/viewer/api.dart` — one new route, e.g. `GET /topics/<id>/history`.
- `lib/viewer/data_access.dart` — a per-topic history cache, dropped when the snapshot list changes.
- `web/views/` — a new history view module; `bundle.js` gains a History button on the thread page; `app.js` routes `#/topics/<id>/history` and `#/bundle/<id>/history` to it.
- `web/style.css` — the log rail (dots and line) and diff styling.
- No config changes, no scraper changes, no new on-disk files.
