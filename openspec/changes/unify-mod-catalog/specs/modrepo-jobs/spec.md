## MODIFIED Requirements

### Requirement: Merging is a job the manager can run

The manager SHALL offer two catalog jobs:

- `mergeModRepo`: merge saved data without network calls.
- `scrapeAndMerge`: fetch the requested Discord and Nexus sources, then merge.

Both SHALL read forum listings from QB rather than scrape the forum. Both SHALL write `ModRepo-v2.json` and, when merge debug is collected, a merge snapshot.

Neither job SHALL call the LLM. They SHALL use stored forum and Discord results. Discord threads without extraction SHALL retain their rules listings until the next QB coverage pass.

QB jobs that can change listings (`fullRun`, `rescrapeTopics`, `extractLlm`, `llmCoveragePass`, `rebuildBundle`) SHALL finish with the same merge and then a site build.

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

The ModRepo service SHALL be constructed once with its environment and guardrails:

- Environment: source-cache, QB-store, output and snapshot locations; Discord and Nexus tokens and ids.
- Guardrails: per-source scrape timeout and snapshot retention limit.

Each job request SHALL specify sources, Discord raw-cache replay, whether to retain all game versions from a source, and merge-debug collection. The service MUST NOT read `config.properties`.

#### Scenario: A request cannot change the environment

- **WHEN** a job request is submitted over the web API
- **THEN** it can say which sources to scrape but cannot name a token, a data folder, or an output path

#### Scenario: Config keys are read in one place

- **WHEN** the CLI runs its ModRepo pipeline
- **THEN** the `modrepo_*` job-shape keys are read only where the request is built, and the service is handed the same environment whichever side started the job

### Requirement: A cancelled merge leaves the output alone

The service SHALL check cancellation between sources and merge phases. Cancellation before merge completion SHALL preserve the existing `ModRepo-v2.json` and write no snapshot. The log SHALL state that the output was preserved. Completed source-cache writes SHALL remain available.

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

`MainRepoScraper.main` SHALL build one request from the `modrepo_*` job settings and submit it to the manager.

When `qb_manager_url` identifies a running manager with the same data path, the CLI SHALL delegate using the QB job's progress and summary behavior. If delegation is unavailable, it SHALL run locally.

Remove `modrepo_forums_enabled` and forum page-count keys. Config files retaining those keys SHALL receive the standard unknown-key warning.

#### Scenario: Old forum key in the config file

- **WHEN** `config.properties` still sets `modrepo_forums_enabled`
- **THEN** the run warns that the key is not recognized and carries on

#### Scenario: Merge and QB share one queue

- **WHEN** a CLI merge is delegated to a running manager that is busy with a QB run
- **THEN** the merge is queued behind it, shows in the queue on the Runs view, and starts when the QB run ends

### Requirement: The Discord scrape saves each thread's opening run

A successful Discord scrape SHALL save `<qb_data_path>/discord-posts.json` alongside `discord_cache.json`, under the same all-or-nothing rules. The site build SHALL stop writing this file.

The file SHALL be keyed by thread id. Each thread SHALL include its name, author, link and opening run. That run starts with the first message containing text, includes consecutive messages by the same author, and stops at another author or ten messages. Each message SHALL retain its text, timestamp and image attachments.

Until replaced by a successful scrape, the old URL-keyed string format SHALL remain readable by the site's Discord panel. It SHALL NOT supply LLM input.

#### Scenario: Discord scrape finishes

- **WHEN** a `scrapeAndMerge` job's Discord scrape succeeds
- **THEN** `discord-posts.json` holds every thread it read, keyed by thread id, with each thread's opening run

#### Scenario: Discord scrape fails

- **WHEN** the Discord scrape fails part-way
- **THEN** `discord-posts.json` is left as it was

#### Scenario: Merge from saved files

- **WHEN** a `mergeModRepo` job runs
- **THEN** it reads `discord-posts.json` and does not write it
