## 1. Config reading (`lib/bot/common.dart`)

- [x] 1.1 Rename every property lookup in `Common.readConfig()` to the new key names per the design's rename map, and delete the `generate_debug_html` and `openrouter_api_token` alias reads
- [x] 1.2 Add the recognized-key set and warn (one line per key, via the same stderr path `readConfig` uses today) for every key in the file that is not in the set
- [x] 1.3 Update `BotConfig` doc comments that mention old key names (Dart field names stay as they are)

## 2. qb_scope parsing (`lib/bot/scraper/main_repo_scraper.dart`)

- [x] 2.1 Match `qb_scope` against `ScopeType` names after lowercasing and stripping underscores on both sides, so `new_data` and `libraries_only` work
- [x] 2.2 Log a warning naming the bad value and the accepted values when nothing matches, before falling back to the default scope

## 3. Config file and docs

- [x] 3.1 Rewrite `config.properties` with the new key names in four labeled sections (Global / ModRepo / QB / LLM+fallback), keeping the real token values and updating all comments — including standardizing scope values on snake_case spellings
- [x] 3.2 Update CLAUDE.md's Configuration section (key names and `qb_scope` value spellings); check README and other docs for stale key names
- [x] 3.3 Grep the repo for every old key name to catch stragglers (tests, comments, openspec change docs in flight)

## 4. Tests and verification

- [x] 4.1 Add or update tests covering: new keys load, unknown keys warn, `qb_scope` snake_case and camelCase values both resolve, and an unrecognized scope value warns and defaults
- [x] 4.2 Run `dart test` and check for analyzer problems via the IDE (`mcp__idea__get_file_problems`), not the CLI analyzer
- [x] 4.3 Do a real run with the rewritten `config.properties` (cached mode is fine) and confirm no unknown-key warnings and the same pipelines run as before
