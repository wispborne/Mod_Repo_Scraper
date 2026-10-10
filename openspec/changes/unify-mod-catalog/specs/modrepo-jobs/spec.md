## MODIFIED Requirements

### Requirement: Merging is a job the manager can run
The manager SHALL offer two job kinds for the ModRepo pipeline: `mergeModRepo`, which merges from the data already saved on disk without touching the network, and `scrapeAndMerge`, which fetches the chosen sources (Discord and Nexus) and then merges. The forum is not a source either kind fetches: its listings SHALL be read from the QB store. Both kinds SHALL write `ModRepo-v2.json` and, when merge debug data was collected, a merge snapshot. Neither kind SHALL send anything to an LLM; LLM listings SHALL be read from the answers already stored. Every QB job kind that can change listings (`fullRun`, `rescrapeTopics`, `extractLlm`, `llmCoveragePass`, `rebuildBundle`) SHALL end with the same merge, followed by the site build.

#### Scenario: Merge from saved files
- **WHEN** a `mergeModRepo` job runs and the QB store and the Discord and Nexus cache files are on disk
- **THEN** the listings from all of them are merged, `ModRepo-v2.json` is written, and no network request is made

#### Scenario: Scrape then merge
- **WHEN** a `scrapeAndMerge` job runs asking for Discord and Nexus
- **THEN** each source is fetched, its cache file is written as that source finishes, and the merge runs over the fresh results and the QB store

#### Scenario: Source with no token
- **WHEN** a `scrapeAndMerge` job asks for Discord and no Discord token is set up
- **THEN** that source is skipped with a log line saying why, the job carries on with the others, and the job does not fail

#### Scenario: An LLM pass changes the catalog straight away
- **WHEN** an `llmCoveragePass` job finds that a topic holds four mods
- **THEN** the job ends with a merge and a site build, and the four mods are in `ModRepo-v2.json` when the job finishes

### Requirement: The ModRepo service is told what to do, never asked to look it up
The ModRepo service SHALL be built once with its environment (where the source caches, the QB store, outputs and snapshots live; the Discord and Nexus tokens and ids) and its guardrails (per-source scrape timeout, how many snapshots to keep). Everything about what one job does — which sources, whether to replay the Discord raw cache, whether to keep all game versions from one source, whether to collect merge debug data — SHALL arrive on the job request. The service MUST NOT read `config.properties`.

#### Scenario: A request cannot change the environment
- **WHEN** a job request is submitted over the web API
- **THEN** it can say which sources to scrape but cannot name a token, a data folder, or an output path

#### Scenario: Config keys are read in one place
- **WHEN** the CLI runs its ModRepo pipeline
- **THEN** the `modrepo_*` job-shape keys are read only where the request is built, and the service is handed the same environment whichever side started the job

### Requirement: A cancelled merge leaves the output alone
The ModRepo service SHALL check for cancellation between sources and between merge phases. A job cancelled before the merge finished SHALL write neither `ModRepo-v2.json` nor a snapshot, and SHALL say in its log that the existing output was left as it was. Source cache files already written SHALL be kept.

#### Scenario: Cancelled part-way through the merge
- **WHEN** the user cancels a `mergeModRepo` job while it is merging
- **THEN** the run is recorded as cancelled, `ModRepo-v2.json` is untouched, and the log says so

#### Scenario: Cancelled after one source finished
- **WHEN** the user cancels a `scrapeAndMerge` job after the Discord scrape finished but during the Nexus scrape
- **THEN** `discord_cache.json` holds the fresh Discord results and no merge output is written

## REMOVED Requirements

### Requirement: The CLI hands its ModRepo work to the manager
**Reason**: Its scenario "CLI run is unchanged from the outside" can no longer hold: the forum scrape and `ModRepo.json` are gone. The delegation behaviour itself is unchanged and is restated in the ADDED requirement below.
**Migration**: See "The CLI hands its catalog work to the manager".

## ADDED Requirements

### Requirement: The CLI hands its catalog work to the manager
`MainRepoScraper.main` SHALL turn the config file's `modrepo_*` keys into one job request and submit it, rather than running the pipeline inline. When `qb_manager_url` names a running manager, the merge job SHALL be delegated to it on the same terms as the QB job — matching data paths, live progress, the usual summary — and SHALL run locally when it cannot be. The `modrepo_forums_enabled` key and the forum page-count keys SHALL be removed; a config file that still sets them SHALL get the usual unknown-key warning.

#### Scenario: Old forum key in the config file
- **WHEN** `config.properties` still sets `modrepo_forums_enabled`
- **THEN** the run warns that the key is not recognized and carries on

#### Scenario: Merge and QB share one queue
- **WHEN** a CLI merge is delegated to a running manager that is busy with a QB run
- **THEN** the merge is queued behind it, shows in the queue on the Runs view, and starts when the QB run ends
