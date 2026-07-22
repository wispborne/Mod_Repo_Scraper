## MODIFIED Requirements

### Requirement: Searchable merge explorer
The viewer SHALL render a saved merge as a set of searchable views covering every section the old HTML page had: run summary, phase timings, pre-dedup removals, match groups (with singleton/multi-member breakdown and match reasons), same-source dedup entries, merge decisions, and validation removals. Group and removal lists SHALL be filterable by mod name and author, and served paged. Every merge page SHALL have a run picker naming which saved merge is being read, defaulting to the newest, and SHALL fall back to `merge-debug.json` when no snapshots are saved.

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

## ADDED Requirements

### Requirement: Merges can be started from the website
The Runs view SHALL offer a start-a-merge panel with the two merge kinds and, for `scrapeAndMerge`, tick boxes for the sources. What a merge will do SHALL be readable from the form itself, never inherited invisibly from the config file. The confirm box for a scraping merge SHALL say in one plain sentence that it will fetch from the mod sources and may take a few minutes. Merge runs SHALL appear in the same history, with the same live progress, cancel button, log and "run again" as every other run.

#### Scenario: Starting a merge from saved files
- **WHEN** the user picks "merge from saved files" and confirms
- **THEN** a `mergeModRepo` job is queued and the Runs view follows it like any other run

#### Scenario: Confirming a scraping merge
- **WHEN** the user picks "scrape then merge" with all three sources ticked
- **THEN** the confirm box says plainly that it will fetch from the mod sources and can take a few minutes

#### Scenario: Manager off
- **WHEN** the manager is off
- **THEN** the merge views still read the saved merges and no start, cancel or run-again buttons are drawn

### Requirement: Before and after views in the explorer
The explorer SHALL have a before-and-after page reachable from a group, showing what each source contributed and what came out field by field, and a what-changed page comparing two saved merges, searchable by mod name and author and paged. Neither page SHALL fetch a whole merge snapshot into the browser.

#### Scenario: Seeing what a group turned into
- **WHEN** the user opens before-and-after for a group
- **THEN** each field shows every member's value, the final value, and which source supplied it

#### Scenario: Comparing two merges
- **WHEN** the user picks two merges on the what-changed page
- **THEN** they see counts of added, gone, changed and unchanged mods, with the added, gone and changed lists searchable and paged
