## MODIFIED Requirements

### Requirement: Before and after for one mod
For any group in a saved merge, the system SHALL be able to show a field-by-field table: what each member that went in had for that field, what the merged mod ended up with, and which source that value came from. The winning source SHALL be worked out from the merge steps already recorded, without changing the merge code. When a field's value cannot be pinned to one source, the row SHALL say it could not be told rather than guessing.

The name-comparison step now applies a version-stripping function before the fuzzy match and the length-ratio check. This means some groups will contain members they previously did not (e.g. a Discord entry whose version-inflated name used to fail the 0.85 ratio gate). The comparison views SHALL continue to display the original names from each member, not the stripped names.

#### Scenario: Reading where each field came from
- **WHEN** the user opens the before-and-after view for a group with a Forum entry and a Nexus entry
- **THEN** each field shows both members' values, the final value, and a mark on the source that supplied it

#### Scenario: A field with no clear winner
- **WHEN** a field's final value cannot be traced to a single merge step
- **THEN** that row says the source could not be told, and no source is marked

#### Scenario: Singleton group
- **WHEN** the group has one member
- **THEN** the view says nothing was merged and shows that member's fields as the final values

#### Scenario: A group formed by version-stripped matching
- **WHEN** a group contains a Forum entry named `Hazard Mining Incorporated` and a Discord entry named `Hazard Mining Incorporated 0.4.0e "Please be fixed Ed."`
- **THEN** the before-and-after view shows both original names in full, and the merged name follows the existing source-priority rules
