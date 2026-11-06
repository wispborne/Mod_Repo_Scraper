## MODIFIED Requirements

### Requirement: No config value goes over the wire
Management responses SHALL be built from an explicit short list of fields. No secret from `config.properties` SHALL appear in any response: the Discord token, the Nexus token, the LLM token and the fallback LLM token, and any user name or password inside an address. Other settings SHALL appear only in the settings route's response and the data path only where it does today. The server SHALL keep binding to `127.0.0.1` only.

#### Scenario: Status carries no secrets
- **WHEN** a client reads `GET /status` on a fully configured server
- **THEN** the response contains no token, key, endpoint URL, or model name from the config file

#### Scenario: Settings carry no secrets
- **WHEN** a client reads `GET /settings` on a server whose config file sets all four tokens and an LLM address with a password in it
- **THEN** the response says each token is set and contains none of their values, and the address's password is hidden

## ADDED Requirements

### Requirement: Settings over HTTP
While the manager is on, `GET /settings` SHALL list every recognised setting with its group, kind, note from `config.example.properties`, built-in default, current value (or, for a secret, only whether it is set), whether it differs from the default, and whether it takes effect only after a restart. `POST /settings` SHALL accept values to set, keys to reset to their default, and secrets to clear. It SHALL check every key and value before writing anything, and refuse the whole request, naming each bad key, when any is wrong. A hidden address sent back unchanged SHALL be refused. On success it SHALL write the file through a temporary file that replaces it, keeping comments, blank lines and the order of lines, and SHALL say whether a job is running and which saved keys need a restart.

#### Scenario: Saving a limit
- **WHEN** the client posts `{ "set": { "llm_max_topics": "300" } }`
- **THEN** that line in `config.properties` reads `llm_max_topics = 300`, and every other line is unchanged

#### Scenario: A bad value
- **WHEN** the client posts `llm_max_topics` as `lots` together with a good value for another key
- **THEN** nothing is written, and the response names `llm_max_topics` and says it must be a whole number

#### Scenario: Reset to default
- **WHEN** the client posts `{ "reset": ["qb_delay_ms"] }`
- **THEN** the `qb_delay_ms` line is removed from the file, and the setting reads as its built-in default

### Requirement: Changing requests come from the viewer
Every `POST` under `/api/manager/` SHALL be refused with 403 and a plain message unless its content type is JSON, its `Host` is a loopback name, and any `Origin` header names the same host and port.

#### Scenario: Another website posts
- **WHEN** a page on another site makes the browser post to `/api/manager/jobs`
- **THEN** the server refuses it and starts nothing
