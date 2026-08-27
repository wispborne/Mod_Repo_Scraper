## ADDED Requirements

### Requirement: A mod's page names the other mods that share its name
Where a published mod shares its name with one or more other published mods, its page
SHALL show them in a block of their own, and SHALL show nothing where it shares its name
with nothing. Each entry SHALL give the mod's name, its authors, its game version, its
mod version and when its forum thread was last posted on, and SHALL be a link to that
mod's page.

The block SHALL sit where a reader who arrived from outside — a search engine, a link
someone posted — meets it without having to scroll past the downloads, because the
reader most likely to be on the wrong page of two is the one who did not come through a
list.

Which mods share a name SHALL be worked out in the browser from the list of every mod
the page has already fetched, on the same comparison the builder uses: each name cut at
the first version it carries, then compared on letters and numbers alone. Nothing extra
SHALL be fetched to draw the block, and no per-mod list of the others SHALL be added to
`mods.json`.

The block's heading SHALL fit every case it covers — a mod's older thread, a fork that
kept the original's name, and two unrelated mods that happen to share a name. It SHALL
NOT say "Older versions", which is true of only one of the three.

#### Scenario: Two pages for the same mod
- **WHEN** a reader opens the "Scy" published from the 2015 thread
- **THEN** the page names the "Scy" published from the newer thread, says who wrote it, which game version it is for and when its thread was last posted on, and links to it

#### Scenario: The fork and the original
- **WHEN** a reader opens Computica's fork of "Junk Pirates"
- **THEN** the page names the original "Junk Pirates" by mendonca with its game version, and links to it

#### Scenario: A mod with a name of its own
- **WHEN** a reader opens a mod whose name no other published mod shares
- **THEN** no such block appears

#### Scenario: Arriving from outside
- **WHEN** a reader follows a link straight to one of two same-name pages
- **THEN** the other is visible on that page without scrolling past the download list

#### Scenario: Lists already say who wrote a mod
- **WHEN** two same-name mods appear in browse, on a card, or in the search box's suggestions
- **THEN** each is shown with its author as it is today, and no further change is made to those lists
