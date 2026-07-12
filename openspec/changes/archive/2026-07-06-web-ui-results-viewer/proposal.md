# Web UI Results Viewer

## Why

The scraper produces many result files (merged mod list, forum data bundle, 889 per-topic detail files, LLM extraction cache, merge debug data, logs) and today the only ways to check them are opening raw JSON by hand or the static 2.5 MB MergeDebug.html page. There is no easy way to verify that scraped data is correct and complete — especially the new LLM post-extraction results, which need eyeball review against the original forum posts.

## What Changes

- Add a small read-only Dart web server (`bin/viewer_server.dart`, using `shelf`) that serves a plain HTML/JS frontend plus a JSON API over the scraper's output files on disk. No framework, no build step for the frontend.
- Search and filtering happen server-side; the browser never downloads whole large files (the 13 MB bundle, the 889 detail files).
- **Phase 1 — LLM verification (immediate goal):**
  - Searchable topic index over `mods-index.json` with quality filters: no download found, low-confidence downloads only, LLM-only downloads, placeholder detail, missing game version, WIP.
  - Topic inspector: rendered forum post HTML side by side with the rule-based and LLM extraction results, showing per-download provenance (`source`: rules / llm / rules+llm) and the LLM extras (changelog, mod version, support links, license).
  - Viewer for the LLM test-mode report (`llm-test-output.json`).
- **Phase 2 — Merge explorer (replaces MergeDebug.html):**
  - **BREAKING** (internal): the merge debug HTML generator is deleted. `MergeDebugCollector` stays, but its data is written as `merge-debug.json` instead of `MergeDebug.html`.
  - The web UI renders merge groups, match reasons, merge decisions, same-source dedup, pre-dedup removals, validation removals, and phase timings, all searchable.
- **Phase 3 — Output browsing and display preview:**
  - `ModRepo.json` browser with per-mod source provenance (forum / Discord / NexusMods).
  - `forum-data-bundle.json` browser showing what TriOS (the consumer) actually receives.
  - A mod-card preview approximating how TriOS displays a mod, to sanity-check end-user presentation.
  - Raw JSON file viewer and `ModRepo.log` viewer.
- Explicitly out of scope: run control (starting/stopping the scraper), config editing, and any writes to scraper data. `config.properties` is never read by the server, so tokens can never reach the browser.

## Capabilities

### New Capabilities

- `viewer-server`: the read-only HTTP server — static frontend hosting, JSON API endpoints, server-side search/filter/pagination over output files, and the guarantee that secrets and writes are off-limits.
- `viewer-llm-inspection`: the LLM verification views — filterable topic index, topic inspector with post-vs-extraction comparison and provenance, LLM test report view.
- `viewer-merge-explorer`: the searchable merge debug views over `merge-debug.json`.
- `viewer-output-browsing`: browsers for `ModRepo.json` and the forum data bundle, the TriOS-style mod-card preview, raw file viewer, and log viewer.
- `merge-debug-json`: the scraper writes merge debug data as `merge-debug.json` (replacing HTML generation).

### Modified Capabilities

_None. Existing scraper behavior is unchanged except for the merge debug output format, which is covered by `merge-debug-json` above; no existing spec documents the HTML debug output._

## Impact

- New code: `bin/viewer_server.dart`, `lib/viewer/` (server-side handlers), `web/` (HTML/JS/CSS frontend).
- New dependency: `shelf` (and `shelf_static` or equivalent) in `pubspec.yaml`.
- Changed code: `MergeDebugCollector` output path — a new JSON serializer replaces `merge_debug_html_generator.dart`, which is deleted. `main_repo_scraper.dart` call site updated; the config key becomes `generate_merge_debug`, with `generate_debug_html` kept as a working alias.
- Removed: `merge_debug_html_generator.dart`, `MergeDebug.html` generation.
- Data files are read-only inputs: `new_data/mods-index.json`, `new_data/mods/<id>/detail.json`, `new_data/llm-extraction-cache.json`, `new_data/llm-test-output.json`, `new_data/assumed-downloads-cache.json`, `outputs/ModRepo.json`, `outputs/forum-data-bundle.json`, `merge-debug.json`, `ModRepo.log`.
- No changes to scraping, merging, LLM extraction logic, or published output formats consumed by TriOS.
