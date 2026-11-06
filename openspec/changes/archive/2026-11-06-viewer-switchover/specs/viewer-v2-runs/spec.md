## MODIFIED Requirements

### Requirement: Run history page
The Run history page SHALL list every saved run, newest first, one row each, with its state (a diamond in the state's colour and the state's name), job, start time, how long it took, how much it did, its errors, its LLM calls, and a note when it reached the call limit or failed. Each row SHALL link to its run page. The list SHALL be paged with the rows-per-page choice (25, 50, 100, 250, 500 or all on one page) shared by every list in the viewer and remembered in the browser. The page number SHALL be kept in the address, without adding a browser history entry for each page. The list SHALL be read again when the running job changes.

#### Scenario: Paging
- **WHEN** the user moves to page 2 and reloads
- **THEN** page 2 is shown again, and Back leaves Run history

#### Scenario: Rows per page
- **WHEN** the user picks 250 rows on Run history
- **THEN** the list shows 250 rows a page from the first page, and the other lists also show 250
