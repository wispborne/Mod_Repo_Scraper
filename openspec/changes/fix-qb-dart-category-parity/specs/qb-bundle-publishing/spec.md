## MODIFIED Requirements

### Requirement: Bundle assembly
The system SHALL assemble a `ForumDataBundle` from the scraped data store and resolved download candidates. When emitting each detail into `bundle.details`, the system SHALL backfill a null `detail.category` from the matching `summary.category` in the index, so every detail record in the published bundle carries a category value whenever the index has one.

#### Scenario: Create bundle
- **WHEN** bundle creation is triggered
- **THEN** the system SHALL load the full index and all details, sort by topicId, strip `localPath` from image refs, collect assumed downloads sorted by topicId, set `updatedAt` to max `scrapedAt`

#### Scenario: Stable JSON output
- **WHEN** the bundle is created
- **THEN** index entries and map keys SHALL be sorted by topicId to produce deterministic output for minimal git diffs

#### Scenario: Strip local image paths
- **WHEN** assembling the bundle
- **THEN** all `ImageRef.localPath` values SHALL be empty string

#### Scenario: Backfill detail category from summary
- **WHEN** a detail being emitted into the bundle has `category == null` and the matching summary has a non-empty category (for example "Faction Mods")
- **THEN** the emitted `QbModDetail.category` SHALL be set to the summary's category value

#### Scenario: Respect detail category when already set
- **WHEN** a detail being emitted into the bundle already has a non-null `category`
- **THEN** the emitted detail SHALL retain that value and SHALL NOT be overwritten by the summary's category
