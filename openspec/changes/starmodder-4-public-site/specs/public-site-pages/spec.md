## ADDED Requirements

### Requirement: The site is read-only and needs no server
The public site SHALL be plain HTML, CSS and JavaScript with no build step, and SHALL
get all its data by fetching the published files. It SHALL offer no way to start a job,
change data or reach the manager. It SHALL work when opened from any static host.

#### Scenario: Nothing can be changed from the site
- **WHEN** any page of the public site is loaded
- **THEN** it makes only read requests for published files, and offers no button that changes anything

### Requirement: The site depends on nothing a plain web server cannot do
The site SHALL be servable by any static web server. It SHALL NOT use Cloudflare Workers,
Pages Functions, Cloudflare redirect rules, or any other host-specific feature. It SHALL
fetch its data from the same origin the pages are served from, so it needs no
cross-origin permission and no third-party host.

#### Scenario: Moving to a different host
- **WHEN** the site's folder is copied to an ordinary web server instead of Cloudflare Pages
- **THEN** every page and every data fetch works, with no change to the files

#### Scenario: Data comes from the same place as the pages
- **WHEN** any page fetches `mods.json`, `updates.json` or a per-mod file
- **THEN** it fetches from its own origin, not from GitHub or any other host

### Requirement: The home page leads with recent releases
The home page SHALL show the mods that have put out a new version, newest first, grouped
by day. Each row SHALL show the mod's name, its new version, and a way to open that
version's changelog notes where there are any. The page SHALL also carry a search box and
a short strip of mods added recently.

#### Scenario: A release with notes
- **WHEN** a release in the feed has changelog notes
- **THEN** the row can be opened to show those notes, as the author wrote them

#### Scenario: The feed is empty
- **WHEN** no releases have been recorded yet
- **THEN** the page says so plainly and still shows search and recently added mods

### Requirement: Browse shows every mod, with search, filters and sorting
The browse page SHALL list every mod, as a grid of cards or as rows, the reader's choice.
It SHALL offer search, and filters for game version and category, and switches for save
compatible, has a direct download, source code is public, and hide works in progress. It
SHALL offer sorting by name, by newest, by most recently updated, and by current game
version first. There SHALL be no author dropdown — search already covers authors, and a
list of hundreds of names cannot be used.

#### Scenario: Filters narrow the list
- **WHEN** the reader picks a game version and turns on save compatible
- **THEN** only mods matching both are listed, and the count of matches is shown

#### Scenario: Nothing matches
- **WHEN** the search and filters leave no mods
- **THEN** the page says nothing matched and offers to clear the filters

### Requirement: Browse opens on mods a reader can use
Browse SHALL open sorted with mods built for the current game release first, then by
most recent release, then by name. Mods for older game releases SHALL be left out to
begin with, behind a switch that is on, and the page SHALL say how many are hidden and
offer one click to include them. The current game release SHALL be worked out from the
data: the highest game version enough mods are built for.

Game versions that only differ in how they are spelled — "0.98", "0.98a" and
"0.98a-RC8" — SHALL be one filter choice, shown with the spelling most mods use and how
many mods it covers.

#### Scenario: Opening Browse
- **WHEN** the reader opens Browse with no filters set
- **THEN** the list holds only mods for the current game release, most recent first, and says how many older ones are hidden

#### Scenario: Picking an older game version
- **WHEN** the reader picks an older game version from the dropdown
- **THEN** those mods are listed, because their own choice overrules the switch

### Requirement: Search is in the bar at the top, on every page
The site SHALL carry one search box in the bar at the top of every page. Typing in it
SHALL show up to five matching mod names straight away, each a link to that mod. Enter
SHALL open Browse with the search filled in. The "/" key SHALL put the cursor in the box
from anywhere on the page, unless the reader is already typing into something.

#### Scenario: Searching from a mod page
- **WHEN** the reader is on one mod's page and types into the search box
- **THEN** matching mods are suggested without leaving the page

