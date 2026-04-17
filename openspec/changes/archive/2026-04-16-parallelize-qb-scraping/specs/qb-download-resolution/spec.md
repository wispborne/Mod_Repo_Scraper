## MODIFIED Requirements

### Requirement: Download URL classification and resolution
The system SHALL classify and resolve direct download URLs from links found in forum topic first posts, with host-specific resolution logic. External links within a single topic SHALL be resolved concurrently rather than sequentially.

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

## ADDED Requirements

### Requirement: Resolver accepts unthrottled client
The `QbDownloadResolver` SHALL accept an `http.Client` parameter for external HTTP requests, separate from the forum `ThrottledClient`. The resolver SHALL NOT depend on `ThrottledClient`.

#### Scenario: Constructor accepts http.Client
- **WHEN** `QbDownloadResolver` is constructed
- **THEN** it SHALL accept a named `http.Client` parameter for making HTTP requests to external hosts

#### Scenario: URL shortener following uses unthrottled client
- **WHEN** a URL shortener (tinyurl.com, bit.ly, etc.) is followed
- **THEN** the request SHALL use the unthrottled HTTP client
