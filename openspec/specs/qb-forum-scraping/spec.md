## ADDED Requirements

### Requirement: QB mod summary model
The system SHALL define a `QbModSummary` data class with fields: topicId (int), title (String), category (String), inModIndex (bool), isArchivedModIndex (bool), gameVersion (String?), author (String), replies (int), views (int), createdDate (String?), lastPostDate (String?), lastPostBy (String?), topicUrl (String), thumbnailPath (String?), scrapedAt (DateTime), isWip (bool), sourceBoard (int?). It SHALL serialize to/from JSON with camelCase keys and null omission.

#### Scenario: Serialize mod summary to JSON
- **WHEN** a `QbModSummary` is serialized
- **THEN** the output SHALL use camelCase keys, omit null fields, and serialize `scrapedAt` as ISO 8601

### Requirement: QB mod detail model
The system SHALL define a `QbModDetail` data class with fields: topicId, title, category, gameVersion, author, authorTitle, authorPostCount, authorAvatarPath, postDate, lastEditDate, contentHtml, images (List<ImageRef>), links (List<LinkRef>), scrapedAt, isPlaceholderDetail. `ImageRef` SHALL have: originalUrl, localPath, alt. `LinkRef` SHALL have: url, text, isExternal.

#### Scenario: Serialize mod detail to JSON
- **WHEN** a `QbModDetail` is serialized
- **THEN** nested `ImageRef` and `LinkRef` lists SHALL be included inline with camelCase keys

### Requirement: Scrape scope and job models
The system SHALL define: `ScrapeState` enum (idle, scraping, completed, failed, cancelled), `ScopeType` enum (newData, all, pages, topics, librariesOnly), `ScrapeBoard` enum (main, lesser, libraries), `ScrapeScope` class (type, maxPages, topicIds, boards as Set<ScrapeBoard>), `ScrapeJob` (mutable progress tracking), `ScrapeResult` (success, modsScraped, imagesDownloaded, errors, duration, errorMessage).

#### Scenario: Scope with board selection
- **WHEN** a `ScrapeScope` is created with `boards: {ScrapeBoard.main, ScrapeBoard.libraries}`
- **THEN** only boards 8 and 9 SHALL be scraped

### Requirement: Forum constants
The system SHALL provide constants and helpers: board URLs for boards 8, 3, 9; `topicUrl(int)` builder; `topicIdRegex` matching `topic[=,/](\d+)`; `gameVersionRegex` matching `\[(\d+\.\d+[\w.\-]*)...\]`; `isForumHosted(String)` URI check; `tryExtractTopicId(String?)` returning int?; `isWipTitle(String?)` checking for "WIP"; `isLesserBoardTopicTitle(String?)` requiring version tag and no "MOVED"; `isLibraryThreadTitle(String?)` requiring bracketed version start and tolerating any Unicode whitespace between the `[` and the digit; `libraryCategory` constant holding the display-cased value `"Libraries"`; `guessCategoryFromTitle(String)` returning the same display-cased bucket names the mod-index scraper emits (`"Faction Mods"`, `"Portrait Packs"`, `"Flag Packs"`, or `uncategorizedCategory`) for faction/portrait/flag keywords; `hasFileHostingLinks(List<LinkRef>)` excluding forum/Nexus/YouTube.

#### Scenario: Extract topic ID from URL
- **WHEN** `tryExtractTopicId` is called with `"https://fractalsoftworks.com/forum/index.php?topic=177.0"`
- **THEN** it SHALL return `177`

#### Scenario: Library title with non-ASCII whitespace
- **WHEN** `isLibraryThreadTitle` is called with a title beginning with `[` followed by a tab or non-breaking space before the first digit (for example `"[\t0.98a] Foo"`)
- **THEN** it SHALL return `true`

#### Scenario: Library display-cased constant
- **WHEN** `libraryCategory` is read
- **THEN** its value SHALL be the display-cased string `"Libraries"` so that the library override and the mod-index normalization produce the same bucket name the UI displays

#### Scenario: Title-guess display-name parity
- **WHEN** `guessCategoryFromTitle` is called with a title containing the substring `"faction"`, `"portrait"`, or `"flag"` (case-insensitively)
- **THEN** it SHALL return `"Faction Mods"`, `"Portrait Packs"`, or `"Flag Packs"` respectively — the same display-cased names the mod-index scraper emits for those categories — and SHALL return `uncategorizedCategory` otherwise

