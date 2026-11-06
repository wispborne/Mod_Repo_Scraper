## ADDED Requirements

### Requirement: Mods list
The Mods page SHALL list every mod in the last build, searchable by name, nickname, author or id, with filters and paging kept in the address. Each row SHALL link to the mod's page.

#### Scenario: Searching
- **WHEN** the user searches "nex"
- **THEN** Nexerelin is listed, and the address includes the search

### Requirement: Mod page
The mod page SHALL show, in this order: a header with the name, permanent id, authors, links to its Starmodder page and raw published files, old ids that lead here and its takedown status; what Starmodder shows; where each fact came from; its source posts with how each joined, its LLM name and whether the rules or the LLM found it; its history; and raw JSON, collapsed. While the manager is on it SHALL offer the per-post jobs for all its posts, Take down, "These are the same person" next to its authors when it credits two or more, and "Match this to a mod" next to each requirement the build could not match, each correction adding a pending change. An old id SHALL open the mod it leads to with a note explaining this.

#### Scenario: A mod made from three posts
- **WHEN** the user opens a mod built from a forum topic and two Discord threads
- **THEN** all three posts are listed with how each joined, and each links to its source post page

#### Scenario: An old address
- **WHEN** the user opens an old id that leads to another mod
- **THEN** that mod's page opens with a note naming the old id

### Requirement: Collection page
A Collection's id SHALL open a page with its name, the post it comes from, and its mods, each linking to its page.

#### Scenario: Opening a Collection
- **WHEN** the user opens a Collection's id
- **THEN** the page lists its mods and links to its source post
