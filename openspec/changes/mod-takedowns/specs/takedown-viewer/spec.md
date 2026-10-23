## ADDED Requirements

### Requirement: A corrections group in the sidebar
The viewer's sidebar SHALL have a new group for manual corrections, holding a Takedowns page at `#/takedowns`. The page SHALL list every entry in `takedowns.json`. Mod entries SHALL show their id, name, blocked posts and date. Author entries SHALL show their names and date. Each entry SHALL show which mods it left out in the last build, read from `takedown-matches.json`.

#### Scenario: The Tidal fork on the list
- **WHEN** the list has the entry for `diable-avionics-tidal-fork`
- **THEN** the Takedowns page shows its id, the name "Diable Avionics (TIDAL FORK)", the post `discord:1507163509224509510` and the day it was added

### Requirement: Mod pages have a Take down button
The Mod Catalog mod page and the thread page SHALL each have a "Take down" button when the manager is on. The Takedowns page SHALL have a form for an author entry, taking one or more names. With the manager off, these buttons and the form SHALL NOT be shown. The Takedowns page SHALL still list the entries.

#### Scenario: Manager off
- **WHEN** the manager is off
- **THEN** the Takedowns page lists the entries with no buttons and no form, and the mod and thread pages have no "Take down" button

### Requirement: The confirmation dialog shows what would be removed
Before a takedown is sent, the viewer SHALL show what it would leave out, from the current `mod-catalog.json`. For a mod: its id and name, each post it would block and whether the whole post or only this mod's listing is blocked, the Collections that would lose it, and the old ids that lead to it. For an author: every mod that would be left out, and the credited name that matched for each mod. The dialog SHALL have a "Publish when done" choice. The dialog SHALL say that the takedown list is public.

#### Scenario: An author takedown matches several credited names
- **WHEN** an author takedown for "tidal5590" is previewed
- **THEN** the dialog lists "Diable Avionics (TIDAL FORK)" and "lpc editor" matched to "tidal5590", "Diable Avionics: Original Flavor" matched to "Tidal", and "Project Solar Tail" matched to "TIDAL"

#### Scenario: A mod takedown on a shared thread
- **WHEN** a takedown is previewed for one of four mods from forum topic 34161
- **THEN** the dialog says only that mod's listing on topic 34161 is blocked and the topic itself stays

### Requirement: Restore from the Takedowns page
Each entry on the Takedowns page SHALL have a Restore button when the manager is on. Restoring SHALL ask for confirmation, offer "Publish when done", and send a `restoreTakedown` job.

#### Scenario: Restoring a mod
- **WHEN** Restore is confirmed on the entry for `diable-avionics-tidal-fork`
- **THEN** a `restoreTakedown` job is sent for that entry

### Requirement: The takedown API only reads
The viewer SHALL serve `GET /api/takedowns` with the list and the last build's matches. It SHALL serve `GET /api/takedowns/preview` with `mod=<id>` or `author=<name>`. These parameters MAY be repeated. These routes SHALL NOT write anything. Every change to the list SHALL go through a manager job.

#### Scenario: Preview writes nothing
- **WHEN** `GET /api/takedowns/preview?author=Tidal` is called
- **THEN** the response lists the mods that would be removed, and `takedowns.json` is unchanged
