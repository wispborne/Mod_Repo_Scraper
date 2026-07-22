## Why

Every list in the viewer showed a fixed number of rows a page — 50 for most, 25 for the run history — with no way to change it. Reading a long list meant clicking through page after page, and there was no way to get the whole thing on screen at once to search it with the browser's own find, or to copy it out.

## What Changes

- Every paged list gains a **Show** box choosing how many rows a page holds: 25, 50, 100, 250, 500, or **all on one page**.
- The choice is one setting for the whole site, remembered in the browser, so picking it on one list holds on the next one and after a reload.
- With "all on one page" picked, the page buttons go away and the row says "All 708 on one page" instead of "Page 1 of 15".
- Both APIs take `pageSize=0` to mean "everything on one page". A number above 500 is still capped at 500; a number that makes no sense still falls back to 50.
- The lists this covers: Topics, ModRepo, Bundle, Merge groups, Merge removals, Merge what-changed, and the run history.

## Capabilities

### New Capabilities
<!-- None: this changes how an existing capability behaves. -->

### Modified Capabilities
- `viewer-server`: list endpoints take `pageSize=0` for "all rows on one page", asked for on purpose rather than by default.

## Impact

- **Changed:** `web/lib.js` (the shared pager grows the box and the remembered setting), `web/style.css`, the six views that draw a pager, `lib/viewer/api.dart` and `lib/manager/manager_api.dart` (both `_pageSize` helpers and the two slicers).
- **Not changed:** what any endpoint returns per row, the 500 cap on a named page size, and the rule that no endpoint hands over the whole bundle or all per-topic details.
