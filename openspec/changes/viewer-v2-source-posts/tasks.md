## 1. Server

- [x] 1.1 `GET /api/posts`: both kinds, search, filters, sort, paging, counts over every post
- [x] 1.2 `GET /api/posts/outcome`: the outcome, the mods, the one line
- [x] 1.3 Dart tests for both routes

## 2. Source posts list

- [x] 2.1 `web2/views/posts.js`: the list with filters, sorting and paging in the address, the data quality numbers at the top, the outcome in each row
- [x] 2.2 Ticking across pages (`sessionStorage`), the per-post job buttons with confirmation; `describeJob` for the per-post kinds
- [x] 2.3 Check with the manager off and at phone screen widths

## 3. Source post page

- [x] 3.1 `web2/post_parts.js`: the old viewer's shared thread pieces, ported
- [x] 3.2 `web2/views/post.js`: forum topic and Discord thread pages, the outcome line, per-post jobs, staleness warning, Take down, raw JSON
- [x] 3.3 `web2/views/post_history.js`: the topic history page
- [x] 3.4 Routes, and the search box opening the new pages

## 4. Checks and docs

- [x] 4.1 Check in the browser against the old pages on the same data (reading only; adding pending changes is fine; no jobs)
- [x] 4.2 Update `CLAUDE.md`
- [x] 4.3 Run `dart test`
