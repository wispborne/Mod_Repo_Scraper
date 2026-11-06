## ADDED Requirements

### Requirement: Counts of what needs attention
The server SHALL answer `GET /api/attention` with counts read from saved files: dependency names that matched no mod, suggested author pairs not yet decided, takedown entries that excluded nothing, taken-down mods that came back under a new id, saved posts with no LLM answer (forum topics that are not placeholders, and Discord threads), and published mods with no download. A count whose file is missing SHALL be left out of the answer. The route SHALL NOT write anything.

#### Scenario: Nothing needs attention
- **WHEN** every file is present and nothing needs attention
- **THEN** every count in the answer is 0

#### Scenario: A file is missing
- **WHEN** `requirement-names-report.json` does not exist
- **THEN** the answer has no dependency name count, and the other counts are still given
