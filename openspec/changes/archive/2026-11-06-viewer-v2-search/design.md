## Context

`GET /api/mods` (`lib/viewer/mod_views.dart`) already searches mods by name, display name, nicknames, LLM names, authors and id; `GET /api/posts` (`lib/viewer/post_views.dart`) searches topics and threads; `GET /api/manager/runs` lists runs (only while the manager is on). The toolbar's search form is drawn by `mountToolbar` in `web2/frame.js`, and `searchRoute` in `web2/routes.js` already turns a forum address, a topic id, a Discord address or a long id into a post page address.

## Goals / Non-Goals

**Goals:** one route, one box, results grouped by kind, nothing sent to the old viewer.

**Non-Goals:** a separate search results page (each group opens its own full list instead); fuzzy spelling matches beyond what the lists already do.

## Decisions

### `GET /api/search?q=&limit=`
```
{ q,
  mods:    { total, items: [ { id, name, authors, detail? } ] },
  topics:  { total, items: [ { id, title, author, detail? } ] },
  discord: { total, items: [ { id, title, author, detail? } ] },
  runs:    { total, items: [ { id, kind, state, startedAt } ] } }
```
`limit` per kind defaults to 5. Exact id or name matches come first. Next come names that start with the text, then names that contain it, then matches in other fields (authors, nicknames, titles). `detail` says why a row matched when it was not the name (for example "author: Histidine" or "also called IndEvo"). Mods and posts reuse the lists' own matching so the box and the lists agree. Runs come from the run history when the manager is on, matched by id (and kind name); with the manager off the group is empty. The route is read-only. Searches with fewer than two characters return empty groups.

### The box
`web2/search_box.js` owns the results panel: it requests results 150 ms after typing stops, ignores responses for earlier searches, and shows up to four groups with a heading and a "See all N" link (`#/mods?q=`, `#/posts?q=&kind=topic`, `#/posts?q=&kind=discord`, `#/runs`). Arrow keys move the highlight through the rows. Enter opens the highlighted row. If none is highlighted, Enter opens the page returned by `searchRoute` for an address or id, or the first row otherwise. Escape and a click outside close the panel. On a phone the panel spans the screen width under the toolbar.

### `searchRoute`
Returns a new-viewer address for an address or id, and null otherwise; the old-viewer fallback is removed.

## Risks / Trade-offs

- [A search on every pause in typing costs a request] → The route works on cached lists and answers in milliseconds; the box waits 150 ms and drops stale answers.
