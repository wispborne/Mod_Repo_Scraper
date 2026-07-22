## ADDED Requirements

### Requirement: Merging is a job the manager can run
The manager SHALL offer two job kinds for the ModRepo pipeline: `mergeModRepo`, which merges from the source files already saved on disk without touching the network, and `scrapeAndMerge`, which fetches the chosen sources and then merges. Both kinds SHALL write `ModRepo.json` and, when merge debug data was collected, a merge snapshot. Neither kind SHALL send anything to an LLM.

#### Scenario: Merge from saved files
- **WHEN** a `mergeModRepo` job runs and the Forum, Discord and Nexus cache files are on disk
- **THEN** the mods in those files are merged, `ModRepo.json` is written, and no network request is made

#### Scenario: Scrape then merge
- **WHEN** a `scrapeAndMerge` job runs asking for all three sources
- **THEN** each source is fetched, its cache file is written as that source finishes, and the merge runs over the fresh results

#### Scenario: Source with no token
- **WHEN** a `scrapeAndMerge` job asks for Discord and no Discord token is set up
- **THEN** that source is skipped with a log line saying why, the job carries on with the others, and the job does not fail

### Requirement: The ModRepo service is told what to do, never asked to look it up
The ModRepo service SHALL be built once with its environment (where the source caches, outputs and snapshots live; the Discord and Nexus tokens and ids) and its guardrails (per-source scrape timeout, how many snapshots to keep). Everything about what one job does — which sources, how many forum pages, whether to replay the Discord raw cache, whether to keep all game versions from one source, whether to collect merge debug data — SHALL arrive on the job request. The service MUST NOT read `config.properties`.

#### Scenario: A request cannot change the environment
- **WHEN** a job request is submitted over the web API
- **THEN** it can say which sources to scrape but cannot name a token, a data folder, or an output path

#### Scenario: Config keys are read in one place
- **WHEN** the CLI runs its ModRepo pipeline
- **THEN** the `modrepo_*` job-shape keys are read only where the request is built, and the service is handed the same environment whichever side started the job

### Requirement: The CLI hands its ModRepo work to the manager
`MainRepoScraper.main` SHALL turn the config file's `modrepo_*` keys into one job request and submit it, rather than running the pipeline inline. When `qb_manager_url` names a running manager, the merge job SHALL be delegated to it on the same terms as the QB job — matching data paths, live progress, the usual summary — and SHALL run locally when it cannot be.

#### Scenario: CLI run is unchanged from the outside
- **WHEN** the CLI runs with the same config as before this change
- **THEN** the same files are written, the same lines are logged, and the exit code is the same

#### Scenario: Merge and QB share one queue
- **WHEN** a CLI merge is delegated to a running manager that is busy with a QB run
- **THEN** the merge is queued behind it, shows in the queue on the Runs view, and starts when the QB run ends

### Requirement: A cancelled merge leaves the output alone
The ModRepo service SHALL check for cancellation between sources and between merge phases. A job cancelled before the merge finished SHALL write neither `ModRepo.json` nor a snapshot, and SHALL say in its log that the existing output was left as it was. Source cache files already written SHALL be kept.

#### Scenario: Cancelled part-way through the merge
- **WHEN** the user cancels a `mergeModRepo` job while it is merging
- **THEN** the run is recorded as cancelled, `ModRepo.json` is untouched, and the log says so

#### Scenario: Cancelled after one source finished
- **WHEN** the user cancels a `scrapeAndMerge` job after the Forum scrape finished but during the Discord scrape
- **THEN** `forum_cache.json` holds the fresh Forum results and no merge output is written

### Requirement: A merge run reports its progress
The ModRepo service SHALL report phases by name (each source, then the merge, then the save) and SHALL report how many mods have been merged out of how many, so the progress bar means something on the long step.

#### Scenario: Watching a merge from the browser
- **WHEN** a merge job is running and the user is on the Runs view
- **THEN** the phase name and the merged-so-far count update about once a second without reloading the page
