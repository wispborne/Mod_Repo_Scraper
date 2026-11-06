## Context

The Control page (`viewer-v2-control`) shows a run panel: header, progress, counters, and Log, What it changed and Record tabs. The run page needs the same panel for any run. The old viewer's run page (`web/views/run.js`) has two things the new panel lacks: "Show more" for the log, and a "What it changed" link that names the snapshot before the run (`addWhatChangedLink`, using `GET /api/bundle/runs`).

The old viewer keeps the rows-per-page choice in `localStorage['viewerPageSize']` (25, 50, 100, 250, 500, or 0 for all). Both viewers are served from the same origin, so they can share it.

## Goals / Non-Goals

**Goals:** the two run pages; one run panel; the shared list and detail-page pieces.

**Non-Goals:** browser notifications (Settings page); filters on Run history (the requirements ask for none); any server change.

## Decisions

### `web2/run_panel.js`
`runPanel(node)` returns `{ show(record, live), off(status) }`, the same as the Control page's private `runView` today, moved without changes except the two below. The Control page imports it.

- **Show more:** the log asks for 200 lines first. "Show more" asks for 2,000, then five times as many on each press, as the old run page does. The lines already shown stay on the page.
- **What it changed:** for a finished run, the panel asks `GET /api/bundle/runs` once per run shown. When the run has a saved snapshot and there is an older one, it links to `bundle/changes?a=<older>&b=<run>` in the old viewer. When there is none, it says "No earlier snapshot to compare with." A live run links to `bundle/changes?b=working`.

### Run history
`GET /api/manager/runs?page=&pageSize=` already returns pages of runs, newest first. The page number is read from and written to the address (`#/runs?page=2`, left out on the first page) with `history.replaceState`, so Back leaves the page rather than stepping through pages. The rows-per-page choice is the shared `viewerPageSize` and is not in the address, as in the old viewer. The list refreshes when the running job changes to show the finished run.

Rows are links to the run page. Columns: state (diamond and word), job, started, took, done, errors, LLM calls, notes. On a narrow screen the table scrolls sideways inside its panel, as the requirements allow for list pages.

### Run page
The record comes from `GET /api/manager/runs/<id>`. While the status reports this run as current, the panel updates with each status response, as on Control. When it ends, the page reads the record once more. A queued run shows "Waiting" and no log. The raw JSON section is a closed `<details>` at the end, redrawn only when the record changes.

### Shared pieces in `web2/lib.js`
`pager(page, pageSize, total, onPage, onPageSize)`, `pageSizePreference()` and the picker reuse the old viewer's labels and key. `breadcrumbs(trail)` draws a trail; the last item is the current page and not a link. `rawJson(value)` is a collapsed section labelled "Raw data (JSON)".

## Risks / Trade-offs

- [Two viewers write the same page-size key] → Both viewers share one setting and accept the same values.
- [The "What it changed" link still goes to the old viewer] → The link uses the old viewer until What changed is built. The tab explains this.
