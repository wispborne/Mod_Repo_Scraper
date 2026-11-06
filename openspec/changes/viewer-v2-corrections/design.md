## Context

`JobRouter._runCorrection` runs `takeDown`, `restoreTakedown` and `setAuthorAliases` as: change the list, merge `ModRepo.json` (`oldRepoOnly`), rebuild the bundle (which builds the catalog and the website), publish when asked. `setRequirementNames` saves `requirement-names.json` and rebuilds only the website. `TakedownService` refuses an unknown id, a mod or person already on the list, and restoring an entry that is not on the list. `AuthorAliasService` saves the whole alias list after `checkAliasRows` (every person needs two names; no name for two people). The old Takedowns page (`web/views/takedowns.js`) reads `GET /api/takedowns`, `/takedowns/mods`, `/takedowns/authors` and `/takedowns/preview`.

## Goals / Non-Goals

**Goals:** one list, one job, one rebuild; the Takedowns page.

**Non-Goals:** the Author aliases and Dependency names pages (next change; the job already accepts their corrections); the buttons on mod and source post pages (those pages are not built yet); removing the old jobs.

## Decisions

### The `Correction` model
A `dart_mappable` class on `JobRequest.corrections`, one of:

| `kind` | fields | does |
|---|---|---|
| `takeDownMod` | `modId` | adds a mod entry (posts from the current catalog, as `TakedownService` does) |
| `takeDownAuthor` | `names` | adds an author entry |
| `restore` | `entry` | removes a takedown entry (`modId` or `author:<first name>`) and records it in `takedowns-restored.json` |
| `sameAuthor` | `names` (two) | joins the two names' people into one; the first name's person keeps its published name, or a new person is made with the first name first |
| `differentAuthors` | `names` (two) | adds the pair to "different people" |
| `removeAuthorName` | `names` (one) | takes the name off its person; a person left with one name is removed |
| `publishAuthorAs` | `names` (one) | moves the name to the front of the person's list, making it the published name |
| `matchRequirement` | `written`, `modId` (null for none of our mods), `forget` | the same as one `RequirementChange` |

Operations rather than whole lists, so changes from different pages combine, and the pending list can say what each one does in one line.

### All or nothing
`CorrectionsService` reads the three files, applies every correction in order to in-memory copies, and runs the existing checks on the results (`TakedownService`'s rules, `checkAliasRows`, mod ids known to the catalog). If any correction is refused, the job fails before writing anything. One message identifies each refused correction by its position and description. Then it writes only the files that changed, each through a temporary file. A file that cannot be read fails the job before anything is written, as the old jobs do.

### One rebuild
`JobRouter` runs `saveCorrections` like `_runCorrection`: the service, then the merge (`oldRepoOnly`), then `rebuildBundle`, then publish when `publishAfter`. A job with only dependency name corrections still runs the merge, so every save takes the same path; the merge reads saved files and costs seconds.

### The pending list in the browser
`web2/pending.js`, no DOM: `pendingItems()`, `addPending(item)`, `removePending(id)`, `clearPending()`, `onPendingChange(fn)`. An item is `{ id, kind, label, correction }`; `label` is the one line the list shows. The list lives in `sessionStorage['viewerPendingChanges']` (the key the toolbar already reads), so it survives reloads in the tab and is gone when the tab closes. Adding a correction equal to one already pending does nothing. Restoring a pending takedown cancels both changes. Changes are announced in the tab with a `pending-changed` event and across tabs by the `storage` event.

### Where the list is shown
The toolbar's "N pending" becomes a button that opens a panel under it: each item with a remove button, "Publish afterwards", "Save all" and "Discard all". The Control page and the Takedowns page also show a Pending changes side panel with the same contents while the list is not empty. Save opens a dialog listing every item. After confirmation, it sends one `saveCorrections` job and clears the list once the server accepts it. `beforeunload` asks while the list is not empty.

### The Takedowns page
A port of the old page into the new frame, reading the same four routes. Entries are rows in the central panel: what was taken down, when, what it left out of the last build, and a warning when it left out nothing or its mod came back under a new id (the same rule as `takedownsReturned` in `/api/attention`). Restore and the two take-down forms add pending changes; the preview a form shows before adding is the old page's. The page shows Pending changes as a side panel.

## Risks / Trade-offs

- [A pending item can go stale: the mod is renamed or already taken down by the time it is saved] → The job checks everything at save time and refuses with the server's message; nothing is written.
- [Two tabs with different pending lists] → `sessionStorage` is per tab; each tab saves its own list. The job checks each against the files at save time.
