## 1. Serving both viewers

- [x] 1.1 Add `twoViewers({root, otherPrefix, other})` to `lib/viewer/server_app.dart`: `<prefix>/…` goes to the other viewer with the prefix removed. A bare `<prefix>` redirects to `<prefix>/`. Everything else goes to the root viewer
- [x] 1.2 Add `--ui` (`v1`/`v2`, default `v1`) and `--web2-dir` (default `web2`) to `bin/viewer_server.dart`. Reject any other `--ui` value. Start without the new viewer when its folder is missing and report this at startup. Print where each viewer is served
- [x] 1.3 Let `LiveReload.watch` take several folders, and watch both `web/` and `web2/` with `--reload`
- [x] 1.4 Add a Dart test for which viewer is served at `/`, `/v2/` and `/v1/`. Check the bare-prefix redirect and that `/api/...` still reaches the API
- [x] 1.5 Update the notes in `bin/dev_servers.dart` and `tool/run-sites-dev.bat` to mention `web2/`

## 2. Look and assets

- [x] 2.1 Copy IBM Plex Sans and IBM Plex Mono (400 and 600, Latin, `.woff2`) and the OFL licence into `web2/fonts/`
- [x] 2.2 `web2/style.css`: the colour names on `:root`, `@font-face` for the local fonts, base text, buttons with cut corners, outlined tag, diamond marks, split progress bar, corner brackets
- [x] 2.3 `web2/icons.js`: Tabler path data for the nav and frame icons, and an `icon(name)` builder

## 3. Frame

- [x] 3.1 `web2/routes.js`: the nav groups, finding the current nav entry from a hash, the old viewer's address, and converting search text to an address in the old viewer (no DOM)
- [x] 3.2 `web2/lib.js`: `el`, `clear`, `api`, the in-page dialog
- [x] 3.3 `web2/frame.js`: nav rail (hover and focus labels, `aria-current`), toolbar (title, actions, pending count, search with "/"), side panel (folding heading, remembered by name), status bar
- [x] 3.4 `web2/status.js`: the status poller (busy and idle speeds, stopped while hidden) and the tab title
- [x] 3.5 `web2/update.js`: the Update link in the status bar, with the same confirm and watch steps as the old viewer
- [x] 3.6 `web2/index.html` and `web2/app.js`: draw the frame once. Have the router redraw the toolbar and content. Add the page for unknown addresses
- [x] 3.7 Narrow-screen layout: rail across the top, side panels below the central panel, status bar at the bottom

## 4. Pages

- [x] 4.1 `web2/views/placeholder.js`: "not built yet" with a link to the matching old-viewer page, used for every nav page but Control
- [x] 4.2 `web2/views/control.js`: a placeholder in the central panel, plus Queue and Recent runs side panels from real data, and the "Viewing only" sentence when the manager is off

## 5. Checks and docs

- [x] 5.1 Node test for `web2/routes.js`, run from `dart test` like the site's search tests
- [x] 5.2 Check in the browser: every nav page, hover and focus labels, folding panels, the status bar while a job runs and with the manager off, the old viewer at `/v1/`, phone width, and no outside requests
- [x] 5.3 Add a short `web2/` and `--ui` note to `CLAUDE.md`
- [x] 5.4 Run `dart test` and fix anything that fails
