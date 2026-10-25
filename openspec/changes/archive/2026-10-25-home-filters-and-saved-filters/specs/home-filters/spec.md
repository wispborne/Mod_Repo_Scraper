## ADDED Requirements

### Requirement: Home has a filter bar at the top

Home SHALL show a filter bar at the top of the page, above the AI summary banner. The bar SHALL start closed on every visit. When closed, the bar SHALL list the filters in use or show the name of the saved filter they match exactly. It SHALL offer a "Clear" link whenever any filter is on. Opening the bar SHALL show the filter controls.

#### Scenario: The bar starts closed

- **WHEN** a reader opens Home, whether or not they left the bar open last time
- **THEN** the bar is closed

#### Scenario: The closed bar lists the filters in use

- **WHEN** Home's filters are set to game version 0.98a and "Has a download"
- **THEN** the closed bar names both, for example "Filters: 0.98a · Has a download"

#### Scenario: The closed bar names a matching saved filter

- **WHEN** Home's filters match a saved filter called "My 0.98 setup" exactly
- **THEN** the closed bar shows "My 0.98 setup" instead of listing the filters

#### Scenario: All filters are off

- **WHEN** no filter is on
- **THEN** the closed bar only identifies the filter controls and shows no "Clear" link

### Requirement: Home's filters are Browse's filters without search, sort and layout

Home's filters SHALL be the game version, the category, the requires choice, the four three-state switches and the AI use filter, with the same choices and meanings as on Browse. Home SHALL NOT offer search text, sort, page, cards or rows, or the top or side layout.

#### Scenario: A switch works as on Browse

- **WHEN** a reader sets "Safe to add mid-game" to its "not" state on Home
- **THEN** Home keeps only the mods whose author says they are not safe to add, as Browse would

#### Scenario: No search box

- **WHEN** a reader opens Home's filter bar
- **THEN** it has no search box or sort control

### Requirement: Home starts with all filters off

Home SHALL start with all filters off. It SHALL show mods for every game version. "Clear" SHALL return Home's filters to that state, not to Browse's starting state.

#### Scenario: A first visit

- **WHEN** a reader who has never set Home's filters opens Home
- **THEN** Home shows the same mods and releases it shows today, for every game version

#### Scenario: Clear

- **WHEN** a reader with Home's filters set presses "Clear"
- **THEN** every filter is off and every game version is shown

### Requirement: Home's filters are kept in the browser only

Home's filters SHALL be kept in the browser's storage under `starmodderHomeFilters` and SHALL NOT appear in the address. Home's address SHALL stay `#/home`. When storage cannot be read or written, Home SHALL start with all filters off.

#### Scenario: Reloading keeps the filters

- **WHEN** a reader sets Home's filters and reloads the page
- **THEN** the same filters are on, and the address is still `#/home`

#### Scenario: Storage blocked

- **WHEN** the browser refuses storage
- **THEN** Home starts by showing every mod, and its filters work for the rest of the visit

### Requirement: Home's filters apply to the whole page

Home's filters SHALL apply to Recently added, to Browse by category, and to Recent updates. Recently added SHALL filter the mods first and then take the 24 newest. The category counts SHALL count only mods that pass every filter except the category. The chosen category SHALL be marked as chosen. Recent updates SHALL show a release only when its mod matches the filters. A release for a mod missing from the mod list SHALL be hidden while any filter is on. It SHALL be shown when all filters are off. The AI summary banner and the feed link SHALL NOT be filtered.

#### Scenario: Recently added shows 24 matching mods

- **WHEN** a filter hides 10 of the 24 newest mods
- **THEN** Recently added shows the 24 newest mods that match the filters, not 14

#### Scenario: Category counts ignore the chosen category

- **WHEN** Home's category filter is "Faction Mods"
- **THEN** every category in the table still shows how many mods it would show, and "Faction Mods" is marked as chosen

#### Scenario: A release for a hidden mod

- **WHEN** a release belongs to a mod for game version 0.97a and Home's filters are on 0.98a
- **THEN** that release is not shown

#### Scenario: A release with no mod record

- **WHEN** a release names a mod that is not in the mod list
- **THEN** it is shown while no filter is on and hidden while any filter is on

### Requirement: Empty sections explain when filters have hidden everything

When Home's filters hide everything in a section, that section SHALL keep its heading. It SHALL show "Everything is hidden by your filters."

#### Scenario: Filters hide all recent updates

- **WHEN** releases exist but none match Home's filters
- **THEN** Recent updates keeps its heading and shows "Everything is hidden by your filters."

#### Scenario: No releases at all

- **WHEN** there are no releases recorded and no filter is on
- **THEN** Recent updates shows its usual "No releases yet" notice

### Requirement: Copy from Browse

Home's filter bar SHALL offer a "Copy filters from Browse page" button that replaces Home's filters with the filters Browse remembers, leaving out Browse's search text and sort. When Browse remembers nothing, the button SHALL copy what Browse would show if opened now, which is the current game release with nothing else on. Copying SHALL NOT change Browse's remembered filters. No other action on Home SHALL change them.

#### Scenario: Copying a set

- **WHEN** Browse remembers category "Faction Mods", "Has a download" and the search "nex", and the reader presses "Copy filters from Browse page" on Home
- **THEN** Home's filters become category "Faction Mods" and "Has a download", with no search

#### Scenario: Browse remembers nothing

- **WHEN** a reader who has never used Browse presses "Copy filters from Browse page"
- **THEN** Home's filters become the current game release and nothing else

#### Scenario: Home never changes Browse's remembered filters

- **WHEN** a reader changes, clears or copies Home's filters
- **THEN** Browse's remembered filters are unchanged

### Requirement: Home's links to Browse include Home's filters

The "See all →" links and the category buttons on Home SHALL open Browse with Home's filters in the address, plus what the link itself adds (the newest-first sort, or the button's category in place of Home's). Links SHALL always include Home's game version choice. When Home's filters are off, the links SHALL open Browse for every game version, as on Home.

#### Scenario: See all from Recently added

- **WHEN** Home's filters are "Has a download" and the reader presses "See all →" under Recently added
- **THEN** Browse opens sorted newest first with "Has a download" on and every game version shown

#### Scenario: A category button

- **WHEN** Home's category is "Faction Mods" and the reader presses the "Ship Packs" button
- **THEN** Browse opens on "Ship Packs" with Home's other filters

#### Scenario: A category button with all filters off

- **WHEN** no filter is on Home and the reader presses the "Ship Packs" button
- **THEN** Browse opens on "Ship Packs" for every game version, not only the current release
