## 0. Sequence with the override-layer change

- [x] 0.1 Confirm `qb-llm-override-layer` is archived first (it is applied and complete), so the spec base reflects it before this change is applied

## 1. Models

- [x] 1.1 In `models/post_extraction.dart`, add an `LlmMod` model: `name`, `role` (main/addon/separate/variant), `requires` (String?, nullable), `downloads` (List of download entries), plus the existing extras (version, changelog, supportLinks, license, summary); add an `isEmpty` getter
- [x] 1.2 Add the per-thread LLM container (holds `mods: List<LlmMod>`, always a list) that will sit on the index item; keep an `isEmpty` getter
- [x] 1.3 Give each download entry a `kind` field (`direct`/`mirror`/`trios`) and a word-for-word `label`, alongside the resolver-filled fields (resolved direct URL, filename, requires-manual-step); reuse `AssumedDownloadCandidate` fields where they fit and drop the `source`/`llmReason` origin tags
- [x] 1.4 In `models/mod_summary.dart`, add an optional nullable `llm` field to `QbModSummary` (absent when off / empty)
- [x] 1.5 In `models/forum_data_bundle.dart`, remove the top-level `llm` map added by `qb-llm-override-layer`; confirm `assumedDownloads` stays a rules-only `Map<String, List<AssumedDownloadCandidate>>`
- [x] 1.6 Regenerate mappers: `dart run build_runner build --delete-conflicting-outputs`

## 2. LLM store

- [x] 2.1 Update `LlmStoreEntry` in `llm/extraction_store.dart` so a stored per-thread entry maps cleanly to the new `mods` list shape
- [x] 2.2 Raise `LlmExtractionStore.schemaVersion` so old cache entries are skipped and re-created, not mis-read
- [x] 2.3 Adjust `toJson`/`fromJson` for the new entry shape

## 3. Prompt

- [x] 3.1 In `llm/prompt.dart`, change the requested JSON to `{ "mods": [ ... ] }`, each mod with name/role/requires, its downloads (url, label, kind), and the extras
- [x] 3.2 Add the hard rule: include only mods actually downloadable from THIS thread — never a mod merely mentioned, recommended, linked as a successor, or required but hosted elsewhere
- [x] 3.3 State the add-on-vs-mirror line: a different file that extends the mod is its own mod entry; the same file on another host is a `mirror` download
- [x] 3.4 Keep the existing hard rules (copy verbatim, only links that appear in the post, never invent or resolve a URL, mod version is not the game version)
- [x] 3.5 Raise `ExtractionPrompt.promptVersion`

## 4. Post extractor wiring

- [x] 4.1 In `llm/post_extractor.dart`, parse the mods list, keep the link-checking step (drop any URL not in the post, drop unstated copied text)
- [x] 4.2 Run each kept download link through the existing `download_resolver.dart` and fill the resolved direct URL, filename, and manual-step flag on each download entry
- [x] 4.3 Group downloads under their mod as the LLM assigned them; store the result in the reshaped store entry
- [x] 4.4 Verify per-thread error isolation is unchanged (a bad thread does not stop the run)

## 5. Bundle publisher

- [x] 5.1 In `bundle_publisher.dart`, always emit the rule-based resolver candidates into `assumedDownloads` (no override, no LLM merge)
- [x] 5.2 Put each thread's LLM output on the matching `index` item's `llm` field when the store has a non-empty entry
- [x] 5.3 Stop emitting the top-level `llm` map
- [x] 5.4 Omit the `llm` field on every index item when the feature is off or nothing was produced
- [x] 5.5 Update the summary log line (rules-only assumed-download count; add a count of threads with LLM output and of multi-mod threads)

## 6. Viewer

- [x] 6.1 Update `lib/viewer/` data access + API to read the LLM output from each index item's `llm` field; drop the old origin-tag logic
- [x] 6.2 Update the index filters: "has LLM downloads the rules missed" (compare LLM download URLs against `assumedDownloads`) and a new "has more than one mod" filter
- [x] 6.3 Update `web/` topic inspector to show the LLM output as a mods list — per mod: name, role, requires, its downloads (kind, host, filename, manual-step), and extras — with LLM-found downloads visually distinguished from the rules

## 7. Tests

