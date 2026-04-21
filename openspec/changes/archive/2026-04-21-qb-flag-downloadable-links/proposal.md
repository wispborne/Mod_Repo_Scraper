## Why

The QB scraper extracts every `<a>` link from a forum topic's first post into `LinkRef` records, but nothing marks which of those links actually point at a mod download vs. a supporting page (images, wiki entries, unrelated forum posts, screenshots, etc.). Consumers (the bundle publisher, the merger, debug HTML) have to re-derive that signal or simply show all links the same way. The main (legacy) scraper already has proven logic for answering "is this URL a downloadable file?" — `Common.isDownloadable` + Discord reader's `_isDefiniteDownloadLink` heuristic — so we want the QB pipeline to reuse that and surface the result as a persistent flag on each `LinkRef`, and to include that flag when a link is rendered as a string.

## What Changes

- Add a `isDownloadable` boolean field to `LinkRef` (default `false`) in [mod_detail.dart](lib/bot/scraper/qb/models/mod_detail.dart).
- During topic scraping, evaluate each extracted link against the shared "is this a mod download?" heuristic and populate `isDownloadable` on the resulting `LinkRef` before it is persisted in the topic bundle.
- Extract the existing main-scraper heuristic (`_isDefiniteDownloadLink` in `discord_reader.dart` + `Common.isDownloadable`) into a single shared helper so both the legacy scraper and the QB scraper call the same code path. (Pure refactor; legacy behavior preserved.)
- Reflect the flag in any place a `LinkRef` is rendered as a human-readable string (i.e. `toString()` / debug-log formatting) by appending a trailing tag such as ` [downloadable]` when `isDownloadable` is true.
- Regenerate the `dart_mappable` serialization for `LinkRef` so the new field round-trips through the forum data bundle JSON.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `qb-download-resolution`: Add a requirement that each extracted forum link be classified as downloadable-or-not, that this classification is persisted on `LinkRef`, and that it surfaces in the link's string representation. Also add a requirement that the classification heuristic be shared with the legacy scraper rather than duplicated.

## Impact

- **Code**
  - [lib/bot/scraper/qb/models/mod_detail.dart](lib/bot/scraper/qb/models/mod_detail.dart) — add `isDownloadable` field to `LinkRef` and override `toString()` (or add a dedicated formatted string) that includes the flag.
  - [lib/bot/scraper/qb/topic_scraper.dart](lib/bot/scraper/qb/topic_scraper.dart) — populate `isDownloadable` when building `LinkRef`s in `_extractLinks`.
  - [lib/bot/scraper/qb/models/mod_detail.mapper.dart](lib/bot/scraper/qb/models/mod_detail.mapper.dart) — regenerated `dart_mappable` output.
  - New shared helper (e.g. `lib/bot/scraper/download_link_detector.dart` or extended `Common`) housing the cheap-heuristic + optional HTTP-probe logic currently split between `Common.isDownloadable` and `discord_reader._isDefiniteDownloadLink`.
  - [lib/bot/scraper/discord_reader.dart](lib/bot/scraper/discord_reader.dart) — switch to the shared helper; delete the now-duplicate private method.
- **Data format**: The cached `QbModDetail` JSON in the forum data bundle gains an `isDownloadable` boolean per link. Reading old cache entries must default missing values to `false`; no migration beyond that.
- **Dependencies**: None.
- **Performance**: The QB classifier uses only the cheap synchronous heuristic by default (extension + known-host substring check). No network calls are added to the QB hot path. The async `Common.isDownloadable` HEAD-like probe remains available for callers that want to opt in, but is NOT called from QB scraping by default to avoid an HTTP request per link.
