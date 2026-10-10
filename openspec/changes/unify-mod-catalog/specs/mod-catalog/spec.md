## ADDED Requirements

### Requirement: Every source post gives zero or more listings
The system SHALL turn each source post into zero or more listings before any merging happens. A listing SHALL record which source post it came from and whether fixed rules or the LLM found it. A forum topic SHALL give its listings from the QB store. A Discord thread SHALL give exactly one listing, as it does today. A Nexus page SHALL give exactly one listing.

#### Scenario: Forum topic with no LLM answer
- **WHEN** a forum topic in the QB store has no LLM answer
- **THEN** it gives exactly one listing, found by rules

#### Scenario: Listing knows its source post
- **WHEN** any listing is made
- **THEN** it carries the kind and id of its source post (forum topic id, Discord thread id, or Nexus id) and, for an LLM listing, the name the LLM gave that mod

### Requirement: Which forum topics give listings
Every forum topic that `keepThreadInBundle` keeps SHALL give listings. A topic SHALL NOT be skipped because its title has no bracketed game version, because it is not in the mod index, or because it is old.

#### Scenario: Topic with no bracketed game version
- **WHEN** a kept topic's title has no bracketed game version (for example topic 35651)
- **THEN** it gives listings like any other topic

#### Scenario: Topic the bundle would drop
- **WHEN** `keepThreadInBundle` drops a topic
- **THEN** it gives no listings

### Requirement: The rules listing for a forum topic
A forum topic SHALL give exactly one rules listing. When the topic is in the mod index, the listing SHALL take its name, author, game version and category from the topic's first mod index line, and SHALL keep the names on the topic's other index lines as other names. When the topic is not in the mod index, the listing SHALL take its name from the topic title with the release parts stripped. Its source SHALL be `Index` when the topic is in the mod index and `ModdingSubforum` otherwise.

#### Scenario: Topic with several index lines
- **WHEN** topic 21968 has index lines "Midline Expansion", "Pirate Collection" and "Yunru Mods"
- **THEN** the rules give one listing named from the first line, with the other two names kept as other names

#### Scenario: Topic outside the mod index
- **WHEN** a kept topic is not in the mod index
- **THEN** its rules listing is named from the topic title with the bracketed game version, the mod version and any date removed

### Requirement: How a topic's rules listing and LLM listings combine
For each forum topic, let R be its rules listing and let M be the LLM's grounded `main` mods on that topic. A grounded mod is one whose name appears in the topic's opening run and that has at least one download tied to it. The system SHALL combine them before the merge as follows:
- When M is empty, R SHALL go into the merge alone.
- When M has one mod, R and that mod SHALL be one listing, whatever either is called. The LLM's facts SHALL apply to it.
- When M has two or more mods, each SHALL be its own listing. R SHALL join the one whose name matches R's name or any of R's other names under `modNamesMatch`. When none match, the topic SHALL be a Collection and R SHALL be dropped.

#### Scenario: One main mod with a different name
- **WHEN** topic 9035's rules listing is "Red" and the LLM's only main mod is "Red - the Oculian Armada"
- **THEN** they are one listing carrying the LLM's facts

#### Scenario: Several main mods, one matches
- **WHEN** a topic's rules listing is "Useful.Tithes 1.0.a" and the LLM names four main mods including "Useful.Tithes"
- **THEN** the rules listing joins "Useful.Tithes", and the other three are listings of their own

#### Scenario: Several main mods, none match
- **WHEN** topic 34161's rules listing is "Hartley's Miscellaneous Mods" and the LLM names four main mods, none with that name
- **THEN** the topic is a Collection, the rules listing is dropped, and the four mods are listings

#### Scenario: Ungrounded LLM mod
- **WHEN** the LLM names a main mod whose name is not in the opening run, or which has no download tied to it
- **THEN** it does not count towards M and gives no listing

### Requirement: Add-ons and variants are never mods
An LLM mod whose role is `addon` or `variant` SHALL NOT give a listing of its own. It SHALL be attached to the listing it belongs to: for an add-on, the main mod its `requires` names; for a variant, the main mod it is a build of. A mod whose role is `separate` SHALL give nothing.

#### Scenario: Library with add-ons
- **WHEN** a topic's LLM answer is one main library and five add-ons that each require it
- **THEN** one listing is made, carrying the five add-ons

