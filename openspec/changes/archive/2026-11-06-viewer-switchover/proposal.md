## Why

Every page of the new viewer is built (`viewer-v2-*`). The two viewers were meant to run side by side only until every new page was built. `docs/viewer-redesign-requirements.md` says the new viewer replaces the old one in one step, and that the same change rewrites or removes the specs that describe the old viewer.

## What Changes

- **BREAKING** The new viewer moves from `web2/` to `web/`. The old viewer is deleted, and its prototypes move to `design-samples/viewer-prototypes/`.
- **BREAKING** The server's `--ui` and `--web2-dir` options are removed, and so is the dev launcher's `--ui`. The server serves one viewer at `/`.
- Addresses that worked while both viewers were served still work. `/v1/...` and `/v2/...` redirect to the same address at `/`. The old viewer's page addresses (`#/topics/<id>`, `#/bundle/changes`, `#/modrepo` and the rest) open the matching page.
- Needs attention on Control and the mod links on Author aliases open pages in this viewer instead of the old one. The "not built yet" page is removed.
- The release ships `web/`. For now it also ships `web2/` containing only a note. The update script on the host may still expect that folder. The script in the repo no longer lists it.
- Specs: the old viewer's pages are removed (`runs-page`, `topic-actions`, `viewer-llm-inspection`, `viewer-merge-explorer`, `viewer-output-browsing`). The server and frame specs drop the two-viewer rules. The history page, run history and job specs name the new pages.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `viewer-server`: one viewer, redirects for the former addresses, live reload of `web/`.
- `viewer-v2-frame`: no temporary search and no "not built yet" pages. The old viewer's addresses open their new pages.
- `viewer-v2-runs`: the rows-per-page choice is no longer shared with another viewer.
- `topic-history`: the page's address and where it is reached from.
- `modrepo-jobs`, `output-publishing`: scenarios name Control and the run page instead of the Runs view.
- `runs-page`, `topic-actions`, `viewer-llm-inspection`, `viewer-merge-explorer`, `viewer-output-browsing`: removed. Their pages are gone. The `viewer-v2-*` specs cover the pages that replaced them.

## Impact

- `web/` (was `web2/`), the old `web/` deleted, `test/web/` (was `test/web2/`).
- `bin/viewer_server.dart`, `bin/dev_servers.dart`, `lib/viewer/server_app.dart`, `tool/run-sites-dev.bat`, `.claude/launch.json`.
- `.gitea/workflows/release.yaml`, `tool/update-scraper-only.sh`. The host's copy of the script is not updated by a release.
- `CLAUDE.md`, `README.md`, `docs/viewer-redesign-requirements.md`.
