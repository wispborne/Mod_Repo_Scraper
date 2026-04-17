## ADDED Requirements

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
