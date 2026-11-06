## Why

Every change to `config.properties` today means opening the file on the host over SSH, finding the key among 318 lines, and restarting the server. `docs/viewer-redesign-requirements.md` asks for a Settings page in the new viewer that changes the file from the browser (**Operate → Settings**). It also asks for an optional browser notification when a run ends, switched on in the viewer's own settings.

## What Changes

- **A Settings page** in the new viewer (`#/settings`), with every setting in four groups: Secrets, Environment, Limits, and Command-line and cron runs only. Each setting shows its note from `config.example.properties`, its current value, and whether it differs from the built-in default, with "Reset to default".
- **Secrets are never sent to the browser.** The four tokens show only "Set" or "Not set", with a box for a new value and a Clear button. User names and passwords in addresses are hidden.
- **Saving** checks every value first, shows the old and new value of each change (a secret only as "changed"), and asks for confirmation. The file is written to a temporary file that then replaces the original, keeping every comment and the order of lines.
- **When a change takes effect:** the server reads the file again before each job, so nothing needs a restart. A running job keeps the settings it started with. The few settings that cannot change while the server runs (the data folder, the log level) say "Takes effect after a restart".
- **Manager requests must come from the viewer itself.** Every request that changes something (`POST` under `/api/manager/`) must be sent as JSON from the viewer's own address. This stops another website open in the same browser from saving settings or starting jobs.
- **This browser** section on the Settings page: a switch for a browser notification when a run ends or fails. It is kept in the browser and needs the browser's permission. No sound.
- **BREAKING (spec only):** the rule "no config value goes over the wire" becomes "no secret goes over the wire". Settings other than the tokens are shown on the Settings page, as the requirements say.

## Capabilities

### New Capabilities
- `viewer-v2-settings`: the Settings page and run notifications.

### Modified Capabilities
- `manager-api`: settings routes; changing requests must be same-origin JSON; non-secret settings may be served.
- `viewer-server`: the server reads the config file again before each job.

## Impact

- New `lib/manager/settings_catalog.dart` (every key with its group, kind, default, note and whether it needs a restart), `lib/manager/config_file_editor.dart` (edits the file keeping comments), settings routes in `lib/manager/manager_api.dart`, and a same-origin check on all manager `POST` routes.
- `bin/viewer_server.dart` and `lib/manager/job_manager.dart`: the services are built again from the file before a job when the file has changed.
- `web2/views/settings.js`, `web2/status.js` (notifications), `web2/style.css`.
- Tests for the catalogue (every recognised key is in it, and its default matches `readConfig`), the editor, the routes, the origin check, and the reload before a job.
- `config.example.properties` is read at run time for the notes, so it now ships in the release beside the server. So does `web2/`, which the release left out. The host's own copy of `tool/update-scraper-only.sh` is not part of the release, so it has to be copied to the host once by hand.
- `readConfig` reads a blank Discord token, Nexus token, Discord server id or log level as not set, so every built-in default can be written in the file. The example file's log levels now name `WARN`, which is what the code reads; `WARNING` was treated as INFO.
