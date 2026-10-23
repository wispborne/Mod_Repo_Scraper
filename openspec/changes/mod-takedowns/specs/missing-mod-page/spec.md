## ADDED Requirements

### Requirement: The site has a not-found page
Starmodder SHALL have a `404.html` at the site root. It SHALL show the site's header and footer. It SHALL use the site's stylesheet and show the message: "This mod may have been removed at the request of its owner...or it may never have existed in the first place. Or something else." Its file addresses SHALL work from any folder under the site root. The host serves this page for any missing file. It SHALL link to the front page and to Browse. It SHALL work on a static host that serves `404.html` for missing files. It SHALL NOT need other server features.

#### Scenario: A removed mod's address
- **WHEN** a reader opens `https://starmodder.wispborne.com/mods/diable-avionics-tidal-fork/` after the takedown is published
- **THEN** the host answers with status 404 and the not-found page, styled, with the message

#### Scenario: A missing data file gets a not-found response
- **WHEN** the site asks for `mods/<id>.json` for an id that has no file
- **THEN** the host answers with status 404, not with the front page

### Requirement: The mod view shows the same message
When a mod's own file cannot be found, the site's mod view SHALL show the same message instead of an error. This SHALL apply to `#` links such as `#/mods/<id>`. It SHALL also apply to any response that is not the mod's JSON.

#### Scenario: A # link to a removed mod
- **WHEN** a reader follows `#/mods/diable-avionics-tidal-fork` after the takedown is published
- **THEN** the page shows the not-found message and no error panel

### Requirement: The local site server serves the not-found page
`bin/site_server.dart` SHALL answer a missing file with `site/404.html` and status 404, so the page can be checked locally.

#### Scenario: Checking locally
- **WHEN** `http://127.0.0.1:8099/mods/no-such-mod/` is opened on the local site server
- **THEN** the not-found page is shown with status 404
