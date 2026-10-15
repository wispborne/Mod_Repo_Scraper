## ADDED Requirements

### Requirement: Every source post gives zero or more listings

The system SHALL build zero or more listings from each source post before merging. Each listing SHALL identify its source post and whether it came from fixed rules or the LLM.

Forum listings SHALL use the QB store. Discord listings SHALL use the Discord cache, `discord-posts.json` and the extraction store. Both sources SHALL use the same listing combination rule. Each Nexus page SHALL retain its existing single listing.

#### Scenario: Source post with no LLM answer

- **WHEN** a forum topic or a Discord thread has no LLM answer
- **THEN** it gives exactly one listing, found by rules

#### Scenario: Listing knows its source post

- **WHEN** any listing is made
- **THEN** it carries the kind and id of its source post (forum topic id, Discord thread id, or Nexus id) and, for an LLM listing, the name the LLM gave that mod

### Requirement: Which forum topics give listings

Every topic retained by `keepThreadInBundle` SHALL produce listings. Missing bracketed game versions, absence from the mod index and topic age SHALL NOT exclude a retained topic.

#### Scenario: Topic with no bracketed game version

- **WHEN** a kept topic's title has no bracketed game version (for example topic 35651)
- **THEN** it gives listings like any other topic

#### Scenario: Topic the bundle would drop

- **WHEN** `keepThreadInBundle` drops a topic
- **THEN** it gives no listings

### Requirement: The rules listing for a forum topic

Each forum topic SHALL produce one rules listing:

- For a topic in the mod index, use its first line's name, author, game version and category. Retain names from other lines as alternate names. Set its source to `Index`.
- For a topic outside the mod index, remove the bracketed game version, mod version and date from the title. Set its source to `ModdingSubforum`.

Index lines SHALL come from the current index when it lists the topic. Only topics absent from the current index SHALL use archived index posts.

#### Scenario: Topic with several index lines

- **WHEN** topic 21968 has index lines "Midline Expansion", "Pirate Collection" and "Yunru Mods"
- **THEN** the rules give one listing named from the first line, with the other two names kept as other names

#### Scenario: Topic in today's index and an old one

- **WHEN** topic 29674 is listed in today's index with game version "[-]" and in an older index with "[0.97a]"
- **THEN** its rules listing has game version "[-]"

#### Scenario: Topic outside the mod index

- **WHEN** a kept topic is not in the mod index
- **THEN** its rules listing is named from the topic title with the bracketed game version, the mod version and any date removed

### Requirement: The rules listing for a Discord thread

Each Discord thread SHALL produce one rules listing, retaining the name, author, links, categories and images supplied by the existing Discord reader.

#### Scenario: Discord thread read by rules

- **WHEN** the Discord reader reads a thread named "Adjustable S-Mods 1.1.2"
- **THEN** its rules listing is the same mod the reader makes today, with a ref to that thread

### Requirement: How a source post's rules listing and LLM listings combine

The system SHALL combine each forum topic's or Discord thread's rules listing with its grounded LLM `main` mods before merging. A main mod is grounded when its name appears in the opening run and at least one download is tied to it.

| Grounded main mods | Required result |
| --- | --- |
| None | Send the rules listing to the merge alone. |
| One | Combine it with the rules listing, regardless of their names, and apply its LLM facts. |
| Two or more | Make one listing per main mod. Combine the rules listing with the mod whose name or grounded nickname matches the rules listing's name or alternate names using `modNamesMatch`. If none matches, classify the source post as a Collection and drop the rules listing. |

Every Discord LLM listing SHALL retain the thread's forum link, if present.

#### Scenario: One main mod with a different name

- **WHEN** topic 9035's rules listing is "Red" and the LLM's only main mod is "Red - the Oculian Armada"
- **THEN** they are one listing carrying the LLM's facts

#### Scenario: Several main mods, one matches

- **WHEN** a topic's rules listing is "Useful.Tithes 1.0.a" and the LLM names four main mods including "Useful.Tithes"
- **THEN** the rules listing joins "Useful.Tithes", and the other three are listings of their own

#### Scenario: Rules name is the LLM mod's former name

