## 1. Mod-index parser: sibling walk and selector (BUG 1, BUG 4)

- [x] 1.1 In `lib/bot/scraper/qb/mod_index_scraper.dart`, change the header selector to the direct-child chain `table.bbc_table > tbody > tr > td > strong`
- [x] 1.2 Rewrite the `sibling`-lookup block in `_extractTopicCategoriesFromPost` to iterate `categoryNode.nextElementSibling` in a loop and pick the first element whose `localName == 'ul'` and whose `classes.contains('bbc_list')`
- [x] 1.3 Remove the now-redundant `if (sibling.localName != 'ul') continue;` check (the loop only assigns matching `ul`s)
- [x] 1.4 Remove the `if (sibling == null)` parent-walk fallback branch (subsumed by the loop)
- [x] 1.5 Remove the unused `dynamic postRoot` parameter type — switch to `Element` from `package:html/dom.dart` (import added)
- [x] 1.6 Expose `extractTopicCategoriesFromPost` (drop leading underscore) and mark it `@visibleForTesting` from `package:meta/meta.dart`

## 2. Mod-index parser: label normalization (BUG 5)

- [x] 2.1 Replace `categoryRaw.replaceAll(RegExp(r':$'), '')` in `_extractTopicCategoriesFromPost` with a regex that strips one-or-more trailing colons: `categoryRaw.replaceAll(RegExp(r':+$'), '')`

## 3. Mod-index parser: canonical casing (BUG 3)

- [x] 3.1 In `ModIndexCategoriesResult`, add a second field `Set<String> mainCategoriesLower = {}` alongside the existing `mainCategories`
- [x] 3.2 In `QbModIndexScraper.scrape`, set `result.mainCategories = mainMap.values.toSet()` (raw casing preserved) and `result.mainCategoriesLower = result.mainCategories.map((v) => v.toLowerCase()).toSet()`
- [x] 3.3 Update the archived-category contains-check from `result.mainCategories.contains(normalized.toLowerCase())` to `result.mainCategoriesLower.contains(normalized.toLowerCase())`
- [x] 3.4 Update the legacy-mapped contains-check from `result.mainCategories.contains(legacyMapped.toLowerCase())` to `result.mainCategoriesLower.contains(legacyMapped.toLowerCase())`

## 4. Mod-index parser: anchor pre-filter (BUG 6)

- [x] 4.1 In `_extractTopicCategoriesFromPost`, change `sibling.querySelectorAll('a')` to `sibling.querySelectorAll("a[href*='topic='], a[href*='topic,'], a[href*='topic/']")`

## 5. Mod-index parser: diagnostic logging (BUG 9, BUG 10)

