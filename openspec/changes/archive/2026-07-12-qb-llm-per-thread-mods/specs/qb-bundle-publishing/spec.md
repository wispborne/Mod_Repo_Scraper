## MODIFIED Requirements

### Requirement: Forum data bundle model
The system SHALL define a `ForumDataBundle` with: `updatedAt` (DateTime), `index` (List<QbModSummary>), `details` (Map<String, QbModDetail>), and `assumedDownloads` (Map<String, List<AssumedDownloadCandidate>>). Map keys SHALL be string representations of topic IDs. `assumedDownloads` SHALL hold only rule-based download candidates and SHALL be exactly what a consumer uses when the LLM feature is off; the LLM SHALL never write into it. Each `QbModSummary` in `index` SHALL carry an optional `llm` field holding that thread's LLM output; the `ForumDataBundle` SHALL NOT have a top-level `llm` map. The `llm` field SHALL be absent on every index item when the LLM feature is off or produced nothing for that thread.

#### Scenario: Serialize bundle to JSON
- **WHEN** a bundle is serialized
- **THEN** the output SHALL use indented formatting, camelCase keys, omit nulls, and use string keys for maps

#### Scenario: LLM output lives on the index item
- **WHEN** the LLM has a result for a thread
- **THEN** that thread's LLM output SHALL appear under its `index` item's `llm` field, and the thread's rule-based downloads SHALL remain in `assumedDownloads` unchanged

#### Scenario: LLM feature off
- **WHEN** the LLM feature is disabled
- **THEN** no `index` item SHALL have an `llm` field, and `assumedDownloads` SHALL be the rule-based lists, matching the pre-change output

### Requirement: Bundle assembly
The system SHALL assemble a `ForumDataBundle` from the scraped data store and resolved download candidates. When emitting each detail into `bundle.details`, the system SHALL backfill a null `detail.category` from the matching `summary.category` in the index, so every detail record in the published bundle carries a category value whenever the index has one. The system SHALL always emit the rule-based resolver's candidates into `assumedDownloads` and SHALL NOT overwrite `assumedDownloads` with LLM output. When the LLM store has an entry for a thread, the system SHALL attach that thread's LLM output to the matching `index` item's `llm` field.

#### Scenario: Create bundle
- **WHEN** bundle creation is triggered
- **THEN** the system SHALL load the full index and all details, sort by topicId, strip `localPath` from image refs, collect assumed downloads sorted by topicId, set `updatedAt` to the latest `scrapedAt`

#### Scenario: Assumed downloads stay rule-based even with LLM on
- **WHEN** the LLM feature is on and a thread has an LLM result
- **THEN** `assumedDownloads.<topicId>` SHALL contain the rule-based candidates for that thread, unchanged by the LLM

#### Scenario: LLM data attached to the index item
- **WHEN** the LLM store has a non-empty entry for a thread
- **THEN** that thread's LLM output SHALL be attached to the matching `index` item's `llm` field

#### Scenario: Stable JSON output
- **WHEN** the bundle is created
- **THEN** index entries and map keys SHALL be sorted by topicId so the output is the same every run and git diffs stay small

#### Scenario: Strip local image paths
- **WHEN** assembling the bundle
- **THEN** all `ImageRef.localPath` values SHALL be empty string

#### Scenario: Backfill detail category from summary
- **WHEN** a detail being emitted into the bundle has `category == null` and the matching summary has a non-empty category (for example "Faction Mods")
- **THEN** the emitted `QbModDetail.category` SHALL be set to the summary's category value

#### Scenario: Respect detail category when already set
- **WHEN** a detail being emitted into the bundle already has a non-null `category`
- **THEN** the emitted detail SHALL retain that value and SHALL NOT be overwritten by the summary's category
