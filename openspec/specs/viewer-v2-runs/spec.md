# viewer-v2-runs Specification

## Purpose
TBD - created by archiving change viewer-v2-runs. Update Purpose after archive.
## Requirements
### Requirement: Run history page
The Run history page SHALL list every saved run, newest first, one row each, with its state (a diamond in the state's colour and the state's name), job, start time, how long it took, how much it did, its errors, its LLM calls, and a note when it reached the call limit or failed. Each row SHALL link to its run page. The list SHALL be paged with the rows-per-page choice (25, 50, 100, 250, 500 or all on one page) shared by every list in the viewer and remembered in the browser. The page number SHALL be kept in the address, without adding a browser history entry for each page. The list SHALL be read again when the running job changes.

#### Scenario: Paging
- **WHEN** the user moves to page 2 and reloads
- **THEN** page 2 is shown again, and Back leaves Run history

#### Scenario: Rows per page
- **WHEN** the user picks 250 rows on Run history
- **THEN** the list shows 250 rows a page from the first page, and the other lists also show 250

### Requirement: Run page
The run page SHALL show breadcrumbs back to Run history, the run panel for that run, and the run's raw JSON in a closed section at the end. While the run is running, the panel SHALL update with the status, as on the Control page. When it ends, the page SHALL read its record once more. A run waiting in the queue SHALL say it is waiting. An unknown run id SHALL show the server's own message.

#### Scenario: A finished run
- **WHEN** the user opens a finished run
- **THEN** the page shows its state, counters, log, record and "Run again"

#### Scenario: Unknown run
- **WHEN** the user opens `#/runs/no-such-run`
- **THEN** the page shows the server's message for that id

### Requirement: Run panel log and changes
The run panel's log SHALL offer "Show more" when the run's log has more lines than are shown, and the lines already shown SHALL stay on the page. The "What it changed" tab of a finished run SHALL link to the comparison of the snapshot saved by the run with the snapshot before it, and SHALL say "No earlier snapshot to compare with." when there is none. For a running job it SHALL link to the changes so far.

#### Scenario: A long log
- **WHEN** a run's log has 12,040 lines and the user presses "Show more"
- **THEN** the panel shows the last 2,000 lines and states how many lines are shown

#### Scenario: First snapshot
- **WHEN** the run's snapshot is the oldest one saved
- **THEN** the tab says "No earlier snapshot to compare with."

