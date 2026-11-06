## Context

Old pages: `web/views/merge.js` with `merge_shared.js` (the run picker, summary, groups, a group's before-and-after, removals; over `/api/merge/runs`, `/merge/summary`, `/merge/groups`, `/merge/groups/<id>`, `/merge/groups/<id>/fields`, `/merge/removals`), `web/views/llm_test.js` (over `/api/llm-test`, with the only button that starts an `llmTest` job), `web/views/files.js` (over `/api/files` and `/api/files/<id>`).

## Goals / Non-Goals

**Goals:** the three pages with everything the old ones show, in the new viewer layout.

**Non-Goals:** server changes; the comparison between two merges (that is the Mods tab of What changed).

## Decisions

### Addresses
`#/explorer` (groups list, with the picked merge, search, filters and page in the address), `#/explorer/groups/<id>`, `#/explorer/removals`; `#/llm-test`; `#/files` and `#/files/<id>`. Detail pages have breadcrumbs and raw JSON. Group members link to their source post pages, and merged mods to their mod pages where the id is known.

### The LLM test button
This remains the only way to start an `llmTest` job. It uses `confirmAndStart`, with a one-sentence description added to `describeJob`. The button appears only while the manager is on.

## Risks / Trade-offs

- [The Catalog explorer's groups are by merge, not by permanent id] → Members link to their source post pages, and from there to mods, so users can still open mod pages from the explorer.
