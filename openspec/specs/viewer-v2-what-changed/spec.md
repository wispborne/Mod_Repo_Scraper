# viewer-v2-what-changed Specification

## Purpose
TBD - created by archiving change viewer-v2-what-changed. Update Purpose after archive.
## Requirements
### Requirement: What changed page
The What changed page SHALL have two tabs, Mods and Facts, sharing one picker for the two sides being compared: two saved runs, or, on the Facts tab, a saved run against the data on disk right now. The tab, the two sides, and the search SHALL be kept in the address. Each changed row SHALL name the fields that changed while closed and list only what changed while open, with Expand all for the list. A comparison with the data on disk SHALL update only when Refresh is pressed. Mod rows SHALL link to the mod page, and topic rows to the source post page.

#### Scenario: Comparing two runs
- **WHEN** the user picks two runs on the Facts tab
- **THEN** the page lists the topics whose details changed, and the address holds both run ids

#### Scenario: Watching a run
- **WHEN** the newer side is the data on disk and the user presses Refresh
- **THEN** the comparison is updated; it does not redraw until the user presses Refresh

### Requirement: Links from the new viewer
The run panel's "What it changed", the source post history and the mod history SHALL open this page with the right tab and sides instead of the old viewer.

#### Scenario: From a run
- **WHEN** the user opens "View changes" on a finished run
- **THEN** What changed opens on the Facts tab comparing that run with the one before it

