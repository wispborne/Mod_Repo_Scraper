## Context

`Common.readConfig` reads `config.properties` into `BotConfig`; `Common.recognizedKeys` lists the 54 keys. The viewer server reads it once at startup to build the manager: `ScraperService`, `ModRepoService`, `PublishService`, `TakedownService`, `AuthorAliasService` behind a `JobRouter`, plus `JobManager`, `RunHistoryStore` and `DataLock`. `config.example.properties` holds a plain-English note above every key. The server binds to `127.0.0.1` and has no sign-in; the copy on the host is reached through an SSH tunnel.

Today the `manager-api` spec says no config value may appear in any response except the data path. The requirements replace that with "no secret".

## Goals / Non-Goals

**Goals:** edit every setting in the browser with validation and confirmation; new settings used from the next job without a restart; run notifications.

**Non-Goals:** a sign-in (the server stays on `127.0.0.1`; the requirements say a sign-in comes first if that ever changes); editing settings when the server has no config file (the page says how to create one); changing the port or `--no-manager` (command-line options, not settings).

## Decisions

### A catalogue of settings in code
`lib/manager/settings_catalog.dart` lists every recognised key once: its group (`secret`, `environment`, `limits`, `jobShape`), its kind (`bool`, `int`, `text`, `address`, or a choice from a list), its built-in default as the file would write it, and whether it needs a restart. The note is read from `config.example.properties`: the comment lines straight above the key, `#` marks removed.

Groups follow the requirements: the four tokens are secrets; folders, addresses, models, the fallback and how much history to keep are environment; call caps, delays and timeouts are limits; `llm_enabled` is environment too, because the server reads it to decide whether its jobs may use the LLM at all; the switches the CLI and cron read to decide what to run (the other `*_enabled`, `*_use_cached`, `qb_scope`, `qb_boards`, page counts, `llm_reprocess_only`, `llm_test_*`, `modrepo_merge_debug`, `modrepo_less_scraping`, `modrepo_keep_all_game_versions`) are command-line and cron only.

Tests check that the catalogue matches the code: every key in `recognizedKeys` is in the catalogue and no other; for each key, writing its catalogue default into an otherwise empty file gives the same `BotConfig` as an empty file. This keeps the defaults consistent with `readConfig`.

Alternative: work defaults out by reading an empty file and mapping `BotConfig` fields back to keys. That needs the same key-to-field table anyway, written backwards.

### Restart-only settings
`qb_data_path` (the lock, run history and every store depend on it) and `log_level` (logging is set up once). Every other setting is read again before the next job.

### Reading the file again before each job
`JobManager` takes an optional `beforeJob` hook, called once the lock for the next job is taken, so a job that waited behind a cron run starts with the settings as they are when it actually starts. The server's hook checks the config file's modification time and size; when they changed, it reads the file and builds a new `JobRouter` with new services, which `JobManager` uses from that job on. The running job holds its own router, so it keeps its settings. A file that cannot be read keeps the last good router and logs why. `qb_data_path` is taken from the startup config whatever the file now says.

Alternative: rebuild on save. Misses edits made by hand on the host, and the cron run's edits.

### Routes
Under `/api/manager/`, so they exist only while the manager is on (the off handler's 503 says why):
- `GET /settings`: `{ file, groups: [...], settings: [{ key, group, kind, choices?, note, default, value?, isSet?, differs, restart }] }`. A secret has `isSet` and no `value`. An address with a user name or password has that part replaced by `•••` in `value` and `masked: true`; so does its query string, since some endpoints take their key there. A `git@host:path` address cannot hold a password and is never masked.
- `POST /settings` with `{ set: { key: value }, reset: [key], clearSecrets: [key] }`. Every key and value is checked first (known key; `bool` is `true`/`false`; `int` is a whole number not below the setting's minimum; `address` is `http`, `https` or, for `publish_repo_url`, an `ssh`/`git@` address; a choice is in its list). A masked address sent back unchanged is refused, so a hidden password can never be overwritten with dots. Any refusal writes nothing and names every bad key in plain words. On success the answer says whether a job is running and which saved keys need a restart.

### Editing the file
`config_file_editor.dart` works on lines. A key already set has its line's value replaced, keeping the `key = ` part as written. A reset key's line is removed, so the built-in default applies. A cleared secret keeps its line as `key =`. A new key goes at the end under one `# Set from the viewer` comment, added once. Comments, blank lines and order stay as they were. The result is written to `config.properties.tmp` and renamed over the file. Line endings follow the file's own. A key written twice in the file has every copy updated, since `readConfig` takes the last.

### Same-origin check on every changing manager request
A page on another website open in the same browser could post to `127.0.0.1:8085` and start jobs or, now, point the LLM address at itself and receive the token. So every `POST` under `/api/manager/` must have `content-type: application/json` (which other sites cannot send without the server's permission), and if it carries an `Origin` header, its host and port must match the request's `Host`. The `Host` must be a loopback name (`127.0.0.1`, `localhost`, `[::1]`), which also stops DNS rebinding. Refusals are a 403 with a plain message. The old viewer's job requests already send JSON; its Update button did not, and now does. The CLI sends JSON for both submit and cancel.

### The page
One central panel with the four groups as sections and a "This browser" section. Each setting is a row: key in mono, its note, its input, a "Changed from default" mark and "Reset to default". Edits stay on the page until saved; the toolbar shows "Save changes (N)" and "Discard". Save sends nothing until the confirmation dialog, which lists each change as old → new (a secret as "changed", a reset as "→ default"). The answer is shown in one line: saved, and the next job uses it; or saved, but the running job keeps its settings; plus any "Takes effect after a restart" keys. The page warns before leaving with unsaved edits.

### Run notifications
A switch under "This browser", kept in `localStorage['viewer2Notify']`. Turning it on asks the browser's permission. `status.js` already notices a run ending (`watchRunEnds`); when the switch is on and permission is granted, it shows one notification: "✓ Fetch and update finished" or "✗ Fetch and update failed", with no sound (`silent: true`).

## Risks / Trade-offs

- [Settings can now be changed over HTTP] → Only from the viewer's own page, on a loopback address, as same-origin JSON; secrets never leave the server; every change is confirmed in the page.
- [Rebuilding the services on a changed file costs the same as startup] → Only when the file changed, and only between jobs.
- [`config.example.properties` missing on a host] → Notes are left empty and the page still works.
