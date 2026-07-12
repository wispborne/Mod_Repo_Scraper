# viewer-output-browsing

## Requirements

### Requirement: ModRepo browser with source provenance
The viewer SHALL show a searchable, paged table of the mods in `outputs/ModRepo.json`, and a per-mod view listing the merged fields and which sources (forum, Discord, NexusMods) contributed, read from the mod's `sources` list. Per-source field values are not stored in `ModRepo.json`; when `merge-debug.json` is present, the per-mod view SHALL link to the mod's merge group in the merge explorer for that detail.

#### Scenario: See where a merged mod came from
- **WHEN** the user opens a mod in the ModRepo browser
- **THEN** the view shows the mod's merged fields and its contributing sources

#### Scenario: Drill into per-source values
- **WHEN** `merge-debug.json` exists and the user follows the merge-group link from a mod
- **THEN** the merge explorer opens that mod's group, showing which source won each field

### Requirement: Forum data bundle browser
The viewer SHALL show a searchable, paged view of `outputs/forum-data-bundle.json` — the file TriOS receives — including bundle metadata (`updatedAt`, `meta`) and per-topic entries with their index data, details, and assumed downloads.

#### Scenario: Browse the published bundle
- **WHEN** the user opens the bundle browser and searches for a mod
- **THEN** the matching bundle entries are shown exactly as published, not re-derived from intermediate files

### Requirement: Mod-card display preview
The viewer SHALL render a selected mod as a card approximating how TriOS displays a mod (title, thumbnail, author, game version, downloads), clearly labeled as an approximation.

#### Scenario: Preview a mod card
- **WHEN** the user opens the card preview for a mod
- **THEN** a TriOS-style card is rendered from the bundle data with an "approximation" label

### Requirement: Raw file and log viewers
The viewer SHALL list the known output files (from the server's allowlist) with their size and last-modified time, let the user view any of them — JSON pretty-printed and, for large files, loaded in chunks — and SHALL provide a `ModRepo.log` view with text filtering and a way to jump to the end of the log.

#### Scenario: View a raw JSON file
- **WHEN** the user opens a file from the file list
- **THEN** its contents are shown pretty-printed without the browser downloading more than the viewed portion of very large files

#### Scenario: Filter the log
- **WHEN** the user filters the log view by a search term
- **THEN** only matching log lines are shown
