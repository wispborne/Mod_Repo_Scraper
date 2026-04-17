## Context

We're porting the QBMBAMM C# scraper into this Dart project. The C# version uses Playwright for browser automation (primarily for Cloudflare bypass); since our IP is allowlisted, we use plain HTTP + the `html` package instead. This change covers the core scraping pipeline — everything needed to scrape the forum and persist results to disk.

**C# source files being ported:**
- `QBModsBrowser.Scraper/Models/ModSummary.cs`, `ModDetail.cs`, `ScrapeJob.cs`
- `QBModsBrowser.Scraper/ForumConstants.cs`, `ImageFormats.cs`, `GameVersionComparer.cs`
- `QBModsBrowser.Scraper/Services/BoardScraper.cs`, `TopicScraper.cs`, `ModIndexCategoryScraper.cs`, `HtmlProcessor.cs`, `ScraperEngine.cs`
- `QBModsBrowser.Scraper/Storage/JsonDataStore.cs`
- `QBModsBrowser.Scraper/legacy-category-map.json`

## Goals / Non-Goals

**Goals:**
- Scrape forum boards 8, 3, 9 and mod index (topic 177) using plain HTTP
- Extract full first-post content (HTML, images, links, author metadata) per topic
- Support incremental scraping (only re-scrape changed topics)
- Persist data in the same layout as C# version (mods-index.json + per-topic detail.json)
- All new code under `lib/bot/scraper/qb/` as a self-contained module

**Non-Goals:**
- Download URL resolution (that's `qb-download-resolution`)
- Bundle assembly or publishing (that's `qb-bundle-publishing`)
- Config integration or entry point changes (that's `qb-bundle-publishing`)
- Image downloading/caching
- Cloudflare bypass logic

## Decisions

### Plain HTTP instead of Playwright
Use `http` package + `html` package, same as the existing Dart forum scraper. IP is Cloudflare-allowlisted, so Playwright is unnecessary. The SMF HTML structure is static and parseable without JS.

### Lazy image resolution without JavaScript
SMF lazy-loads images with `src=loading.gif` and real URLs in `data-imageurl`, `data-src`, `data-original`, or `alt` attributes. The C# version uses Playwright JS eval. We inspect the parsed DOM attributes directly — simpler and more reliable.

### Self-contained module under `lib/bot/scraper/qb/`
The QB scraper has fundamentally different models from `ScrapedMod` (tracks HTML content, image/link refs, categories, per-topic detail files). Sharing the model layer would force awkward compromises. Constants overlap slightly but the QB versions are richer (3 boards, legacy category mapping, WIP detection, board-specific filters).

### dart_mappable for JSON serialization
Existing project convention. C# output uses camelCase with indentation and null omission — dart_mappable's defaults align. Map keys for detail/download maps will be string representations of topic IDs.

### Keep original image URLs
The C# HtmlProcessor rewrites image `src` to `/api/images/{topicId}/...` for its server proxy. We skip this — original URLs are more useful for our use case.

### File layout

```
lib/bot/scraper/qb/
  models/
    mod_summary.dart          ← QbModSummary (17 fields)
    mod_detail.dart           ← QbModDetail, ImageRef, LinkRef
    scrape_job.dart           ← enums, ScrapeScope, ScrapeJob, ScrapeResult
  forum_constants.dart        ← URLs, regexes, category helpers
  legacy_category_map.dart    ← 7-entry const map
  image_formats.dart          ← ext↔MIME maps
  game_version_comparer.dart  ← decimal-first version comparison
  throttled_client.dart       ← rate-limited HTTP wrapper
  board_scraper.dart          ← board listing pagination
  mod_index_scraper.dart      ← topic 177 category extraction
  topic_scraper.dart          ← full OP extraction
  html_processor.dart         ← post-process content HTML
  json_data_store.dart        ← disk persistence
  scraper_engine.dart         ← orchestration
```

## Risks / Trade-offs

**[Risk] SMF HTML structure changes** → Selectors could break on forum updates. Same risk as C# version; monitor and fix.

**[Risk] Plain HTTP gets blocked** → If Cloudflare tightens rules despite allowlist. Fallback: add cookie handling or headless browser step.

**[Trade-off] ~1400 lines of new code** → Substantial, but isolated under `qb/` and touches no existing files in this change.
