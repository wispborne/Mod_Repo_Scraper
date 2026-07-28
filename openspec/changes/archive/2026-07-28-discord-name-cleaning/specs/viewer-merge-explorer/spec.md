## MODIFIED Requirements

### Requirement: Searchable merge explorer
The viewer SHALL render a saved merge as a set of searchable views covering every section the old HTML page had: run summary, phase timings, pre-dedup removals, match groups (with singleton/multi-member breakdown and match reasons), same-source dedup entries, merge decisions, and validation removals. Group and removal lists SHALL be filterable by mod name and author, and served paged. Every merge page SHALL have a run picker naming which saved merge is being read, defaulting to the newest, and SHALL fall back to `merge-debug.json` when no snapshots are saved.

A match reason SHALL say which reading of the names did the work: the names as scraped, or the version-stripped reading. When it was the stripped reading, the entry SHALL also show the stripped name of each side with that reading's score and length ratio, so a person can see what the cleaner produced and judge whether it was right. Merges saved before version stripping existed carry none of this, and the view SHALL render them without it rather than showing blanks or failing.

#### Scenario: Search merge groups by mod name
- **WHEN** the user searches the groups view for a mod name
- **THEN** only groups containing a mod whose name matches are shown, with their match reasons

#### Scenario: View merge decisions for a group
- **WHEN** the user opens a multi-member group
- **THEN** the field-by-field merge decisions for that group are shown, including which source won each field

#### Scenario: Looking at an older merge
- **WHEN** the user picks an earlier merge from the run picker
- **THEN** every merge view — summary, groups, removals — reads that merge, and the picked run stays chosen while moving between them

#### Scenario: No merge debug file
- **WHEN** no merge snapshot is saved and `merge-debug.json` does not exist on disk
- **THEN** the merge explorer says a debug-enabled scraper run is needed instead of erroring

#### Scenario: Matched on the names as scraped
- **WHEN** two mods matched without the stripped reading being needed
- **THEN** the match reason reads as it does today — the name and author scores for the names as scraped, and no stripped-reading details

#### Scenario: Matched on the version-stripped reading
- **WHEN** two mods matched only after the version noise was taken off
- **THEN** the match reason says so and shows both stripped names with that reading's score and length ratio

#### Scenario: A merge saved before this change
- **WHEN** the user opens a merge saved before version stripping existed
- **THEN** its match reasons render without the stripped-reading details rather than showing blanks or failing
