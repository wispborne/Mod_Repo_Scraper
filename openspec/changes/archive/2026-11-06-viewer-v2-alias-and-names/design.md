## Context

The old pages (`web/views/author_aliases.js`, `web/views/requirement_names.js`) edit a whole list in the page and send it as one job (`setAuthorAliases`, `setRequirementNames`). The new viewer saves through Pending changes, one correction at a time, with `saveCorrections` (`sameAuthor`, `differentAuthors`, `removeAuthorName`, `publishAuthorAs`, `matchRequirement`). `web2/views/takedowns.js` is the model for a correction page: a central list, Pending changes first among the side panels, every action adding a pending item through `addPending`, rows marked when their change is pending.

## Goals / Non-Goals

**Goals:** both pages, with everything the old pages show, saving through Pending changes.

**Non-Goals:** buttons on mod pages ("These are the same person" next to an author, "Match this to a mod" next to a requirement) — the mod page is not built yet; any server change.

## Decisions

### Show what the files say, plus what is pending
Each page shows the list returned by the server. It marks rows with a pending change ("Same person pending", "Match pending: <mod>"). It does not predict how pending changes will affect the list. Only the save job runs the rules, so a predicted list could disagree with the saved result.

### Pending item labels
One line in plain words, the same shapes `corrections_service.dart` uses in its messages:
- `"A" and "B" are the same person`
- `"A" and "B" are different people`
- `Take "A" off its person`
- `Publish the person as "A"`
- `"Written" means "<mod name>"` / `"Written" means none of our mods`
- `Forget the saved answer for "Written"`

### Mod picker
The Dependency names page uses the same mod list as the old page: the report's list of every published mod id and name. A search box like the Takedowns mod search finds mods by name or id as you type.

### Save all while jobs are off
`pending_view.js` reads the manager status. While the manager is off, "Save all" is disabled and the list says "Jobs are off on this server, so changes can't be saved." Items can still be removed or discarded.

## Risks / Trade-offs

- [A suggestion that is already pending as "same person" still shows in the suggestions until the save] → It is marked pending, and its buttons are replaced with Undo.
