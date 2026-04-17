## Why

QBMBAMM (QBStarsectorModsBrowser) is a C#/Playwright app that scrapes the Fractalsoftworks forum to produce rich mod data — full OP HTML, images, links, author metadata, and curated categories. The original author is unreliable, so we're porting the scraper into this Dart project as a maintained fork. This first change builds the core scraping pipeline: models, constants, HTTP client, board/topic/index scrapers, HTML processor, data store, and the engine that orchestrates them.

This is part 1 of 3. Part 2 (`qb-download-resolution`) adds download URL resolution. Part 3 (`qb-bundle-publishing`) assembles the final bundle artifact and integrates into the entry point.

## What Changes

- Add data models for QB scraper output: `QbModSummary`, `QbModDetail`, `ImageRef`, `LinkRef`, scrape job/scope/result types
- Add forum constants: board URLs, topic ID/version regexes, category helpers, board-specific filters
- Add legacy category map (7 entries mapping old mod index category names to current ones)
- Add image format and game version comparison utilities
- Add a throttled HTTP client wrapper with configurable delay and browser User-Agent
- Add board listing scraper for boards 8 (main mods), 3 (lesser mods), and 9 (libraries)
- Add mod index category scraper for topic 177 (curated category assignments)
- Add topic scraper for full first-post extraction (HTML content, images, links, author metadata)
- Add HTML post-processor (external link annotation, SMF artifact stripping)
- Add JSON data store for persisting index and per-topic detail files to disk
- Add scraper engine that orchestrates the full pipeline with incremental scraping support

## Capabilities

### New Capabilities

- `qb-forum-scraping`: Board listing scraper (boards 8, 3, 9), mod index category scraper (topic 177), individual topic scraper (full OP extraction), HTML processing, data persistence, incremental scraping, and engine orchestration

### Modified Capabilities

(none)

## Impact

- **New files**: ~16 Dart files under `lib/bot/scraper/qb/` plus generated `*.mapper.dart` files
- **Dependencies**: No new pub dependencies — uses existing `http`, `html`, `dart_mappable`, `path`, `collection`
- **Disk**: Creates `qb_data/` directory with `mods-index.json` and per-topic `mods/{topicId}/detail.json` files
- **Network**: HTTP requests to fractalsoftworks.com forum, rate-limited at configurable delay