- **WHEN** a topic's rules listing is "Pirate Collection", the LLM names several main mods, and one of them gives "Pirate Collection" as a grounded nickname
- **THEN** the rules listing joins that mod

#### Scenario: Several main mods, none match

- **WHEN** topic 34161's rules listing is "Hartley's Miscellaneous Mods" and the LLM names four main mods, none with that name
- **THEN** the topic is a Collection, the rules listing is dropped, and the four mods are listings

#### Scenario: Discord thread holding several mods

- **WHEN** a Discord thread's LLM answer names two grounded main mods and neither matches the thread's name
- **THEN** the thread is a Collection, its rules listing is dropped, and the two mods are listings, each carrying the thread's forum link if it has one

#### Scenario: Ungrounded LLM mod

- **WHEN** the LLM names a main mod whose name is not in the opening run, or which has no download tied to it
- **THEN** it does not count as a grounded main mod and produces no listing

### Requirement: Add-ons and variants are never mods

LLM results with role `addon` or `variant` SHALL NOT create independent listings. Attach an add-on to the main mod named by its `requires` field, and a variant to the main mod it is a build of. Results with role `separate` SHALL produce no listing.

#### Scenario: Library with add-ons

- **WHEN** topic 21968's LLM answer is one main library, "YunruCore", and five add-ons that each require it
- **THEN** one listing is made, carrying the five add-ons, and the topic is not a Collection

### Requirement: The LLM cannot remove what the rules found

With the LLM off, rules SHALL still produce a complete catalog. The system SHALL allow LLM results to add listings and replace a rules listing with a Collection under the combination rule above. They SHALL NOT otherwise remove, rename or merge away rules listings.

#### Scenario: LLM off

- **WHEN** no source post has an LLM answer
- **THEN** every kept forum topic and every Discord thread gives exactly its one rules listing, and the merge runs as normal

#### Scenario: LLM answer with no main mods

- **WHEN** the LLM's answer for a source post has no grounded main mod
- **THEN** the post's rules listing goes into the merge unchanged

### Requirement: One merge over every listing

The system SHALL merge all sources' listings once, using the existing `ModMerger` rules. Later steps SHALL NOT match mods to source posts by name to add, remove or split mods.

#### Scenario: Collection mod also announced on Discord

- **WHEN** one of Hartley's four mods also has a Discord thread that links to topic 34161
- **THEN** the merge joins that Discord listing to that one mod, not to the whole topic

#### Scenario: Site build does no matching

- **WHEN** the site is built
- **THEN** it reads each mod's source post links and looks facts up by them, and never decides by name which LLM mod belongs to which mod

### Requirement: Which answer a mod's facts come from

For mods with LLM results from several source posts, the system SHALL select facts as follows:

- Prefer the forum result for each field. Use Discord only where the forum field is empty.
- Treat downloads as one field: use forum LLM downloads if present, otherwise Discord LLM downloads, otherwise the Discord rules listing's download link.
- Use the higher mod version according to TriOS's version comparison.
- Within one source kind, prefer the newer source post.

#### Scenario: Discord-only mod

- **WHEN** a mod's only source post is a Discord thread with an LLM answer
- **THEN** its requirements, save compatibility answers, support links, license, nicknames, changelog, summaries and downloads all come from that answer

#### Scenario: Forum answer has no license

- **WHEN** a mod's forum answer states no license and its Discord answer does
- **THEN** the mod's license is the Discord answer's

#### Scenario: Forum answer has downloads

- **WHEN** a mod's forum answer has two downloads and its Discord answer has one other
- **THEN** the mod offers the forum answer's two downloads

#### Scenario: Discord announces a newer version

- **WHEN** a mod's forum answer says version "1.2" and its Discord answer says "1.3"
- **THEN** the mod's version is "1.3"

### Requirement: Permanent ids are found by source post

The merge SHALL assign permanent ids by source reference first: forum topic id, Discord thread id or Nexus id, including the LLM mod name where present. Name-based assignment SHALL apply only when none of the mod's source posts has an id.

Renaming a mod SHALL NOT change its id. An assigned id SHALL never be reused for another mod. If source refs point to different ids, the older id SHALL win and the conflict SHALL be logged. If an existing `mod-ids.json` cannot be read, the run SHALL fail without writing anything.

