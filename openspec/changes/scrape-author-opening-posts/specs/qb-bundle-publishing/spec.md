## MODIFIED Requirements

### Requirement: Bundle assembly
The system SHALL assemble a `ForumDataBundle` from the scraped data store and resolved download candidates. When emitting each detail into `bundle.details`, the system SHALL backfill a null `detail.category` from the matching `summary.category` in the index, so every detail record in the published bundle carries a category value whenever the index has one. Each emitted detail SHALL carry its `extraPosts` with the same cleaning as the first post: session ids stripped from each post's HTML, and every `ImageRef.localPath` blanked. The field SHALL be additive — every field TriOS already reads keeps its meaning, and `contentHtml` remains the first post alone. The system SHALL always emit the rule-based resolver's candidates into `assumedDownloads` and SHALL NOT overwrite `assumedDownloads` with LLM output; the resolver's candidates for a topic SHALL be resolved from the union of the first post's and the extra posts' links. When the LLM store has an entry for a thread, the system SHALL attach that thread's LLM output to the matching `index` item's `llm` field.

#### Scenario: Create bundle
- **WHEN** bundle creation is triggered
- **THEN** the system SHALL load the full index and all details, sort by topicId, strip `localPath` from image refs (extra posts included), collect assumed downloads sorted by topicId, set `updatedAt` to the latest `scrapedAt`

#### Scenario: Extra posts ride additively
- **WHEN** a detail with `extraPosts` is emitted into the bundle
- **THEN** the extra posts appear on the detail with session ids stripped, and `contentHtml`, `images`, and `links` still describe the first post alone

#### Scenario: Downloads from a follow-up post
- **WHEN** a thread's only download links sit in the author's second post
- **THEN** `assumedDownloads.<topicId>` SHALL contain the resolver's candidates for those links

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
- **THEN** all `ImageRef.localPath` values SHALL be empty string, in `extraPosts` entries too

#### Scenario: Backfill detail category from summary
- **WHEN** a detail being emitted into the bundle has `category == null` and the matching summary has a non-empty category (for example "Faction Mods")
- **THEN** the emitted `QbModDetail.category` SHALL be set to the summary's category value

#### Scenario: Respect detail category when already set
- **WHEN** a detail being emitted into the bundle already has a non-null `category`
- **THEN** the emitted detail SHALL retain that value and SHALL NOT be overwritten by the summary's category
