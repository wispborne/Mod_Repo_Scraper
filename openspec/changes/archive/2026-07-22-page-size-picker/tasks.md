## 1. Servers

- [x] 1.1 `lib/viewer/api.dart`: `_pageSize` honours 0 as "everything", still caps at 500 and still falls back on nonsense
- [x] 1.2 `lib/viewer/api.dart`: `_paged` returns every row with `page` and `pageSize` of 0 when the size is 0
- [x] 1.3 `lib/manager/manager_api.dart`: the same for `_pageSize` and the runs slicer
- [x] 1.4 Test: a page size is honoured, 0 puts everything on one page, nonsense falls back, an enormous number is capped
- [x] 1.5 Test: the manager's runs list answers `pageSize=0` with every run

## 2. The shared pager

- [x] 2.1 `web/lib.js`: `PAGE_SIZES`, `pageSizePreference()` / `setPageSizePreference()` over localStorage
- [x] 2.2 `web/lib.js`: `pager()` takes an `onPageSize` callback and draws the Show box; with everything on one page it drops the buttons and says how many rows there are
- [x] 2.3 `web/style.css`: styles for the box, pushed to the right of the page buttons

## 3. The lists

- [x] 3.1 Topics
- [x] 3.2 ModRepo
- [x] 3.3 Bundle
- [x] 3.4 Merge groups
- [x] 3.5 Merge removals
- [x] 3.6 Merge what-changed
- [x] 3.7 Run history

## 4. Finish

- [x] 4.1 Run `dart test` — 378 tests, all passing
- [x] 4.2 Check a real list end to end: 708 mods on one page, 25 a page, and an enormous number capped at 500
- [x] 4.3 Click the box on each list in a browser
