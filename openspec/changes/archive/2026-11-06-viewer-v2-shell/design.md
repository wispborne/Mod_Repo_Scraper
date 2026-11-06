## Context

`docs/viewer-redesign-requirements.md` describes the new results viewer. This is the first of several changes that build it. It builds the frame shared by every page. It also serves the new viewer alongside the old one. The look was chosen from `web/prototype-control/variant-d.js` (the Workbench layout in the Homeworld colours). The prototype builds its pages from HTML strings and loads its fonts from Google. Neither is allowed in the real viewer.

Today `bin/viewer_server.dart` serves `web/` with `shelf_static`. `buildServerHandler` in `lib/viewer/server_app.dart` handles the manager routes and viewer API first. Both viewers call the API by absolute address (`/api/...`). The old viewer loads its own files by relative address (`style.css`, `app.js`). Either viewer can therefore be served from a folder below `/` without changes.

## Goals / Non-Goals

**Goals:**
- `web2/` exists and is served beside `web/`, chosen with `--ui`.
- The frame: nav rail, toolbar, side panels, status bar, tab title, the look, and a router that later changes add pages to.
- Every nav page is reachable and links to the old viewer until it is built.

**Non-Goals:**
- Any real page beyond the frame. The Control page's job buttons, Needs attention and the central run panel come in the next change.
- The Pending changes list itself. This change only reads its count.
- The real search, which needs a new API route.
- Any change to `web/` or to the API.

## Decisions

### Both viewers are always served; `--ui` only chooses the root
The server always serves both folders. `--ui v1` (default) puts the old viewer at `/` and the new one at `/v2/`; `--ui v2` swaps them, with the old one at `/v1/`. A new function in `server_app.dart`, `twoViewers({root, otherPrefix, other})`, sends `<prefix>/…` to the other viewer with the prefix removed. It redirects a bare `<prefix>` to `<prefix>/` and sends everything else to the root viewer. It replaces `staticHandler`, so API routes are still handled first.

A second port would need a second server and a second set of flags. Both servers would need the same lock if both had the manager on. Serving only the chosen viewer would prevent placeholders from linking to the old viewer. Comparing the viewers would then need two servers. Serving both needs only one extra handler and lets them use the same data.

### The new viewer uses its current address to find the old viewer
A placeholder links to the old viewer at `/v1/#/…` when the new viewer is at `/`, and at `/#/…` when the new viewer is at `/v2/`. `web2/routes.js` works this out from `location.pathname`. This needs no value from the server and sends no new data over the network.

### Build pages with DOM nodes
`web2/lib.js` has an `el(tag, attrs, children)` helper like `web/lib.js`. Pages build nodes and never put data in `innerHTML`. This prevents mod names from becoming markup. The two `lib.js` files stay separate. `web/` is deleted at the switch-over. Sharing a file would also require the server to serve a third folder.

### Module layout
- `web2/index.html`: the frame's fixed parts (`#rail`, `#toolbar`, `#content`, `#statusbar`) and one script.
- `web2/app.js`: the router. Each page module exports `title`, and `render(content, parts, toolbar)`. A route change redraws the toolbar and content only.
- `web2/routes.js`: the nav list (groups, ids, labels, icons, old-viewer address), which nav entry is current for a hash, the old-viewer address, and how the search box reads its text. It uses no DOM, so Node can test it.
- `web2/frame.js`: nav rail, toolbar, side panel and status bar builders.
- `web2/status.js`: the shared status poller, copied from `web/manager.js`'s poller (subscribe, refresh, faster while busy, stopped while hidden), plus the tab title.
- `web2/update.js`: the Update link, adapted from `web/update.js` to sit in the status bar. It uses the same server route and the same steps to confirm and watch the update.
- `web2/icons.js`: Tabler path data for the icons the frame uses.
- `web2/style.css`: the colour names on `:root`, then the frame.
- `web2/fonts/`: IBM Plex Sans and Mono, regular and semibold, Latin only, as `.woff2`, with the font licence.
- `web2/views/placeholder.js` and `web2/views/control.js`.

### Pending changes count
The count is the length of a JSON list under `sessionStorage['viewerPendingChanges']`. Nothing writes it yet. The corrections change will add that. If the list cannot be read, the count is zero. The toolbar re-reads it on every page draw and on the `storage` event.

### Fonts
The IBM Plex `.woff2` files come from the `@fontsource/ibm-plex-sans` and `@fontsource/ibm-plex-mono` npm packages (Latin subset, weights 400 and 600), copied into `web2/fonts/` with the OFL licence text. They are checked in, like the Tabler icons. Four files, about 100 KB together.

### Progress bar split into parts
A bar with a fill and a repeating gap drawn over it in the page colour, as in the prototype. Widths are whole pixels so the gaps do not blur.

### Narrow screens
Under 640 px the frame's grid becomes one column. The rail becomes a strip across the top that scrolls sideways. The page content follows, and the status bar stays at the bottom. Narrow screens have no hover, so rail labels are not shown on hover. The accessible labels remain.

## Risks / Trade-offs

- [Two copies of the poller and update code] → Accepted. `web/` is deleted at the switch-over; until then the copies serve different pages. Both copies of the update code use the same server route. They keep working as long as that route does not change.
- [Font files in the repo] → Small, licensed for this, and needed because nothing may load from the internet.
- [Old viewer under `/v1/` has never been served from a folder] → It can work under `/v1/` because it loads its own files by relative address and calls the API by absolute address. A server test checks that `/v1/` serves its `index.html`. The old viewer is also checked by hand at `/v1/`.
- [Live reload watching two folders] → `LiveReload.watch` takes one folder today. This change makes it take a list.

## Migration Plan

Nothing to migrate. Default behaviour is unchanged: `/` is still the old viewer. The new viewer is opened at `/v2/`, or at `/` with `--ui v2`. At the final switch-over (a later change), `web2/` replaces `web/` and `--ui` goes away.

## Open Questions

None for this change.
