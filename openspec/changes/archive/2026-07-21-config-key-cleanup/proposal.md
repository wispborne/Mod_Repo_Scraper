# Config Key Cleanup

## Why

`config.properties` has grown organically and its key names no longer follow one scheme: ModRepo keys have no group prefix while QB keys do, two keys are half camelCase (`discord_serverId`, `discord_forumChannelIdsAndGameVersions`), the per-board page limits use two different word orders, and two renamed keys still carry working aliases. There is also a latent bug: `qb_scope` values are matched against Dart enum names exactly, so the documented value `new_data` silently falls back to the default instead of matching `newData`. We are willing to take breaking changes now, before more config files exist in the wild, so this is the time to fix the names once.

## What Changes

- **BREAKING**: Rename every config key to one consistent scheme: all snake_case, every key starts with its group prefix (`modrepo_`, `qb_`, `llm_`), and only `log_level` stays global. Old key names stop working — no aliases.
- **BREAKING**: Drop the two legacy aliases `generate_debug_html` and `openrouter_api_token`.
- **BREAKING**: Fix the word-order drift: `qb_lesser_board_max_pages` becomes `qb_max_pages_lesser`, matching `qb_max_pages_main` and `qb_max_pages_libraries`.
- Fix `qb_scope` value parsing: accept snake_case values (`new_data`, `libraries_only`) by normalizing before matching the enum, and log a warning when the value is unrecognized instead of silently using the default.
- Warn on unknown keys when reading `config.properties`. This catches typos and, importantly, tells anyone still using an old key name exactly which key was not recognized — the migration path that replaces the dropped aliases.
- Reorganize `config.properties` itself into clearly labeled sections (Global, ModRepo, QB, LLM) with keys in a sensible order, and update the comments.
- Update docs that mention key names (CLAUDE.md, README if applicable) and the committed `config.properties`.

The full old-name → new-name table lives in design.md.

## Capabilities

### New Capabilities

- `scraper-configuration`: How `config.properties` is read — the key naming scheme, group prefixes, unknown-key warnings, and `qb_scope` value normalization.

### Modified Capabilities

- `merge-debug-json`: The controlling key is renamed to `modrepo_merge_debug` and the requirement that `generate_debug_html` keeps working as an alias is removed.
- `qb-llm-client`: `enable_llm` becomes `llm_enabled`; the requirement to read the legacy `openrouter_api_token` fallback is removed.
- `qb-bundle-publishing`: References to `enable_qb` and `qb_lesser_board_max_pages` change to `qb_enabled` and `qb_max_pages_lesser`.

## Impact

- `lib/bot/common.dart` (`Common.readConfig`, `BotConfig` doc comments) — the only place keys are read.
- `lib/bot/scraper/main_repo_scraper.dart` — `qb_scope` value matching.
- `config.properties` — rewritten with new names and sections (keep the real token values).
- Docs: CLAUDE.md, config comments, and any README mentions of key names.
- No output-format change; TriOS and the results viewer are unaffected.
- Anyone with an existing config file must rename their keys; the unknown-key warning names each stale key at startup.
