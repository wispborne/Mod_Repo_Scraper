## ADDED Requirements

### Requirement: Every page uses the same frame
Every page of the new viewer SHALL be drawn inside one frame: a nav rail down the left edge, a toolbar across the top of the page, the page's content below the toolbar, and a status bar along the bottom edge. The content SHALL be a large central panel, optionally with side panels stacked on its right. The frame SHALL be drawn once and kept when the reader moves between pages. Only the toolbar's contents and the page's content are redrawn.

#### Scenario: Moving between pages
- **WHEN** the reader moves from one page to another
- **THEN** the nav rail and status bar stay in place, and the toolbar and content show the new page

### Requirement: Nav rail
The nav rail SHALL hold one icon link per page, in three groups in this order, with a short line between groups: Operate (Control, Run history, Settings), Correct (Takedowns, Author aliases, Dependency names), Investigate (Mods, Source posts, What changed, Catalog explorer, LLM test report, Files). Each icon SHALL show only its page name on hover or keyboard focus, and its accessible label SHALL be the page name. The current page's icon SHALL be drawn in the Action colour and marked as the current page for screen readers. A detail page SHALL highlight the icon of the page it belongs to.

#### Scenario: Hovering over an icon
- **WHEN** the reader hovers over the Takedowns icon
- **THEN** a label reading "Takedowns" appears beside it, and no group name is shown

#### Scenario: Keyboard focus
- **WHEN** the reader moves keyboard focus onto an icon
- **THEN** the same label appears as on hover

#### Scenario: Current page
- **WHEN** the Run history page is open
- **THEN** its icon is in the Action colour and carries `aria-current="page"`, and no other icon does

### Requirement: Toolbar
Each page's toolbar SHALL show the page name in small mono capitals, the page's own buttons, the Pending changes count, and the search box at the right. The Pending changes count SHALL be read from the browser's session storage and SHALL be shown only when it is above zero. Pressing "/" anywhere outside a text box SHALL put the cursor in the search box.

#### Scenario: No pending changes
- **WHEN** there are no pending changes in this browser session
- **THEN** the toolbar shows no Pending changes count

#### Scenario: Slash focuses search
- **WHEN** the reader presses "/" while not typing in a text box
- **THEN** the cursor moves into the search box and no "/" is typed

### Requirement: Temporary search
Until the new viewer has its own search, the search box SHALL send the reader to the old viewer when Enter is pressed. A forum topic address, a bare topic id, or a Discord thread address SHALL open that post's page in the old viewer. Any other text SHALL open the old viewer's Topics list with a search for that text. An empty search box SHALL do nothing.

#### Scenario: Pasting a forum address
- **WHEN** the reader pastes `https://fractalsoftworks.com/forum/index.php?topic=18011.0` and presses Enter
- **THEN** the old viewer opens on topic 18011

#### Scenario: Typing a name
- **WHEN** the reader types "nexerelin" and presses Enter
- **THEN** the old viewer opens its Topics list with a search for "nexerelin"

### Requirement: Side panels fold
Each side panel SHALL have a heading bar showing its name and, a count if it has one. Pressing the heading bar SHALL fold or open the panel. The heading SHALL be a button reachable by keyboard, and it SHALL indicate whether the panel is open. The browser SHALL remember which panels are folded, by panel name, across pages and reloads. When local storage cannot be used, panels SHALL start open and still allow folding during the visit.

#### Scenario: Folding a panel
- **WHEN** the reader presses the Recent runs heading
- **THEN** the panel's contents are hidden, and they stay hidden after a reload

### Requirement: Status bar
The status bar SHALL show, from left to right: the manager's state (a diamond mark and "Running", "Ready" or "Viewing only"), the running job's name and progress as a bar split into parts with its percentage, how many jobs are waiting (only when there are any), and at the right the build version and, when a newer release is out, an Update link. The state SHALL be read from the manager's status once a second while a job runs or waits, and every five seconds otherwise. No status requests are made while the tab is hidden. The build version SHALL come from the version route and SHALL be left out when it is unknown. The Update link SHALL follow the current update rules: it shows only when the server says an update is possible, it asks for confirmation in a dialog within the page, and it watches the update and reloads the page once the new build answers.

#### Scenario: A job is running
- **WHEN** a Fetch and update job is 40% done and one more job is waiting
- **THEN** the status bar shows a diamond in the Running colour, "Fetch and update", a split progress bar at 40%, "40%", and "1 waiting"

#### Scenario: Manager off
- **WHEN** the manager is off
- **THEN** the status bar shows a grey diamond and "Viewing only", and no job or waiting count

### Requirement: Tab title follows the run
While a job is running, the browser tab's title SHALL start with "▶", the job's name and its percentage. After a job shown as running on the page has ended, the title SHALL start with "✓ Done" or "✗ Failed" until another job starts or the reader moves to another page. Otherwise the title SHALL be the page name and the viewer's name.

#### Scenario: A run fails
- **WHEN** the page showed a running job and that job then fails
- **THEN** the tab title starts with "✗ Failed"

### Requirement: Colours and appearance
The new viewer SHALL use only the colours named in `docs/viewer-redesign-requirements.md` (Background, Panel, Raised, Line, Frame, Text, Dim text, Faint text, Heading, Action, Running, Done, Failed, Warning), each defined once as a named value and used for its stated purpose. It SHALL use IBM Plex Sans for words and IBM Plex Mono for numbers, ids, times and logs, both served from the `web2/` folder. Corners SHALL be square. Buttons SHALL have their top-right and bottom-left corners cut. The central panel SHALL have small corner brackets in the Action colour. Status marks SHALL be small diamonds. "Running" SHALL be an outlined tag. The viewer SHALL be dark only. Nothing SHALL load from the internet: fonts and icons are part of the folder.

#### Scenario: No outside requests
- **WHEN** any page of the new viewer is opened
- **THEN** every request the page makes goes to the viewer's own server

### Requirement: Pages not built yet
Every page in the nav rail SHALL exist. A page not yet built SHALL say so in one sentence and link to the page in the old viewer that does the same work, when one exists. The link SHALL lead to the old viewer wherever it is being served (at `/` or at `/v1/`). The Control page SHALL also show the real queue and the most recent runs in side panels. When the manager is off, the Control page SHALL say "Viewing only" and how to turn the manager on, in one sentence.

#### Scenario: Opening a page not built yet
- **WHEN** the reader opens Takedowns in the new viewer
- **THEN** the page says it is not built yet and links to the old viewer's Takedowns page

#### Scenario: Unknown address
- **WHEN** the reader opens an address that does not match any page
- **THEN** the page says the address does not match any page, and the frame remains visible

### Requirement: Narrow screens
On a screen narrower than 640 pixels, the nav rail SHALL become a strip across the top that scrolls sideways. Side panels SHALL go below the central panel. The status bar SHALL stay at the bottom with all required information visible. The waiting count and version may be left out.

#### Scenario: Phone width
- **WHEN** the Control page is opened 375 pixels wide
- **THEN** the page does not scroll sideways, the side panels are below the central panel, and the status bar shows the manager's state
