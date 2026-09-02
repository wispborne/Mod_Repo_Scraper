## 1. Address ownership

- [x] 1.1 Make `site/address.js` derive the route from the browser address alone — a `mods/<id>/` folder path, else the hash on the front document — with nothing kept in `history.state`. Verify a root and a nested deployment, `index.html` and a trailing slash, and that `mods/<id>.json` is not read as a page.
- [x] 1.2 Make the router read its route and its scroll key through the address module, and point every mod link at `mods/<id>/`.
- [x] 1.3 Move `go` and `replaceHash` onto the address module so nothing else writes to `location.hash`.

## 2. Navigation

- [x] 2.1 Listen for `popstate` as well as `hashchange`, remembering the address last drawn so one move is never drawn twice. Verify Back and Forward across a mod's path and a hash address — the case that was broken.
- [x] 2.2 Catch clicks on links to our own pages and turn them into history entries, leaving other origins, data files, the feed, new tabs, downloads and modified clicks to the browser. Verify no document is fetched for an in-site move.
- [x] 2.3 Pin the document base absolute at startup, carrying the reader's `?data=…`. Verify a data request made from a mod address resolves beside the front document, and that sample data survives navigation.

## 3. The published pages

- [x] 3.1 Mark the swappable head region in `site/index.html` and build each mod's page from that document, with its own base, title, description and preview tags.
- [x] 3.2 Read the site's document once per run in `PublicDataBuilder` (`sitePath`, threaded from `PublicSiteStep`); fall back to the small redirecting page with a warning when it cannot be read or has lost its marks.
- [x] 3.3 Pin the marks, and their position above the first relative address, with a test against the real `site/index.html`.

## 4. Checking it

- [x] 4.1 Rewrite the browser tests over a fake browser with a real history stack, so a traversal bug can fail a test. 15 tests, covering both route shapes, Back, Forward, link interception, the pinned base and the empty history state.
- [x] 4.2 `dart test` — the whole suite.
- [x] 4.3 Drive the real site in a browser: open a mod from Browse, Back, Forward, mod to mod, a direct load of a shared address, a nav link from a mod, the skip link, a search suggestion, `?data=sample`, and Browse's scroll position on return. Confirm no reload and no console errors from our own origin.
