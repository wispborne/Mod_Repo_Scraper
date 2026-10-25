## Why

Home shows every mod for every game version. Readers cannot limit it to mods for the current release or mods without AI art. Browse has filters, but opening a link with filters replaces the ones it remembered. This happens when a reader selects a category on Home or opens a shared link.

## What Changes

- Home gets its own filters, in a bar at the very top of the page, above the AI summary banner. The bar always starts closed. When closed, it lists the filters that are on, or the name of the saved filter they match, and offers "Clear" whenever any filter is on.
- Home's filters are game version, category, requires, the four three-state switches and AI use: Browse's filters without the search text, sort, page, view and layout.
- Home starts with all filters off. It looks exactly as it does today until a reader turns on a filter. "Clear" turns all filters off again.
- Home's filters apply to the whole page: Recently added (filtered, then the 24 newest), the category counts, and Recent updates. If filters hide everything in a section, it keeps its heading and says "Everything is hidden by your filters."
- A "Copy filters from Browse page" button copies Browse's remembered filters into Home's own. Home never changes Browse's filters. Changes on either page do not automatically change the other page's filters.
- Home's "See all →" links and its category buttons include Home's filters. Browse opens with the same filters as Home.
- Browse remembers its filters only when the reader changes a control on Browse itself. Opening Browse from a link (Home, a shared link, the top search box) shows that link's list without replacing what Browse remembered. **BREAKING**: opening a link no longer replaces the remembered filters.
- **Saved filters** lets readers name and save their filters. Home and Browse use the same list. Readers can save the current filters, apply a saved filter, or delete one. Undo restores a deleted filter. Saved filters contain the same fields as Home's filters. A game version that was the current release when saved keeps meaning "the current release" after the game updates.
- The site always calls them "Saved filters" to distinguish them from the AI use filter's presets ("No AI", "No vibecoded mods" and so on).

## Capabilities

### New Capabilities

- `home-filters`: the filter bar on Home, what it filters, how it starts, Copy from Browse, and Home's links into Browse.
- `saved-filters`: the reader's named filter sets, shared by Home and Browse.
- `browse-filter-memory`: when Browse remembers its filters and when a link into Browse leaves them alone.

### Modified Capabilities

None. No current spec covers Browse's filters or Home.

## Impact

- `site/views/home.js`: the filter bar, filtering each section, the message for an empty section, links into Browse.
- `site/views/browse.js`: remember filters only when the reader changes them on Browse; the Saved filters menu in both layouts; the filter controls made reusable by Home.
- New `site/filter_set.js` (no page code): reading, writing and comparing a set of filters, and the saved filters list. Tested by a new `test/site/filter_set_test.mjs`, run from `dart test` like the search tests.
- `site/lib.js`: a small dialog that asks for a name, and one that asks before replacing a saved filter.
- `site/style.css`: the bar and the menu.
- New browser storage keys: `starmodderHomeFilters` and `starmodderSavedFilters`. `starmodderBrowseFilters` keeps its name and format.
- `CLAUDE.md`: the public website section.
- No change to any data file, the builder, or anything published apart from the site's own scripts.
