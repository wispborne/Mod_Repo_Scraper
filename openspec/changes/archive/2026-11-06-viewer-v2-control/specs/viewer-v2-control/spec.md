## ADDED Requirements

### Requirement: Job buttons in the toolbar
While the manager is on, the Control page's toolbar SHALL show four job buttons: "Fetch and update", "Run LLM", "Rebuild from saved" and "Publish", with "Fetch and update" the most prominent. "Fetch and update" SHALL have a drop-down with forum scope, boards, Discord, Nexus and LLM on or off, using today's defaults (new and changed topics, all three boards, Discord on, Nexus off, LLM on). Its button SHALL be disabled, with a reason, when no board and no source is picked. "Run LLM" SHALL have a drop-down with "Only changed" (the default) and "All", and its button SHALL show "All" while "All" is picked. A less prominent "More" menu SHALL offer "Scan images" and "Match dependency names". Every job SHALL require confirmation in a dialog within the page that describes the job in one sentence. A refusal SHALL be shown with the server's own message. With the manager off, no job buttons SHALL be shown.

#### Scenario: Starting a fetch
- **WHEN** the user presses "Fetch and update" with the default options and confirms
- **THEN** a `fetchAndUpdate` job is sent with scope `newData`, boards main, lesser and libraries, sources Discord, LLM on

#### Scenario: Run LLM, All
- **WHEN** the user picks "All" in the Run LLM drop-down, presses the button and confirms
- **THEN** a `llmCoveragePass` job is sent with `llmRereadAll` set, and the dialog said that every post may be read again up to the call limit and that LLM calls may cost money

#### Scenario: Nothing to fetch
- **WHEN** every board, Discord and Nexus are unticked
- **THEN** the "Fetch and update" button cannot be pressed, and the drop-down says to choose a board or source, or to use "Rebuild from saved"

### Requirement: Run panel
The central panel SHALL show the running job: its name, an outlined "Running" tag, its phase and current item, a progress bar split into parts with the count done and the total, its live counters (errors, LLM calls), how long it has run, and a Stop button that asks first. When nothing runs, it SHALL show the last finished run with its state, when it ended, how long it took, its counters and "Run again". The panel SHALL have three tabs: Log (the latest log lines), What it changed (a link to the comparison of this run's details with the run before, or with the data on disk while it runs) and Record (the run's settings, times and any error or limit reached). The log SHALL keep the reader's scroll position and selection, and follow new lines only while the reader is at the bottom.

#### Scenario: A job is running
- **WHEN** a job is running
- **THEN** the panel shows its progress and counters, updated about once a second, and new log lines appear without moving a reader who has scrolled up

#### Scenario: Nothing is running
- **WHEN** no job runs and there is a finished run
- **THEN** the panel shows that run with "Run again"

#### Scenario: Stopping
- **WHEN** the user presses Stop and confirms
- **THEN** the server is asked to stop that run, naming its id

### Requirement: Side panels on the Control page
The side panels SHALL be, in order: Needs attention, Queue and Recent runs. Needs attention SHALL list only items with a count above zero, each with its count and a link to where it can be fixed, and SHALL be hidden when there are none. Its items are: dependency names not matched, author pairs to decide, takedown entries that excluded nothing, taken-down mods back under a new id, posts with no LLM answer, the last run's errors, and mods with no download. The counts SHALL be requested when the page opens and again when a run ends. Queue SHALL list the waiting jobs. Recent runs SHALL list the latest runs, each with a diamond in its state's colour, and a link to the full run history.

#### Scenario: Something needs attention
- **WHEN** 7 dependency names matched no mod and nothing else needs attention
- **THEN** the Needs attention panel shows one item, "Dependency names not matched", with 7

#### Scenario: Nothing needs attention
- **WHEN** every count is zero and the last run had no errors
- **THEN** no Needs attention panel is drawn

### Requirement: Narrow screens on the Control page
On a screen narrower than 640 pixels, the job buttons SHALL wrap onto more lines rather than leave the screen, and the side panels SHALL be below the run panel.

#### Scenario: Phone width
- **WHEN** the Control page is opened 375 pixels wide while a job runs
- **THEN** every job button and the Stop button can be reached without scrolling sideways
