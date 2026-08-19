## ADDED Requirements

### Requirement: Releases are worked out by comparing saved bundles
The scraper SHALL work out which mods put out a new version by walking the saved bundles
in order and watching each mod's version. A release SHALL be recorded only when a mod's
version moves forward. Replies, view counts, when a topic was last scraped, and anything
else that moves whether or not the mod did SHALL NOT produce a release.

#### Scenario: Somebody replies to a thread
- **WHEN** a thread's last post date changes but its mod version does not
- **THEN** no release is recorded

#### Scenario: A mod puts out a new version
- **WHEN** a mod's version moves from 0.12.1e to 0.12.2 and settles there
- **THEN** one release is recorded, naming the old and new version and the day it was seen

### Requirement: Version strings are cleaned before they are compared
Before two versions are compared they SHALL be cleaned: lower-cased, with a leading
`v`, `v.`, `ver`, `version`, `update` or `rev` removed, and spaces, dashes and
underscores treated as dots. A cleaned version that does not start with a number, or
that holds more than one version at once, SHALL be treated as unreadable and ignored.
Two versions that clean to the same thing SHALL NOT count as a release.

#### Scenario: The same version spelled differently
- **WHEN** a mod's version is read as "0.95" and later as "v.0.95"
- **THEN** no release is recorded

#### Scenario: An unreadable version
- **WHEN** a mod's version is read as "v.60, .54a"
- **THEN** it is ignored, and the mod's last known version is left as it was

### Requirement: The game's version is never taken for the mod's version
A version that matches the thread's game version, or the version in square brackets at
the front of the thread title, SHALL be thrown out.

#### Scenario: The extractor returns the game version
- **WHEN** a thread titled "[0.98a] Some Mod" reports its mod version as "0.98a"
- **THEN** that reading is thrown out and no release is recorded

### Requirement: Versions are compared by their parts, not as text
Versions SHALL be compared part by part, numbers as numbers. A trailing letter SHALL
count as newer than the same version without it, so 3.5.2g is newer than 3.5.2. A
trailing `rc`, `alpha`, `beta`, `pre` or `dev` SHALL count as older, so 1.0-rc1 is older
than 1.0.

#### Scenario: Leaving beta
- **WHEN** a mod's version moves from "0.99a BETA" to "0.99a"
- **THEN** a release is recorded

#### Scenario: A letter is added
- **WHEN** a mod's version moves from 3.5.2 to 3.5.2g
- **THEN** a release is recorded

### Requirement: A version must settle before it is believed
A version SHALL only be believed once it has been read the same way in two scrapes
running. A version read once and then read differently SHALL never produce a release.

#### Scenario: A one-off misreading
- **WHEN** a mod reads as 1.4.0 in one scrape and back to 1.3.1 in the next
- **THEN** no release is recorded

### Requirement: A mod's known version never moves backwards
Once a version is believed for a mod, a later reading that is older SHALL be ignored and
the believed version SHALL be left alone. This SHALL hold even when the older reading
settles across several scrapes.

#### Scenario: The extractor changes its mind twice
- **WHEN** a mod settles at 1.3.3, later settles back at 1.3.2, and later still settles at 1.3.3 again
- **THEN** exactly one release is recorded, for the first move to 1.3.3

### Requirement: The thread title overrules the extractor
When the thread title carries a version of its own, a new version that disagrees with it
SHALL be ignored. When the title carries no version, it SHALL have no say.

#### Scenario: The title still names the old version
- **WHEN** a thread titled "BattleFarer Forever [v 0.3]" reports its version as 0.30
- **THEN** no release is recorded

#### Scenario: No version in the title
- **WHEN** a thread titled "Planet Search" moves from 1.3.0 to 1.3.2
- **THEN** a release is recorded

### Requirement: The first version seen is not a release
The first time a mod's version is believed, no release SHALL be recorded. Only later
moves count.

#### Scenario: Backfilling from saved bundles
- **WHEN** the detector is run for the first time over every saved bundle
- **THEN** it does not report a release for every mod at once

### Requirement: The feed says what changed and when
`updates.json` SHALL hold the releases newest first, each with the mod's permanent id
and name, the day it was seen, the old and new version, the game version, and — where
the post gave one — that version's changelog notes copied word for word.

#### Scenario: A release with notes
- **WHEN** a mod releases a version the post has changelog notes for
- **THEN** the feed entry carries those notes as the author wrote them

#### Scenario: A release with no notes
- **WHEN** a mod releases a version the post gives no notes for
- **THEN** the feed entry is still recorded, with no notes
