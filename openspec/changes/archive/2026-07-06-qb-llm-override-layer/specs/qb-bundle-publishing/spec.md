## MODIFIED Requirements

### Requirement: Forum data bundle model
The system SHALL define a `ForumDataBundle` with: `updatedAt` (DateTime), `index` (List<QbModSummary>), `details` (Map<String, QbModDetail>), `assumedDownloads` (Map<String, List<AssumedDownloadCandidate>>), and an optional `llm` (Map<String, LlmModData>). Map keys SHALL be string representations of topic IDs. `assumedDownloads` SHALL hold only rule-based download candidates and SHALL be the pure base layer that a consumer shows when LLM data is turned off. The `llm` block SHALL be the separate override layer: for each topic it MAY carry the LLM's reconciled `downloads` list plus the LLM extras (version, changelog, support links, license, summary). The `llm` block SHALL be absent when the LLM feature is off or produced nothing.

#### Scenario: Serialize bundle to JSON
- **WHEN** a bundle is serialized
- **THEN** the output SHALL use indented formatting, camelCase keys, omit nulls, and use string keys for maps

#### Scenario: Base and override layers are separate
- **WHEN** the LLM has a result for a topic
- **THEN** the topic's rule-based downloads SHALL remain in `assumedDownloads` unchanged, and the LLM's reconciled downloads and extras SHALL appear only under `llm.<topicId>`

#### Scenario: LLM feature off
- **WHEN** the LLM feature is disabled
- **THEN** the bundle SHALL contain no `llm` block, and `assumedDownloads` SHALL be the rule-based lists

### Requirement: Bundle assembly
The system SHALL assemble a `ForumDataBundle` from the scraped data store and resolved download candidates. When emitting each detail into `bundle.details`, the system SHALL backfill a null `detail.category` from the matching `summary.category` in the index, so every detail record in the published bundle carries a category value whenever the index has one. The system SHALL always emit the rule-based resolver's candidates into `assumedDownloads` and SHALL NOT overwrite `assumedDownloads` with LLM output. When the LLM store has an entry for a topic, the system SHALL emit that topic's LLM download list and extras into the `llm` block instead.

#### Scenario: Create bundle
- **WHEN** bundle creation is triggered
- **THEN** the system SHALL load the full index and all details, sort by topicId, strip `localPath` from image refs, collect assumed downloads sorted by topicId, set `updatedAt` to max `scrapedAt`

#### Scenario: Assumed downloads stay rule-based even with LLM on
- **WHEN** the LLM feature is on and a topic has an LLM result
- **THEN** `assumedDownloads.<topicId>` SHALL contain the rule-based candidates for that topic, unchanged by the LLM

#### Scenario: LLM data emitted into the llm block
- **WHEN** the LLM store has a non-empty entry for a topic
- **THEN** that topic's reconciled downloads and any non-empty extras SHALL be written under `llm.<topicId>`, sorted by topicId

#### Scenario: Stable JSON output
- **WHEN** the bundle is created
- **THEN** index entries and map keys (including `llm` keys) SHALL be sorted by topicId to produce deterministic output for minimal git diffs

#### Scenario: Strip local image paths
- **WHEN** assembling the bundle
- **THEN** all `ImageRef.localPath` values SHALL be empty string

#### Scenario: Backfill detail category from summary
- **WHEN** a detail being emitted into the bundle has `category == null` and the matching summary has a non-empty category (for example "Faction Mods")
- **THEN** the emitted `QbModDetail.category` SHALL be set to the summary's category value

#### Scenario: Respect detail category when already set
- **WHEN** a detail being emitted into the bundle already has a non-null `category`
- **THEN** the emitted detail SHALL retain that value and SHALL NOT be overwritten by the summary's category
