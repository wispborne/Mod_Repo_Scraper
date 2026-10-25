# browse-filter-memory Specification

## Purpose
When Browse remembers its filters, and when a link into Browse leaves them alone.

## Requirements
### Requirement: Browse remembers filters changed on Browse

Browse SHALL save its filters, search text and sort to the browser's storage under `starmodderBrowseFilters` only when the reader changes a control on Browse itself: the search box, a filter, the sort, Shuffle, "Include N for other game versions", "Clear AI filter", "Clear filters", or picking a saved filter. Changing pages SHALL NOT count as changing a control. Browse SHALL NOT remember the page number.

#### Scenario: Changing a filter on Browse

- **WHEN** a reader opens Browse and turns on "Has a download"
- **THEN** the next visit to Browse without a query in the address opens with "Has a download" on

### Requirement: Opening a link to Browse does not change remembered filters

When Browse is opened from an address that carries filters (a link from Home, a shared link, the top search box, a link on a mod page), Browse SHALL show that address's list and SHALL NOT replace the remembered filters until the reader changes a control on Browse. After the reader changes a control, Browse SHALL remember the choices on the page at that moment.

#### Scenario: A shared link

- **WHEN** a reader with "Faction Mods" remembered opens a shared link to Browse with category "Ship Packs", then later opens Browse from the top bar
- **THEN** Browse opens on "Faction Mods"

#### Scenario: Changing filters after opening a link

- **WHEN** a reader opens a link to Browse with category "Ship Packs" and then turns on "Has a download"
- **THEN** Browse remembers "Ship Packs" with "Has a download"

#### Scenario: Opening Browse without a query

- **WHEN** a reader opens Browse without a query in the address
- **THEN** Browse opens on the remembered filters, on the first page, as it does today
