## ADDED Requirements

### Requirement: Pending changes
Correction actions in the new viewer SHALL add an item to one list of pending changes instead of starting a job. The list SHALL be kept in the browser tab for the session and never on the server. While it is not empty, the toolbar SHALL show how many items it holds, and pressing the count SHALL show the list. Each item SHALL say in one line what it does and SHALL be removable. The list SHALL offer "Publish afterwards", "Save all" and "Discard all". Closing or reloading the tab while the list is not empty SHALL ask for confirmation.

#### Scenario: Adding from a page
- **WHEN** the user takes down a mod on the Takedowns page
- **THEN** no job starts, and the toolbar shows "1 pending"

#### Scenario: Surviving a reload
- **WHEN** the user reloads the tab with two pending changes and confirms
- **THEN** both are still pending

### Requirement: Saving pending changes
"Save all" SHALL first show a dialog listing every pending change and whether the outputs will be published, and send nothing until confirmed. It SHALL then start one `saveCorrections` job and clear the list once the server accepts it. A refusal SHALL be shown with the server's own message, and the list SHALL stay as it was.

#### Scenario: Saving
- **WHEN** the user saves three pending changes with "Publish afterwards" ticked
- **THEN** one job is started with the three corrections and `publishAfter` set, and the list is empty

### Requirement: Takedowns page
The Takedowns page SHALL list every takedown entry: what was taken down, when, and what it excluded from the last build. It SHALL warn about an entry that left out nothing and about a mod that came back under a new id. It SHALL offer forms to take down a mod or a person, each showing what would be left out before the change is added, and a Restore action on each entry. Every action SHALL add a pending change. While the list is not empty, the page SHALL show it as a side panel.

#### Scenario: Restore
- **WHEN** the user presses Restore on an entry and confirms
- **THEN** a pending change "Restore …" is added, and the entry is marked as pending restore

#### Scenario: A mod came back
- **WHEN** a taken-down mod returned under a new id in the last build
- **THEN** its entry shows a warning saying so
