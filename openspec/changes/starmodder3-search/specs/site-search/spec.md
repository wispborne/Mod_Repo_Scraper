# site-search

How the public website decides which mods match what a reader typed — on the browse page and in the top-bar suggestion box.

## ADDED Requirements

### Requirement: Each mod has a list of search terms

The site SHALL build, once per mod, a list of the things a search can match: the thread title, the tidied display name, the display name broken into its words, the first letters of those words joined as an acronym, every credited author, every other name those authors go by (from `otherAuthorNames`), every category, the summary, the game version, and the mod version. Every term SHALL be compared in lowercase.

#### Scenario: An acronym finds a mod

- **WHEN** a reader types "swp" and a mod's display name is "Ship/Weapon Pack"
- **THEN** the mod matches, because "swp" is the acronym of its name's words

#### Scenario: A version finds a mod

- **WHEN** a reader types "0.98" and a mod's game version is "0.98a-RC8"
- **THEN** the mod matches

#### Scenario: A term must sit inside one fact

- **WHEN** a typed term only appears by running the end of one fact into the start of another (for example the author's name into a category name)
- **THEN** the mod does not match, because each fact is checked on its own

### Requirement: A typed term matches by substring

A typed term SHALL match a mod when the term, lowercased and trimmed, appears anywhere inside at least one of that mod's search terms.

#### Scenario: Part of a word is enough

- **WHEN** a reader types "nex"
- **THEN** every mod with "nex" inside any of its search terms matches, including one named "Nexerelin"

### Requirement: Commas mean any of these

The search SHALL split what the reader typed on commas. A mod SHALL be listed when it matches **any** comma-separated term that has no leading minus. Terms that are empty after trimming SHALL be ignored, and typing nothing SHALL list every mod.

#### Scenario: Two terms widen the list

- **WHEN** a reader types "faction, portrait"
- **THEN** the list holds every mod matching "faction" and every mod matching "portrait"

#### Scenario: Only a comma typed

- **WHEN** the search box holds only "," or spaces
- **THEN** every mod is listed

### Requirement: A leading minus leaves mods out

A comma-separated term starting with "-" SHALL remove every mod that matches the rest of the term, even when that mod matched a positive term. When only minus terms are typed, the list SHALL be every mod except the removed ones.

#### Scenario: Mixing keep and leave out

- **WHEN** a reader types "faction, -portrait"
- **THEN** mods matching "faction" are listed, except any that also match "portrait"

#### Scenario: Only leaving out

- **WHEN** a reader types "-portrait"
- **THEN** every mod is listed except those matching "portrait"

#### Scenario: A bare minus does nothing

- **WHEN** a reader types "-" on its own
- **THEN** it is ignored and does not empty the list

### Requirement: The browse page and the suggestion box search the same way

The browse page's search and the top-bar suggestion box SHALL both match against the same per-mod term list, so a query that finds a mod in one finds it in the other. The suggestion box SHALL still rank a name that starts with the typed text above a name that merely holds it, and both above a match on any other term.

#### Scenario: An acronym suggests a mod

- **WHEN** a reader types "swp" into the top-bar box
- **THEN** "Ship/Weapon Pack" appears among the suggestions

#### Scenario: Name matches come first

- **WHEN** a typed text starts one mod's name and only matches another mod's author
- **THEN** the mod matched by name is suggested above the one matched by author

### Requirement: The hint says what commas do

The line under the browse page's search box SHALL say, in plain English, that commas list mods matching any of the terms and that a leading minus leaves mods out.

#### Scenario: Reading the hint

- **WHEN** a reader looks under the search box
- **THEN** the hint explains the comma and the minus with an example
