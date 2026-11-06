## 1. Server

- [x] 1.1 `chooseFacts` returns the source of each field; the site build saves `fact-sources.json` (never published)
- [x] 1.2 `GET /api/mods`: list with search, filters, sort, paging
- [x] 1.3 `GET /api/mods/<id>`: mod, Collection, moved, taken down; source posts with how they joined; fact sources; old ids; unmatched requirements
- [x] 1.4 `GET /api/mods/<id>/history`: runs with changes to the mod, found by permanent id, using `compare_rows.dart`
- [x] 1.5 Dart tests

## 2. Pages

- [x] 2.1 `web2/views/mods.js`: the list
- [x] 2.2 `web2/views/mod.js`: header, what Starmodder shows, fact sources, source posts, history, raw JSON
- [x] 2.3 Per-post jobs for all the mod's posts, Take down, same person, match a requirement (mod picker shared with Dependency names)
- [x] 2.4 Collection page and moved ids
- [x] 2.5 Manager off and phone screen widths

## 3. Checks and docs

- [x] 3.1 Check in the browser on real data (reading, pending changes, cancelled confirms only)
- [x] 3.2 Update `CLAUDE.md`
- [x] 3.3 Run `dart test`
