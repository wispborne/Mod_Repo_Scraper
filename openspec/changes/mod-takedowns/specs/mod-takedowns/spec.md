## ADDED Requirements

### Requirement: The takedown list
The takedown list SHALL be kept in `<qb_data_path>/takedowns.json`. It SHALL contain two lists: mod entries and author entries. A mod entry SHALL record the mod's permanent id, the name it was published under, the source post keys it blocks, and the day it was added. An author entry SHALL record one or more names for the person and the day it was added. No entry SHALL include a reason or any other note. A missing file SHALL mean an empty list. A file that exists but cannot be read SHALL fail the job before any output is written. The file SHALL be written to a replacement file first and then moved over the old one. This prevents a stopped process from leaving an incomplete file.

#### Scenario: No list yet
- **WHEN** the catalog is built and `takedowns.json` does not exist
- **THEN** no mod is taken down and the build goes on as before

#### Scenario: A broken list stops the job
- **WHEN** `takedowns.json` exists but is not valid JSON
- **THEN** the job fails with a message naming the file, and `mod-catalog.json`, `mod-catalog-details.json` and the site files are left as they were

#### Scenario: An entry includes no reason
- **WHEN** a mod entry is written
- **THEN** it holds the id, the name, the post keys and the day, and no other field

### Requirement: A mod entry records the mod's current posts
When a mod is taken down, its entry SHALL record the source posts linked to the mod in the current `mod-catalog.json`. A post SHALL be recorded as the whole post (`discord:<id>`, `forum:<id>`) when no other mod in the catalog comes from that post. A post that other mods also come from SHALL be recorded with this mod's LLM name (`forum:<id>#<name>`), so only this mod's listing is blocked.

#### Scenario: The Tidal fork
- **WHEN** `diable-avionics-tidal-fork` is taken down and the catalog has it from Discord thread 1507163509224509510 only, with no other mod from that thread
- **THEN** the entry records `discord:1507163509224509510` as a whole post

#### Scenario: One mod on a shared thread
- **WHEN** a mod is taken down that is one of four mods from forum topic 34161, under the LLM name "Useful.Tithes"
- **THEN** the entry records `forum:34161#Useful.Tithes` and not `forum:34161`

### Requirement: Mod entries are applied before the merge
The catalog step SHALL remove blocked listings before the merge. A whole-post key SHALL block every listing from that post. A named key SHALL block only the listing with that LLM name on that post. A blocked listing SHALL NOT take part in the merge. This prevents it from being joined to another mod. After the merge, a mod that is given the id of a mod entry SHALL also be left out. This removes a listing on a shared post even if its LLM name changed after the entry was made.

#### Scenario: Only the Tidal fork is removed
- **WHEN** the catalog is built with an entry for `diable-avionics-tidal-fork` blocking `discord:1507163509224509510`, and that thread's LLM answer names its mod "Diable Avionics"
- **THEN** `diable-avionics-tidal-fork` is not in `mod-catalog.json`, and `diable-avionics`, `diable-avionics-2`, `diable-avionics-3`, `diable-avionics-4` and `diable-avionics-original-flavor` are, with the same source posts they had without the entry

#### Scenario: A renamed mod on a shared thread stays removed
- **WHEN** a mod entry blocks `forum:34161#Useful.Tithes`, and the LLM now calls that mod "Useful Tithes", and the id store gives the renamed listing the entry's id
- **THEN** that mod is left out of `mod-catalog.json`, and the other mods from topic 34161 are not

#### Scenario: A new thread is not blocked by a mod entry
- **WHEN** the author of a taken-down mod posts it again in a new Discord thread that no entry names
- **THEN** that thread's mod is published under a new id, since a mod entry blocks only the posts it records

### Requirement: Author entries are applied after the merge
After the merge, the catalog step SHALL leave out every mod that credits a person named by an author entry. A credited name and an entry name SHALL be compared using the merge's author name rules. The comparison SHALL ignore capitals, punctuation and digits at the end of a Discord name. Names in one row of the author alias table SHALL count as one person. Names SHALL NOT match just because they are similar or one contains part of the other. A mod SHALL be left out when any one of its credited authors matches. This includes mods made with others and forks that still credit the person. This SHALL apply to mods first seen after the entry was made.

#### Scenario: Different spellings of one person's name
- **WHEN** an author entry names "tidal5590"
- **THEN** mods credited to "tidal5590", "Tidal" or "TIDAL" are all left out

#### Scenario: A mod made with others
- **WHEN** an author entry names "Tidal" and "Diable Avionics: Original Flavor" credits "After", "Tartiflette" and "Tidal"
- **THEN** that mod is left out

#### Scenario: A part of a name is not a match
- **WHEN** an author entry names "Tidal" and a mod credits "Tidalwave"
- **THEN** that mod is kept

