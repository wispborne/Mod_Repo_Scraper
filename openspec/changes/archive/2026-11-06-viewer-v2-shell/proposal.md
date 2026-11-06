## Why

The results viewer is being redesigned (see `docs/viewer-redesign-requirements.md`). The layout and colours were chosen from prototypes on 5 November 2026. Every new page uses the same frame: a nav rail, a toolbar, side panels and a status bar. The frame must be built before the pages. The requirements put the new viewer in `web2/`. Both viewers are served together so they can be compared using the same data.

## What Changes

- A new folder, `web2/`, holds the new viewer. It uses plain JavaScript modules with no build step, like `web/`.
- The viewer server serves both viewers. A new `--ui` option (`v1` or `v2`, default `v1`) chooses which viewer is at `/`. The other one is at `/v1/` or `/v2/`. Nothing else about the server changes, and both viewers use the same API.
- The frame every new page uses:
  - A **nav rail** down the left edge, with icons only, in three groups (Operate, Correct, Investigate) separated by short lines. Each icon shows its page name on hover and on keyboard focus. The current page is marked in the Action colour.
  - A **toolbar** across the top of each page, holding the page name, a place for the page's own buttons, the Pending changes count (shown only when there are pending changes) and the search box. "/" puts the cursor in the search box.
  - **Side panels** on the right, each with a heading bar. Pressing the heading folds or opens the panel. The browser remembers whether it is open.
  - A **status bar** along the bottom with the running job and its progress, how many jobs are waiting, the build version, and the Update link.
- The chosen look: the "Homeworld" colours, IBM Plex Sans and IBM Plex Mono shipped with the viewer, square corners, buttons with two cut corners, corner brackets on the main panels, diamond status marks, an outlined "Running" tag and a progress bar split into parts. Dark only.
- The browser tab's title shows the running job and its progress, then the result.
- Every page in the nav rail exists as a page that says it is not built yet and links to the matching page in the old viewer. The Control page also shows the real queue and recent runs in side panels, so the frame can be tested with real data.
- Until search is built in a later change, the search box sends the reader to the old viewer. A topic id or a forum or Discord address opens that post. Other text searches the old Topics list.
- The old viewer in `web/` is not changed.

## Capabilities

### New Capabilities
- `viewer-v2-frame`: the frame shared by every page of the new viewer: nav rail, toolbar, side panels, status bar, the look, the tab title, placeholder pages and the temporary search.

### Modified Capabilities
- `viewer-server`: the server also serves `web2/`, and `--ui` chooses which viewer is at `/`.

## Impact

- `bin/viewer_server.dart`: the `--ui` and `--web2-dir` options, and live reload watching both folders.
- `lib/viewer/server_app.dart`: a small handler that sends `/v1/…` or `/v2/…` to the other viewer.
- `bin/dev_servers.dart` and `tool/run-sites-dev.bat`: notes updated, since `web2/` changes now reload pages too.
- New `web2/` folder, including the IBM Plex font files (SIL Open Font License) and Tabler icon path data (MIT).
- Tests: a Dart test for which viewer is served at each address, and a Node test for the frame's routing helpers, run from `dart test`.
- `CLAUDE.md`: a short note on `web2/` and `--ui`.
