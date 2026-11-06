# viewer-v2-search Specification

## Purpose
TBD - created by archiving change viewer-v2-search. Update Purpose after archive.
## Requirements
### Requirement: Search box
The search box at the top of every page SHALL show matches as the user types, grouped by kind (mods, forum topics, Discord threads, runs), each linking to its page, with a link to the full list for each kind. The arrow keys SHALL move through the matches. Enter SHALL open the selected match, or the first match if none is selected. Escape SHALL close the results. A forum or Discord address, or a topic or thread id, SHALL open that post's page on Enter. No search SHALL open the old viewer.

#### Scenario: Typing a name
- **WHEN** the user types "nexer"
- **THEN** Nexerelin appears under Mods, and Enter opens its mod page

#### Scenario: Pasting an address
- **WHEN** the user pastes a Discord thread address and presses Enter
- **THEN** that thread's source post page opens

