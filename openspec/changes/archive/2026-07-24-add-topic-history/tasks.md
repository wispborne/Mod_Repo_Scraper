## 1. Building the history (server)

- [x] 1.1 Add a topic-history builder to `lib/viewer/bundle_views.dart`: walk snapshots oldest to newest, pull the topic's record from each via `topicsOf`'s flattening, diff neighbours with `changedFields` over `bundleFields`, and emit entries for changes plus first-seen / dropped. Skip unreadable snapshots and count how many were read.
- [x] 1.2 Add the item-by-item list diffing beside it: downloads lined up by original URL (added / removed / details-that-moved rows), LLM facts lined up by mod name and diffed per part, plain lists (links, images) as added/removed by value.
- [x] 1.3 Tests for the builder: a changed field makes an entry; an ignored field (`scrapedAt`, `replies`) makes none; enter/leave the bundle; an unreadable snapshot is skipped and counted; download added / resolved-differently; LLM version old → new.

## 2. Serving it (API and cache)

- [x] 2.1 Add `GET /topics/<id>/history` to `lib/viewer/api.dart`: entries newest first, readable-snapshot count, oldest snapshot date. Never a whole snapshot in the answer.
- [x] 2.2 Give `data_access.dart` a per-topic history cache, dropped whenever the snapshot list changes; leave the two-slot snapshot pen alone. Test: a new snapshot invalidates; the compare page's pair is not evicted by a history ask.

## 3. The page (frontend)

- [x] 3.1 New view module `web/views/topic_history.js`: the rail (dots and line), one collapsed card per entry with a summary line from the changed fields' labels, expanding to the diff table; list fields drawn as +/− / changed rows. Foot of the rail says where history ends; empty state names snapshots checked and the oldest date.
- [x] 3.2 The unpublished entry: reuse the thread page's staleness check; hollow-dot entry at the top with the Rebuild bundle button when the manager is on, plain text when off, absent when current.
- [x] 3.3 Routes: `#/topics/<id>/history` and `#/bundle/<id>/history` in `web/app.js`, breadcrumbs back through the matching list and the thread page; History button in the thread page's controls row in `web/views/bundle.js`.
- [x] 3.4 Styles in `web/style.css`: the rail, dot states (filled / hollow / capped end), and any diff rows the compare page's styles don't already cover.

## 4. Rounding off

- [x] 4.1 Check the page by hand against real data: a topic with changes (34633), a topic with none, a topic with unpublished changes, manager off.
- [x] 4.2 `dart test` and lint clean; update CLAUDE.md's frontend section with the new page in one or two sentences.
