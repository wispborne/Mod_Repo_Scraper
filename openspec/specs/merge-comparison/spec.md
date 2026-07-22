# merge-comparison Specification

## Purpose
TBD - created by archiving change merge-from-website. Update Purpose after archive.
## Requirements
### Requirement: Before and after for one mod
For any group in a saved merge, the system SHALL be able to show a field-by-field table: what each member that went in had for that field, what the merged mod ended up with, and which source that value came from. The winning source SHALL be worked out from the merge steps already recorded, without changing the merge code. When a field's value cannot be pinned to one source, the row SHALL say it could not be told rather than guessing.

#### Scenario: Reading where each field came from
- **WHEN** the user opens the before-and-after view for a group with a Forum entry and a Nexus entry
- **THEN** each field shows both members' values, the final value, and a mark on the source that supplied it

#### Scenario: A field with no clear winner
- **WHEN** a field's final value cannot be traced to a single merge step
- **THEN** that row says the source could not be told, and no source is marked

#### Scenario: Singleton group
- **WHEN** the group has one member
- **THEN** the view says nothing was merged and shows that member's fields as the final values

### Requirement: What changed between two merges
The system SHALL be able to compare two saved merges and report mods **added** (in the newer, not the older), **gone** (in the older, not the newer), and **changed** (in both, with at least one differing field, naming the fields and both values). Mods that are the same in both SHALL be counted but not listed. The comparison SHALL be searchable by mod name and author and served paged, and MUST NOT return a whole snapshot to the browser.

#### Scenario: Judging a rule change
- **WHEN** the user compares the merge from before a matching-rule change with the one from after
- **THEN** they see which mods newly merged together, which came apart, and which fields changed value

#### Scenario: Searching the differences
- **WHEN** the user types a mod name into the comparison search box
- **THEN** only differences involving a mod whose name or author matches are shown, paged

#### Scenario: Same mod, different name
- **WHEN** a mod's name gained a version suffix between the two merges but its forum topic is the same
- **THEN** it is reported as changed, not as one added and one gone

#### Scenario: Comparing a merge with itself
- **WHEN** the same merge id is given twice
- **THEN** nothing is added, gone or changed, and the same-count equals the mod count

### Requirement: Mods are lined up by forum topic first
When matching mods between two merges, the system SHALL use the forum topic id when the mod has one, and otherwise the mod's name and authors put through the same normalizing the merger uses. When more than one mod in a single merge shares a key, they SHALL be compared as a set and reported as changed when the sets differ.

#### Scenario: Mod with no forum topic
- **WHEN** a Discord-only mod with no forum link appears in both merges with the same name and author
- **THEN** it is lined up across the two merges and reported as unchanged if its fields match

#### Scenario: Two mods share a key
- **WHEN** two mods in one merge normalize to the same name and authors
- **THEN** they are compared as a set against the other merge's set for that key, and any difference is reported as changed

