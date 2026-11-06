## Why

The three kinds of correction (takedowns, author aliases, dependency names) are separate jobs today, and each one merges and rebuilds everything. Correcting three things means three full rebuilds, one after another. `docs/viewer-redesign-requirements.md` (**Correct → Saving corrections**) asks for one shared list of pending changes, saved by one button that applies every change, rebuilds once, and publishes if asked. This change builds that list, the job behind it, and the first correction page, Takedowns. Author aliases and Dependency names follow in the next change.

## What Changes

- **Pending changes** in the new viewer: a list kept in the browser for the session (`sessionStorage`), never on the server. Any page can add to it. The toolbar's "N pending" count opens it; each item can be removed; "Save all" asks first, then sends one job; a "Publish afterwards" checkbox enables publishing when the job is done. Closing or reloading the tab with pending changes asks first. A refusal shows the server's own message, and nothing is written.
- **A new job, `saveCorrections`**, carrying a list of corrections: take down a mod or a person, restore an entry, join two author names as one person, mark two names as different people, remove a name from a person, choose the name a person is published under, and match a dependency name to a mod (or to none, or forget the saved answer). Every correction is checked first; if any is refused, nothing is written and the message names each one. Then the three files are saved, `ModRepo.json` is merged again, the bundle, catalog and website are rebuilt once, and the outputs are published when asked. No network, no LLM.
- **The Takedowns page** in the new viewer, with what the old page shows: every entry, what it left out of the last build, the warnings (left out nothing; the mod came back under a new id), the forms to take down a mod or a person with a preview, and Restore. Each action adds a pending change instead of starting a job at once.
- The Control page shows Pending changes as its first side panel while the list is not empty.
- The old jobs (`takeDown`, `restoreTakedown`, `setAuthorAliases`, `setRequirementNames`) stay for the old viewer.

## Capabilities

### New Capabilities
- `viewer-v2-corrections`: the pending changes list, saving it, and the Takedowns page of the new viewer.

### Modified Capabilities
- `scraper-jobs`: the `saveCorrections` job.

## Impact

- `lib/manager/job.dart` (new kind, `Correction` model, regenerated mappers), a new `lib/manager/corrections_service.dart`, `lib/manager/modrepo_service.dart` (`JobRouter`), `lib/manager/takedown_service.dart`, `author_alias_service.dart` and the requirement name store (shared checks).
- New `web2/pending.js`, `web2/views/takedowns.js`; `web2/frame.js`, `web2/jobs.js`, `web2/views/control.js`, `web2/app.js`, `web2/style.css`.
- Tests for the job (all or nothing, each kind, one rebuild) and for the pending list.
