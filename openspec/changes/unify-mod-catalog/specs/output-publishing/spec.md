## MODIFIED Requirements

### Requirement: Publishing is a job the manager can run
The manager SHALL offer a `publishOutputs` job kind that publishes the current output files to the target GitHub repo. The job SHALL make sure a clone of the target repo is present and current, copy `outputs/ModRepo-v2.json` and `outputs/forum-data-bundle-v2.json` into it, stage the changes, and — only when something changed — commit and push. It SHALL leave `ModRepo.json` and `forum-data-bundle.json` in the clone exactly as they are: not written, not staged, not deleted. It SHALL push over the host's existing git/SSH auth and touch no network of its own beyond git. The job SHALL send nothing to an LLM and SHALL not scrape.

#### Scenario: Publish changed outputs
- **WHEN** a `publishOutputs` job runs and the current v2 output files differ from what is in the target repo
- **THEN** both files are copied into the clone, one commit is made, the commit is pushed, and the run is recorded as completed

#### Scenario: Frozen files stay put
- **WHEN** a `publishOutputs` job runs
- **THEN** `ModRepo.json` and `forum-data-bundle.json` in the target repo are the same after the commit as before it

#### Scenario: Nothing changed
- **WHEN** a `publishOutputs` job runs and neither v2 output file differs from what is already in the target repo
- **THEN** no commit is made and nothing is pushed, and the run finishes as completed with a log line saying there was nothing to publish

#### Scenario: Normal history is kept
- **WHEN** a `publishOutputs` job commits and pushes
- **THEN** it makes an ordinary commit on top of the existing history and never force-pushes or rewrites history
