## ADDED Requirements

### Requirement: The site has a not-found page
Starmodder SHALL have a `404.html` at the site root. The site step SHALL build it from the site's own `index.html` by replacing only the region between `<!--page-head-->` and `<!--/page-head-->`. The replaced region SHALL hold a "Not found" title, a `noindex` tag, `<base href="/">`, and a mark identifying the document as a not-found page. The page SHALL retain the site's working header, nav, search box, footer and stylesheet, and SHALL use the theme the reader chose. On startup, `app.js` SHALL show the not-found view at the requested address without rewriting that address. Later navigation uses normal routing; returning to the address that returned 404 shows the not-found view again. The view SHALL show the message: "This mod may have been removed at the request of its owner...or it may never have existed in the first place. Or something else." It SHALL link to the front page and to Browse. The page SHALL work on a static host that serves `404.html` for missing files. It SHALL NOT need other server features. When `index.html` cannot be read or its head markers are missing, the site step SHALL write a small plain page with the message and a link to the front page, and log the fallback.

#### Scenario: A removed mod's address
- **WHEN** a reader opens `https://starmodder.wispborne.com/mods/diable-avionics-tidal-fork/` after the takedown is published
- **THEN** the host answers with status 404 and the not-found page, with the site's header, footer and the reader's theme, and the message

#### Scenario: The page works from any folder
- **WHEN** a reader opens a missing address two folders deep, such as `mods/no-such-mod/extra/`
- **THEN** the page's stylesheet and scripts load, and the search box works

#### Scenario: A missing data file gets a not-found response
- **WHEN** the site asks for `mods/<id>.json` for an id that has no file
- **THEN** the host answers with status 404, not with the front page

### Requirement: The mod view tells a missing mod from a failed fetch
The site's mod view SHALL show the same message when the mod's own file returns 404, or when a successful response is not JSON. The latter supports hosts that return the front page for a missing file. This SHALL apply to `#` links such as `#/mods/<id>`. Any other failure, including a connection failure or a server error with an HTML response, SHALL show an error with its reason and SHALL NOT say the mod does not exist.

#### Scenario: A # link to a removed mod
- **WHEN** a reader follows `#/mods/diable-avionics-tidal-fork` after the takedown is published
- **THEN** the page shows the not-found message and no error panel

#### Scenario: The connection drops
- **WHEN** a reader opens a mod's page and the request for `mods/<id>.json` fails with no answer
- **THEN** the page shows an error saying the mod could not be loaded, not the not-found message

### Requirement: The local site server serves the not-found page
`bin/site_server.dart` SHALL answer a missing file with the built `404.html` and status 404, so the page can be checked locally.

#### Scenario: Checking locally
- **WHEN** `http://127.0.0.1:8099/mods/no-such-mod/` is opened on the local site server
- **THEN** the not-found page is shown with status 404
