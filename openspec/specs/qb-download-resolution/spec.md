# qb-download-resolution

## Purpose

Turn the links in a mod's forum post into real download addresses — following the rules each host needs, tidying and de-duplicating them, and remembering the answers so the same link isn't chased twice.
## Requirements
### Requirement: Download URL classification and resolution
The system SHALL classify and resolve direct download URLs from links found in forum topic first posts, with host-specific resolution logic.

#### Scenario: GitHub direct asset link
- **WHEN** a link matches a GitHub releases download URL pattern (`/releases/download/{tag}/{file}` or the latest-release permalink `/releases/latest/download/{file}`)
- **THEN** it SHALL be high confidence with filename extracted from URL path

#### Scenario: GitHub releases page
- **WHEN** a link points to a GitHub releases page
- **THEN** the system SHALL call GitHub API to find the first archive asset (.zip, .rar, .7z, etc.), skipping "source" archives; if found, high confidence; otherwise low confidence with `requiresManualStep=true`

#### Scenario: Google Drive link
- **WHEN** a link points to `drive.google.com` or `drive.usercontent.google.com`
- **THEN** the system SHALL normalize to `uc?export=download` form and probe for filename; medium confidence

#### Scenario: Google Drive folder link
- **WHEN** a Google Drive link points to a folder (`/drive/folders/...`, `/folderview`, or an `open?id=` link whose redirect lands on a folder)
- **THEN** it SHALL be low confidence with `requiresManualStep=true`, keeping the folder URL

#### Scenario: Google Drive open?id= link
- **WHEN** a Google Drive link is in `open?id=` form (which can hide a file or a folder)
- **THEN** the system SHALL follow the redirect once to find out which; a folder is handled per the folder scenario, a file (or an unreadable redirect) is handled per the normal Drive scenario

#### Scenario: Dropbox link
- **WHEN** a link points to `dropbox.com`
- **THEN** the system SHALL normalize `dl=0` to `dl=1`, extract filename from path; medium confidence

#### Scenario: MediaFire link
- **WHEN** a link points to `mediafire.com`
- **THEN** the system SHALL fetch the page HTML and extract CDN URL via regex; if found, medium confidence; otherwise low with `requiresManualStep=true`

#### Scenario: OneDrive link
- **WHEN** a link points to `onedrive.live.com` or `1drv.ms`
- **THEN** the system SHALL append `download=1`; medium confidence

#### Scenario: Bitbucket downloads link
- **WHEN** a link points to `bitbucket.org` with `/downloads/` in the path
- **THEN** it SHALL extract the filename from the URL and return high confidence

#### Scenario: Concurrent resolution within a topic
- **WHEN** `resolveForTopic` is called with multiple external links
- **THEN** all links SHALL be resolved concurrently using `Future.wait`
- **AND** post-processing (filename extraction, inference, filtering, dedup) SHALL run after all links have resolved

#### Scenario: Unthrottled HTTP client for external requests
- **WHEN** the resolver makes HTTP requests to external hosts
- **THEN** it SHALL use an unthrottled HTTP client, not the forum-throttled client

#### Scenario: Patreon link
- **WHEN** a link points to `patreon.com`
- **THEN** low confidence with `requiresManualStep=true`

#### Scenario: Unknown host confirmed by probe
- **WHEN** a link's host matches no host-specific rule
- **THEN** the system SHALL probe the URL to see whether it serves a file — an obvious archive extension short-circuits with no request; otherwise a HEAD (falling back to GET) inspects `Content-Disposition` and `Content-Type`
- **AND** the answer SHALL be saved (in `link-downloadable-cache.json`), so each link only goes to the network once across runs and paths; a link being checked twice at the same time SHALL only make one request
- **AND** if the URL serves a file, it SHALL be medium confidence with `requiresManualStep=false`
- **AND** if it does not, it SHALL be treated as unresolved (dropped on the rules path, kept as a low-confidence manual step on the LLM path)

#### Scenario: URL shortener resolution
- **WHEN** a link points to a known shortener (tinyurl, bit.ly, t.co, goo.gl, ow.ly, is.gd, buff.ly, rebrand.ly)
- **THEN** the system SHALL follow the redirect to resolve the real host, then classify

#### Scenario: Non-archive files filtered
- **WHEN** a candidate suggests a non-archive extension (.ogg, .mp3, .png, .jpg, .pdf, .txt, .jar, .exe, etc.)
- **THEN** that candidate SHALL be skipped

### Requirement: URL normalization
The system SHALL normalize hosting-provider URLs into direct-download forms.

#### Scenario: Google Drive normalization
- **WHEN** a Google Drive URL contains `/file/d/{id}` or is in `open?id={id}` form
- **THEN** it SHALL be normalized to `https://drive.google.com/uc?export=download&id={id}`

#### Scenario: Dropbox normalization
- **WHEN** a Dropbox URL has `dl=0` or no dl parameter
- **THEN** it SHALL be normalized to `dl=1`

#### Scenario: OneDrive normalization
- **WHEN** a OneDrive URL lacks `download=1`
- **THEN** it SHALL be appended

#### Scenario: GitHub blob to raw
- **WHEN** a GitHub URL contains `/blob/`
- **THEN** it SHALL be rewritten to `raw.githubusercontent.com` with `/blob/` removed

### Requirement: Post-resolution deduplication
The system SHALL deduplicate resolved download candidates.

