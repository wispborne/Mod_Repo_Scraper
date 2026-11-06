## Why

Three Investigate tools are still placeholders in the new viewer: the Catalog explorer, the LLM test report and Files. `docs/viewer-redesign-requirements.md` (**Investigate → Other investigation tools**) keeps all three. The Catalog explorer stays separate from What changed because it explains why a merge happened rather than what changed.

## What Changes

- **Catalog explorer** (`#/explorer`): why each group of posts became one mod, before and after for a group, and what was removed, for the merge picked (the newest by default). A port of the old Merge view (`#/merge`).
- **LLM test report** (`#/llm-test`): the report of the last LLM test job, and the button that starts one (still the only place that starts it, after a confirmation). A port of the old page.
- **Files** (`#/files`): the output files with their size and date, each opening as raw text. A port of the old page.
- No server change: they read the routes the old pages read.

## Capabilities

### New Capabilities
- `viewer-v2-tools`: the new viewer's Catalog explorer, LLM test report and Files pages.

### Modified Capabilities
None.

## Impact

- New `web2/views/explorer.js`, `web2/views/llm_test.js`, `web2/views/files.js`, styles.
- `web2/app.js`: the routes (registered beforehand). `web2/jobs.js`: the LLM test's confirmation sentence.
