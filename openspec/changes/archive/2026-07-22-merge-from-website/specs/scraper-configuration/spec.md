## ADDED Requirements

### Requirement: How many merge snapshots to keep is a config key
`config.properties` SHALL have a `modrepo_merges_to_keep` key setting how many merge snapshots the system keeps, defaulting to 20, where 0 keeps everything. It SHALL be listed among the recognized keys and documented in `config.example.properties` with its default and a plain-English note saying roughly how much disk each snapshot costs.

#### Scenario: Key is read
- **WHEN** a config file sets `modrepo_merges_to_keep=5`
- **THEN** the snapshot store keeps the newest five merges

#### Scenario: Key is left out
- **WHEN** the key is absent
- **THEN** twenty snapshots are kept and no warning is given

#### Scenario: Key is misspelled
- **WHEN** a config file sets `modrepo_merges_to_keep_count=5`
- **THEN** a startup warning names the unrecognized key and the default of twenty applies

### Requirement: modrepo_merge_debug decides debug collection for CLI runs only
`modrepo_merge_debug` SHALL decide whether a merge started by the CLI collects merge debug data. A merge started from the website SHALL always collect it, so a run asked for from the browser can always be looked at afterwards. Whether to collect SHALL travel on the job request, not be read from the config file by the service.

#### Scenario: Production CLI run stays quiet
- **WHEN** the CLI runs a merge with `modrepo_merge_debug=false`
- **THEN** no debug data is collected, no snapshot is written, and no `merge-debug.json` is written

#### Scenario: Website merge is always inspectable
- **WHEN** the user starts a merge from the website while `modrepo_merge_debug=false`
- **THEN** debug data is collected and that run's snapshot is saved
