## ADDED Requirements

### Requirement: Publishing is a job the manager can run
The manager SHALL offer a `publishOutputs` job kind that publishes the current output files to the target GitHub repo. The job SHALL make sure a clone of the target repo is present and current, copy `outputs/ModRepo.json` and `outputs/forum-data-bundle.json` into it, stage the changes, and — only when something changed — commit and push. It SHALL push over the host's existing git/SSH auth and touch no network of its own beyond git. The job SHALL send nothing to an LLM and SHALL not scrape.

#### Scenario: Publish changed outputs
- **WHEN** a `publishOutputs` job runs and the current `outputs/` files differ from what is in the target repo
- **THEN** both files are copied into the clone, one commit is made, the commit is pushed, and the run is recorded as completed

#### Scenario: Nothing changed
- **WHEN** a `publishOutputs` job runs and neither output file differs from what is already in the target repo
- **THEN** no commit is made and nothing is pushed, and the run finishes as completed with a log line saying there was nothing to publish

#### Scenario: Normal history is kept
- **WHEN** a `publishOutputs` job commits and pushes
- **THEN** it makes an ordinary commit on top of the existing history and never force-pushes or rewrites history

### Requirement: The publish service is told what to do, never asked to look it up
The publish service SHALL be built once with its environment — the target repo URL and the folder to keep the clone in — and SHALL NOT read `config.properties`. A publish job request SHALL carry no repo URL, no folder and no token, so no caller over the web API can point a publish at a different repo or folder.

#### Scenario: A request cannot change the target
- **WHEN** a `publishOutputs` request is submitted over the web API
- **THEN** it can ask for a publish but cannot name the repo URL, the clone folder, or any credential

### Requirement: A publish rides the shared queue, lock, history and log
The `publishOutputs` kind SHALL be owned by a publish `JobRunner` wired through the same `JobRouter` as the QB and ModRepo services, so a publish SHALL take its turn in the one queue, hold the single-writer lock while it runs, appear in the run history with its own log, and report progress to the same status chip. A publish SHALL never run at the same time as a scrape or merge.

#### Scenario: Publish waits behind a running job
- **WHEN** a publish job is submitted while a scrape or merge is running
- **THEN** it is queued behind that job, shows in the queue on the Runs view, and starts when the running job ends

#### Scenario: Publish appears in history
- **WHEN** a publish job finishes
- **THEN** it is listed in the run history with its kind, timing and state, and its log can be opened from its detail page

### Requirement: A failed publish is reported plainly, never as a silent no-op
When git fails — the clone cannot be reached, the push is rejected, or the service runs as a user without push access — the publish job SHALL record the run as failed and SHALL put the git error in the run's log. A publish SHALL never report success without having pushed the changed files.

#### Scenario: Push rejected
- **WHEN** the push is rejected because the service user has no access to the target repo
- **THEN** the run is recorded as failed, the git error is in the log, and no run claims to have published

### Requirement: A cancelled publish leaves the target repo alone
The publish service SHALL check for cancellation before it commits and pushes. A publish cancelled before the push SHALL push nothing and SHALL say in its log that the target repo was left as it was. Any local clone it prepared SHALL be safe to leave for the next publish.

#### Scenario: Cancelled before the push
- **WHEN** the user cancels a `publishOutputs` job before it has pushed
- **THEN** the run is recorded as cancelled, nothing is pushed, and the log says the target repo was left as it was