- [x] 5.1 Before `return result;` in `QbModIndexScraper.scrape`, log the distinct main-post category names: `_log.info('Mod index distinct categories: ${result.mainTopicCategoryMap.values.toSet().toList()..sort().join(', ')}')` (sort case-insensitively; adjust to match C# `OrderBy OrdinalIgnoreCase`)
- [x] 5.2 Before `return result;`, log the first 10 sample mappings: `_log.info('Mod index sample topic-category mappings: ${... first 10 entries as "id:value" joined by "; "}')`
- [x] 5.3 Change the unknown-legacy warning at the end of `scrape()` to append the source file path hint, e.g. `'Unmapped legacy categories (update lib/bot/scraper/qb/legacy_category_map.dart): ${deduped.join(', ')}'`
- [x] 5.4 Dedupe the warning list case-insensitively: `unknownLegacyCategories.map((s) => s.toLowerCase()).toSet().toList()..sort()`

## 6. Forum constants: Unicode whitespace in `isLibraryThreadTitle` (BUG 7)

- [x] 6.1 In `lib/bot/scraper/qb/forum_constants.dart`, replace the `while (i < t.length && t[i] == ' ')` loop with a precompiled `static final RegExp _libraryTitlePrefix = RegExp(r'^\[\s*\d');` and rewrite `isLibraryThreadTitle` to `title != null && _libraryTitlePrefix.hasMatch(title.trimLeft())`
- [x] 6.2 Remove the now-unused `_isDigit` helper if no other callers remain

## 7. Scraper engine: unknown-legacy warning path (BUG 8)

- [x] 7.1 In `lib/bot/scraper/qb/scraper_engine.dart`, update the `currentJob.errorMessage` assignment to include the source file hint: `'Unmapped legacy categories (update lib/bot/scraper/qb/legacy_category_map.dart): ${...deduped case-insensitively...}'`

## 8. Bundle publisher: detail-category backfill (BUG 2)

- [x] 8.1 In `lib/bot/scraper/qb/bundle_publisher.dart`'s `createBundle`, inside the `for (final summary in index)` loop, change the `category: detail.category` argument on the rebuilt `QbModDetail` to `category: detail.category ?? summary.category`

## 9. Tests

- [x] 9.1 Create `test/qb/mod_index_scraper_test.dart` with fixture-HTML tests for the happy path (strong + ul immediate siblings)
- [x] 9.2 Add fixture-HTML test: strong + `<br>` + `<ul class="bbc_list">` — assert topic ids are extracted (regression for BUG 1)
- [x] 9.3 Add fixture-HTML test: nested `<strong>` inside a `<p>` under `<td>` is NOT treated as a category header (regression for BUG 4)
- [x] 9.4 Add fixture-HTML test: label `"Factions:::"` normalizes to `"Faction Mods"` via legacy map (regression for BUG 5)
- [x] 9.5 Add fixture-HTML test: archived topic whose id is also in the main map is skipped in archived map
- [x] 9.6 Add fixture-HTML test: archived category absent from main set and absent from legacy map → routed to `uncategorized` and tracked in `unknownLegacyCategories`
- [x] 9.7 Add fixture-HTML test: main-category casing in `result.mainCategories` matches source (for example `"Faction Mods"`, not `"faction mods"`) (regression for BUG 3)
- [x] 9.8 Create `test/qb/bundle_publisher_test.dart`: seed `JsonDataStore` with a summary where `category == "Faction Mods"` and a detail where `category == null`; run `createBundle`; assert the emitted detail has `category == "Faction Mods"` (regression for BUG 2)
- [x] 9.9 Add a second `bundle_publisher_test.dart` case: detail with non-null `category` is NOT overwritten by the summary
- [x] 9.10 Add a `forum_constants_test.dart` case: `isLibraryThreadTitle("[\t0.98a] Foo")` returns `true` (regression for BUG 7)

## 11. Display-name parity with C# commit 378df5a

- [x] 11.1 In `lib/bot/scraper/qb/forum_constants.dart`, change `libraryCategory` from `'libraries'` to `'Libraries'`
- [x] 11.2 In `guessCategoryFromTitle`, return `'Faction Mods'` / `'Portrait Packs'` / `'Flag Packs'` instead of `'factions'` / `'portraits'` / `'flags'`
- [x] 11.3 Add a `forum_constants_test.dart` case: `guessCategoryFromTitle("[0.98a] Awesome Faction")` returns `"Faction Mods"`; `"Some Portrait Pack"` returns `"Portrait Packs"`; `"Cool Flags"` returns `"Flag Packs"`; title with none returns `uncategorizedCategory`
- [x] 11.4 Update the existing mod-index test that asserts `libraryCategory` usage (if any) and add a `forum_constants_test.dart` case asserting `ForumConstants.libraryCategory == 'Libraries'`

## 10. Verification

- [x] 10.1 Run `dart analyze` — no new warnings
- [x] 10.2 Run `dart test` — all tests green (new + existing)
- [x] 10.3 Run `dart run bin/qb_smoke_test.dart` against the live forum once; confirm `ModRepo.log` now contains the new "Mod index distinct categories" and "Mod index sample topic-category mappings" lines
- [x] 10.4 Inspect the generated `forum-data-bundle.json` and confirm at least one non-library, non-board-3 entry has a non-null `details[<id>].category` matching the corresponding `index[<id>].category`
- [ ] 10.5 Diff category values for ~20 sampled topic ids across boards 3/8/9 against a last-known-good C# bundle; confirm parity (document the sample IDs in the PR description)
