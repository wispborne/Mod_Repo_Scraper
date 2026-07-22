## ADDED Requirements

### Requirement: Every merge run saves its own snapshot
A merge job that collected debug data SHALL write its full merge debug data to `<qb_data_path>/merges/<run id>.json.gz` — the same content `merge-debug.json` holds, stored without indentation and gzipped, because a real run's data is around 12 MB uncompressed. The run id SHALL be the id of the run record, so a snapshot and its run, log and request are all found by the same name. The newest snapshot SHALL also be written to `merge-debug.json` in the working folder, uncompressed, so everything that reads that file keeps working.

#### Scenario: A merge run leaves a snapshot behind
- **WHEN** a merge job with debug collection on finishes
- **THEN** `merges/<run id>.json.gz` holds that run's merge debug data and `merge-debug.json` holds the same data uncompressed

#### Scenario: Debug collection off
- **WHEN** a CLI merge runs with `modrepo_merge_debug=false`
- **THEN** no snapshot is written and no `merge-debug.json` is written, and the merge behaves as it always has

### Requirement: Only the newest snapshots are kept
The snapshot store SHALL keep only the newest `modrepo_merges_to_keep` snapshots (default 20; 0 keeps everything) and SHALL drop the rest when it saves a new one. A snapshot belonging to a run that has not ended SHALL never be dropped. The store SHALL delete a file only when its name ends in `.json.gz` and it sits directly inside `merges/`.

#### Scenario: Old snapshot is dropped
- **WHEN** the limit is 20, twenty snapshots are on disk, and a new merge finishes
- **THEN** the oldest snapshot file is deleted and twenty remain

#### Scenario: Nothing but snapshots is ever deleted
- **WHEN** the trim runs
- **THEN** no file outside `merges/`, no file whose name does not end in `.json.gz`, and no scraped data, cache or output file is touched

#### Scenario: Keep everything
- **WHEN** `modrepo_merges_to_keep=0`
- **THEN** no snapshot is ever dropped

### Requirement: Snapshots can be listed and read back by id
The system SHALL be able to list the saved snapshots newest first — id, when the merge ran, and the headline counts (mods in, groups, mods out) — and to read one snapshot by id. A snapshot that is missing or unreadable SHALL be reported as missing in plain words, not as a crash.

#### Scenario: Listing what is saved
- **WHEN** the list is asked for
- **THEN** it names every saved snapshot newest first with its run id, time and headline counts

#### Scenario: Asking for a snapshot that is gone
- **WHEN** a snapshot id is asked for that has been trimmed away
- **THEN** the answer says that merge's details are no longer kept, and nothing crashes
