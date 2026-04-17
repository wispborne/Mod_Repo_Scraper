## Context

The Dart QB scraper in `lib/bot/scraper/qb/` is a port of the C# QBModsBrowser scraper in `QBMBAMM/src/QBModsBrowser.Scraper/`. The C# implementation is considered authoritative — it has been running in production against the Fractal Softworks forum, has a richer test harness, and is where the curators iterate on classification logic first.

An audit comparing the two category pipelines surfaced ten parity gaps, two of which cause real data loss:

1. `QbModIndexScraper._extractTopicCategoriesFromPost` uses `nextElementSibling`, which gives up as soon as a `<br>`, text node, or other non-`<ul>` element sits between the `<strong>` label and the `<ul class="bbc_list">`. SMF's BBCode renderer routinely inserts such elements. The C# XPath `following-sibling::ul[contains(... 'bbc_list' ...)][1]` walks past them.
2. `BundlePublisher.createBundle` emits `detail.category` verbatim. Neither the Dart nor C# scraper writes `category` into the detail object at scrape time. C# masks this because its live API controller backfills category from the summary on every response; the Dart bundle publisher has no equivalent fallback, so every `details[*].category` in `forum-data-bundle.json` is null.

The remaining eight issues are smaller (strictness of CSS selectors, casing preservation, ASCII-only whitespace, missing diagnostic logs, single-colon trim, anchor pre-filter, legacy-path-in-warning, case-sensitive dedupe). They don't individually break category output, but they make the two high-impact bugs harder to detect and mean a live-vs-bundle diff drifts over time.

Constraints:
- Dart uses the `html` package (html5 parser) with CSS selectors via `querySelectorAll` and direct DOM traversal via `nextElementSibling` / `children`.
- `dart_mappable`-generated `.mapper.dart` files must stay in sync — new fields on `QbModDetail` or `QbModSummary` are out of scope for this change.
- `forum-data-bundle.json` is consumed by a Git-published pipeline ([bundle_publisher.dart:116](lib/bot/scraper/qb/bundle_publisher.dart:116)), so its schema must remain stable.

## Goals / Non-Goals

**Goals:**
- Bring Dart category derivation to functional parity with C# for every documented path (main-post parse, archived-post parse, legacy mapping, library override, title-guess fallback).
- Guarantee that every topic with a known category in the in-memory index is reflected in `details[*].category` in the published bundle.
- Add regression tests so each bug can be proven fixed and remains fixed.
- Bring diagnostic logs in line with C# so category-parse regressions are spottable from log output alone.