### Requirement: A page for everyone with a mod here
The site SHALL have a page listing every person credited on a mod, with how many mods
each has, the ones with the most first. Each name SHALL link to that person's own page.

#### Scenario: Finding somebody's mods
- **WHEN** the reader opens the people page and picks a name
- **THEN** they see every mod credited to that person, however their name was spelled

### Requirement: An About page, and a way to report a problem
The site SHALL have an About page saying where the data comes from, how often it is
collected, what "AI" means here and how to turn it off, how releases are worked out, and
how to get a wrong entry fixed or a mod taken down. It SHALL be linked from the bar at
the top and from the foot of every page. Every mod page SHALL carry a link at its foot
that opens a report naming that mod.

#### Scenario: A mod author finds a wrong entry
- **WHEN** they open a mod's page and follow the report link
- **THEN** a report opens already naming the mod and its address

### Requirement: Moving between pages starts at the top
Every route change SHALL put the page at its top. Coming back to Browse SHALL be the one
exception: it SHALL return to where the reader left off, and only when the list is the
same one they left.

#### Scenario: Home to Browse
- **WHEN** the reader follows a link from the foot of Home
- **THEN** the new page starts at its top

#### Scenario: Back from a mod page
- **WHEN** the reader goes back to the same Browse list they came from
- **THEN** the page is where they left it

### Requirement: Search covers name, author, category and description
Search SHALL match on a mod's name, its authors including the other names those authors
are known by, its categories and its description. Several terms separated by commas SHALL
all be searched for, and a term starting with a minus SHALL leave matching mods out.

#### Scenario: Searching by another name for the author
- **WHEN** the reader searches for "histidine_my"
- **THEN** mods credited to Histidine are found

#### Scenario: Leaving results out
- **WHEN** the reader searches for "faction, -portrait"
- **THEN** mods matching "faction" are listed except those matching "portrait"

### Requirement: What the reader is looking at is in the address
The search text, the filters, the sort order and the page number SHALL be kept in the
page address. Opening that address again SHALL bring back the same list.

#### Scenario: Sharing a filtered list
- **WHEN** the reader copies the address of a filtered list and opens it again
- **THEN** the same search, filters, sort and page are in place

### Requirement: Every mod has its own page at a permanent address
Each mod SHALL have a page at an address built from its permanent id. The page SHALL show
the mod's name, authors, version, game version and whether it can be added to an existing
save; its download buttons; its screenshots; its description; its changelog by version;
its links to the forum thread, Discord, Nexus and source code; its license; and any links
for supporting the author. Where older threads for the same mod are known, the page SHALL
list them as older versions.

#### Scenario: The mod releases a new version
- **WHEN** a mod's name changes because its thread title changed
- **THEN** its page is still at the same address

#### Scenario: A field the mod has no answer for
- **WHEN** a mod has no license, no source code link and no support links
- **THEN** those parts of the page are left out entirely rather than shown empty

#### Scenario: Text the LLM wrote
- **WHEN** a mod's summary was written by the LLM rather than copied from the post
- **THEN** the page marks it as such

### Requirement: The reader can turn AI-written summaries off
The site SHALL offer a checkbox that hides every summary the LLM wrote in its own words.
It SHALL be on by default. The choice SHALL be kept in a cookie so it holds between
visits, and SHALL apply everywhere a summary appears — the browse cards, the mod page and
the author page.

#### Scenario: Turning summaries off
- **WHEN** the reader unticks the AI summaries checkbox
- **THEN** every AI-written summary disappears from the page, and words copied from the author's post stay

#### Scenario: The choice holds
- **WHEN** the reader unticks the checkbox and comes back to the site later
- **THEN** AI summaries are still hidden

#### Scenario: A mod with nothing else to show
- **WHEN** AI summaries are off and a mod's only description was AI-written
- **THEN** the mod still appears in the list, with no description rather than a gap or a placeholder

### Requirement: Every author has a page
Each author SHALL have a page listing every mod credited to them, with the other names
they are known by folded in. A mod page's author name SHALL link to it.

