## ADDED Requirements

### Requirement: Download URL classification and resolution
The system SHALL classify and resolve direct download URLs from links found in forum topic first posts, with host-specific resolution logic.

#### Scenario: GitHub direct asset link
- **WHEN** a link matches a GitHub releases download URL pattern (e.g., `/releases/download/{tag}/{file}`)
- **THEN** it SHALL be high confidence with filename extracted from URL path

#### Scenario: GitHub releases page
- **WHEN** a link points to a GitHub releases page
- **THEN** the system SHALL call GitHub API to find the first archive asset (.zip, .rar, .7z, etc.), skipping "source" archives; if found, high confidence; otherwise low confidence with `requiresManualStep=true`

#### Scenario: Google Drive link
- **WHEN** a link points to `drive.google.com` or `drive.usercontent.google.com`
- **THEN** the system SHALL normalize to `uc?export=download` form and probe for filename; medium confidence

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

#### Scenario: URL shortener resolution
- **WHEN** a link points to a known shortener (tinyurl, bit.ly, t.co, goo.gl, ow.ly, is.gd, buff.ly, rebrand.ly)
- **THEN** the system SHALL follow the redirect to resolve the real host, then classify

#### Scenario: Non-archive files filtered
- **WHEN** a candidate suggests a non-archive extension (.ogg, .mp3, .png, .jpg, .pdf, .txt, .jar, .exe, etc.)
- **THEN** that candidate SHALL be skipped

### Requirement: URL normalization
The system SHALL normalize hosting-provider URLs into direct-download forms.

#### Scenario: Google Drive normalization
- **WHEN** a Google Drive URL contains `/file/d/{id}`
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
- **WHEN** resolver logic changes
- **THEN** incrementing the schema version SHALL invalidate all old cache entries

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