- [x] 7.1 Update `test/qb_llm_post_extractor_test.dart`: mods-list output, per-mod downloads with `kind`, resolver-filled fields, link-checking still drops made-up URLs, only-mods-on-this-thread rule
- [x] 7.2 Update `test/bundle_publisher_test.dart`: `assumedDownloads` stays pure rules with LLM on; the `llm` field appears on index items; no top-level `llm` map; field absent when feature off
- [x] 7.3 Update `test/viewer_server_test.dart` for the new bundle shape and filters
- [x] 7.4 `dart analyze` clean and `dart test` green

## 8. README / end-client docs

- [x] 8.1 Update the README end-client section: the shipped fields are unchanged; each `index` item may gain an optional `llm` field holding a `mods` list
- [x] 8.2 Document each mod's fields (name, role, requires, downloads with kind + resolved URL/filename/manual-step, and the extras) and that a single-mod thread is a one-item list
- [x] 8.3 State the read rule plainly: when a thread's `llm` field is present, it is the full answer for that thread's mods and downloads; when absent, use the rules-based `assumedDownloads`

## 10. Per-mod image (multi-mod threads)

- [x] 10.1 In `models/post_extraction.dart`, add an optional `image` (String?, `ext:<url>` form matching `thumbnailPath`) to `LlmMod`; keep `isEmpty` unchanged (an image alone does not keep a mod); regenerate mappers
- [x] 10.2 In `llm/prompt.dart`, add an `"image"` field to each mod, a new "IMAGES IN THE POST" section (URL + alt), and guidance to pick one only when it clearly belongs to a specific mod (mainly multi-mod posts) and never a badge; add `image` to the field set; raise `promptVersion` (7 → 8)
- [x] 10.3 In `llm/post_extractor.dart`, offer the post's images (minus badges) to the model, parse the chosen `image`, ground it against the post's real images (drop if absent), store the exact scraped URL as `ext:<url>`, and set it on each `LlmMod`
- [x] 10.4 Raise `LlmExtractionStore.schemaVersion` (3 → 4) for the new per-mod `image`
- [x] 10.5 In `web/views/topic.js`, show a mod's `image` under its name (strip the `ext:` marker); add a small style
- [x] 10.6 Tests in `test/qb_llm_post_extractor_test.dart`: an image in the post is kept as `ext:<url>`, an invented one is dropped, a badge is never used, and each mod in a multi-mod thread keeps its own image
- [x] 10.7 README: note the optional per-mod `image` field and its `ext:<url>` form

## 11. Per-mod save-compatibility text

- [x] 11.1 In `models/post_extraction.dart`, add an optional `saveCompatibility` (String?) to `LlmExtras`; include it in the constructor and `isEmpty`; regenerate mappers
- [x] 11.2 In `llm/prompt.dart`, add a `"saveCompatibility"` field to each mod and copy-exactly guidance (copy the post's own words on adding to an existing save vs needing a new game; never decide it yourself); add `saveCompatibility` to the field set; raise `promptVersion` (8 → 9)
- [x] 11.3 In `llm/post_extractor.dart`, parse `saveCompatibility`, ground it word-for-word against the post (drop when not found), and build it into each mod's extras; keep a mod whose only fact is save compatibility (add it to the checked-mod `isEmpty`)
- [x] 11.4 Raise `LlmExtractionStore.schemaVersion` (4 → 5) for the new extra
- [x] 11.5 In `web/views/topic.js`, show "Save compatibility" in the LLM extras list
- [x] 11.6 Tests in `test/qb_llm_post_extractor_test.dart`: text in the post is kept word-for-word, a needs-new-game note is kept, and text not in the post is dropped
- [x] 11.7 README: note the optional per-mod `saveCompatibility` field

## 9. Verify end to end

- [x] 9.1 Run a small `llm_test_mode` / cached QB pass and confirm the emitted `forum-data-bundle.json` has rules-only `assumedDownloads` and an `llm` field on the index items that produced output — verified end to end against the real store (old v2 cache skipped; no top-level `llm` map; rules-only `assumedDownloads` for 624 topics; a v3 store entry surfaces as an `llm` mods list on its index item)
- [ ] 9.2 Check the ShaderLib thread: exactly one mod (ShaderLib), with its download and its mirror — GraphicsLib and Version Checker are NOT mod entries — NEEDS a live LLM run (`enable_llm=true` with your endpoint/token); the grounding safety net is unit-tested, but the prompt behavior itself can only be confirmed against the model
- [ ] 9.3 Open the viewer and confirm the mods list, per-download kinds, and the multi-mod grouping render correctly — viewer server + API verified against real data (`/api/topics`, `/api/bundle/mods` serve without error); the visual render needs a browser pass by you
