## 1. Author aliases page

- [x] 1.1 `web2/views/author_aliases.js`: people with names and mod counts, suggestions, "different people" pairs
- [x] 1.2 Actions as pending changes (same person, different people, take a name off, publish as, join two names by hand), rows marked pending with Undo
- [x] 1.3 Read-only when the manager is off; layout at phone width

## 2. Dependency names page

- [x] 2.1 `web2/views/dependency_names.js`: spellings with mod counts, matched mods, match sources, and unused saved answers
- [x] 2.2 Actions as pending changes (match with a mod search box, none of our mods, forget), rows marked pending with Undo
- [x] 2.3 Read-only when the manager is off; layout at phone width

## 3. Shared

- [x] 3.1 `pending_view.js`: "Save all" disabled with a reason while the manager is off
- [x] 3.2 Routes in `web2/app.js`

## 4. Checks and docs

- [x] 4.1 Check both pages in the browser (adding, Undo, pending marks, manager off, phone width), adding pending changes only
- [x] 4.2 Update `CLAUDE.md`
- [x] 4.3 Run `dart test`
