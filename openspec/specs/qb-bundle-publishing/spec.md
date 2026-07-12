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

### Requirement: Git publishing
The system SHALL optionally publish the bundle to a local git repo clone.

#### Scenario: Write and push
- **WHEN** `qbRepoPath` is configured
- **THEN** the system SHALL write `forum-data-bundle.json`, run `git add`, `git commit -m "scrape update: {updatedAt}"`, and `git push`

#### Scenario: Skip push when unchanged
- **WHEN** git commit reports nothing to commit
- **THEN** push SHALL be skipped with an info log

#### Scenario: Skip when not configured
- **WHEN** `qbRepoPath` is null or empty
- **THEN** publishing SHALL be silently skipped

#### Scenario: Local bundle copy
- **WHEN** a scrape completes
- **THEN** the bundle SHALL be written to `{qbDataPath}/forum-data-bundle.json` regardless of repo config

### Requirement: Config integration
The system SHALL add QB scraper config to `config.properties` and `BotConfig`.

#### Scenario: Enable QB scraper
- **WHEN** `enable_qb=true` in config
- **THEN** the QB pipeline SHALL run after the existing pipeline

#### Scenario: Disabled by default
- **WHEN** `enable_qb` is absent
- **THEN** the QB scraper SHALL not run

#### Scenario: Configurable data path
- **WHEN** `qb_data_path` is set
- **THEN** all QB data SHALL be stored there; default `qb_data`

#### Scenario: Configurable scope
- **WHEN** `qb_scope` is `new_data`, `all`, or `pages`
- **THEN** the engine SHALL use the corresponding scope type; default `new_data`

#### Scenario: Configurable boards
- **WHEN** `qb_boards` is a comma-separated list
- **THEN** only listed boards SHALL be scraped; default `main,libraries`

#### Scenario: Configurable delay
- **WHEN** `qb_delay_ms` is set
- **THEN** the throttled client SHALL use that delay; default 1500

#### Scenario: Configurable repo path
- **WHEN** `qb_repo_path` is set to a directory
- **THEN** the bundle SHALL be published there via git

#### Scenario: Configurable lesser board max pages
- **WHEN** `qb_lesser_board_max_pages` is set
- **THEN** board 3 SHALL be capped at that page count; default 20

### Requirement: Entry point integration
The system SHALL invoke the QB pipeline from `main_repo_scraper.dart` after the existing pipeline.

#### Scenario: Sequential execution
- **WHEN** `enableQb` is true
- **THEN** the QB pipeline SHALL run after the Forum/Discord/Nexus pipeline completes, not in parallel

#### Scenario: Pipeline wiring
- **WHEN** the QB pipeline runs
- **THEN** it SHALL create scope from config, instantiate store/resolver/engine, run engine with download resolution callback, create bundle, optionally publish, and log results

#### Scenario: Error isolation
- **WHEN** the QB pipeline throws an exception
- **THEN** it SHALL be caught and logged without crashing the process
