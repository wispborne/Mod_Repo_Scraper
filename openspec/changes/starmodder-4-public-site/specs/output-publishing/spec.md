## MODIFIED Requirements

### Requirement: Publishing is a job the manager can run
The manager SHALL offer a `publishOutputs` job kind that publishes the current output files to the target GitHub repo. The job SHALL make sure a clone of the target repo is present and current, copy `outputs/ModRepo.json` and `outputs/forum-data-bundle.json` into it, stage the changes, and — only when something changed — commit and push. It SHALL also copy the public website's data files — `mods.json`, every `mods/<id>.json`, `updates.json` and `updates.xml` — into the clone, and SHALL remove any `mods/<id>.json` in the clone that the current run did not produce, so a mod that no longer exists does not linger. It SHALL also copy the website's own files from `site/` into the clone, so the repo holds a complete, servable copy of the site next to the data it reads. It SHALL push over the host's existing git/SSH auth and touch no network of its own beyond git. The job SHALL send nothing to an LLM and SHALL not scrape.

#### Scenario: Publish changed outputs
- **WHEN** a `publishOutputs` job runs and the current `outputs/` files differ from what is in the target repo
- **THEN** both files are copied into the clone, one commit is made, the commit is pushed, and the run is recorded as completed

#### Scenario: Nothing changed
- **WHEN** a `publishOutputs` job runs and neither output file differs from what is already in the target repo
- **THEN** no commit is made and nothing is pushed, and the run finishes as completed with a log line saying there was nothing to publish

#### Scenario: Normal history is kept
- **WHEN** a `publishOutputs` job commits and pushes
- **THEN** it makes an ordinary commit on top of the existing history and never force-pushes or rewrites history

#### Scenario: The website files go out with the rest
- **WHEN** a `publishOutputs` job runs and the website files have been built
- **THEN** `mods.json`, `updates.json`, `updates.xml` and every per-mod file are copied into the clone and go out in the same commit

#### Scenario: A mod disappears
- **WHEN** a mod that had a per-mod file in the target repo is no longer produced by the current run
- **THEN** that file is removed from the clone in the same commit

#### Scenario: The website files were not built
- **WHEN** a `publishOutputs` job runs and no website files exist to copy
- **THEN** the existing outputs are still published, and the log says the website files were not there

#### Scenario: The site's own files go out too
- **WHEN** a `publishOutputs` job runs
- **THEN** the contents of `site/` are copied into the clone, so the pushed repo can be served as the website with no further step

#### Scenario: The pushed repo is servable on its own
- **WHEN** the target repo is handed to a static host after a publish
- **THEN** the site loads and every data file it asks for is present at the address the site expects
