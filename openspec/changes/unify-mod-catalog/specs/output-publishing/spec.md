## MODIFIED Requirements

### Requirement: Publishing is a job the manager can run

The manager SHALL offer `publishOutputs` to publish current outputs to the target GitHub repo. The job SHALL prepare an up-to-date clone and copy `outputs/ModRepo-v2.json` and `outputs/forum-data-bundle-v2.json` into it. Stage changes, then commit and push only if something changed. The frozen `ModRepo.json` and `forum-data-bundle.json` SHALL NOT be written, staged or deleted.

The job SHALL also copy:

- Site data: `mods.json`, each `mods/<id>.json`, each `mods/<id>/index.html`, `updates.json`, `updates.xml`, `sitemap.xml` and `robots.txt`.
- Site files from `site/`, so the clone contains the complete website.

Remove stale `mods/<id>.json` files and `mods/<id>/` folders that the build did not produce. A generated Collection page SHALL count as a produced folder and be retained.

Publishing SHALL use the host's existing git/SSH authentication. It SHALL make no network calls beyond git, perform no scraping and call no LLM.

#### Scenario: Publish changed outputs

- **WHEN** a `publishOutputs` job runs and the current v2 output files differ from what is in the target repo
- **THEN** both files are copied into the clone, one commit is made, the commit is pushed, and the run is recorded as completed

#### Scenario: Frozen files stay put

- **WHEN** a `publishOutputs` job runs
- **THEN** `ModRepo.json` and `forum-data-bundle.json` in the target repo are the same after the commit as before it

#### Scenario: A Collection's page is kept

- **WHEN** a run publishes a Collection page at `mods/derelict-start-remnant-start-omega-start-threat-start/`
- **THEN** the publish does not remove that folder as a mod that no longer exists

#### Scenario: Nothing changed

- **WHEN** a `publishOutputs` job runs and no output file differs from what is already in the target repo
- **THEN** no commit is made and nothing is pushed, and the run finishes as completed with a log line saying there was nothing to publish

#### Scenario: Normal history is kept

- **WHEN** a `publishOutputs` job commits and pushes
- **THEN** it makes an ordinary commit on top of the existing history and never force-pushes or rewrites history