#### Scenario: A new mod by a blocked author
- **WHEN** an author entry exists and that person posts a new mod after it was made
- **THEN** the new mod is left out of the first catalog it would have been in

### Requirement: Takedowns only affect publishing
A takedown SHALL only decide what is published. The scrapers and the LLM SHALL read taken-down posts as they read any other post. Their saved data SHALL be kept. Restoring an entry therefore needs no new scrape or LLM call.

#### Scenario: Restoring needs no network
- **WHEN** a mod entry is removed and the outputs are rebuilt from saved files
- **THEN** the mod is back in `mod-catalog.json` with its facts, and no page is fetched and no LLM call is made

### Requirement: A taken-down id is kept
The id of a mod entry SHALL stay in `mod-ids.json`, linked to its posts. It SHALL never be given to another mod. It SHALL NOT appear in the catalog's `movedIds`, either as an old id or as the mod an old id leads to. When the entry is removed, the mod SHALL come back under the same id.

#### Scenario: Restoring keeps the same address
- **WHEN** the entry for `diable-avionics-tidal-fork` is removed and the catalog is built again
- **THEN** the mod's id is `diable-avionics-tidal-fork`

#### Scenario: An old id does not lead to a taken-down mod
- **WHEN** an old id would lead to a mod that is now taken down
- **THEN** that old id is not in `movedIds`

### Requirement: Published files exclude taken-down mods
A mod left out by a takedown SHALL NOT appear anywhere in `mod-catalog.json` or in the files Starmodder builds. That covers its record, any Collection's list of mods, `movedIds`, `mods.json`, its own `mods/<id>.json` and page, `updates.json`, `updates.xml`, `sitemap.xml`, other mods' "Requires" links (the name stays as plain text, as for any mod we do not publish), and other mods' "same name" panels.

#### Scenario: Another mod needs a taken-down mod
- **WHEN** mod A's post says it needs mod B, and mod B is taken down
- **THEN** mod A's page lists B by name with no link

#### Scenario: A Collection loses one mod
- **WHEN** a mod on a Collection is taken down
- **THEN** the Collection's list of mods no longer has its id, and the Collection's page still lists the others

#### Scenario: The release feed excludes the mod
- **WHEN** a taken-down mod had releases in the release history
- **THEN** none of them appear in `updates.json` or `updates.xml`

### Requirement: The details file follows the catalog
The catalog SHALL be built before `mod-catalog-details.json` and `forum-data-bundle.json` are written. The catalog step SHALL report which source posts had every listing removed by a takedown, and the bundle SHALL leave those forum topics and Discord threads out. A post that still has a published mod SHALL stay in the bundle in full. This applies even when another mod from it was taken down.

#### Scenario: The details file excludes the Tidal fork's thread
- **WHEN** the outputs are built with the entry for `diable-avionics-tidal-fork`
- **THEN** `mod-catalog-details.json` has no `discordThreads` entry for thread 1507163509224509510

#### Scenario: A shared post stays
- **WHEN** one of four mods from forum topic 34161 is taken down
- **THEN** topic 34161 is still in `mod-catalog-details.json`

### Requirement: Each build reports what the takedowns removed
Each catalog build SHALL log, for every entry, which mods it left out and how many. An author entry that left out no mods SHALL be logged as such. This usually means the person has a new name. The same report SHALL be saved to `<qb_data_path>/takedown-matches.json` for the viewer. That file SHALL NOT be published.

#### Scenario: An author entry that matches nothing
- **WHEN** an author entry's names match no credited author in this build
- **THEN** the run log says that entry left out no mods

### Requirement: Taking down and restoring are jobs
The manager SHALL offer a `takeDown` job and a `restoreTakedown` job. A `takeDown` request SHALL name either one mod id or one or more author names. It MAY ask to publish when done. The job SHALL take the data lock, add the entry, rebuild the bundle, catalog and site from saved files, and then publish when asked. A `restoreTakedown` request SHALL name the entry to remove. The job SHALL otherwise work the same way. A request for a mod id that is not in the current catalog, or that is already taken down, SHALL be refused with a reason. A request to restore an entry that does not exist SHALL be refused with a reason. Neither job SHALL scrape or call an LLM.

#### Scenario: Take down and publish
- **WHEN** a `takeDown` job runs for `diable-avionics-tidal-fork` with publishing requested
- **THEN** the entry is added, the outputs are rebuilt without the mod, and the outputs are published. These steps appear as one run in the history

#### Scenario: An unknown id is refused
- **WHEN** a `takeDown` request names an id that is not in `mod-catalog.json`
- **THEN** the request is refused with a message saying no mod has that id, and the list is unchanged

#### Scenario: Stopped before the rebuild finishes
- **WHEN** a `takeDown` job is cancelled after the entry is written but before the outputs are rebuilt
- **THEN** the entry stays in the list and the next rebuild applies it
