# qb-bundle-publishing — delta

## MODIFIED Requirements

### Requirement: Config integration
The system SHALL add QB scraper config to `config.properties` and `BotConfig`.

#### Scenario: Enable QB scraper
- **WHEN** `qb_enabled=true` in config
- **THEN** the QB pipeline SHALL run after the existing pipeline

#### Scenario: Disabled by default
- **WHEN** `qb_enabled` is absent
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
- **WHEN** `qb_max_pages_lesser` is set
- **THEN** board 3 SHALL be capped at that page count; default 20