#### Scenario: Dedup by resolved URL
- **WHEN** multiple candidates resolve to the same normalized URL
- **THEN** only the first SHALL be kept

#### Scenario: Dedup by archive filename
- **WHEN** candidates from different hosts have the same archive filename
- **THEN** only the first SHALL be kept

#### Scenario: Alternate download filename inference
- **WHEN** only one unique filename exists and a nameless candidate's link text contains "alternate"
- **THEN** that candidate SHALL be assigned the known filename

#### Scenario: Google Drive filename inference
- **WHEN** a Google Drive candidate has no filename but one unique filename exists among siblings
- **THEN** it SHALL be assigned that filename

### Requirement: Filename extraction
The system SHALL extract archive filenames from URLs, link text, and HTTP responses.

#### Scenario: Filename from link text
- **WHEN** link text contains an archive filename pattern
- **THEN** it SHALL be extracted (link text takes priority over URL)

#### Scenario: Filename from URL path
- **WHEN** a URL path contains an archive filename
- **THEN** it SHALL be extracted

#### Scenario: Filename from Content-Disposition header
- **WHEN** an HTTP response includes Content-Disposition with filename or filename*
- **THEN** that filename SHALL be used if it has a supported archive extension

#### Scenario: Filename from Google Drive HTML
- **WHEN** a Google Drive page contains title, og:title, or JSON title matching an archive name
- **THEN** it SHALL be extracted

### Requirement: Resolution caching
The system SHALL cache resolution results with fingerprint-based invalidation.

#### Scenario: Cache hit
- **WHEN** a topic's link fingerprint matches the cached value
- **THEN** cached candidates SHALL be returned without HTTP calls

#### Scenario: Cache invalidation
- **WHEN** a topic's link set changes (different fingerprint)
- **THEN** resolution SHALL run fresh

#### Scenario: Disk persistence
- **WHEN** new results are computed
- **THEN** the cache SHALL be written to `{dataPath}/assumed-downloads-cache.json`

#### Scenario: Schema versioning
- **WHEN** resolver logic changes and the schema version is incremented
- **THEN** entries saved under the old version SHALL be kept and continue to fill the bundle, so no mod loses its download links in the meantime
- **AND** those topics SHALL be reported as outdated, and the next scrape run SHALL redo them from the links already saved on disk — no manual step needed

#### Scenario: Bundle-imported candidates
- **WHEN** candidates are imported via `importCandidates`
- **THEN** they SHALL use sentinel fingerprint `"bundle"` and be overwritten on next real resolve

### Requirement: Archive extension helpers
The system SHALL check and normalize archive file extensions.

#### Scenario: Supported extensions
- **WHEN** `hasSupportedArchiveExtension` is called with ".zip", ".rar", ".7z", ".tar.gz", ".tar", ".bz2", ".gz", ".xz"
- **THEN** it SHALL return true

#### Scenario: Base name extraction
- **WHEN** `getArchiveBaseName` is called with "MyMod.zip"
- **THEN** it SHALL return "MyMod"

### Requirement: Resolver accepts unthrottled client
The `QbDownloadResolver` SHALL accept an `http.Client` parameter for external HTTP requests, separate from the forum `ThrottledClient`. The resolver SHALL NOT depend on `ThrottledClient`.

#### Scenario: Constructor accepts http.Client
- **WHEN** `QbDownloadResolver` is constructed
- **THEN** it SHALL accept a named `http.Client` parameter for making HTTP requests to external hosts

#### Scenario: URL shortener following uses unthrottled client
- **WHEN** a URL shortener (tinyurl.com, bit.ly, etc.) is followed
- **THEN** the request SHALL use the unthrottled HTTP client

### Requirement: Resilient URL decoding
The system SHALL gracefully handle malformed percent-encoded URLs encountered during download resolution, without crashing or halting the scraping process.

#### Scenario: Malformed percent-encoding in Bitbucket URL
- **WHEN** a Bitbucket download URL contains invalid percent-encoding (e.g., `%252.2.7`)
- **THEN** the system SHALL skip filename extraction for that URL, return `null` for `archiveFilename`, and log a warning containing the malformed URL

#### Scenario: Malformed percent-encoding in Dropbox URL
- **WHEN** a Dropbox URL path segment contains invalid percent-encoding
- **THEN** the system SHALL skip filename extraction for that URL, return `null` for `archiveFilename`, and log a warning

#### Scenario: Malformed percent-encoding in Content-Disposition header
- **WHEN** a Content-Disposition header value contains invalid percent-encoding
- **THEN** the system SHALL return `null` for the filename and log a warning

#### Scenario: Valid percent-encoding still works
- **WHEN** a URL contains valid percent-encoding (e.g., `My%20Mod%20v1.0.zip`)
- **THEN** the system SHALL decode it normally and extract the filename as before

#### Scenario: Download candidate still created despite decode failure
- **WHEN** URL decoding fails during download resolution
- **THEN** a `DownloadCandidate` SHALL still be created with the original `resolvedUrl` intact, only `archiveFilename` SHALL be `null`

### Requirement: Per-URL error isolation in topic resolution
The download resolver SHALL catch and log exceptions during per-URL resolution so that one bad link does not prevent other links in the same topic from being resolved.

#### Scenario: Single URL resolution throws in resolveForTopic
- **WHEN** `_resolveLink` throws for a single URL during `resolveForTopic`
- **THEN** the system SHALL catch the error, log a warning with the URL, skip that candidate, and continue resolving remaining URLs

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
