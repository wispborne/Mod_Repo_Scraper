## Why

The new viewer has the Pending changes list and the `saveCorrections` job (`viewer-v2-corrections`), but only Takedowns adds to it. `docs/viewer-redesign-requirements.md` (**Correct → The correction pages**) also asks for Author aliases and Dependency names pages that work the same way. The job already accepts their corrections.

## What Changes

- **Author aliases page** (`#/author-aliases`): each person with the names they go by and how many mods use each name, the suggested pairs (forum and Discord name different authors for the same mod), and the pairs marked "different people". Actions add pending changes: "These are the same person" on a suggestion, "Different people", take a name off a person, publish a person under another of their names, and join any two names by hand.
- **Dependency names page** (`#/dependency-names`): every spelling seen in the last build, how many mods use it, what it matched and how (hand entry, rules, LLM, not matched), and saved answers no build used. Actions add pending changes: match a spelling to a mod with a mod picker, mark it as none of our mods, or forget the saved answer so the rules and the LLM decide again.
- Both pages show the Pending changes side panel. They are read-only when the manager is off. They mark rows whose change is already pending.
- **Pending changes while jobs are off:** "Save all" is disabled to prevent a failed save on the server. One line explains why.

## Capabilities

### New Capabilities
- `viewer-v2-alias-and-names`: the new viewer's Author aliases and Dependency names pages.

### Modified Capabilities
None. The server is not changed.

## Impact

- New `web2/views/author_aliases.js`, `web2/views/dependency_names.js`, and their styles.
- `web2/app.js` (routes), `web2/pending_view.js` (Save all while jobs are off).
- No server change: the pages read `GET /api/author-aliases`, `GET /api/requirement-names` and the catalog list the old pages read.
