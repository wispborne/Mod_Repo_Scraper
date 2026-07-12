## 1. Models

- [x] 1.1 Add an `LlmModData` model in `models/post_extraction.dart` (or a new sibling) that holds `downloads` (List<AssumedDownloadCandidate>) plus the existing extras fields (version, changelog, supportLinks, license, summary); reuse `LlmExtras` fields or fold them in, with an `isEmpty` getter
- [x] 1.2 Replace `ForumDataBundle.llmExtraction` (extras-only map) with `llm` (Map<String, LlmModData>) in `models/forum_data_bundle.dart`; keep it optional/nullable so an off run omits it
- [x] 1.3 Confirm `assumedDownloads` stays `Map<String, List<AssumedDownloadCandidate>>` and is documented as pure rules-based
- [x] 1.4 Regenerate mappers: `dart run build_runner build --delete-conflicting-outputs`

## 2. LLM store

- [x] 2.1 Update `LlmStoreEntry` in `llm/extraction_store.dart` so a stored per-topic entry maps cleanly to `LlmModData` (downloads + extras together)
- [x] 2.2 Bump `LlmExtractionStore.schemaVersion` so old cache entries are skipped and re-derived, not mis-read
- [x] 2.3 Adjust `toJson`/`fromJson` (and any `_migrateExtras`) for the new entry shape

## 3. Bundle publisher

- [x] 3.1 In `bundle_publisher.dart`, always emit the rule-based resolver candidates into `assumedDownloads` (remove the branch that swaps in `llmEntry.downloads` at ~line 95)
- [x] 3.2 Build the `llm` block: for each topic with a non-empty LLM store entry, emit its reconciled `downloads` plus non-empty extras under `llm.<topicId>`, sorted by topicId
- [x] 3.3 Omit the `llm` block entirely when the LLM feature is off or nothing was produced
- [x] 3.4 Update the summary log line (assumed-download count is rules-only; add an `llm` entry count)

## 4. Post extractor wiring

- [x] 4.1 Confirm `post_extractor.dart` still produces the reconciled download list with `source`/`llmReason` per entry, now stored under the topic's LLM data rather than merged into `assumedDownloads`
- [x] 4.2 Verify grounding behavior and per-topic error isolation are unchanged

## 5. Viewer

- [x] 5.1 Update `lib/viewer/` data access + API to read downloads/extras from the `llm` block instead of the old `llmExtraction`/merged `assumedDownloads`
- [x] 5.2 Update `web/` topic inspector to show the rules base layer and the LLM override layer side by side, with per-download provenance from the `llm` block

## 6. Tests

- [x] 6.1 Update `test/qb_llm_post_extractor_test.dart` for the new storage location of reconciled downloads
- [x] 6.2 Add/adjust bundle-publisher tests: `assumedDownloads` stays pure rules with LLM on; `llm` block carries downloads + extras; `llm` absent when feature off
- [x] 6.3 Update `test/viewer_server_test.dart` for the new bundle shape
- [x] 6.4 `dart analyze` clean and `dart test` green

## 7. README / end-client docs

- [x] 7.1 Add a plain-English README section: the bundle has a rules base layer (`assumedDownloads`, details, index) and an LLM override layer (`llm.<topicId>`)
- [x] 7.2 Document where each field lives — rules-based downloads vs LLM downloads, and which fields are LLM-only (version, changelog, support links, license, summary)
- [x] 7.3 Document the consumer merge rule: for any field, if `llm.<topicId>` has it and the user's per-field switch is on, use it; otherwise use the base value, otherwise nothing
- [x] 7.4 State clearly that the per-field toggle lives in the consumer UI, that turning LLM off means ignoring the `llm` block, and note the coordinated TriOS read-path change is out of this repo's scope

## 8. Verify end to end

- [x] 8.1 Run a small `llm_test_mode` / cached QB pass and confirm the emitted `forum-data-bundle.json` has pure-rules `assumedDownloads` plus a populated `llm` block
- [x] 8.2 Open the viewer and confirm the base vs override layers render correctly
