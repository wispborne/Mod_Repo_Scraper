## Why

The Dart QB migration silently drops category data and publishes nulls where the C# reference has working values. The two highest-impact defects — a fragile next-sibling walk in the mod-index parser, and a missing detail-category backfill at bundle-publish time — cause whole sections of `topic=177` to be misclassified as `uncategorized` and every `details[*].category` field in `forum-data-bundle.json` to come out null. Several smaller parity gaps (selector strictness, casing preservation, diagnostic logging) compound the problem by making the bugs hard to notice. Fixing these brings the Dart scraper's category pipeline to full parity with the authoritative C# implementation.

## What Changes

- Rewrite `QbModIndexScraper._extractTopicCategoriesFromPost` to scan *all* following siblings of each `<strong>` label for the first `ul.bbc_list`, matching the C# XPath `following-sibling::ul[...][1]`. Drop the current `nextElementSibling`-only path that skips labels interrupted by `<br>`, text nodes, or other elements.
- Tighten the category-header selector from `table.bbc_table tbody tr td strong` (descendant) to a direct-child chain, so nested `<strong>` elements inside topic descriptions cannot be mistaken for category labels.
- In `BundlePublisher.createBundle`, join details to summaries by `topicId` and fall back to `summary.category` when `detail.category` is null, mirroring the C# server's read-time backfill in `ModsController`. Without this the published bundle carries null categories for every mod.
- Preserve canonical casing of `ModIndexCategoriesResult.mainCategories` (store raw values, compare case-insensitively) instead of lowercasing on ingest. Consumers that want to surface category names for UI/logs currently lose the source-of-truth casing.
- Strip all trailing `:` from category labels (match C# `TrimEnd(':')`), not just a single colon via `RegExp(r':$')`.
- Broaden `ForumConstants.isLibraryThreadTitle`'s whitespace skip to match C# `char.IsWhiteSpace` (accept tab, NBSP, etc.) rather than only the ASCII space.
- Add the parity-missing diagnostic logs: "Mod index distinct categories", "Mod index sample topic-category mappings" (first 10 entries), and include the legacy-map source file path in the unknown-legacy warning for both `QbModIndexScraper` and `QbScraperEngine`.
- Case-insensitively dedupe `unknownLegacyCategories` at log time, matching C# `OrdinalIgnoreCase` distinct.
- Pre-filter the topic-link anchor query to `a[href*='topic='], a[href*='topic,'], a[href*='topic/']` for parity with C# (cosmetic; already filtered by regex downstream).
- Add regression tests covering each fixed parsing/backfill behavior plus the pre-existing cascade (library override, title-guess fallback, legacy mapping).

The pre-existing shared bug where `guessCategoryFromTitle` overrides the library-only category for non-indexed library-board topics is **not** in scope — it is present in both the Dart and C# implementations, so addressing it is not a parity concern.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `qb-forum-scraping`: Tightens the "Mod index category scraper" and "Orchestrator" requirements — specifies robust `<strong>` → following `ul.bbc_list` sibling resolution, direct-child header selector, casing-preserving `mainCategories`, multi-colon trim, and parity diagnostic logging.
- `qb-bundle-publishing`: Adds a requirement that the bundle writer backfills null `detail.category` from the matching summary before emitting the bundle, so consumers reading per-detail category always get a value.

## Impact

- Affected code: `lib/bot/scraper/qb/mod_index_scraper.dart`, `lib/bot/scraper/qb/forum_constants.dart`, `lib/bot/scraper/qb/scraper_engine.dart`, `lib/bot/scraper/qb/bundle_publisher.dart`.
- Affected output: `forum-data-bundle.json` will gain non-null `details[*].category` values; existing consumers that tolerated nulls continue to work, but any that explicitly relied on null-as-signal would need review (none known).
- Affected logs: additional INFO lines per mod-index scrape; unknown-legacy WARNING gains a file-path hint.
- No dependency, API, or schema changes. No breaking changes to persisted JSON shape (only fills previously-null fields and adds log lines).
- Test surface: new `test/qb/mod_index_scraper_test.dart` and `test/qb/bundle_publisher_test.dart` (fixture HTML + bundle-join assertions).
