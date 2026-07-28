# merge-name-cleaning Specification

## Purpose

Strip version noise from mod names so the merger can find matches it would otherwise miss because a version suffix inflates one name's length well past the length-ratio gate.
## Requirements
### Requirement: Version noise can be stripped from a mod name
The system SHALL provide a function that removes version noise from a mod name. It SHALL remove a leading bracketed tag (whatever it holds — `[0.97a]` and `[WIP]` alike), a trailing version string (starting at an optional opening bracket or paren, an optional `v`/`V`, an optional dot, then `digits.digits`), everything after that version string, and any trailing separators (`-`, `–`, `|`, `:`, `,`, whitespace) left behind. The function SHALL return the original name unchanged when none of these patterns are found or when the result would be empty.

#### Scenario: Name with version and subtitle
- **WHEN** a mod's name is `Hazard Mining Incorporated 0.4.0e "Please be fixed Ed."`
- **THEN** the version-stripped name is `Hazard Mining Incorporated`

#### Scenario: Name with a leading game-version tag
- **WHEN** a mod's name is `[0.97a] Combat Docking Module v0.0.6`
- **THEN** the version-stripped name is `Combat Docking Module`

#### Scenario: Name with a leading tag that is not a game version
- **WHEN** a mod's name is `[WIP] Arcahv Empire`
- **THEN** the version-stripped name is `Arcahv Empire` — any leading bracketed tag is removed, not only a game version

#### Scenario: Name with a v-dot prefix
- **WHEN** a mod's name is `Caymon's Ship pack v.1.2.4- Full stop to life`
- **THEN** the version-stripped name is `Caymon's Ship pack`

#### Scenario: Name with no version
- **WHEN** a mod's name is `Chatter Expansion Project`
- **THEN** the version-stripped name is `Chatter Expansion Project` (unchanged)

#### Scenario: Name containing a number that is not a version
- **WHEN** a mod's name is `Warhammer 40000: Banished Imperium 1.0`
- **THEN** the version-stripped name is `Warhammer 40000: Banished Imperium` (the bare number `40000` is kept because it has no dot)

#### Scenario: Empty result falls back to the original
- **WHEN** a mod's name consists entirely of a version pattern (e.g. `v1.0.0`)
- **THEN** the version-stripped name is the original string `v1.0.0`

#### Scenario: A version in the middle of a title takes the rest with it
- **WHEN** a mod's name is `Substance.Abuse 1.1.c - Consumable Alcohol`
- **THEN** the version-stripped name is `Substance.Abuse` — the stripping starts at the first version-looking number, so part of the real name is lost. This is a known weakness, and it costs nothing because the name as scraped is still compared as well.

### Requirement: Stripping adds a second reading; it never replaces the name
The merger SHALL compare the names as scraped first, and SHALL fall back to the version-stripped reading only when that comparison fails. A pair SHALL be treated as a name match when **either** reading passes both the fuzzy comparison and the length-ratio gate. The version-stripped name SHALL NOT replace the scraped name anywhere: not in the candidate indexes, not in the check that two mods sharing a forum thread have related names, and not in the `ScrapedMod` objects.

#### Scenario: A match the stripped reading finds
- **WHEN** a Discord entry named `Hazard Mining Incorporated 0.4.0e "Please be fixed Ed."` is compared against a Forum entry named `Hazard Mining Incorporated`, by the same author
- **THEN** the names as scraped fail the length-ratio gate, the stripped reading passes it, and the two are grouped together

#### Scenario: A match the scraped names already found is kept
- **WHEN** two entries named `Substance.Abuse - Consumable Alcohol` and `Substance.Abuse 1.1.c - Consumable Alcohol` are compared, and stripping would shorten the second to `Substance.Abuse`
- **THEN** the two are still grouped together, because the names as scraped are compared first and match

#### Scenario: The shared-forum-thread guard is unaffected
- **WHEN** two entries share a forum thread and are checked for whether their names look related
- **THEN** that check reads the names as scraped, so no merge that works on a shared thread today is lost

### Requirement: The stripped name is used only for matching
The version-stripped name SHALL be used only inside the merger's comparison steps. The `ScrapedMod` objects, the group member lists in the merge debug records, and the final `ModRepo.json` output SHALL keep the original name. No config key controls this step.

#### Scenario: Original name preserved in output
- **WHEN** a Discord mod named `Nexerelin 0.12.1d "Fires on the Frontier"` merges with a Forum entry named `Nexerelin`
- **THEN** the merged `ScrapedMod` in `ModRepo.json` carries whichever name wins the existing source-priority rules, not the stripped name

#### Scenario: Debug data keeps original names
- **WHEN** merge debug collection is on
- **THEN** each group's member list shows the original names as they came from the source, not the stripped versions

### Requirement: The same-source dedup safety check uses the same rule
The safety check that refuses to discard an older game version when two names are too different SHALL also accept **either** reading — the names as scraped or the version-stripped names — so that it agrees with the grouping step about which names count as similar.

#### Scenario: Dedup is not blocked for a pair this change newly grouped
- **WHEN** two Discord entries named `Domain Historical Society-0.97 Achi edition (original edition attached below)` and `Domain Historical Society-0.98` are grouped together, and only their stripped names are close in length
- **THEN** the safety check passes on the stripped reading, and the older game version is dropped as normal instead of being kept with a "safety blocked" warning

### Requirement: The stripped reading is visible in merge debug data
Each match entry in the merge debug output SHALL include the version-stripped name used for each side, and — when the second comparison ran — the score and length ratio it produced. The scores and ratio for the names as scraped SHALL keep their existing meaning and field names, so saved merges from before this change stay readable. The reason recorded for the match SHALL say which reading matched.

#### Scenario: Stripped name in a match entry
- **WHEN** two mods are compared and the debug collector is on
- **THEN** the match entry includes the stripped name for both sides, next to the name score and length ratio

#### Scenario: Stripped name equals original
- **WHEN** a mod's name has no version noise (e.g. `Nexerelin`)
- **THEN** the stripped name in the match entry is the same as the original name

#### Scenario: The second comparison did not run
- **WHEN** two mods match on their names as scraped, so the stripped reading is never compared
- **THEN** the stripped score and stripped length ratio are absent from the match entry, and the reason names the scraped reading
