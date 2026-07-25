# scraper-configuration

## Purpose

One naming scheme for every key in `config.properties`, so a key's name says which pipeline it belongs to, and a typo or an old key name is caught at startup instead of silently doing nothing.
## Requirements
### Requirement: Config keys follow one naming scheme
Every key in `config.properties` SHALL be snake_case and SHALL start with the prefix of the group it belongs to — `modrepo_` for the ModRepo pipeline (including the Discord and Nexus auth tokens, which only ModRepo uses), `qb_` for the QB pipeline, and `llm_` for QB LLM extraction — except `log_level`, which is global. Pipeline and source on/off switches SHALL end in `_enabled` (`modrepo_enabled`, `modrepo_forums_enabled`, `qb_enabled`, `llm_enabled`). The per-board page limits SHALL share one word order: `qb_max_pages_main`, `qb_max_pages_lesser`, `qb_max_pages_libraries`.

#### Scenario: Renamed keys are read
- **WHEN** a config file uses the new key names (for example `modrepo_enabled`, `modrepo_discord_auth_token`, `qb_enabled`, `qb_max_pages_lesser`, `llm_enabled`, `llm_reprocess_only`)
- **THEN** each value loads into the matching `BotConfig` field and drives the same behavior its old-named key drove before

#### Scenario: Old key names no longer work
- **WHEN** a config file uses an old key name (for example `enable_mod_repo`, `use_cached`, `discord_serverId`, `qb_lesser_board_max_pages`, `enable_llm`, or the aliases `generate_debug_html` / `openrouter_api_token`)
- **THEN** the value is not loaded, the built-in default applies, and the key is reported as unknown at startup

### Requirement: Unknown config keys produce a startup warning
When reading `config.properties`, the system SHALL compare every key in the file against the set of recognized keys and SHALL emit one warning per unrecognized key, naming that key. Unrecognized keys SHALL NOT stop the run.

#### Scenario: Typo is reported
- **WHEN** the config file contains `qb_delay_sm=1000`
- **THEN** a startup warning names `qb_delay_sm` as unrecognized and the run continues with the default delay

#### Scenario: Stale old-name key is reported
- **WHEN** the config file still contains `enable_forums=true`
- **THEN** a startup warning names `enable_forums` as unrecognized, pointing the user at the rename

### Requirement: qb_scope values are normalized and bad values are loud
The system SHALL match the `qb_scope` value against the scope types after lowercasing and stripping underscores from both sides, so `new_data` and `newData` (and `libraries_only` and `librariesOnly`) all select the intended scope. When the value matches no scope type, the system SHALL log a warning naming the bad value and the accepted values, then use the default scope.

#### Scenario: snake_case scope value works
- **WHEN** `qb_scope=libraries_only`
- **THEN** the QB engine runs with the librariesOnly scope

#### Scenario: camelCase scope value works
- **WHEN** `qb_scope=newData`
- **THEN** the QB engine runs with the newData scope

#### Scenario: Unrecognized scope value warns and defaults
- **WHEN** `qb_scope=everything`
- **THEN** a warning names `everything` and lists the accepted values, and the engine runs with the default (newData) scope

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

### Requirement: How many bundle snapshots to keep is a config key
`config.properties` SHALL have a `qb_bundles_to_keep` key setting how many bundle snapshots the system keeps, defaulting to 500, where 0 keeps everything. It SHALL be listed among the recognized keys and documented in `config.example.properties` with its default and a plain-English note saying roughly how much disk each snapshot costs.

#### Scenario: Key is read
- **WHEN** a config file sets `qb_bundles_to_keep=5`
- **THEN** the snapshot store keeps the newest five bundles

#### Scenario: Key is left out
- **WHEN** the key is absent
- **THEN** five hundred snapshots are kept and no warning is given

#### Scenario: Key is misspelled
- **WHEN** a config file sets `qb_bundle_to_keep=5`
- **THEN** a startup warning names the unrecognized key and the default of five hundred applies

### Requirement: modrepo_merge_debug decides debug collection for CLI runs only
`modrepo_merge_debug` SHALL decide whether a merge started by the CLI collects merge debug data. A merge started from the website SHALL always collect it, so a run asked for from the browser can always be looked at afterwards. Whether to collect SHALL travel on the job request, not be read from the config file by the service.

#### Scenario: Production CLI run stays quiet
- **WHEN** the CLI runs a merge with `modrepo_merge_debug=false`
- **THEN** no debug data is collected, no snapshot is written, and no `merge-debug.json` is written

#### Scenario: Website merge is always inspectable
- **WHEN** the user starts a merge from the website while `modrepo_merge_debug=false`
- **THEN** debug data is collected and that run's snapshot is saved

### Requirement: The publish target is set by config keys
`config.properties` SHALL have a `publish_` group setting where a publish sends the output files and where it keeps its working clone: `publish_repo_url` (the target repo, defaulting to the SSH URL of `wispborne/StarsectorModRepo`) and `publish_clone_dir` (the folder the server keeps its clone in, kept apart from any folder the cron script wipes). These keys SHALL be manager environment — read where the publish service is built, never served to the browser — and SHALL be listed among the recognized keys and documented in `config.example.properties` with their defaults and a plain-English note. There SHALL be no token key; publishing SHALL use the host's existing git/SSH auth.

#### Scenario: Keys are read
- **WHEN** a config file sets `publish_repo_url` and `publish_clone_dir`
- **THEN** the publish service is built to push to that repo using that folder for its clone

#### Scenario: Keys are left out
- **WHEN** the `publish_` keys are absent
- **THEN** the built-in defaults apply and no warning is given

#### Scenario: Key is misspelled
- **WHEN** a config file sets `publish_repo_ur=...`
- **THEN** a startup warning names the unrecognized key and the default applies

