# saved-filters Specification

## Purpose
The reader's named filter sets, shared by Home and Browse.

## Requirements
### Requirement: Saved filters are one list shared by Home and Browse

The site SHALL keep the reader's saved filters as one list in the browser's storage under `starmodderSavedFilters`. Each saved filter SHALL have a name and a set of filters. The same list SHALL be offered on Home and on Browse, in both of Browse's layouts. The list SHALL start empty, with no built-in entries. When storage cannot be read, the list SHALL be empty and the pages SHALL still work.

#### Scenario: Saved on Browse, used on Home

- **WHEN** a reader saves a filter on Browse and then opens Home's filter bar
- **THEN** the saved filter is in Home's list

#### Scenario: A first visit

- **WHEN** a reader who has never saved a filter opens the menu
- **THEN** it lists no saved filters and offers "Save current filters…"

### Requirement: A saved filter contains the same fields as Home's filters

A saved filter SHALL hold the game version, the category, the requires choice, the four three-state switches and the AI use filter, and nothing else. Applying a saved filter SHALL replace those fields and SHALL leave the search text and the sort as they are.

#### Scenario: Applying on Browse keeps the search

- **WHEN** a reader has typed "nex" on Browse and picks a saved filter
- **THEN** the search still says "nex" and the filters are the saved filter's

#### Scenario: Saving on Browse leaves out the search

- **WHEN** a reader saves a filter on Browse while the search says "nex" and the sort is Newest
- **THEN** the saved filter holds no search text and no sort

### Requirement: Filters saved for the current release follow game updates

When a reader saves a filter with the current game release selected, the saved filter SHALL record "the current release", not that version. Applying it SHALL use whichever release is current at that time. Any other game version choice SHALL be recorded as it is.

#### Scenario: The game updates

- **WHEN** a reader saved a filter while 0.98a was current, and the site's current release is now 0.99a
- **THEN** applying the filter shows mods for 0.99a

#### Scenario: A filter for an older release keeps that version

- **WHEN** a reader saved a filter on 0.97a while 0.98a was current
- **THEN** applying it shows mods for 0.97a, whatever is current

### Requirement: Saving, replacing and deleting

The menu SHALL offer "Save current filters…", which asks for a name. A blank name SHALL NOT be saved. Saving under a name already in the list SHALL ask before replacing that entry. Each entry SHALL have a delete button that deletes it at once and offers Undo. Readers SHALL NOT be able to rename a saved filter. They SHALL NOT be able to edit it in place.

#### Scenario: Replacing

- **WHEN** a reader saves under a name already in the list
- **THEN** the site asks before replacing it, and keeps the old one if the reader says no

#### Scenario: Deleting

- **WHEN** a reader deletes a saved filter
- **THEN** it leaves the list at once, and pressing Undo puts it back where it was

### Requirement: Applying a saved filter

Picking a saved filter on Browse SHALL count as a change made on Browse, so Browse remembers the result. Picking one on Home SHALL set Home's filters and SHALL NOT change Browse's remembered filters.

#### Scenario: Picking on Home

- **WHEN** a reader picks a saved filter on Home
- **THEN** Home's filters become the saved filter's and Browse's remembered filters are unchanged

### Requirement: The name of the saved filter in use

While the filters on a page match a saved filter exactly, the page SHALL show that saved filter's name: in the menu, and on Home in the closed bar. When the filters stop matching, the name SHALL no longer be shown. Changing the filters SHALL NOT change the saved filter. The page SHALL find the matching saved filter by comparing filters. It SHALL NOT store which saved filter is in use.

#### Scenario: A change after applying

- **WHEN** a reader picks "My 0.98 setup" and then turns on one more switch
- **THEN** the name is no longer shown, and "My 0.98 setup" itself is unchanged

### Requirement: The words "Saved filters"

The site SHALL call these filters "Saved filters" or "saved filter". The site SHALL use "preset" only for the AI use filter's choices.

#### Scenario: The menu's label

- **WHEN** a reader looks at the menu on Home or Browse
- **THEN** it is labelled "Saved filters"