### Requirement: The LLM cannot remove what the rules found
With the LLM off, the rules SHALL still give a full catalog. The LLM SHALL be able to add listings and to make a topic a Collection under the rule above. It SHALL NOT remove, rename or merge away any other rules listing.

#### Scenario: LLM off
- **WHEN** no topic has an LLM answer
- **THEN** every kept topic gives exactly its one rules listing, and the merge runs as normal

#### Scenario: LLM answer with no main mods
- **WHEN** the LLM's answer for a topic has no grounded main mod
- **THEN** the topic's rules listing goes into the merge unchanged

### Requirement: One merge over every listing
All listings from every source SHALL be merged once, by the existing `ModMerger` rules, into mods. No later step SHALL match mods against forum topics by name to add, remove or split mods.

#### Scenario: Collection mod also announced on Discord
- **WHEN** one of Hartley's four mods also has a Discord thread
- **THEN** the merge joins that Discord listing to that one mod, not to the whole topic

#### Scenario: Site build does no matching
- **WHEN** the site is built
- **THEN** it reads each mod's source post links and looks facts up by them, and never decides by name which LLM mod belongs to which mod

### Requirement: Permanent ids are found by source post
The merge SHALL assign each mod its permanent id. It SHALL look the id up by the mod's source posts first (forum topic id with the LLM mod name where there is one, Discord thread id, Nexus id), and SHALL fall back to the name only for a mod none of whose source posts has an id. A mod's id SHALL NOT change because its name changed. An id once given SHALL never be given to a different mod. If `mod-ids.json` exists but cannot be read, the run SHALL fail and write nothing.

#### Scenario: Title gains a new version
- **WHEN** a mod's forum title changes from "Foo 1.2" to "Foo 1.3"
- **THEN** the mod keeps the same id

#### Scenario: Merge picks a different name
- **WHEN** a mod that was named from its Discord thread is now named from its mod index line
- **THEN** it keeps the id its source posts already had

#### Scenario: Brand-new mod
- **WHEN** a mod has no source post with an id
- **THEN** it gets a new id worked out from its name, with a number on the end if that id is taken

### Requirement: Existing ids are linked to their source posts once
A one-time step SHALL record, for every id in `mod-ids.json`, which source posts that id's mod currently covers, using the current published data. It SHALL be safe to run again.

#### Scenario: Run twice
- **WHEN** the step runs a second time on the same data
- **THEN** `mod-ids.json` comes out the same

### Requirement: A Collection keeps an id it already had
When a Collection's rules listing had a permanent id, that id SHALL stay reserved, and the site SHALL publish a page at that id's address that names the topic and links to each mod on it. A Collection with no earlier id SHALL get no id and no page.

#### Scenario: Collection with an existing page
- **WHEN** `yunru-mods` had a page and its topic becomes a Collection
- **THEN** `mods/yunru-mods/` is a page listing the mods on that topic, and no mod is ever given the id `yunru-mods`

### Requirement: ModRepo-v2.json
The merge SHALL write `ModRepo-v2.json`: one record per mod, holding its permanent id, the fields `ModRepo.json` holds today, and the list of its source post links. It SHALL hold no copy of the forum facts that `forum-data-bundle-v2.json` holds. It SHALL hold no config value, token, local path or confidence score. A cancelled merge SHALL write nothing.

#### Scenario: Mod from a Collection
- **WHEN** a mod came from an LLM listing on topic 34161
- **THEN** its record links to forum topic 34161 and names the LLM mod "Useful.Tithes", so a reader finds that mod's facts in the bundle without matching names

#### Scenario: Cancelled merge
- **WHEN** a merge is cancelled part-way
- **THEN** `ModRepo-v2.json` is left as it was

### Requirement: The old files are frozen
Nothing SHALL write `ModRepo.json` or `forum-data-bundle.json` after this change.

#### Scenario: A full run
- **WHEN** any job runs
- **THEN** neither old file in `outputs/` or the target repo changes

### Requirement: Switch-over comparison
A one-time comparison SHALL run the new pipeline on a copy of the real data and compare it with the current published site by permanent id. It SHALL list every existing id that disappears, every id whose source posts change, every id that becomes a Collection, and every new mod. The switch SHALL happen only when no existing id disappears other than the expected Collections. It SHALL run after the LLM has read every topic at the current prompt version, or on a frozen copy, so all topics are compared on answers of the same version.

#### Scenario: An id disappears
- **WHEN** an existing id has no mod in the new output and is not a Collection
- **THEN** the comparison names it and the switch does not happen
