## MODIFIED Requirements

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
