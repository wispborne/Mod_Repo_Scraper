## ADDED Requirements

### Requirement: Link-level downloadable classification
The QB topic scraper SHALL classify every extracted forum link as downloadable-or-not at scrape time and persist that classification on the `LinkRef` record, so that downstream consumers (bundle publisher, merger, debug HTML, logs) can distinguish mod-download links from supporting links without re-deriving the signal.

#### Scenario: Link with archive-file URL is flagged downloadable
- **WHEN** an extracted link's URL contains an archive extension (`.zip`, `.rar`, `.7z`)
- **THEN** its `LinkRef.isDownloadable` SHALL be `true`

#### Scenario: Known file-hosting hosts are flagged downloadable
- **WHEN** an extracted link's URL host matches a known file-hosting host (`drive.google.com`, `mega.nz`, `mediafire.com`)
- **THEN** its `LinkRef.isDownloadable` SHALL be `true`

#### Scenario: Non-download supporting links are not flagged
- **WHEN** an extracted link points at imgur, youtube, a forum topic, a nexus mod page, a patreon post, or any other non-file destination not covered by the heuristic
- **THEN** its `LinkRef.isDownloadable` SHALL be `false`

#### Scenario: Classification uses sync heuristic first, async probe for the uncertain tail
- **WHEN** the QB topic scraper classifies a link during scraping
- **THEN** it SHALL first evaluate the synchronous extension/host heuristic (`isLikelyModDownloadUrl`); if that returns `true`, the link SHALL be flagged `isDownloadable = true` without issuing any HTTP request
- **AND** if the sync heuristic returns `false`, the classifier SHALL fall through to an async HTTP probe that inspects `Content-Disposition` and `Content-Type` (the same logic as the legacy `Common.isDownloadable`), with the probe's result being the final value of `isDownloadable`

#### Scenario: Probes within a topic run concurrently
- **WHEN** a topic has multiple links requiring the async probe
- **THEN** the probes SHALL be issued concurrently via `Future.wait`, so per-topic wall time is bounded by the slowest single probe, not the sum

#### Scenario: Probe failure falls back to sync answer
- **WHEN** the async probe errors, times out, or returns an ambiguous response
- **THEN** `isDownloadable` SHALL fall back to what the sync heuristic returned (effectively `false` when the sync heuristic did not already short-circuit to `true`)

#### Scenario: Cached bundles are not re-probed
- **WHEN** a later scrape run reuses an already-persisted `QbModDetail` from the bundle cache
- **THEN** the cached `LinkRef.isDownloadable` values SHALL be trusted and no new probe SHALL be issued for those links

#### Scenario: Default for deserialized pre-existing bundles
- **WHEN** a cached `QbModDetail` JSON from before this change is deserialized by the mapper
- **THEN** any `LinkRef` missing `isDownloadable` SHALL default to `false` at the mapper layer

#### Scenario: Backfill on load for legacy cached details
- **WHEN** `JsonDataStore.loadDetail` reads a cached `QbModDetail` whose links have `isDownloadable = false`
- **THEN** each such link SHALL be re-evaluated with the synchronous heuristic (`isLikelyModDownloadUrl`) before being returned; any link whose URL passes the heuristic SHALL be upgraded to `isDownloadable = true`
- **AND** links already marked `isDownloadable = true` SHALL NOT be downgraded

### Requirement: Downloadable flag surfaces in link string form, additively
The `isDownloadable` classification SHALL appear in `LinkRef.toString()` as an additive field, preserving the positions and syntax of the pre-existing `url`, `text`, and `isExternal` fields so that readers of the previous format continue to work.

#### Scenario: Existing fields appear unchanged in `toString()`
- **WHEN** `LinkRef.toString()` is called
- **THEN** `url`, `text`, and `isExternal` SHALL appear in the output in the same order and with the same surrounding syntax as before this change

#### Scenario: `isDownloadable` is appended to `toString()` output
- **WHEN** `LinkRef.toString()` is called on a `LinkRef`
- **THEN** the output SHALL include the `isDownloadable` field value after the pre-existing fields (consistent with how `dart_mappable` appends newly-declared fields)

#### Scenario: No reordering or removal of prior fields
- **WHEN** this change lands
- **THEN** no existing field SHALL be removed from or reordered in `LinkRef.toString()` output

### Requirement: Shared downloadable-link heuristic between QB and legacy scrapers
The "is this URL a mod download?" heuristic SHALL live in a single shared module that both the QB scraper and the legacy (Discord/forum) scraper call into, so that the two pipelines cannot disagree on classification.

#### Scenario: Legacy scraper uses the shared helper
- **WHEN** the legacy Discord reader decides whether a URL is a "definite download link"
- **THEN** it SHALL delegate to the shared helper rather than maintain its own private implementation

#### Scenario: QB scraper uses the shared helper
- **WHEN** the QB topic scraper populates `LinkRef.isDownloadable`
- **THEN** it SHALL delegate to the same shared helper

#### Scenario: Shared helper preserves legacy semantics
- **WHEN** the shared helper is called with any URL the legacy `_isDefiniteDownloadLink` previously returned `true` for
- **THEN** the shared helper SHALL also return `true` (no regression in legacy classification)
