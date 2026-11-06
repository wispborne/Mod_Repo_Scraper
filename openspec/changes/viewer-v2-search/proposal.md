## Why

The new viewer's search box still sends most text to the old viewer's Topics list. `docs/viewer-redesign-requirements.md` (**Search**) asks for one box at the top of every page that finds mods (by name, nickname, author or permanent id), forum topics (by id or title), Discord threads (by id or name) and runs (by id), with results grouped by kind, and a pasted forum or Discord address going straight to that post's page. Every page it can lead to now exists in the new viewer.

## What Changes

- **`GET /api/search?q=`**, read-only: up to a few results of each kind (mods, forum topics, Discord threads, runs), best matches first, with a total for each kind.
- **The search box** shows results below it as you type, grouped by kind. Each result links to its page. Arrow keys move through the results. Enter opens the selected result, or the first result if none is selected. Each group can open the full list with the search filled in (Mods, Source posts, Run history). "/" still puts the cursor in the box; Escape closes the results.
- A forum topic address or id, or a Discord address or long id, still opens that post's page at once on Enter. No search opens the old viewer.

## Capabilities

### New Capabilities
- `viewer-v2-search`: the new viewer's search box.

### Modified Capabilities
- `viewer-server`: the search route.

## Impact

- `lib/viewer/api.dart`, a new `lib/viewer/search_views.dart`; it reuses the matching the Mods and Source posts lists already do.
- `web2/frame.js` (the box), a new `web2/search_box.js`, `web2/routes.js` (`searchRoute`), styles; Node tests for pure helpers; Dart tests for the route.
