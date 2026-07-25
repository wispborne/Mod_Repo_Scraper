# runs-page

## Purpose

Show what the scraper is doing now, what is waiting its turn, and what it did before — and let somebody start or stop a job from the browser.
## Requirements

### Requirement: A Runs view shows now, next, and before
The frontend SHALL have a Runs view (`#/runs`) showing the current run (live progress bar, phase, current item, and a cancel button), the queued runs in order, and past runs newest first with paging. Each past run SHALL show its kind, start time, duration, state, counters, and a badge when a guardrail cut it short. Rows SHALL link to a detail page.

#### Scenario: Watching a live run
- **WHEN** a job is running and the user is on the Runs view
- **THEN** the progress bar, phase, and current item update about once a second without reloading the page

#### Scenario: Cancelling from the browser
- **WHEN** the user clicks cancel on the current run and confirms
- **THEN** the run stops between topics, keeps what it saved, and shows as cancelled in the history list

### Requirement: A run's detail page tells the whole story
The detail page (`#/runs/<id>`) SHALL show the full record — including the stored request — and the run's log (default tail, with a way to load more). While that run is live, the log SHALL refresh along with the status. A **run again** button SHALL post the stored request as a new job and go to it.

#### Scenario: Reading a failed run
- **WHEN** the user opens a failed run
- **THEN** they see the error message, the counters at failure, and the log tail without leaving the page

#### Scenario: Run it again
- **WHEN** the user clicks "run again" on a past `rescrapeTopics` run
- **THEN** a new job with exactly the same topic ids is queued and the UI follows it

### Requirement: Whole-store jobs start from a visible form
The Runs view SHALL offer a start-a-job panel for `fullRun` (scope, boards, LLM on/off shown as form fields with their defaults visible), `llmCoveragePass`, and `rebuildBundle`. What a job will do SHALL be readable from the form itself — never inherited invisibly from the config file. Jobs started from the browser SHALL never ask for replay mode.

#### Scenario: Starting a full run
- **WHEN** the user opens the panel, keeps the visible defaults, and confirms
- **THEN** a `fullRun` job with exactly those visible choices is queued

### Requirement: The header always says what's happening
Every view SHALL show a small status chip: what's running and how far along, "ready" when idle, or "viewing only" when the manager is off. It SHALL link to the Runs view. One shared poller SHALL feed the chip and the Runs view — about once a second while a run is live or queued, more slowly when idle.

#### Scenario: A run is visible from any view
- **WHEN** a job runs while the user is browsing the Merge view
- **THEN** the header chip shows the job's progress without the user visiting the Runs view

### Requirement: Manager off reads as a mode, not a failure
When the server answers that the manager is off, the Runs view SHALL say so in one plain sentence (and how to turn it on), the chip SHALL say "viewing only", and no job-starting UI SHALL render. All read-only viewer pages keep working untouched.

#### Scenario: Viewer-only server
- **WHEN** the user opens the Runs view against a server started without a config file
- **THEN** they see a calm explanation instead of an error page, and the rest of the viewer works as always

### Requirement: A Publish to GitHub card starts a publish job
The Runs view SHALL offer a "Publish to GitHub" card in the start-a-job area, beside the scrape and merge cards. Its button SHALL show the usual in-page confirm dialog describing what will happen (publish the current `outputs/` files to the target repo) and, on confirm, submit a `publishOutputs` job. The card SHALL follow the same manager-on/off rules as the other cards: when the manager is off, no publish button renders.

#### Scenario: Publishing from the browser
- **WHEN** the user clicks "Publish to GitHub", reads the confirm dialog, and confirms
- **THEN** a `publishOutputs` job is queued and the UI follows it like any other job

#### Scenario: Card hidden when manager is off
- **WHEN** the manager is off
- **THEN** the Runs view shows no publish button, matching the scrape and merge cards
