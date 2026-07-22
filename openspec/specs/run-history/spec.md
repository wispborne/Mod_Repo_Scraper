# run-history

## Purpose

Keep a record of every job that ran — what was asked for, what happened, and its own log — saved as the run goes, so even a run that dies leaves an honest account.
## Requirements

### Requirement: Every run is recorded
The manager core SHALL record every job it runs — from any caller — in `<qb_data_path>/runs/runs-index.json`. Each record SHALL hold: a unique id, the kind, the full request (topic ids, scope, boards, flags), state (queued, running, completed, failed, cancelled, interrupted), start and end times, counters (items done and total, errors, live LLM calls), any guardrail stop, an error message when failed, and the name of its log file.

#### Scenario: A finished run is fully described
- **WHEN** a `rescrapeTopics` job for topics 123 and 456 completes
- **THEN** the index holds a record with the kind, both topic ids, state completed, start and end times, and its counters

#### Scenario: The request is kept, not just the outcome
- **WHEN** any run record is read back later
- **THEN** it contains enough of the original request to run the same job again

### Requirement: History is saved as the run goes
The run index SHALL be written when a run starts, on every state change, and periodically during progress — not only at the end — following the project's incremental-save rule. On startup, the manager SHALL mark any record still saying `running` as `interrupted`.

#### Scenario: A crash leaves an honest record
- **WHEN** the process is killed while a run is at 40 of 100 topics
- **THEN** the index on disk already shows the run with its last saved counters, and on next startup its state becomes `interrupted`

#### Scenario: A failed run records why
- **WHEN** a run stops on an error
- **THEN** its record is saved with state failed and the error message, even though the process may be about to exit

### Requirement: Each run has its own log
Log lines produced while a run is active SHALL be copied to `<qb_data_path>/runs/<run id>.log`, so each run's log can be read on its own later. The main `ModRepo.log` SHALL keep working as before.

#### Scenario: Run log holds that run only
- **WHEN** two jobs run one after the other
- **THEN** each run's log file contains its own lines and not the other run's
