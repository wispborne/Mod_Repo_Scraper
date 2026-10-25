## 1. Filter sets

- [x] 1.1 Create `site/filter_set.js` with no page code: filter keys, reading a set from a query string, writing it back, keeping only filter fields from a query, and comparing the filters represented by two queries
- [x] 1.2 Move `switchesFromAddress` and `gameFromAddress` (and `SWITCHES`' keys and labels) from `site/views/browse.js` into `filter_set.js`, and make Browse import them
- [x] 1.3 Add a short description of a set for Home's closed bar (e.g. "0.98a · Has a download")
- [x] 1.4 Add the saved filters list: read from a JSON string, save, replace by name, delete, and restore to the original position
- [x] 1.5 Write `test/site/filter_set_test.mjs` and `test/site/filter_set_test.dart` (run through `dart test` like `search_test.dart`): key order, the current release written two ways, no remembered Browse filters, dropping `q`/`sort`/`seed`/`page`, an unreadable saved list, replacing an entry and restoring a deleted entry

## 2. Browse remembers only its own changes

- [x] 2.1 Call `rememberFilters` only from change handlers, not from every draw
- [x] 2.2 Check by hand: a shared link and a Home link leave the remembered filters alone; changing a control after opening a link saves the choices on that page

## 3. Reusable filter controls

- [x] 3.1 Split `drawControls` so the filter controls can be drawn without the search row, sort, view and layout
- [x] 3.2 Check both Browse layouts by hand in the browser: the controls look and work as before

## 4. Saved filters menu

- [x] 4.1 Add a name dialog and a dialog that asks before replacing a saved filter to `site/lib.js`, built like `openInfoDialog`
- [x] 4.2 Add the "Saved filters" menu: list, apply, delete with Undo, "Save current filters…"
- [x] 4.3 Put it on Browse in both layouts. Picking one counts as a change on Browse
- [x] 4.4 Show the matching saved filter's name in the menu

## 5. Home's filter bar

- [x] 5.1 Add the filter bar above the AI banner on Home. Start it closed on every visit. Show the filters in use or the matching saved filter's name. Include "Clear" when any filter is on
- [x] 5.2 Inside it: the filter controls, the Saved filters menu, and "Copy filters from Browse page"
- [x] 5.3 Store Home's filters in `starmodderHomeFilters`, starting at `game=any`, with storage failures handled
- [x] 5.4 Filter Recently added (filter, then the 24 newest), the category counts (ignoring the chosen category, marking it chosen) and Recent updates (hiding releases with no mod record while any filter is on)
- [x] 5.5 Show "Everything is hidden by your filters." when filters hide everything in a section
- [x] 5.6 Make "See all →" and the category buttons include Home's filters, always including the game version

## 6. Appearance and wording

- [x] 6.1 Style the bar and the menu in `site/style.css` using the existing names only; check light and dark themes and phone width
- [x] 6.2 Check any icon beside words against the icon alignment rule in CLAUDE.md
- [x] 6.3 Run all new site text through Codex
- [x] 6.4 Update the public website section of `CLAUDE.md`

## 7. Checks

- [x] 7.1 `dart test` passes
- [x] 7.2 Walk through every scenario in the three specs in the browser with `bin/site_server.dart`
