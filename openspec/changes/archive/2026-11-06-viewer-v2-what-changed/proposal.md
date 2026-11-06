## Why

The old viewer compares saved runs on two pages, Catalog diff (`#/merge/changes`) and Details diff (`#/bundle/changes`), each with its own picker. `docs/viewer-redesign-requirements.md` (**Investigate → What changed**) asks for one page with two tabs sharing one picker. The new viewer's run pages, source post history and mod history still link to the old pages.

## What Changes

- **What changed** (`#/changes`): two tabs, **Mods** (the catalog comparison, what Catalog diff shows) and **Facts** (the details comparison, what Details diff shows), sharing one picker for the two sides: two saved runs, or a saved run against the data on disk right now. The picked sides, the tab, the search and the open rows are kept in the address. A comparison with the data on disk updates only when Refresh is pressed.
- Rows name which fields changed when closed, and list only what changed when open, using the old pages' shared diff rules. Mod rows link to the mod page and topic rows to the source post page.
- The new viewer's links that went to the old diff pages (the run panel's "What it changed", the Control page, the source post history, the mod history) now open this page.
- No server change: it reads the routes the old pages read (`/api/merge/runs`, `/api/merge/compare`, `/api/bundle/runs`, `/api/bundle/compare`).

## Capabilities

### New Capabilities
- `viewer-v2-what-changed`: the What changed page.

### Modified Capabilities
None.

## Impact

- New `web2/views/changes.js` and a ported `web2/diff_table.js`; styles.
- `web2/run_panel.js`, `web2/views/post_history.js`, `web2/views/mod.js`: links to the new page.
- `web2/app.js`: the route (registered beforehand).
