# Tasks: Web UI Results Viewer

Implementation reference: design.md defines the flags (D2), filter predicates (D6), API contract (endpoint table), and on-disk data shapes. Do not invent endpoints or filters not listed there.

## 1. Server foundation

- [x] 1.1 Add `shelf`, `shelf_static`, `shelf_router`, and `args` to `pubspec.yaml`
- [x] 1.2 Create `bin/viewer_server.dart`: parse `--port/--data-dir/--outputs-dir/--root-dir` (defaults 8085 / `new_data` / `outputs` / `.`), bind `127.0.0.1`, serve `web/` statically, mount `/api`, print the URL
- [x] 1.3 Create `lib/viewer/data_access.dart`: typed loaders for each file in design.md's data-shapes reference, reusing existing `dart_mappable` models where they exist; mtime-keyed in-memory cache per D4; string-vs-int topic-id conversion at the join boundary
- [x] 1.4 Implement the placeholder-detail scan (Set of topic ids with `isPlaceholderDetail: true`), cached and invalidated per D4
- [x] 1.5 Implement the file allowlist (the 8 ids in D7) and shared response helpers: list envelope (`items/total/page/pageSize`), missing-file envelope (`missing/file/hint`), common params (`q/sort/dir/page/pageSize`, pageSize max 500)
- [x] 1.6 Create `web/` skeleton: `index.html` shell with nav, hash-based view switching (`#/topics` etc. per D3), shared CSS and a fetch helper that understands both envelopes

## 2. Phase 1 — LLM verification

- [x] 2.1 Server: `GET /api/topics` — join index + LLM cache + assumed-downloads + placeholder set; text search on title/author; sort columns and default per D6; `filters` param implementing exactly the seven D6 predicates; rows include the computed filter booleans and download counts
- [x] 2.2 Server: `GET /api/topics/<id>` returning `{ index, detail, assumedDownloads, llm }` with nulls for absent parts; `<id>` must parse as int
- [x] 2.3 UI: topic index table — search box, one toggle per D6 filter, sortable columns, paging
- [x] 2.4 UI: topic inspector — `contentHtml` in a sandboxed iframe (`sandbox` attribute, `srcdoc`, forum-ish stylesheet for `bbc_*` classes per D8) beside index fields, images, and links
- [x] 2.5 UI: extraction panel — downloads table with source/confidence/host/filename/manual-step, `source=="llm"` rows visually highlighted; extras (changelog map, mod version, support links, license); explicit "no LLM extraction for this topic" state
- [x] 2.6 Server + UI: `GET /api/llm-test` and the `#/llm-test` report page (topics with their extraction output; missing-file message when absent)

## 3. Phase 2 — merge debug JSON + merge explorer

- [x] 3.1 Annotate the classes in `merge_debug_data.dart` with `@MappableClass()` (keep field names unchanged) and run `dart run build_runner build`
- [x] 3.2 Write `merge-debug.json` (repo root) from `main_repo_scraper.dart` when merge debug is enabled; delete `merge_debug_html_generator.dart` and its call site
- [x] 3.3 Config: rename key to `generate_merge_debug`, keep `generate_debug_html` as a working alias; update `config.properties` comments
- [x] 3.4 Server: `GET /api/merge/summary`, `/api/merge/groups` (`q` over member names/authors, `multiOnly`), `/api/merge/groups/<id>` (merge decisions incl. winning source per field), `/api/merge/removals?kind=preDedup|sameSource|validation`
- [x] 3.5 UI: `#/merge` views for summary/timings, groups (search + singleton/multi breakdown + match reasons), group detail with decisions, and the three removal lists; missing-file message when `merge-debug.json` absent
- [x] 3.6 Delete `MergeDebug.html` from the repo root; add both `MergeDebug.html` and `merge-debug.json` to `.gitignore` if not covered

## 4. Phase 3 — output browsing and display preview

- [x] 4.1 Server: `GET /api/modrepo` (paged/searchable over `items[]`: name, authors, game version, urls, `sources`) and `GET /api/modrepo/<index>` (full mod)
- [x] 4.2 UI: `#/modrepo` table and per-mod view showing merged fields + contributing `sources`, with a link to the mod's merge group when `merge-debug.json` exists (per updated spec)
- [x] 4.3 Server: `GET /api/bundle/meta` and `GET /api/bundle/mods` (join bundle `index` array with `details`/`assumedDownloads` maps by string id)
- [x] 4.4 UI: `#/bundle` browser
- [x] 4.5 UI: mod-card preview per D9 (thumbnail with `ext:` prefix stripped, title, author, game-version chip, views/replies, ~200-char text excerpt, download buttons for high/medium confidence) with permanent "approximation" label
- [x] 4.6 Server + UI: `GET /api/files` (allowlist with size/mtime/exists) and `GET /api/files/<id>?offset&length` (256 KiB default slices); `#/files` viewer pretty-prints only fully-fetched files under 5 MB, else plain-text slices with prev/next
- [x] 4.7 Server + UI: `GET /api/log?q&tail` and `#/log` view with text filter and jump-to-end

## 5. Verification and docs

- [x] 5.1 Tests (`test/viewer_server_test.dart`): allowlist ids only (unknown id → 404; no path-based access), all seven D6 filter predicates against fixture data (cover the string-key join), mtime cache invalidation, missing-file envelope
- [x] 5.2 Test: annotated `MergeDebugData` round-trips through JSON with all sections populated
- [x] 5.3 Manual check: run the scraper, start the viewer with defaults, walk every `#/` view against the real data on disk
- [x] 5.4 Update `README.md`: how to start the viewer and its flags, what each view is for, `generate_merge_debug` rename (old key still works), MergeDebug.html removal
