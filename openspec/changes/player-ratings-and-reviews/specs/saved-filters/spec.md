## MODIFIED Requirements

### Requirement: A saved filter contains the same fields as Home's filters

A saved filter SHALL store the game version, the category, the requires choice, the four three-state switches, the AI use filter, the rating filters ("at least N" per criterion) and the "Hide mods with no ratings" switch, and nothing else. Applying a saved filter SHALL replace those fields and SHALL leave the search text and the sort as they are. A saved filter SHALL NOT store sorting by a rating criterion.

#### Scenario: Applying on Browse keeps the search

- **WHEN** a reader has typed "nex" on Browse and picks a saved filter
- **THEN** the search still says "nex" and the saved filters are applied

#### Scenario: Saving on Browse leaves out the search

- **WHEN** a reader saves a filter on Browse while the search says "nex" and the sort is Newest
- **THEN** the saved filter stores no search text and no sort

#### Scenario: Saving a rating filter

- **WHEN** a reader saves a filter on Browse with Stability at least 4, sorted by Fun
- **THEN** the saved filter stores Stability at least 4 and does not store the Fun sort
