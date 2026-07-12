## Why

Today the LLM's download results overwrite the rule-based ones in `assumedDownloads` ([bundle_publisher.dart:95](../../../lib/bot/scraper/qb/bundle_publisher.dart)). Once that happens the pure rules answer is gone, so a consumer can never fall back to it. We want the mod manager (TriOS) to let each end user turn LLM-sourced data on or off, per field, in its own UI — which is only possible if the published bundle keeps the rules answer and the LLM answer side by side. TriOS does not read any LLM data yet, so we can lay this out cleanly now with no LLM-shape compatibility to preserve.

## What Changes

- **One rule for the bundle: a rules base layer plus an LLM override layer.** The base data is always pure rules-based (it is exactly what "LLM off" shows). The LLM data sits in one separate per-topic block that overrides the base, field by field, only when a consumer asks for it.
- **`assumedDownloads` goes back to pure rules, always.** **BREAKING** (internal shape): the LLM SHALL stop writing into `assumedDownloads`. Its reconciled download list moves into the per-topic LLM block instead. `assumedDownloads` becomes a stable, rules-only list again.
- **All LLM output lives under one per-topic `llm` block**, keyed by topic ID, holding the LLM download list alongside the existing extras (version, changelog, support links, license, summary). This block is the single home — and the extension point — for every current and future LLM field.
- **Drop the "additive tags on the rules list" approach.** Because the two layers are now fully separate and TriOS reads no LLM data yet, we no longer need `source`/`llmReason` tags bolted onto `assumedDownloads` entries or a backwards-compatible-overlay contract. Provenance detail stays inside the LLM block where it belongs.
- **Consumer merge rule (documented, not enforced by the scraper).** For any field: if the LLM block has it and the user's switch for that field is on, use the LLM value; otherwise use the base (rules) value, or nothing if the rules produced none. The per-field switch lives entirely in the consumer UI.
- **README documentation for end clients.** Add a plain-English section explaining the base-plus-override layout, where rules data vs LLM data lives in the JSON, the per-field merge rule, and how a consumer implements the toggle.
- **Out of scope:** `ModRepo.json` is unchanged and stays rules-only (the website needs no LLM data; TriOS gets LLM data from the bundle). Updating TriOS to read the new location and render the toggles is a separate, coordinated change in that project — this repo only publishes the contract and documents it.

## Capabilities

### New Capabilities

(none — this restructures existing bundle and LLM-extraction behavior)

### Modified Capabilities

- `qb-bundle-publishing`: the `ForumDataBundle` model gains a separate per-topic `llm` override block; `assumedDownloads` is redefined as pure rules-based data that the LLM never overwrites; bundle assembly stops merging LLM downloads into `assumedDownloads`.
- `qb-llm-post-extraction`: the LLM's reconciled download list and extras SHALL be written into the per-topic `llm` block rather than merged into `assumedDownloads`; the old "additive `source`/`llmReason` tags plus backwards-compatible overlay" output requirement is replaced by the clean base-plus-override separation.

## Impact

- **Code:** `models/forum_data_bundle.dart` (replace `llmExtraction` extras-only map with a per-topic `llm` block that also carries downloads), `bundle_publisher.dart` (stop overwriting `assumedDownloads`; emit the `llm` block), `llm/extraction_store.dart` and `models/post_extraction.dart` (shape of the stored per-topic LLM entry), plus the generated `*.mapper.dart` siblings (regenerate via `build_runner`).
- **Output:** `forum-data-bundle.json` changes shape — `assumedDownloads` is rules-only again and a new `llm` block appears. This is a coordinated break: TriOS must be updated to read downloads/extras from the `llm` block (tracked outside this repo).
- **Docs:** `README.md` gains an end-client section for the new layout and merge rule.
- **Viewer:** the local results viewer (`web/`, `lib/viewer/`) reads the bundle and shows LLM provenance, so it must follow the new shape (per the "keep the viewer in sync" convention).
- **No change:** `ModRepo.json`, the scrapers themselves, the download rules, and the LLM prompt/grounding behavior.
