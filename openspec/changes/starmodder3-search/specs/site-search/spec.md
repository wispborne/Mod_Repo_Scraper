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

### Requirement: A plus joins terms that must all match

Inside one comma-separated group, "+" SHALL split the group into terms that must **all** match for that group to match. This works the same in a group that leaves mods out. A plus with nothing either side of it SHALL be ignored rather than emptying the list.

#### Scenario: Two terms that must both match

- **WHEN** a reader types "hartley + abuse"
- **THEN** only mods answering both terms are listed, which over the real data is one mod

#### Scenario: A plus narrows where a comma widens

- **WHEN** a reader types "faction + portrait" instead of "faction, portrait"
- **THEN** the list is the mods answering both, which is a smaller list than either term alone

#### Scenario: A bare plus does nothing

- **WHEN** a reader types "+" on its own
- **THEN** it is ignored and every mod is listed

### Requirement: A term can ask about one field by name

A term written as `key:value` SHALL be matched against that field alone, where the value is looked for inside any of the field's values, ignoring capitals. The keys SHALL be `name`, `author`, `category`, `version`, `gameversion`, `modversion`, `source`, `url` and `summary`, with `authors`, `categories` and `sources` accepted as well. A key the site does not know SHALL fall through to an ordinary search of the whole term, so a mod whose name carries a colon can still be found. A key with nothing after the colon SHALL do the same.

#### Scenario: Asking about one field

- **WHEN** a reader types "author:Wisp"
- **THEN** only mods crediting that person are listed, and not mods that merely mention the word elsewhere

#### Scenario: A field a mod's own file holds is not offered

- **WHEN** a field is not carried in the published list file, such as a mod's full description
- **THEN** it is not one of the keys, because the browse page never fetches that file and the search would quietly match nothing

#### Scenario: An unknown key is just words

- **WHEN** a reader types a term with a colon whose key the site does not know, such as part of a mod's own name
- **THEN** the whole term is searched for as ordinary words and the mod is found

#### Scenario: Fields join up with the rest

- **WHEN** a reader types "category:weapons, -source:discord"
- **THEN** the field terms take part in the comma, plus and minus rules exactly as plain terms do

### Requirement: The browse page and the suggestion box search the same way

The browse page's search and the top-bar suggestion box SHALL both match and score against the same per-mod term list, so a query that finds a mod in one finds it in the other and the two agree about which mod answers best.

#### Scenario: An acronym suggests a mod

- **WHEN** a reader types "swp" into the top-bar box
- **THEN** "Ship/Weapon Pack" appears among the suggestions

#### Scenario: The better answer is suggested first

- **WHEN** one mod's name is exactly what was typed and another merely holds it somewhere
- **THEN** the exact one is suggested above the other, by the same score the browse page sorts on

### Requirement: The hint says what commas do

The line under the browse page's search box SHALL say, in plain English, that commas list mods matching any of the terms and that a leading minus leaves mods out.

#### Scenario: Reading the hint

- **WHEN** a reader looks under the search box
- **THEN** the hint explains the comma and the minus with an example

### Requirement: A panel says what the search understands

Every search box on the site SHALL offer a panel listing what the search understands: an opening line naming what it looks at, then one line each for commas, the plus, the minus, acronyms, versions and field search. Each line SHALL be a short name in bold, then how it works with the letters to type shown as typed. The panel SHALL describe only what the search actually does — it must never offer a way of searching the site does not have.

#### Scenario: The panel is up under the pointer

- **WHEN** a reader rests the pointer anywhere on a search box
- **THEN** the panel appears below it, and stays up while the pointer moves down into the panel to read it

#### Scenario: The panel is up while the box is in use

- **WHEN** a reader puts the cursor in a search box
- **THEN** the panel appears below it and stays there while they type, so it can be read while the search is being written

#### Scenario: It goes when the box is done with

- **WHEN** the reader clicks off the search box
- **THEN** the panel goes away

#### Scenario: A marked button anyone can find

- **WHEN** a reader points at or presses the "?" beside a search box
- **THEN** the panel appears, so somebody with no pointer or no keyboard can still reach it

#### Scenario: The box at the top gives way to the suggestions

- **WHEN** a reader types into the search box in the bar at the top
- **THEN** the panel goes and the suggested mods take that room, and clearing the box brings the panel back

### Requirement: One panel, built in one place

The panel SHALL be built by one shared piece of code used by every search box, so no two boxes can come to describe the search differently.

#### Scenario: The same panel everywhere

- **WHEN** the ways of searching change
- **THEN** they are edited once and every search box on the site says the same thing

### Requirement: A search can be sorted by how well each mod answers

Every term SHALL be scored, not merely matched: a fact that is exactly what was typed SHALL score highest, one that starts with it next, and one that merely holds it lowest. A match on a fact further from the mod's identity — a category, a version, the summary — SHALL score below the same kind of match on its name or the people credited. A field asked about by name SHALL score as well as the mod's own name does. Terms joined by a plus SHALL have their scores added; where several comma groups let a mod in, the best-scoring group SHALL speak for it.

#### Scenario: An exact answer beats a partial one

- **WHEN** a reader types the initials of one mod's name, which another mod merely contains
- **THEN** the mod whose initials are exactly that is listed first

#### Scenario: The browse page offers Best match while searching

- **WHEN** a reader types into the browse page's search box
- **THEN** a "Best match" sort appears and is chosen for them, and the list is ordered by how well each mod answers

#### Scenario: Best match is not offered with an empty box

- **WHEN** the search box is empty
- **THEN** "Best match" is not among the sorts, and the list falls back to the usual order

#### Scenario: A sort chosen by hand is kept

- **WHEN** a reader picks another sort while searching and then types more
- **THEN** their sort is kept rather than being taken back to Best match
