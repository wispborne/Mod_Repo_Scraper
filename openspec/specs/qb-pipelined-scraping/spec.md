# qb-pipelined-scraping

## Purpose

Work on each forum topic as soon as it is fetched, rather than in separate passes over everything, and keep the polite forum delay from slowing down calls to other sites.
## Requirements
### Requirement: Separate HTTP clients for forum and external hosts
The system SHALL use a throttled HTTP client exclusively for forum requests and an unthrottled HTTP client for all non-forum requests (GitHub API, Google Drive, MediaFire, Dropbox, OneDrive, Bitbucket, URL shorteners).

#### Scenario: Forum requests use throttled client
- **WHEN** a topic detail is fetched from the forum
- **THEN** the request SHALL go through `ThrottledClient` with the configured delay

#### Scenario: Download resolution uses unthrottled client
- **WHEN** a download link is resolved against an external host (e.g., GitHub API, Google Drive)
- **THEN** the request SHALL use the unthrottled HTTP client with no inter-request delay

#### Scenario: Unthrottled client has timeout
- **WHEN** a request is made via the unthrottled client
- **THEN** it SHALL have a configurable timeout (default 30 seconds)

### Requirement: Pipelined topic scraping loop
The system SHALL pipeline the topic scraping loop so that non-forum work (HTML processing, disk writes, download resolution) runs concurrently with the throttle wait for the next forum request, without increasing the forum request rate.

#### Scenario: Forum fetch rate unchanged
- **WHEN** multiple topics are scraped
- **THEN** forum HTTP requests SHALL maintain the same inter-request delay as the sequential implementation (one request per throttle interval)

#### Scenario: Processing overlaps with throttle wait
- **WHEN** a topic detail is fetched from the forum
- **THEN** HTML processing, detail persistence, and download resolution for that topic SHALL begin immediately without waiting for the next topic's forum fetch to complete

#### Scenario: Bounded concurrency
- **WHEN** the number of in-flight topic processing futures exceeds the concurrency limit
- **THEN** the system SHALL await the oldest pending future before initiating the next forum fetch

#### Scenario: Drain pending work at end of loop
- **WHEN** all topics have been fetched from the forum
- **THEN** the system SHALL await all remaining in-flight processing futures before proceeding to index save

### Requirement: Index bookkeeping after pipeline drain
The system SHALL update the index map and meaningful-change tracking for each topic after its processing future completes, and SHALL save the final index only after all processing futures have completed.

#### Scenario: Index saved after all processing completes
- **WHEN** the topic scraping loop finishes and all pending futures are drained
- **THEN** the final index SHALL be saved with all topic summaries updated

#### Scenario: Error in processing does not block pipeline
- **WHEN** a topic's processing future fails (e.g., download resolution error)
- **THEN** the error SHALL be logged, the error counter incremented, and the pipeline SHALL continue processing remaining topics
