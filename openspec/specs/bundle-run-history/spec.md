# bundle-run-history

## Purpose

Keep a small copy of the bundle each run published, named after that run, so two runs can be compared later without holding on to every full bundle.
## Requirements

### Requirement: Every run that publishes a bundle saves a snapshot
A job that writes `forum-data-bundle.json` SHALL also save a snapshot of what it wrote to `<qb_data_path>/bundles/<run id>.json.gz`, stored without indentation and gzipped. The run id SHALL be the id of the run record, so the snapshot, the run, its log and its request are all found by the same name. This SHALL apply to every job kind that publishes a bundle, without any of them being asked for it.

#### Scenario: A full run leaves a snapshot
- **WHEN** a `fullRun` finishes and publishes the bundle
- **THEN** `bundles/<run id>.json.gz` holds a snapshot of the bundle that was published

#### Scenario: A bundle rebuild leaves one too
- **WHEN** a `rebuildBundle`, `llmCoveragePass` or per-topic job publishes the bundle
- **THEN** that run also leaves a snapshot, named after it

#### Scenario: A run that publishes nothing leaves nothing
- **WHEN** an `llmTest` job finishes, having saved and published nothing
- **THEN** no bundle snapshot is written for it

#### Scenario: A job run with no history behind it
- **WHEN** a job publishes a bundle but was not given a run id, as in a direct call from a test
- **THEN** no snapshot is written, because there is no run to file it under

### Requirement: Snapshots leave out the post text
A bundle snapshot SHALL NOT contain the posts' HTML. Each detail SHALL instead carry a short fingerprint of the post text it had, so a post that changed can be reported as changed without the text being kept. A snapshot is therefore not a bundle and MUST NOT be published, served, or read as one.

#### Scenario: The post text is not kept
- **WHEN** a snapshot is read back
- **THEN** no post HTML is in it, and each detail carries a fingerprint of the text it had instead

#### Scenario: A changed post is still noticed
- **WHEN** a topic's post text changes between two runs
- **THEN** the two snapshots' fingerprints for that topic differ

#### Scenario: A snapshot is small enough to keep many of
- **WHEN** a snapshot of the full bundle is written
- **THEN** it is a fraction of the size of the published bundle, in the same range as a merge snapshot

### Requirement: Only the newest bundle snapshots are kept
The store SHALL keep only the newest `qb_bundles_to_keep` snapshots (default 500; 0 keeps everything) and SHALL drop the rest when it saves a new one. A snapshot belonging to a run that has not ended SHALL never be dropped. The store SHALL delete a file only when its name ends in `.json.gz` and it sits directly inside `bundles/`.

#### Scenario: Old snapshot is dropped
- **WHEN** the limit is 20, twenty snapshots are on disk, and a new run publishes a bundle
- **THEN** the oldest snapshot file is deleted and twenty remain

#### Scenario: Nothing but snapshots is ever deleted
- **WHEN** the trim runs
- **THEN** no file outside `bundles/`, no file whose name does not end in `.json.gz`, and no scraped data, cache or output file is touched

#### Scenario: Keep everything
- **WHEN** `qb_bundles_to_keep=0`
- **THEN** no snapshot is ever dropped

### Requirement: Snapshots can be listed and read back by id
The system SHALL be able to list the saved bundle snapshots newest first — id, when the run was, the file's size on disk, and the headline counts (topics in the index, topics with details, topics with downloads) — and to read one by id. A snapshot that is missing or unreadable SHALL be reported as missing in plain words, not as a crash.

#### Scenario: Listing what is saved
- **WHEN** the list is asked for
- **THEN** it names every saved snapshot newest first with its run id, time, size and headline counts

#### Scenario: Asking for one that is gone
- **WHEN** a snapshot id is asked for that has been trimmed away
- **THEN** the answer says that run's bundle is no longer kept, and nothing crashes
