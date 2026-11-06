## ADDED Requirements

### Requirement: The config file is read again before each job
Before starting each job, the server SHALL check whether `config.properties` has changed since it was last read and, if so, read it again and use the new settings for that job and subsequent jobs. A running job SHALL keep the settings it started with. A file that cannot be read SHALL leave the last good settings in use and SHALL be logged. `qb_data_path` and `log_level` SHALL take effect only after a restart.

#### Scenario: A limit changed between jobs
- **WHEN** `llm_max_topics` is changed from 200 to 300 while no job runs, and a job starts
- **THEN** that job uses 300, without the server restarting

#### Scenario: Changed during a job
- **WHEN** the file is changed while a job runs
- **THEN** that job keeps its settings, and the next job uses the new ones
