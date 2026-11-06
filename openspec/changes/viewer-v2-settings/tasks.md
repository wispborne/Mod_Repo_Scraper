## 1. Settings on the server

- [x] 1.1 `lib/manager/settings_catalog.dart`: every recognised key with group, kind, default, minimum, choices and restart flag; notes read from `config.example.properties`
- [x] 1.2 Tests: the catalogue matches `Common.recognizedKeys`, and each default gives the same `BotConfig` as an empty file
- [x] 1.3 `lib/manager/config_file_editor.dart`: set, reset and add keys keeping comments, blank lines, order and line endings; write through a temporary file
- [x] 1.4 `GET /settings` and `POST /settings` in `manager_api.dart`: secrets never sent, addresses with a password masked, every value checked before anything is written
- [x] 1.5 Same-origin check on every `POST` under `/api/manager/`
- [x] 1.6 Read the config file again before each job when it changed (`JobManager` hook, services rebuilt in `bin/viewer_server.dart`); `qb_data_path` and `log_level` need a restart
- [x] 1.7 Tests for the editor, the routes (including no secret in any answer), the origin check and the reload before a job
- [x] 1.8 Check the release includes `config.example.properties`

## 2. Settings page

- [x] 2.1 `web2/views/settings.js`: four groups, rows with note, input, default mark, Reset to default, secrets as Set or Not set with a new-value box and Clear
- [x] 2.2 Save and Discard in the toolbar, the confirmation dialog listing old and new values, the save result, and a warning before leaving with unsaved edits
- [x] 2.3 "This browser": the notification switch, and the notification in `web2/status.js`
- [x] 2.4 Viewing only mode and layout at phone widths

## 3. Checks and docs

- [x] 3.1 Check in the browser on a copy of the config file: each kind of setting, a refused value, reset, a secret, a save during a job (faked), notifications
- [x] 3.2 Update `CLAUDE.md` (Configuration, Manager core, the new viewer)
- [x] 3.3 Run `dart test`
