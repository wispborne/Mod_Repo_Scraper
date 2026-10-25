## Context

Browse records the reader's choices in the address (`#/browse?category=…&only=…&ai=…`). It also saves the last address's query to `starmodderBrowseFilters`. Opening Browse without a query restores those choices (`browseQuery`). Every redraw saves again (`saveState` → `rememberFilters`). Opening an address with filters therefore replaces the remembered filters immediately. Home's category buttons, its "See all →" (`?sort=newest`) and the top search box all do that today.

Home (`site/views/home.js`) shows these parts without filtering: the AI summary banner, Recently added (the 24 newest by `addedOn`), Browse by category (`categoryChips`), Recent updates (from `updates.json`, matched to mods by `modId`), and the feed link.

The filter logic lives in `site/views/browse.js`: `SWITCHES`, `switchesFromAddress`, `gameFromAddress`, `matchesFilters`, and the controls in `drawControls`. The AI use filter's address keys and matching are already in `site/ai_filter.js`, which has no page code and is tested in Node.

## Goals / Non-Goals

**Goals:**
- One way to read, write and compare a set of filters, shared by Browse, Home and saved filters, and testable in Node.
- Home uses Browse's filter controls and matching rules. The same filter means the same thing on both pages.
- Browse's remembered filters change only when the reader changes something on Browse.

**Non-Goals:**
- Automatically updating one page's filters when the other page's filters change. Copy from Browse is a one-time copy.
- Sharing saved filters between browsers or devices.
- Renaming or editing a saved filter in place.
- Filtering anything outside Home and Browse (Favorites, Reports, author pages).

## Decisions

**A filter set is written in Browse's own address format.** A set is a query string using the keys Browse already writes: `game`, `category`, `needs`, `only`, `not`, and the AI keys from `aiFilterToAddress`. Home's filters, saved filters and Browse's remembered filters are all stored in it. Browse already leaves `game` out when the current release is chosen. It reads a missing `game` as the current release (`gameFromAddress`). A saved filter made on the current release stores no `game`. Applying it later picks whatever release is current then. Home uses `game=any` when all filters are off. Copying when Browse has no remembered filters gives an empty string. This selects the current release with all other filters off, just as Browse would.
Alternative: a JSON object per set. Rejected because it would need a second reader and writer for the same fields, and a second current-release rule.

**A new `site/filter_set.js` holds the code that does not depend on a page.** It holds the filter keys and switch keys. It reads a query string into a state object and writes it back. `switchesFromAddress` and `gameFromAddress` move here from `browse.js`. It keeps only filter fields from a query, dropping `q`, `sort`, `seed` and `page`. It compares the filters represented by two queries. Key order makes no difference. `game=<current>` matches a query with no `game`. It describes a set in a few words for Home's closed bar. It also reads, saves, replaces, deletes and restores entries in the saved filters list. It has no page code and no `localStorage` calls of its own. Callers pass strings. This lets Node test it. If the `keep` functions need page code, `SWITCHES` stays in `browse.js`. In that case, `filter_set.js` holds only its keys and labels. Otherwise, all of `SWITCHES` can move. Decide this when writing the file.

**Home reuses Browse's controls.** `drawControls` is split so the filter controls (category, game version, requires, switches, AI use) can be drawn without the search row, sort, view and layout parts. Home draws them inside a `<details>` bar using Browse's top layout. Home filters with `matchesFilters` from `browse.js` (Home already imports `modCard` from there), with an empty search. Home's bar uses the top layout's category dropdown. Category counts stay in the table further down the page.

**Browse saves only on a change.** `saveState` keeps writing the address on every draw. `rememberFilters` is called only from the change handlers (`onChange` in `render`, plus the results line's "Include N…" and "Clear AI filter", "Clear filters", and picking a saved filter). The first draw from an address never writes storage. `forgetSearch` is unchanged.
Alternative: compare the address with the remembered set and write only when the reader changed a control. Rejected: there is no way to tell from the address alone.

**Saved filters menu.** A `<details>` menu labelled "Saved filters" sits with the other filters. It appears in the filters row of Browse's top layout. It is the first panel in the side layout. On Home, it is inside the filter bar. It lists the saved filters. Pressing an entry applies it. Its × button deletes it. The menu ends with "Save current filters…". The name and the replace question use a small `<dialog>` helper in `lib.js` built like `openInfoDialog`. Undo after a delete follows the Favorites "Clear all" pattern (`views/favorites.js`). Undo puts the deleted entry back in its original position.

**Storage.** `starmodderHomeFilters`: a query string. `starmodderSavedFilters`: a JSON list of `{ name, filters }`, where `filters` is a query string. Every read and write is wrapped in try/catch, as `rememberFilters` already is. If the list cannot be read, it is treated as empty. It is not overwritten until the reader saves something.

**Home's links.** "See all →" and the category buttons are built with `buildHash(['browse'], { ...homeFilters, …linkParams })`. `categoryChips` gets an optional argument for extra address values to include in its links. Links always include Home's game version, `game=any` included.

## Risks / Trade-offs

- When Home's filters are off, its category buttons open Browse for every game version. Today they open Browse for the current release. This follows the rule that links include Home's filters. Browse's game version filter shows "Any game version" in that case. Readers can change it with one press. Mention this in the commit message.
- Splitting `drawControls` could change Browse's controls. Browse keeps calling the same parts in the same order. Check both layouts by hand in the browser after the split.
- Comparing query strings as text would miss matching filters. `filter_set.js` compares parsed sets. Tests cover key order, the current release written two ways, and an empty AI filter against a missing one.
- A saved filter for the current release follows game updates (see the spec). A saved filter that names an older release keeps it.

## Migration Plan

No existing data needs to change. `starmodderBrowseFilters` keeps its name and format. The two new keys start empty. An older version of the site's scripts will ignore the new keys.

## Open Questions

None.
