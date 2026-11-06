## MODIFIED Requirements

### Requirement: A publish rides the shared queue, lock, history and log
The `publishOutputs` kind SHALL be owned by a publish `JobRunner` wired through the same `JobRouter` as the QB and ModRepo services, so a publish SHALL take its turn in the one queue, hold the single-writer lock while it runs, appear in the run history with its own log, and report progress to the same status bar. A publish SHALL never run at the same time as a scrape or merge.

#### Scenario: Publish waits behind a running job
- **WHEN** a publish job is submitted while a scrape or merge is running
- **THEN** it is queued behind that job, shows in the queue on the Control page, and starts when the running job ends

#### Scenario: Publish appears in history
- **WHEN** a publish job finishes
- **THEN** it is listed in the run history with its kind, timing and state, and its log can be opened from its run page
