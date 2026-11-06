## 1. Shared pieces

- [x] 1.1 `web2/lib.js`: pager with the shared rows-per-page choice, breadcrumbs, and the raw JSON section
- [x] 1.2 `web2/routes.js`: reading and writing the address's query (no DOM), with Node tests

## 2. Run panel

- [x] 2.1 Move the run panel from `web2/views/control.js` to `web2/run_panel.js`; Control imports it
- [x] 2.2 "Show more" for the log
- [x] 2.3 "What it changed" finds the snapshot before the run, or says there is none

## 3. Pages

- [x] 3.1 `web2/views/runs.js`: Run history with the pager, the page in the address, and a redraw when the running job changes
- [x] 3.2 `web2/views/run.js`: breadcrumbs, the run panel for a running or finished run, waiting runs, unknown ids, raw JSON
- [x] 3.3 Route `#/runs` and `#/runs/<id>` in `web2/app.js`; styles for the table, pager and breadcrumbs

## 4. Checks and docs

- [x] 4.1 Check in the browser: paging and reload, rows per page shared with the old viewer, a finished run, a live run (simulated in the page), Show more, What it changed, an unknown id, phone width
- [x] 4.2 Update `CLAUDE.md`
- [x] 4.3 Run `dart test`
