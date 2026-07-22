# single-writer-lock

## ADDED Requirements

### Requirement: One writer per data folder
A lock file at `<qb_data_path>/scraper.lock` SHALL guard the QB data folder. `JobManager` SHALL take the lock before each job starts and release it when the job ends — on the completed, failed, and cancelled paths alike. The file SHALL hold the holder's pid, a short label ("server" or "cli"), and the start time. A delegating CLI SHALL NOT take the lock; the server holds it for the job.

#### Scenario: Standalone CLI and server take turns
- **WHEN** a standalone CLI job is running and the server is asked to start a job on the same folder
- **THEN** the server's job waits, logs who holds the lock, and starts only after the CLI job ends and releases it

#### Scenario: Lock released on failure
- **WHEN** a job throws part-way through
- **THEN** the run is recorded as failed and the lock file is gone, so the next job can start

### Requirement: Waiting is patient and explained
A job that finds the lock held by a live process SHALL wait and retry every few seconds, logging once, in plain words, who holds the lock. It SHALL NOT fail the job just because the folder is busy.

#### Scenario: Second writer waits its turn
- **WHEN** a job wants the lock while another process holds it
- **THEN** it logs "waiting for the lock held by <label> (pid N)" once and starts when the lock frees up

### Requirement: A dead holder's lock is cleared
When the lock's pid is no longer a running process, the lock SHALL be deleted with a log line and the new job SHALL proceed. (The dead process's run is already marked interrupted by the history store.)

#### Scenario: Lock left by a crash
- **WHEN** a job wants the lock and the lock file names a pid that is not running
- **THEN** the stale lock is removed, the removal is logged, and the job starts normally
