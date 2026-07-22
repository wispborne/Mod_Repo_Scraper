# viewer-output-browsing

## Purpose

Let somebody look through what a run produced — the merged mod list, the forum bundle, the raw files and the log — and see where each piece of a mod came from, without opening big JSON files by hand.
## Requirements

### Requirement: ModRepo browser with source provenance
The viewer SHALL show a searchable, paged table of the mods in `outputs/ModRepo.json`, and a per-mod view listing the merged fields and which sources (forum, Discord, NexusMods) contributed, read from the mod's `sources` list. Per-source field values are not stored in `ModRepo.json`; when `merge-debug.json` is present, the per-mod view SHALL link to the mod's merge group in the merge explorer for that detail.

#### Scenario: See where a merged mod came from
- **WHEN** the user opens a mod in the ModRepo browser
- **THEN** the view shows the mod's merged fields and its contributing sources

#### Scenario: Drill into per-source values
- **WHEN** `merge-debug.json` exists and the user follows the merge-group link from a mod
- **THEN** the merge explorer opens that mod's group, showing which source won each field

#### Scenario: Re-run the merge from a mod's page
- **WHEN** the manager is on and the user clicks "Re-run the merge" on a mod's page
- **THEN** after the usual confirmation a `mergeModRepo` job is queued and the browser goes to that run's page; with the manager off the button is not there at all

### Requirement: Forum data bundle browser
The viewer SHALL show a searchable, paged view of `outputs/forum-data-bundle.json` — the file TriOS receives — including bundle metadata (`updatedAt`, `meta`) and per-topic entries with their index data, details, and assumed downloads. The view SHALL also offer a what-changed page comparing two saved bundle snapshots, with a picker for the two runs being compared.

#### Scenario: Browse the published bundle
- **WHEN** the user opens the bundle browser and searches for a mod
- **THEN** the matching bundle entries are shown exactly as published, not re-derived from intermediate files

#### Scenario: Compare two bundles
- **WHEN** the user opens the what-changed page and picks two saved runs
- **THEN** they see counts of added, gone, changed and unchanged topics, with the added, gone and changed lists searchable and paged

#### Scenario: Nothing saved to compare yet
- **WHEN** fewer than two bundle snapshots are saved
- **THEN** the what-changed page says so in one sentence and explains that running the scraper again will give it something to compare

#### Scenario: See everything the bundle holds for one mod
- **WHEN** the user opens a single mod from the bundle browser
- **THEN** every field the bundle carries for that mod is on the page — the thread's fields, the post's fields, the post itself, its images and links, the rule-based downloads in full, and every mod the LLM found with its downloads, extras and changelog

#### Scenario: Open a mod the bundle does not have
- **WHEN** the user opens a mod that is not in the published bundle
- **THEN** the page says so and shows what is saved on disk for that topic instead

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
