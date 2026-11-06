## ADDED Requirements

### Requirement: Settings page
The Settings page SHALL show every setting in four groups, in this order: Secrets, Environment, Limits, and Command-line and cron runs only. Each setting SHALL show its key, its note, its value, a mark when it differs from the built-in default, and "Reset to default" when it does. A secret SHALL show only "Set" or "Not set", with a box for a new value and a Clear button. A setting that needs a restart SHALL say "Takes effect after a restart". When the manager is off, the page SHALL say in one sentence that settings can only be changed while jobs are on, and how to turn them on.

#### Scenario: A secret
- **WHEN** the Discord token is set
- **THEN** its row says "Set" and shows no part of the token

### Requirement: Saving settings
Edits SHALL be collected on the page until saved. The toolbar SHALL show how many edits there are, with Save and Discard. Save SHALL first show a dialog in the page listing each change with its old and new value (a secret only as "changed"), and send nothing until it is confirmed. A refusal SHALL be shown with the server's own message, and the edits SHALL stay on the page. After saving, the page SHALL say that the next job uses the new settings, that a running job keeps the settings it started with when one is running, and which saved settings take effect only after a restart. The page SHALL ask for confirmation before leaving with unsaved edits.

#### Scenario: Saving during a job
- **WHEN** the user saves a change while a job runs
- **THEN** the page says the running job keeps its settings and the change applies from the next job

### Requirement: Run notifications
The Settings page SHALL have a "This browser" section with a switch for a notification when a run ends. Turning it on SHALL ask for the browser's permission. While it is on and allowed, the viewer SHALL show one silent notification when a run it saw running finishes or fails, naming the job and how it ended. The switch SHALL be kept in the browser.

#### Scenario: A run fails
- **WHEN** notifications are on and a Fetch and update run fails while the viewer is open
- **THEN** one notification says that Fetch and update failed
