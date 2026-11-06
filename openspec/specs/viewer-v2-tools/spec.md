# viewer-v2-tools Specification

## Purpose
TBD - created by archiving change viewer-v2-tools. Update Purpose after archive.
## Requirements
### Requirement: Catalog explorer
The Catalog explorer SHALL show, for the merge picked (the newest by default), why each group of posts became one mod, a group's before and after, and what was removed, with the picked merge, search, filters and page kept in the address. Group members SHALL link to their source post pages.

#### Scenario: Looking at a group
- **WHEN** the user opens a group
- **THEN** the page shows its members, why each joined, and the merged result

### Requirement: LLM test report
The LLM test report page SHALL show the last LLM test's report. It SHALL be the only place that starts an LLM test job. Starting a test SHALL require confirmation and the manager to be on.

#### Scenario: Starting a test
- **WHEN** the user presses the start button and confirms
- **THEN** an `llmTest` job is sent

### Requirement: Files page
The Files page SHALL list the output files with their size and date, and each SHALL open as raw text.

#### Scenario: Opening a file
- **WHEN** the user opens `mod-catalog.json`
- **THEN** its text is shown, in the parts the server sends

