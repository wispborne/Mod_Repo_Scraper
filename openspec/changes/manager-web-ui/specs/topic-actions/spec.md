# topic-actions

## ADDED Requirements

### Requirement: Topics can be selected across pages
The Topics view SHALL show a checkbox per row and a selection bar saying how many are selected, with a clear button. The selected set SHALL survive paging, searching, and switching views within the session, and SHALL be cleared when a job is submitted for it.

#### Scenario: Selection survives paging
- **WHEN** the user ticks two topics on page 1, pages to page 3, and ticks one more
- **THEN** the bar says 3 selected and all three ids go into the next action

### Requirement: Per-stage actions on the selection
The selection bar SHALL offer the three per-stage actions — re-scrape, re-resolve downloads, re-run LLM — posting `rescrapeTopics`, `resolveDownloads`, and `extractLlm` jobs with the selected ids. A single topic's page SHALL offer the same three actions for just that topic. After submitting, the UI SHALL go to the Runs view so the new job is immediately visible.

#### Scenario: Re-running the LLM on three mods
- **WHEN** the user selects three topics and clicks "re-run LLM"
- **THEN** after confirming, an `extractLlm` job with those three ids is queued and the Runs view shows it

#### Scenario: Acting on one topic from its page
- **WHEN** the user clicks "re-scrape" on a topic's detail page
- **THEN** a `rescrapeTopics` job for that one id is queued, leaving the selection set alone

### Requirement: Actions confirm by describing what will happen
Before any job is posted, the UI SHALL show one plain-words confirmation naming the kind, the number of topics, and the cost in kind ("makes network requests", "may spend LLM budget"). Declining posts nothing.

#### Scenario: The user changes their mind
- **WHEN** the user clicks "re-scrape" on 40 selected topics and then declines the confirmation
- **THEN** no job is created and the selection is kept

### Requirement: No action UI without a manager
When the manager is off, the Topics view SHALL show no checkboxes, no selection bar, and no action buttons — the view reads exactly as the read-only viewer always has.

#### Scenario: Read-only topics view
- **WHEN** the user browses Topics against a viewer-only server
- **THEN** the list looks and works as before this change, with no dead buttons
