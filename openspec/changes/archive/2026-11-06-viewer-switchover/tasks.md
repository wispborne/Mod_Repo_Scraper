## 1. Viewer

- [x] 1.1 Move `web2/` to `web/`, delete the old viewer, move its prototypes to `design-samples/viewer-prototypes/`
- [x] 1.2 Add `movedAddress` to `routes.js` and call it from the router. Remove the old-viewer helpers, the `old` nav fields and the placeholder page
- [x] 1.3 Needs attention and Author aliases link to this viewer's pages
- [x] 1.4 Move `test/web2/` to `test/web/`; Node tests for `movedAddress`

## 2. Server and tools

- [x] 2.1 `withFormerViewerAddresses` in `server_app.dart`; remove `--ui` and `--web2-dir`; live reload watches `web/`
- [x] 2.2 Dart test for the redirects
- [x] 2.3 Dev launcher, `run-sites-dev.bat` and `.claude/launch.json` without `--ui`
- [x] 2.4 Release ships `web/` and an empty `web2/` with a note; the update script lists `web/` only

## 3. Specs and docs

- [x] 3.1 Archive the `viewer-v2-*` changes
- [x] 3.2 Write spec changes for the switch-over
- [x] 3.3 Update `CLAUDE.md`, `README.md`, `docs/viewer-redesign-requirements.md`

## 4. Checks

- [x] 4.1 Check in the browser: pages, old addresses, `/v2/` redirects
- [x] 4.2 Run `dart test`
