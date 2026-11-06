## ADDED Requirements

### Requirement: One viewer, and the former addresses
The server SHALL serve the viewer from `web/` at `/`. A request for `/v1` or `/v2`, or for any path under `/v1/` or `/v2/`, SHALL be redirected to the same path without that prefix, preserving the query string. A path that only starts with those letters, such as `/v2x/`, SHALL NOT be redirected.

#### Scenario: A bookmark from when two viewers were served
- **WHEN** the browser asks for `/v2/` with `#/runs` after it
- **THEN** the server redirects to `/`, and the browser opens `/#/runs`

#### Scenario: A file under the old prefix
- **WHEN** the browser asks for `/v1/style.css`
- **THEN** the server redirects to `/style.css`

### Requirement: Live reload watches the viewer
When the server is started with `--reload`, open pages SHALL reload when a file in `web/` changes.

#### Scenario: Editing the viewer
- **WHEN** a file in `web/` is saved while the server runs with `--reload`
- **THEN** open pages of the viewer reload

## MODIFIED Requirements

### Requirement: Every list lets the reader choose how many rows a page holds
Every paged list in the viewer SHALL offer a choice of rows per page — including all of them on one page — next to its page buttons. The choice SHALL be one setting for the whole site, remembered in the browser between views and across reloads. With every row on one page, the page buttons SHALL NOT be drawn, and the row SHALL say how many rows are being shown rather than which page of how many.

#### Scenario: Reading a long list in one go
- **WHEN** the user picks "all on one page" on the Mods list
- **THEN** every matching mod is shown, no page buttons are drawn, and the row says how many there are

#### Scenario: The choice sticks
- **WHEN** the user picks 250 rows on one list and then opens another list, or reloads the page
- **THEN** that list also shows 250 rows a page

#### Scenario: Changing the size goes back to the first page
- **WHEN** the user is on page 4 and changes the rows per page
- **THEN** the list reloads at the first page, so the rows on screen are the ones the new setting describes

## REMOVED Requirements

### Requirement: The server serves both viewers
**Reason**: The new viewer replaced the old one, which is deleted.
**Migration**: The viewer is at `/`. `/v1/` and `/v2/` addresses redirect there. Drop `--ui` and `--web2-dir` from any command line.

### Requirement: Live reload watches both viewers
**Reason**: There is one viewer folder.
**Migration**: See "Live reload watches the viewer".
