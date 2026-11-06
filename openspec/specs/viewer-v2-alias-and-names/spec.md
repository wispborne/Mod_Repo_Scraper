# viewer-v2-alias-and-names Specification

## Purpose
TBD - created by archiving change viewer-v2-alias-and-names. Update Purpose after archive.
## Requirements
### Requirement: Author aliases page
The Author aliases page SHALL list each person with the names they go by and how many mods use each name, the suggested pairs, and the pairs marked "different people". Its actions SHALL add pending changes: join two names as one person, mark two names as different people, take a name off a person, and publish a person under another of their names. A row whose change is pending SHALL say so and offer Undo. With the manager off, the page SHALL show the lists and no actions.

#### Scenario: Accepting a suggestion
- **WHEN** the user presses "These are the same person" on a suggested pair
- **THEN** a pending change "\"A\" and \"B\" are the same person" is added and the suggestion is marked pending

### Requirement: Dependency names page
The Dependency names page SHALL list every spelling seen in the last build with how many mods use it, what it matched and how, and the saved answers no build used. Its actions SHALL add pending changes: match a spelling to one of our mods chosen with a search box, mark it as none of our mods, or forget its saved answer. A row whose change is pending SHALL say so and offer Undo. With the manager off, the page SHALL show the lists and no actions.

#### Scenario: Matching a spelling
- **WHEN** the user picks LazyLib for the spelling "Lazy Lib"
- **THEN** a pending change "\"Lazy Lib\" means \"LazyLib\"" is added

### Requirement: Saving is unavailable while jobs are off
While the manager is off, the Pending changes list SHALL disable "Save all". It SHALL say in one line that changes can't be saved. It SHALL still allow items to be removed or discarded.

#### Scenario: Manager off
- **WHEN** the list has an item and the manager is off
- **THEN** "Save all" cannot be pressed and the list says why

