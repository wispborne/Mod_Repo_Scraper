## ADDED Requirements

### Requirement: A Publish to GitHub card starts a publish job
The Runs view SHALL offer a "Publish to GitHub" card in the start-a-job area, beside the scrape and merge cards. Its button SHALL show the usual in-page confirm dialog describing what will happen (publish the current `outputs/` files to the target repo) and, on confirm, submit a `publishOutputs` job. The card SHALL follow the same manager-on/off rules as the other cards: when the manager is off, no publish button renders.

#### Scenario: Publishing from the browser
- **WHEN** the user clicks "Publish to GitHub", reads the confirm dialog, and confirms
- **THEN** a `publishOutputs` job is queued and the UI follows it like any other job

#### Scenario: Card hidden when manager is off
- **WHEN** the manager is off
- **THEN** the Runs view shows no publish button, matching the scrape and merge cards
