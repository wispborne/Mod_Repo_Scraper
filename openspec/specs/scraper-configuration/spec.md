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