#### Scenario: One person under several names
- **WHEN** an author's mods are credited to two spellings of their name across sources
- **THEN** one author page lists all of them

### Requirement: The site says how fresh it is
Every page SHALL say when the data it is showing was last collected.

#### Scenario: Showing the age of the data
- **WHEN** any page is loaded
- **THEN** it shows when the published files were last built

### Requirement: The site works on a phone
Every page SHALL be usable on a phone-sized screen, with no sideways scrolling of the
page itself.

#### Scenario: Browsing on a phone
- **WHEN** the browse page is opened on a narrow screen
- **THEN** the cards, filters and sort controls all fit and can be used

### Requirement: Categories are a row of chips, not a dropdown
Home and Browse SHALL show the site's categories as a row of chips, each with
how many mods are on it, biggest first. On Browse a chip SHALL filter the list,
and pressing the chip that is already on SHALL clear it. There SHALL be no
category dropdown.

#### Scenario: Browsing by kind
- **WHEN** a reader opens Home
- **THEN** every category is on screen at once with its count, and each one opens Browse filtered to it

### Requirement: A mod page says what the mod needs, before the download
A mod's page SHALL show the other mods it will not run without, directly under
the header and above the download. Each SHALL be a link where this site has a
page for it. Where a mod needs nothing, nothing SHALL be shown.

#### Scenario: A mod that needs LazyLib
- **WHEN** a reader opens a mod whose post says it requires LazyLib
- **THEN** they see that before the download button, and can follow it to LazyLib's page

### Requirement: The feed is offered from every page
Every page SHALL offer the release feed: as a link in the bar at the top and at
the foot, and as the page's own feed declaration so a feed reader finds it
without being told where to look.

### Requirement: A mod's page answers a reader's questions in order
A mod's page SHALL open with the mod's picture beside its name, the people who
made it, its version, the game version it is for, and whether it can be added to
an existing save — followed straight away by the buttons that get it.

The first button SHALL be a download where the mod has one. Where it has none,
the first button SHALL be the forum thread, or failing that Discord or Nexus
Mods, so no mod's page is a dead end. The thread SHALL be on the page either
way.

The page SHALL end with the rest of that person's mods and other mods on the
same shelves, so it leads somewhere rather than stopping.

#### Scenario: A mod with no download link
- **WHEN** a mod has no link that goes straight to a file
- **THEN** its first button is "Get it from the forum thread", not nothing at all

#### Scenario: Where to go next
- **WHEN** a reader reaches the foot of a mod's page
- **THEN** they are shown other mods by the same people and others of the same kind

### Requirement: Screenshots open over the page
A screenshot SHALL open over the page rather than as a raw image in a new tab.
The reader SHALL be able to move between screenshots and close it with the
keyboard, and closing it SHALL leave them where they were.

#### Scenario: Looking through the screenshots
- **WHEN** a reader opens one screenshot and presses the right arrow
- **THEN** the next one is shown, and Escape puts them back on the page they were reading

### Requirement: A reader can build and share a mod list
The site SHALL let a reader tick mods into a list of their own. The list SHALL
be kept in their own browser and SHALL NOT be sent anywhere. It SHALL be shown
on one page with every mod's download links, and the page SHALL name anything
the listed mods need that is not itself in the list.

The list SHALL be shareable as a single address carrying the ids, so somebody
following that link sees the same list without an account and without anything
being stored for them. A reader looking at somebody else's list SHALL be told
whose it is and SHALL be able to make it their own.

#### Scenario: Building a list
- **WHEN** a reader ticks a mod on the browse page
- **THEN** it is added to their list without leaving the page, and the count in the bar at the top goes up

#### Scenario: Sharing it
- **WHEN** a reader copies the link to their list and somebody else opens it
- **THEN** they see the same mods, told plainly that it is somebody else's list

#### Scenario: A mod in the list has gone
- **WHEN** a shared list names a mod this site no longer has
- **THEN** the page says so and how many, rather than quietly leaving it out
