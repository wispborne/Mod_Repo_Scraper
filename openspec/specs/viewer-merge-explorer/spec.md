# viewer-merge-explorer

## Requirements

### Requirement: Searchable merge explorer
The viewer SHALL render `merge-debug.json` as a set of searchable views covering every section the old HTML page had: run summary, phase timings, pre-dedup removals, match groups (with singleton/multi-member breakdown and match reasons), same-source dedup entries, merge decisions, and validation removals. Group and removal lists SHALL be filterable by mod name and author, and served paged.

#### Scenario: Search merge groups by mod name
- **WHEN** the user searches the groups view for a mod name
- **THEN** only groups containing a mod whose name matches are shown, with their match reasons

#### Scenario: View merge decisions for a group
- **WHEN** the user opens a multi-member group
- **THEN** the field-by-field merge decisions for that group are shown, including which source won each field

#### Scenario: No merge debug file
- **WHEN** `merge-debug.json` does not exist on disk
- **THEN** the merge explorer says a debug-enabled scraper run is needed instead of erroring
