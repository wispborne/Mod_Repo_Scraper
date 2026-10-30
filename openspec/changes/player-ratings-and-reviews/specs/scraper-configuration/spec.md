## MODIFIED Requirements

### Requirement: Config keys follow one naming scheme
Every key in `config.properties` SHALL be snake_case and SHALL start with the prefix of the group it belongs to — `modrepo_` for the ModRepo pipeline (including the Discord and Nexus auth tokens, which only ModRepo uses), `qb_` for the QB pipeline, `llm_` for QB LLM extraction, and `ratings_` for the account service and the review check job — except `log_level`, which is global. Pipeline and source on/off switches SHALL end in `_enabled` (`modrepo_enabled`, `modrepo_forums_enabled`, `qb_enabled`, `llm_enabled`). The per-board page limits SHALL share one word order: `qb_max_pages_main`, `qb_max_pages_lesser`, `qb_max_pages_libraries`.

#### Scenario: Renamed keys are read
- **WHEN** a config file uses the new key names (for example `modrepo_enabled`, `modrepo_discord_auth_token`, `qb_enabled`, `qb_max_pages_lesser`, `llm_enabled`, `llm_reprocess_only`)
- **THEN** each value loads into the matching `BotConfig` field and has the same effect as the old key

#### Scenario: Old key names no longer work
- **WHEN** a config file uses an old key name (for example `enable_mod_repo`, `use_cached`, `discord_serverId`, `qb_lesser_board_max_pages`, `enable_llm`, or the aliases `generate_debug_html` / `openrouter_api_token`)
- **THEN** the value is not loaded, the built-in default applies, and the key is reported as unknown at startup

## ADDED Requirements

### Requirement: ratings_ keys configure the account service
The config SHALL have four keys for ratings, all environment settings: `ratings_service_url` (the account service's address), `ratings_service_token` (the scraper's token for it), `ratings_check_minutes` (how often the review check job runs, default 60) and `ratings_llm_activity_url` (the LLM server's request log). With `ratings_service_url` empty, the scraper SHALL NOT call the account service, SHALL publish no averages, and SHALL NOT start the check job. `config.example.properties` SHALL list all four with a plain-English note, and no token value.

#### Scenario: No account service configured
- **WHEN** `ratings_service_url` is empty
- **THEN** a site build makes no call to the account service and publishes no `ratings` fields, and no check job is started

#### Scenario: The token never reaches the browser
- **WHEN** the viewer's status or any other route is read
- **THEN** the response contains no `ratings_` values