### Requirement: Board listing scraper
The system SHALL scrape forum board listing pages to extract mod topic summaries. It SHALL support boards 8, 3, and 9 with configurable pagination, sorting, sticky filtering, title filtering, duplicate-page detection, and early-stop callbacks.

#### Scenario: Scrape main mods board
- **WHEN** board scraper is invoked for board 8
- **THEN** it SHALL fetch pages at `board=8.{offset}`, parse `span[id^='msg_']` rows, and return `QbModSummary` objects

#### Scenario: Sticky topic filtering
- **WHEN** scraping boards 8 or 3
- **THEN** topics with `show_sticky.gif` in their row SHALL be skipped

#### Scenario: Lesser board title filtering
- **WHEN** scraping board 3
- **THEN** only topics matching `gameVersionRegex` and not containing "MOVED" SHALL be included

#### Scenario: Library board title filtering
- **WHEN** scraping board 9
- **THEN** only topics whose title starts with a bracketed version number SHALL be included

#### Scenario: Sort by last post descending
- **WHEN** `sortByLastPostDesc` is true
- **THEN** the URL SHALL include `;sort=last_post;desc`

#### Scenario: Duplicate page detection
- **WHEN** two consecutive pages return the same topic ID set
- **THEN** scraping SHALL stop

#### Scenario: Max pages and early stop
- **WHEN** `maxPages` is reached or `shouldContinueAfterPage` returns false
- **THEN** scraping SHALL stop

#### Scenario: Lesser board max pages cap
- **WHEN** scraping board 3
- **THEN** pages SHALL be capped at `lesserBoardMaxPages` (default 20)

### Requirement: Mod index category scraper
The system SHALL scrape topic 177 to build topicId-to-category mappings. It SHALL handle main (first post) and archived (subsequent posts) categories, apply a legacy category name map, and track unknown legacy categories. Category-header extraction SHALL be robust to intermediate elements (for example `<br>`) between the label and its topic list, SHALL reject nested `<strong>` elements that are not direct children of the category cell, SHALL strip any number of trailing `:` from labels, SHALL preserve the canonical casing of main-post category names while comparing case-insensitively, and SHALL emit parity diagnostic logs.

#### Scenario: Parse mod index
- **WHEN** topic 177 is fetched
- **THEN** the system SHALL match category headers with a direct-child chain `table.bbc_table > tbody > tr > td > strong`, and for each header SHALL locate the topic list by walking all following element siblings and picking the first `ul.bbc_list`

#### Scenario: Low link count retry
- **WHEN** fewer than 20 topic links are found
- **THEN** the system SHALL retry with `;all` suffix

#### Scenario: Intermediate element between header and list
- **WHEN** a `<strong>` category header is followed by a `<br>` (or any non-`<ul>` element) before the `<ul class="bbc_list">`
- **THEN** the scraper SHALL still find that `<ul>` and map its topics to the header's category

#### Scenario: Legacy category mapping
- **WHEN** an archived category is not in the main categories set
- **THEN** it SHALL be mapped via the legacy map (e.g., "Factions" → "Faction Mods"); unmapped categories become "uncategorized" and are tracked as unknowns

#### Scenario: Nested strong ignored
- **WHEN** a `<strong>` element appears nested inside a descendant of `<td>` (for example inside a `<p>` in a description) rather than as a direct child of `<td>`
- **THEN** it SHALL NOT be treated as a category header

#### Scenario: Trailing colons stripped
- **WHEN** a category label ends with one or more `:` characters (for example "Factions:::")
- **THEN** all trailing `:` SHALL be removed before normalization

#### Scenario: Main-category casing preserved
- **WHEN** the result object exposes the set of main-post categories
- **THEN** values SHALL retain their original casing (for example "Faction Mods"), and membership checks against either casing SHALL succeed

#### Scenario: Diagnostic logging
- **WHEN** a mod-index scrape completes
- **THEN** the scraper SHALL log the distinct main-post categories and up to the first 10 topic-to-category sample mappings at INFO level

#### Scenario: Unknown-legacy warning includes map source
- **WHEN** one or more archived categories cannot be resolved via the legacy map
- **THEN** the WARNING log SHALL include a pointer to `lib/bot/scraper/qb/legacy_category_map.dart` so operators know which source file to edit

#### Scenario: Case-insensitive unknown-legacy dedupe
- **WHEN** `unknownLegacyCategories` contains entries that differ only by casing
- **THEN** the logged set SHALL be deduplicated case-insensitively

### Requirement: Topic scraper
The system SHALL scrape individual topic pages to extract full first-post content and metadata, producing `QbModDetail` objects.

