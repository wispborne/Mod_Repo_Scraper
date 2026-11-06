## Context

Old pages: `web/views/merge_compare.js` (the Catalog diff, over `/api/merge/compare?a=&b=`, with `merge_shared.js` for the run picker), `web/views/bundle_compare.js` (the Details diff, over `/api/bundle/compare?a=&b=`, where `b=working` compares with the data on disk and a Refresh button redraws), and `web/views/diff_table.js` (shared by both and the topic history). The new viewer already ported the diff helpers the topic history uses (`web2/views/post_history.js` exports `diffTable`, `changedFieldsLine`, `changedFieldsTitle`, `expandAllButton`).

## Goals / Non-Goals

**Goals:** one page, two tabs, one picker; links from the new viewer open this page.

**Non-Goals:** server changes; the Catalog explorer (separate tool, separate change).

## Decisions

### One picker over two lists of runs
The Mods tab compares merge snapshots; the Facts tab compares bundle snapshots. Most runs save both, under the same run id. The picker lists runs by id and time, with the snapshots each has. A pair is offered on a tab only when both runs have that tab's snapshot. Picking a run on one tab keeps it when switching tabs where possible, and says so when the other tab has no snapshot for it. "The data on disk right now" is offered as the newer side on the Facts tab only (a merge writes nothing until it finishes).

### Address
`#/changes?tab=mods|facts&a=<run>&b=<run|working>&q=<search>`. Defaults: the Facts tab, the newest run against the one before it. Old links from the run panel pass `tab`, `a` and `b`.

### Shared diff code
`diff_table.js` and the helpers now exported from `post_history.js` move to one module, `web2/diff_parts.js`, which the history pages, the mod page and What changed import. The old viewer's notes require one shared copy.

## Risks / Trade-offs

- [Comparing against the data on disk is slow on a cold server] → Same as the old page; the Refresh button is the only redraw, never a timer.
