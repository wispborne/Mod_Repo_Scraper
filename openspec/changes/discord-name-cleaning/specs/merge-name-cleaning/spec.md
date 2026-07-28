## ADDED Requirements

### Requirement: Version noise is stripped from mod names before comparison
The merger SHALL apply a version-stripping function to each mod's name before comparing it against other names. The function SHALL remove a leading bracketed game-version tag (e.g. `[0.97a]`), a trailing version string (starting at an optional opening bracket or paren, optional `v`/`V`, optional dot, then `digits.digits`), everything after the version string, and any trailing separators (`-`, `–`, `|`, `:`, `,`, whitespace) left behind. The function SHALL return the original name unchanged when none of these patterns are found or when the result would be empty.

#### Scenario: Discord name with version and subtitle
- **WHEN** a mod's name is `Hazard Mining Incorporated 0.4.0e "Please be fixed Ed."`
- **THEN** the version-stripped name used for comparison is `Hazard Mining Incorporated`

#### Scenario: Discord name with leading game-version tag
- **WHEN** a mod's name is `[0.97a] Combat Docking Module v0.0.6`
- **THEN** the version-stripped name used for comparison is `Combat Docking Module`

#### Scenario: Name with v-dot prefix
- **WHEN** a mod's name is `Caymon's Ship pack v.1.2.4- Full stop to life`
- **THEN** the version-stripped name used for comparison is `Caymon's Ship pack`

#### Scenario: Name with no version
- **WHEN** a mod's name is `Chatter Expansion Project`
- **THEN** the version-stripped name is `Chatter Expansion Project` (unchanged)

#### Scenario: Name containing a number that is not a version
- **WHEN** a mod's name is `Warhammer 40000: Banished Imperium 1.0`
- **THEN** the version-stripped name is `Warhammer 40000: Banished Imperium` (the bare number `40000` is kept because it has no dot)

#### Scenario: Empty result falls back to original
- **WHEN** a mod's name consists entirely of a version pattern (e.g. `v1.0.0`)
- **THEN** the version-stripped name is the original string `v1.0.0`

### Requirement: The stripped name is used only for matching
The version-stripped name SHALL be used only inside the merger's grouping comparison. The `ScrapedMod` objects, the merge debug records, and the final `ModRepo.json` output SHALL keep the original name. No config key controls this step.

#### Scenario: Original name preserved in output
- **WHEN** a Discord mod named `Nexerelin 0.12.1d "Fires on the Frontier"` merges with a Forum entry named `Nexerelin`
- **THEN** the merged `ScrapedMod` in `ModRepo.json` carries whichever name wins the existing source-priority rules, not the stripped name

#### Scenario: Debug data keeps original names
- **WHEN** merge debug collection is on
- **THEN** each group's member list shows the original names as they came from the source, not the stripped versions

### Requirement: The stripped name is visible in merge debug data
Each match entry in the merge debug output SHALL include the version-stripped name that was used for comparison, so a person reviewing a merge can see what the regex produced. The field SHALL appear alongside the existing match scores and length ratio.

#### Scenario: Stripped name in a match entry
- **WHEN** two mods are compared and the debug collector is on
- **THEN** the match entry includes the stripped name for both sides, next to the name score and length ratio

#### Scenario: Stripped name equals original
- **WHEN** a mod's name has no version noise (e.g. `Nexerelin`)
- **THEN** the stripped name in the match entry is the same as the original name
