## 1. Models

- [x] 1.1 Create `lib/bot/scraper/qb/models/mod_summary.dart` — `QbModSummary` with 17 fields, `@MappableClass()`, camelCase JSON keys, null omission
- [x] 1.2 Create `lib/bot/scraper/qb/models/mod_detail.dart` — `QbModDetail` (15 fields), `ImageRef` (originalUrl, localPath, alt), `LinkRef` (url, text, isExternal)
- [x] 1.3 Create `lib/bot/scraper/qb/models/scrape_job.dart` — `ScrapeState`, `ScopeType`, `ScrapeBoard` enums; `ScrapeScope` (type, maxPages, topicIds, boards as Set<ScrapeBoard>); `ScrapeJob` (mutable progress); `ScrapeResult` (immutable outcome)
- [x] 1.4 Run `dart run build_runner build` to generate mapper files, verify no errors

## 2. Constants and Utils

- [x] 2.1 Create `lib/bot/scraper/qb/forum_constants.dart` — board URLs (8, 3, 9), topicUrl(), topicIdRegex, gameVersionRegex, isForumHosted(), tryExtractTopicId(), isWipTitle(), isLesserBoardTopicTitle(), isLibraryThreadTitle(), isLibraryBoardBase(), isLibraryCategoryName(), guessCategoryFromTitle(), hasFileHostingLinks(), category constants
- [x] 2.2 Create `lib/bot/scraper/qb/legacy_category_map.dart` — 7-entry const map
- [x] 2.3 Create `lib/bot/scraper/qb/image_formats.dart` — ext↔MIME maps, isImageExtension(), guessExtensionFromUrl()
- [x] 2.4 Create `lib/bot/scraper/qb/game_version_comparer.dart` — decimal-first compare(), isAtLeast()

## 3. Throttled HTTP Client

- [x] 3.1 Create `lib/bot/scraper/qb/throttled_client.dart` — wraps http.Client, enforces configurable delay, sets browser User-Agent

## 4. Board Scraper

- [x] 4.1 Create `lib/bot/scraper/qb/board_scraper.dart` — `QbBoardScraper` with `scrapeAllPages()` taking throttled client, board URL, maxPages, sort, callbacks, filters
- [x] 4.2 Implement `_extractTopicsFromPage()` — parse span[id^='msg_'] rows, extract topic data, handle sticky filtering
- [x] 4.3 Implement pagination — offset URLs, duplicate-page detection, next-page check, max pages, early stop

## 5. Mod Index Category Scraper

- [x] 5.1 Create `lib/bot/scraper/qb/mod_index_scraper.dart` — `QbModIndexScraper` with `scrape()` returning `ModIndexCategoriesResult`
- [x] 5.2 Implement topic 177 fetch with low-count retry, post parsing for category tables + topic links
- [x] 5.3 Implement first-post vs archived separation, legacy map application, unknown tracking

## 6. Topic Scraper

- [x] 6.1 Create `lib/bot/scraper/qb/topic_scraper.dart` — `QbTopicScraper` with `scrapeTopic(int topicId)` returning `QbModDetail?`
- [x] 6.2 Implement lazy image resolution — check data-imageurl/data-src/data-original/alt when src contains loading.gif
- [x] 6.3 Implement title, author, post date, last edit date extraction
- [x] 6.4 Implement content HTML extraction, image extraction (regex, skip smileys/icons), link extraction with spoiler exclusion

## 7. HTML Processor

- [x] 7.1 Create `lib/bot/scraper/qb/html_processor.dart` — add target="_blank" to external links, replace smiley imgs with alt text, remove last-edit spans, keep original image URLs

## 8. JSON Data Store

- [x] 8.1 Create `lib/bot/scraper/qb/json_data_store.dart` — loadIndex()/saveIndex() for mods-index.json, loadDetail()/saveDetail() for mods/{topicId}/detail.json, pickThumbnail(), in-memory cache

## 9. Scraper Engine

- [x] 9.1 Create `lib/bot/scraper/qb/scraper_engine.dart` — `QbScraperEngine` with `run(ScrapeScope, {onTopicSaved})`
- [x] 9.2 Implement orchestration: mod index → boards → merge/dedup → incremental filter → topic loop → save
- [x] 9.3 Implement category priority (mod index → libraries → title-guess), board-3 quality gate
- [x] 9.4 Implement meaningful change detection and logging

## 10. Verify

- [x] 10.1 Run `dart run build_runner build` and `dart analyze`
- [x] 10.2 Smoke test: scrape 1-2 pages of board 8, verify mods-index.json and detail.json are created