#### Scenario: Extract OP content
- **WHEN** a topic page is fetched
- **THEN** the system SHALL extract `div.post div.inner` innerHTML as content HTML

#### Scenario: Resolve lazy-loaded images
- **WHEN** `<img>` tags have `src` containing `loading.gif`
- **THEN** the system SHALL check `data-imageurl`, `data-src`, `data-original` attributes; if absent and `alt` matches a URL pattern, use `alt`

#### Scenario: Extract title
- **WHEN** parsing a topic page
- **THEN** title SHALL come from `#top_subject`, stripping "Topic:" prefix and "(Read N times)" suffix

#### Scenario: Extract author info
- **WHEN** parsing the first post
- **THEN** author name from `div.poster h4 a`, rank from first `ul li`, post count from "Posts:" li, avatar from `img.avatar`

#### Scenario: Extract images and links
- **WHEN** processing content HTML
- **THEN** images SHALL be extracted via regex (skipping smileys, icons, data: URIs); links SHALL be extracted via regex (skipping spoiler ranges, # anchors, javascript: hrefs), with HTML-decoded hrefs

#### Scenario: Board-3 quality gate
- **WHEN** a topic is from board 3 with no external file-hosting links (excluding forum, Nexus, YouTube)
- **THEN** it SHALL be skipped

### Requirement: HTML post-processing
The system SHALL post-process scraped content HTML for bundle consumption.

#### Scenario: External link annotation
- **WHEN** processing content HTML
- **THEN** non-forum links without `target` SHALL get `target="_blank" rel="noopener"`

#### Scenario: SMF smiley replacement
- **WHEN** `<img>` tags match `/Smileys/`
- **THEN** they SHALL be replaced with their `alt` text

#### Scenario: Last edit span removal
- **WHEN** content contains last-edit metadata spans
- **THEN** those spans SHALL be removed

#### Scenario: Original image URLs preserved
- **WHEN** processing content HTML
- **THEN** image `src` attributes SHALL NOT be rewritten

### Requirement: Throttled HTTP requests
The system SHALL enforce a configurable minimum delay between requests and set a browser-like User-Agent.

#### Scenario: Request throttling
- **WHEN** multiple requests are made in sequence
- **THEN** at least `delayMs` milliseconds (default 1500) SHALL elapse between them

#### Scenario: Browser User-Agent
- **WHEN** making HTTP requests
- **THEN** a browser-like User-Agent header SHALL be set

### Requirement: Data persistence
The system SHALL persist scraped data to disk in a structured layout.

#### Scenario: Index persistence
- **WHEN** the scraper completes
- **THEN** `{dataPath}/mods-index.json` SHALL contain the full `QbModSummary` list

#### Scenario: Detail persistence
- **WHEN** a topic detail is scraped
- **THEN** `{dataPath}/mods/{topicId}/detail.json` SHALL contain the `QbModDetail`

#### Scenario: Thumbnail selection
- **WHEN** selecting a thumbnail
- **THEN** the first non-shields.io, non-loading.gif image SHALL be stored as `"ext:{originalUrl}"`

### Requirement: Incremental scraping
The system SHALL support `new_data` scope that only re-scrapes topics with changed `lastPostDate`.

#### Scenario: Detect changed topics
- **WHEN** running in `new_data` scope
- **THEN** only topics with new or different `lastPostDate` SHALL be re-scraped

#### Scenario: Early stop on unchanged pages
- **WHEN** a board page (sorted by last post desc) has no changed topics
- **THEN** scraping SHALL stop for that board

### Requirement: Scraper engine orchestration
The system SHALL orchestrate the full pipeline: mod index → boards → topic scraping → persistence. It SHALL merge topics from multiple boards with dedup priority main > lesser > library.

#### Scenario: Full pipeline
- **WHEN** the engine runs
- **THEN** it SHALL: scrape mod index, scrape boards, merge/dedup, apply categories, scrape topics, process HTML, save to store, track meaningful changes

#### Scenario: Category priority
- **WHEN** assigning categories
- **THEN** mod index category first; "libraries" for library-only topics; title-guess fallback for uncategorized

#### Scenario: Board merge deduplication
- **WHEN** a topic ID appears on multiple boards
- **THEN** main (8) takes priority over lesser (3) over library (9)

#### Scenario: Meaningful change detection
- **WHEN** a scrape completes
- **THEN** the system SHALL compare pre/post values of title, category, inModIndex, isArchivedModIndex, gameVersion, author, createdDate, thumbnailPath, isWip, sourceBoard and log changed topic IDs
