## ADDED Requirements

### Requirement: Mods over HTTP
The server SHALL answer `GET /api/mods` with every mod in the last build as a paged, searchable, filterable list; `GET /api/mods/<id>` with one mod's catalog record, published record, source posts (with how each joined, when the build recorded it), the source of each fact, old ids that lead to it, its takedown status and its unmatched requirements; and `GET /api/mods/<id>/history` with the saved runs in which the mod changed and which fields changed. An id that only leads to another mod SHALL answer with the mod it leads to. A Collection's id SHALL answer as a Collection. The routes SHALL only read data.

#### Scenario: A moved id
- **WHEN** the client asks for an old id that now leads to another mod
- **THEN** the answer says `moved` and names the mod it leads to

#### Scenario: Where a fact came from
- **WHEN** the client asks for a mod whose mod version came from its Discord thread
- **THEN** the mod version's source names that Discord thread and its LLM name

### Requirement: The build records where each fact came from
When the website is built, the source of each chosen fact SHALL be saved for every mod in `<qb_data_path>/fact-sources.json`, with the build's time. The file SHALL never be published, and SHALL be read only when its build time matches the catalog's.

#### Scenario: After a rebuild
- **WHEN** Rebuild from saved finishes
- **THEN** `fact-sources.json` has an entry for every mod, with the same build time as the catalog
