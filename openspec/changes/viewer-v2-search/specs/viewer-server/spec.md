## ADDED Requirements

### Requirement: Search over HTTP
The server SHALL answer `GET /api/search?q=` with up to a few matches of each kind — mods (by name, nickname, author or permanent id), forum topics (by id or title), Discord threads (by id or name) and runs (by id) — best matches first, with the total number of matches of each kind. Searches with fewer than two characters SHALL return empty groups. The route SHALL be read-only.

#### Scenario: A nickname
- **WHEN** the client searches "IndEvo"
- **THEN** Industrial.Evolution is among the mods, with a note that it is also called IndEvo

#### Scenario: Runs with the manager off
- **WHEN** the manager is off
- **THEN** the runs group is empty and the other groups still return results
