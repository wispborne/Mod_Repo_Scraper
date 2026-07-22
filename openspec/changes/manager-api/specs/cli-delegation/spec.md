# cli-delegation

## ADDED Requirements

### Requirement: Delegation is opt-in through one config key
A new environment key `qb_manager_url` SHALL control delegation. When empty or absent (the default), the CLI SHALL run its QB job standalone exactly as before this change. When set, the CLI SHALL try to hand its QB job to the server at that address. The ModRepo pipeline SHALL always run locally either way.

#### Scenario: Default is standalone
- **WHEN** the CLI runs with no `qb_manager_url` set, with a manager server running nearby
- **THEN** the CLI runs standalone and never contacts the server

#### Scenario: Key set, server present
- **WHEN** `qb_manager_url` points at a running server whose manager is on and whose data path matches
- **THEN** the CLI submits its job to the server instead of running it in-process

### Requirement: Delegated runs feel like local runs
While a delegated job runs, the CLI SHALL poll the server about once a second and drive the same console progress bar — phases, counts, current item — from the server's status. When the run ends, the CLI SHALL print the same kind of summary as a local run; when it failed, the CLI SHALL also fetch and print the tail of the run's log.

#### Scenario: Watching a delegated run
- **WHEN** the CLI delegates a full run
- **THEN** the console shows the same progress bar and phases the standalone run would show, fed from the server

#### Scenario: A delegated run fails
- **WHEN** the server-side job ends in state failed
- **THEN** the CLI exits non-zero, prints the error from the run record, and prints the last lines of that run's log

### Requirement: Ctrl-C cancels the delegated job
On the first interrupt during a delegated run, the CLI SHALL ask the server to cancel, keep polling until the run settles, and report the outcome ("cancelled, N topics kept"). A second interrupt SHALL just exit, leaving the server to finish handling the cancel.

#### Scenario: One Ctrl-C
- **WHEN** the user presses Ctrl-C while a delegated job is running
- **THEN** the server-side job is cancelled between topics and the CLI reports the cancelled record before exiting

### Requirement: Fallback is safe and explained
When `qb_manager_url` is set but the server is unreachable, answers that the manager is off, or reports a different absolute data path than the CLI's `qb_data_path`, the CLI SHALL say so in plain words and run standalone instead. Delegation problems SHALL never silently skip the job.

#### Scenario: Server not running
- **WHEN** `qb_manager_url` is set but nothing answers there
- **THEN** the CLI logs that it could not reach the manager and runs the job standalone

#### Scenario: Server manages a different folder
- **WHEN** the server's data path differs from the CLI's `qb_data_path`
- **THEN** the CLI names both folders in a warning and runs standalone against its own folder
