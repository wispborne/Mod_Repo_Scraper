# mod-page-sharing

## Purpose

Let readers share a mod-specific Starmodder address that link-preview clients can fetch without losing the mod identity in a URL fragment.

## Requirements

### Requirement: A mod's page is its address
Every mod SHALL have a published page at `mods/<id>/`, and that page SHALL be the address the site uses for the mod: every in-site link to a mod SHALL point at it, and the browser address SHALL be it whenever that mod is displayed. The address SHALL preserve any path under which the site is deployed and SHALL carry no `#/mods/<id>` fragment. No separate share action SHALL be required to obtain it.

#### Scenario: Copying the page address
- **WHEN** a reader opens a mod and copies the browser's ordinary page address
- **THEN** the copied address ends in `mods/<id>/` and contains no fragment

#### Scenario: Site hosted below a path
- **WHEN** the site is served from `https://example.test/catalog/` and the reader shares mod `nexerelin`
- **THEN** the shared address is `https://example.test/catalog/mods/nexerelin/`

#### Scenario: Loading a shared address directly
- **WHEN** a reader opens `mods/<id>/` with no prior visit to the site
- **THEN** that mod's page is drawn and the address stays `mods/<id>/`, without bouncing through another address

### Requirement: A shared mod address describes that mod
The shared address SHALL serve the mod-specific page already published for that permanent id. Its link-preview metadata SHALL identify the mod by its displayed name and published summary, or by the existing truthful author-and-game-version fallback when no summary exists, and SHALL include the mod's chosen web picture when one exists.

#### Scenario: Discord fetches the shared address
- **WHEN** Discord fetches a copied mod address
- **THEN** the returned HTML identifies that mod in its Open Graph title and description instead of returning the generic Starmodder description

#### Scenario: The mod has a picture
- **WHEN** a mod with a chosen web picture is shared
- **THEN** the returned HTML offers that picture as the Open Graph image

### Requirement: A mod's page is the site's own document
Each published mod page SHALL be the site's own front document with a single marked head region replaced by that mod's base, title, description and preview metadata, so the site's chrome, styles and scripts are authored once. When the site's front document cannot be read or has lost its marks, the run SHALL log the fact, SHALL still write a page for every mod carrying that mod's preview metadata and a route to it, and SHALL NOT fail.

#### Scenario: A reader lands on a shared address
- **WHEN** a reader opens a shared `mods/<id>/` address
- **THEN** the page they land on is the working site, showing that mod

#### Scenario: The site's own document is unavailable at build time
- **WHEN** the website's own files cannot be read while the data is built
- **THEN** the data files and a preview-carrying page for every mod are still written, and the missing document is reported as a warning

### Requirement: The address is the only record of the current route
The application SHALL derive the displayed route from the browser address alone and SHALL NOT keep the route in browser history state. Traversing Back or Forward SHALL draw the route the resulting address names, whether that address is a mod path or a hash, and SHALL NOT require the site to reload.

#### Scenario: Leaving a mod with the Back button
- **WHEN** a reader opens a mod from a hash-addressed page and then presses Back
- **THEN** the hash-addressed page is drawn again, matching the address shown

#### Scenario: Returning to a mod with the Forward button
- **WHEN** a reader presses Forward after leaving a mod
- **THEN** that mod is drawn again, matching the address shown

#### Scenario: A setting redraws the mod
- **WHEN** a reader changes a display setting while the browser address is `mods/<id>/`
- **THEN** the same mod is drawn again and its visible address stays `mods/<id>/`

### Requirement: Moving between address shapes does not reload the site
A click on a link to any page the site draws SHALL become a browser-history entry that the router draws, without fetching a new document. Links the site does not draw — other origins, published data files, the release feed — and clicks that ask for a new tab, a download or a modified action SHALL be left to the browser.

#### Scenario: Opening a mod from a list
- **WHEN** a reader clicks a mod in a hash-addressed list
- **THEN** the mod is drawn, the address becomes `mods/<id>/`, and no new document is fetched

#### Scenario: Following a hash link from a mod
- **WHEN** a reader follows a hash-based site link while the visible address is `mods/<id>/`
- **THEN** the linked page is drawn without a reload and the link resolves from the site's deployment directory rather than from inside the mod folder

#### Scenario: A link to a published data file
- **WHEN** a reader follows a link to a file such as `mods/<id>.json` or the release feed
- **THEN** the browser fetches it as usual and the router does not treat it as a page

### Requirement: Site files and development data selection survive the moving address
Relative styles, scripts and data requests SHALL continue to resolve against the site's deployment directory while the browser address is a mod path. A `?data=sample` selection present when the site is opened SHALL be preserved across in-site navigation, including on mod addresses.

#### Scenario: Data requested from a mod address
- **WHEN** a mod is displayed and the site requests a published data file
- **THEN** the request resolves beside the site's front document, not inside the mod folder

#### Scenario: Sample data across navigation
- **WHEN** a reader opens the site with `?data=sample` and moves between mods and hash-addressed pages
- **THEN** every page continues to read the sample data