**Non-Goals:**
- Fix the pre-existing shared cascade bug where the title-guess fallback overrides the library-board override for non-indexed topics. That bug exists in both implementations; treating C# as authoritative means leaving it alone here. A follow-up proposal can address it across both codebases.
- Schema changes to `QbModSummary` / `QbModDetail`.
- Any change to `TopicScraper` to populate `detail.category` at scrape time (would diverge from C#, which deliberately leaves it null).
- Changes to boards 3/8/9 scraping logic, incremental filtering, or pipelining.

## Decisions

### D1. Sibling walk: manual `nextElementSibling` loop, not `querySelector`

The C# implementation uses XPath to pick "the first following-sibling `ul.bbc_list`". Dart's `html` package doesn't expose XPath, and `querySelector`-from-parent would re-scan the whole subtree (risking matches from sibling categories' lists when category headers share a `<td>`). The cleanest port is a manual loop:

```dart
Element? nextList;
for (Element? node = categoryNode.nextElementSibling;
     node != null;
     node = node.nextElementSibling) {
  if (node.localName == 'ul' && node.classes.contains('bbc_list')) {
    nextList = node;
    break;
  }
}
```

Alternatives considered:
- *Use `querySelector` on the parent `<td>`* — risks cross-category leakage when a single `<td>` contains multiple `<strong>` + `<ul>` pairs. The forum index sometimes packs several categories in one cell.
- *Continue with `nextElementSibling` but loosen the class check* — doesn't help when the immediate next sibling is a `<br>` or text, which is the actual failure case.

The loop also replaces the current "parent-walk fallback when sibling is null" branch; that branch is rarely exercised and its `.bbc_list` check would only now become redundant.

### D2. Header selector: direct-child chain

Change `table.bbc_table tbody tr td strong` to `table.bbc_table > tbody > tr > td > strong`. The Dart `html` package supports child combinators. This matches C# XPath `table/tbody/tr/td/strong` and eliminates the risk of nested `<strong>` in mod descriptions being treated as category labels.

HTML5 parsers (including Dart's) auto-insert `<tbody>` when the source omits it, so the direct-child chain is safe for both explicit and implicit `<tbody>` markup.

### D3. Bundle publisher backfill: join by topicId at write time

In `BundlePublisher.createBundle`, convert the existing `for (final summary in index)` loop into one that threads the summary through to the detail emission:

```dart
details[summary.topicId.toString()] = QbModDetail(
  ...
  category: detail.category ?? summary.category,
  ...
);
```

Alternatives considered:
- *Populate `detail.category` earlier, at `_store.saveDetail` time* — would diverge from C# (which deliberately leaves `ModDetail.Category` null on disk) and bake categories into detail JSON files, making recategorization on a re-scrape more expensive.
- *Backfill at `_store.loadDetail` read time* — same behavior, but spreads the fallback across every call site of `loadDetail`. Bundle publish is the only place that cares today.

The backfill at bundle-emit time is the narrowest fix and mirrors the C# controller's response-time fill.

### D4. Preserve canonical casing of `mainCategories`

Store raw values in a normal `Set<String>` and do case-insensitive membership with a separate lowercased lookup set (kept in the result object for downstream consumers to reuse). This matches the C# `HashSet<string>(StringComparer.OrdinalIgnoreCase)` semantics — values keep their display casing, but `.Contains("factions")` and `.Contains("Factions")` both succeed.

Alternative: use a custom `LinkedHashSet` with a case-insensitive equality — feasible but adds a type that's used only in this one place.

### D5. Trailing-colon strip: loop or `r':+$'`

Use `RegExp(r':+$')` so `"Factions:::"` collapses to `"Factions"`, matching `TrimEnd(':')`.

### D6. Whitespace in `isLibraryThreadTitle`

Replace the `t[i] == ' '` loop with a check against Dart's whitespace class. The cheapest faithful port of `char.IsWhiteSpace` is a regex — rewrite the helper to:

```dart
static final RegExp _libraryTitlePrefix = RegExp(r'^\[\s*\d');
static bool isLibraryThreadTitle(String? title) =>
    title != null && _libraryTitlePrefix.hasMatch(title.trimLeft());
```

This covers tab, NBSP, and all Unicode whitespace that `char.IsWhiteSpace` accepts.

### D7. Diagnostic logging parity

Add, right before the `scrape()` return:
- `Mod index distinct categories: {joined}`
- `Mod index sample topic-category mappings: {first 10 "id:category" entries}`

In the unknown-legacy warning (both the mod-index scraper and the orchestrator), append a hint pointing at `lib/bot/scraper/qb/legacy_category_map.dart`. The Dart map is a `const` in source rather than an external JSON file, so the pointer is a source path, not a runtime file path.

### D8. Case-insensitive unknown-legacy dedupe

When logging `unknownLegacyCategories`, dedupe via `.map((s) => s.toLowerCase()).toSet()` (keep the lowercased representatives) — matches C# `.Distinct(OrdinalIgnoreCase)`.

### D9. Anchor pre-filter

Change `sibling.querySelectorAll('a')` to `querySelectorAll("a[href*='topic='], a[href*='topic,'], a[href*='topic/']")`. Purely a cosmetic parity change; the topic-id regex downstream already rejects non-topic hrefs.

### D10. Test strategy

Two new test files:

1. `test/qb/mod_index_scraper_test.dart` — drives `QbModIndexScraper._extractTopicCategoriesFromPost` (exposed via test-only visibility or a thin public wrapper) with fixture HTML strings covering:
   - happy path (`<strong>Label:</strong><ul class="bbc_list">...`),
   - `<strong>Label:</strong><br><ul>` (regression for BUG 1),
   - nested `<strong>` inside a `<td>` that is not a category header (regression for BUG 4),
   - legacy-mapped archived category,
   - unknown legacy archived category → `uncategorized` + tracked,
   - archived topic already in main map → skipped,
   - trailing `::` stripped (regression for BUG 5).
2. `test/qb/bundle_publisher_test.dart` — constructs a `JsonDataStore` populated with a summary whose `category == "Faction Mods"` and a detail whose `category == null`, runs `createBundle`, asserts `bundle.details["<id>"].category == "Faction Mods"` (regression for BUG 2).

To expose `_extractTopicCategoriesFromPost` for testing, prefer making it package-private (remove leading underscore → `extractTopicCategoriesFromPost`) and marking it `@visibleForTesting`, rather than building a parallel test-only entry point. The method has no I/O so it's safe to expose.

### D11. Library + title-guess display names

C# commit `378df5a` changed `ForumConstants.LibraryCategory` from `"libraries"` to `"Libraries"`, and retargeted `GuessCategoryFromTitle` from `"factions"/"portraits"/"flags"` to `"Faction Mods"/"Portrait Packs"/"Flag Packs"` — the same strings the mod-index scraper emits for those categories. The motivation in the commit message ("fixed categories name mismatch") is to collapse two separate casing buckets in the UI into one. The Dart port must follow verbatim.

No downstream consumer in this repo case-sensitively matches on the old strings — `ForumConstants.isLibraryCategoryName` already does a `toLowerCase()` comparison, so mod-index payloads with "Libraries" still route through the normalization path unchanged.

### D12. Ordering of fixes

Apply fixes in severity order so the first commit already restores correctness even if later commits slip:
1. Sibling-walk fix (BUG 1)
2. Bundle backfill (BUG 2)
3. Selector + colon strip + casing + whitespace (BUGS 3, 4, 5, 7) — cluster cosmetic-but-correct fixes
4. Logging + dedupe + anchor filter (BUGS 6, 8, 9, 10) — purely diagnostic
5. Display-name alignment (D11) — trailing update once the parse pipeline is sound
6. Tests — written alongside the relevant fix, but the whole suite is landed and green before merge

## Risks / Trade-offs

- **[Risk] Changing `details[*].category` from null to real values may break consumers that pattern-match on null** → Mitigation: grep the repo and any known downstream consumers for `detail.category == null` usage before landing. Nothing found in this repo, and the field has always been populated on the C# side at API time, so external consumers are likely already handling a string.

- **[Risk] Exposing `_extractTopicCategoriesFromPost` changes the public API of `QbModIndexScraper`** → Mitigation: mark `@visibleForTesting` (from `package:meta`). The class is internal to the bot package; no downstream code imports it.

- **[Risk] Direct-child selector breaks on a mod-index page that legitimately nests `<strong>` inside a wrapper element** → Mitigation: if ever observed, fall back to a post-filter in the loop (reject headers whose parent isn't a `<td>`). Low probability — the C# XPath has this same strictness and hasn't needed exceptions.

- **[Trade-off] Adding diagnostic logs increases log volume on every scrape run** → Acceptable: the added lines are two per scrape (plus one conditional warning), not per-topic. Bounded cost.

- **[Risk] Regex-based whitespace check is slightly slower than a tight ASCII loop** → Negligible — `isLibraryThreadTitle` is called O(topics) times, regex compile is cached, no hot path.

## Migration Plan

No schema migrations. Deployment is a source change + re-scrape:

1. Land code changes + tests on a branch.
2. Run `dart test` locally to confirm all QB tests green.
3. Run `bin/qb_smoke_test.dart` against the live forum (once) and diff the resulting `forum-data-bundle.json` against the last C#-generated bundle for a sample of topics across boards 3/8/9 — category values should match for every topic id present in both. Archive the diff report on the branch before merging.
4. Merge to master. The next scheduled scrape will regenerate `ModRepo.json` / `forum-data-bundle.json` with correct categories.

Rollback: straight `git revert` of the merge commit. Persisted bundle JSON is overwritten on every scrape, so no data migration to reverse.

## Open Questions

None.
