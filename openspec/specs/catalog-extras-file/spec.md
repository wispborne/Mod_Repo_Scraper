# catalog-extras-file Specification

## Purpose
TBD - created by archiving change mod-catalog-extras-file. Update Purpose after archive.
## Requirements
### Requirement: One record per mod, keyed by permanent id
The site build SHALL write `mod-catalog-extras.json` in the outputs folder, beside `mod-catalog.json`. The top level SHALL hold `schemaVersion` (a whole number, starting at 1), `generatedAt`, and `mods`: a map from a mod's permanent id to its record. The id SHALL be the same id the mod has in `mod-catalog.json` and on the site.

#### Scenario: A published mod
- **WHEN** the site build publishes a mod with id `lazylib`
- **THEN** `mods.lazylib` holds that mod's record

#### Scenario: Not a mod
- **WHEN** an id is a collection, a moved id, or a taken-down mod
- **THEN** it has no record in the file

### Requirement: Record fields
Each record SHALL use the site's own field names and shapes, taken from the mod's `PublicMod` and `PublicModDetail`:
- `displayName`, only when it differs from the name
- `categories` (the 13 public categories) and `rawCategories`
- `otherAuthorNames`
- `addedOn`, `editedOn`, `lastReleaseDate`
- `releases`
- `needs` and `optionalNeeds`, each entry `{name, id}`
- `isTool`, `saveCompatible`
- `canAdd`, `canUpdate`, `canRemove`, with `saveCompatibilityText`, `updateCompatibilityText` and `removalCompatibilityText`
- `aiUse`
- `sameNameMods`
- `gallery`
- `discordPostHtml`

Null values and empty lists SHALL be left out. A record SHALL NOT carry downloads, the best download, the summary, the description or the images.

#### Scenario: Same values as the site
- **WHEN** a mod's site file has a release history, a gallery and a Discord post
- **THEN** its record holds the same `releases`, `gallery` and `discordPostHtml`

#### Scenario: AI use states
- **WHEN** a mod was read and the author said nothing about AI
- **THEN** its record holds an empty `aiUse`
- **WHEN** a mod has not been read yet
- **THEN** its record has no `aiUse`

### Requirement: Never older than the site
The file SHALL be written by every site build: after a bundle, after a merge, and after a requirement-names change.

#### Scenario: Merge-only run
- **WHEN** a merge renames a mod and no bundle is built
- **THEN** the rebuilt file shows the new name's `displayName`

### Requirement: Published with the other outputs
Both publish paths SHALL copy the file to the repository root next to `mod-catalog.json`. A publish without the file SHALL log that it was missing and go on.

#### Scenario: Viewer publish
- **WHEN** the viewer's publish runs after a site build
- **THEN** the clone holds a current `mod-catalog-extras.json`

### Requirement: Discord text only here
`discordPostHtml` SHALL be allowed in this file. `mod-catalog-details.json` SHALL still carry no Discord message text. The file SHALL carry nothing internal: no config value, token, local path or run id.

#### Scenario: Details file unchanged
- **WHEN** the extras file carries a mod's Discord post
- **THEN** `mod-catalog-details.json` still does not contain any of its words