#### Scenario: Title gains a new version

- **WHEN** a mod's forum title changes from "Foo 1.2" to "Foo 1.3"
- **THEN** the mod keeps the same id

#### Scenario: Merge picks a different name

- **WHEN** a mod that was named from its Discord thread is now named from its mod index line
- **THEN** it keeps the id its source posts already had

#### Scenario: Discord-only mod gains an LLM name

- **WHEN** a Discord-only mod's thread is read by the LLM for the first time and the LLM gives it a different name
- **THEN** the mod keeps the id its Discord thread already had

#### Scenario: Brand-new mod

- **WHEN** a mod has no source post with an id
- **THEN** it gets a new id worked out from its name, with a number on the end if that id is taken

### Requirement: Existing ids are linked to their source posts once

A one-time migration SHALL link every id in `mod-ids.json` to its source posts using the current published data. For mods sharing a forum topic with two or more LLM main mods, include the LLM name selected by the current site build in each forum ref. Repeating the migration SHALL produce the same result.

#### Scenario: Run twice

- **WHEN** the step runs a second time on the same data
- **THEN** `mod-ids.json` comes out the same

#### Scenario: Mods sharing a topic

- **WHEN** `useful-tithes-1-0-a` and `big-pilum-energy-1-0-d` both link to topic 34161
- **THEN** their forum refs name "Useful.Tithes" and "Big Pilum Energy" respectively, not just topic 34161

### Requirement: A Collection keeps an id it already had

If a Collection's rules listing had a permanent id, that id SHALL remain reserved. The site SHALL keep a page at that address, naming the source post and linking to its mods. A Collection without an existing id SHALL receive neither an id nor a page.

#### Scenario: Collection with an existing page

- **WHEN** topic 34457 was published as `derelict-start-remnant-start-omega-start-threat-start` and becomes a Collection of four mods
- **THEN** `mods/derelict-start-remnant-start-omega-start-threat-start/` is a page linking to the four mods, and no mod is ever given that id

#### Scenario: Collection with no earlier page

- **WHEN** topic 34161 becomes a Collection and "Hartley's Miscellaneous Mods" never had an id
- **THEN** no page is published for the topic itself

### Requirement: ModRepo-v2.json

The merge SHALL write `ModRepo-v2.json` with one record per mod: permanent id, existing `ModRepo.json` fields and source post refs. It SHALL NOT duplicate facts from `forum-data-bundle-v2.json` or include config values, tokens, local paths or confidence scores. A cancelled merge SHALL write nothing.

#### Scenario: Mod from a Collection

- **WHEN** a mod came from an LLM listing on topic 34161
- **THEN** its record links to forum topic 34161 and names the LLM mod "Useful.Tithes", so a reader finds that mod's facts in the bundle without matching names

#### Scenario: Discord-only mod

- **WHEN** a mod came from an LLM listing on a Discord thread
- **THEN** its record links to that thread and names the LLM mod, so a reader finds its facts in the bundle's Discord answers

#### Scenario: Cancelled merge

- **WHEN** a merge is cancelled part-way
- **THEN** `ModRepo-v2.json` is left as it was

### Requirement: The old files are frozen

After the switch, nothing SHALL write `ModRepo.json` or `forum-data-bundle.json`.

#### Scenario: A full run

- **WHEN** any job runs
- **THEN** neither old file in `outputs/` or the target repo changes

### Requirement: Switch-over comparison

Before switching, a comparison SHALL run the new pipeline on copied real data and compare it with the published site by permanent id. It SHALL report:

- Existing ids missing from the new catalog.
- Ids whose source posts changed.
- Ids becoming Collections.
- Discord threads producing several listings.
- New mods.

The switch SHALL be blocked while an existing mod id is missing, except ids becoming expected Collection pages. Compare after forum and Discord coverage finishes at the current prompt versions, or use a frozen copy, so extraction versions are consistent.

#### Scenario: An id disappears

- **WHEN** an existing id has no mod in the new output and is not a Collection
- **THEN** the comparison names it and the switch does not happen
