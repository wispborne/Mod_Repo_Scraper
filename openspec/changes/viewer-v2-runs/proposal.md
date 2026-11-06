## Why

The new viewer's Control page links to Run history and to each run, but both are still placeholders. `docs/viewer-redesign-requirements.md` describes them under **Operate → Run history and the run page**. They are also the first pages to need the shared rules for lists and detail pages: rows per page, list state in the address, breadcrumbs and a raw JSON section.

## What Changes

- **Run history** (`#/runs`): every saved run, newest first, with its job, state, start time, how long it took, how much it did, its errors and LLM calls, and a note when it reached the call limit or failed. Paged, with the rows-per-page setting shared with the old viewer. The page number is kept in the address.
- **The run page** (`#/runs/<id>`): breadcrumbs back to Run history, the same run panel as the Control page (progress, counters, Stop or Run again, and Log, What it changed and Record tabs), and the run's raw JSON, collapsed, at the end. A queued run says it is waiting. An unknown id shows the server's own message.
- **One run panel for both pages.** The run panel moves out of the Control page into its own module. Both pages gain two features:
  - The log gets "Show more", which loads more lines.
  - "What it changed" finds the snapshot saved before the run and links straight to the comparison, as the old run page does. A live run links to "Changes so far". When there is no earlier snapshot, the tab says so.
- Shared pieces for later pages: a pager with the rows-per-page choice, breadcrumbs, and a collapsed raw JSON section.
- Browser notifications when a run ends are left for the Settings page, where the requirements place the setting.

## Capabilities

### New Capabilities
- `viewer-v2-runs`: the new viewer's Run history page and run page, and the shared pager, breadcrumbs and raw JSON section.

### Modified Capabilities
None. The server is not changed.

## Impact

- New `web2/run_panel.js` (moved from `web2/views/control.js`), `web2/views/runs.js`, `web2/views/run.js`.
- `web2/lib.js` (pager, rows-per-page setting, breadcrumbs, raw JSON), `web2/routes.js` (address query helpers), `web2/app.js`, `web2/style.css`.
- Node tests for the new routing helpers.
