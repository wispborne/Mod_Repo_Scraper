## MODIFIED Requirements

### Requirement: The CLI hands its ModRepo work to the manager
`MainRepoScraper.main` SHALL turn the config file's `modrepo_*` keys into one job request and submit it, rather than running the pipeline inline. When `qb_manager_url` names a running manager, the merge job SHALL be delegated to it on the same terms as the QB job — matching data paths, live progress, the usual summary — and SHALL run locally when it cannot be.

#### Scenario: CLI run is unchanged from the outside
- **WHEN** the CLI runs with the same config as before this change
- **THEN** the same files are written, the same lines are logged, and the exit code is the same

#### Scenario: Merge and QB share one queue
- **WHEN** a CLI merge is delegated to a running manager that is busy with a QB run
- **THEN** the merge is queued behind it, shows in the queue on the Control page, and starts when the QB run ends

### Requirement: A merge run reports its progress
The ModRepo service SHALL report phases by name (each source, then the merge, then the save) and SHALL report how many mods have been merged out of how many, so the progress bar shows progress during the long merge step.

#### Scenario: Watching a merge from the browser
- **WHEN** a merge job is running and the user is on the Control page
- **THEN** the phase name and the merged-so-far count update about once a second without reloading the page
