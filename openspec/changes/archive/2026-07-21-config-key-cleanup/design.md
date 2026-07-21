# Config Key Cleanup — Design

## Context

All config keys are read in exactly one place, `Common.readConfig()` in `lib/bot/common.dart`, which fills `BotConfig`. The key names grew over time and mix several styles:

- ModRepo pipeline keys have no group prefix (`use_cached`, `enable_forums`, `less_scraping`), while every QB key starts with `qb_`.
- Two keys are half camelCase: `discord_serverId`, `discord_forumChannelIdsAndGameVersions`.
- Per-board page limits use two word orders: `qb_max_pages_main` / `qb_max_pages_libraries` vs `qb_lesser_board_max_pages`.
- Two renamed keys still have working aliases: `generate_debug_html` (for `generate_merge_debug`) and `openrouter_api_token` (for `llm_api_token`).
- `qb_scope` values are matched against the Dart enum names exactly (`main_repo_scraper.dart:322`), so the value the config file itself documents, `new_data`, never matches `newData` — it silently falls back to the default. It only works today because the default happens to be the same scope. `libraries_only` would silently scrape the wrong thing.

The user has explicitly accepted breaking changes; no aliases will be kept.

## Goals / Non-Goals

**Goals:**

- One naming scheme for every key, applied everywhere at once.
- Kill both legacy aliases.
- Make `qb_scope` values forgiving (snake_case or camelCase) and make bad values loud.
- Warn on unknown keys so typos and stale (old-name) keys are caught at startup.
- Reorganize the committed `config.properties` into clear sections and update all docs that name keys.

**Non-Goals:**

- Renaming the Dart field names on `BotConfig` (e.g. `enableModRepo`). They are internal; renaming them is mechanical churn across many call sites plus a mapper regeneration, with no user-facing benefit. Only the string keys in `readConfig()` change.
- Changing what any setting does, its default, or its value format (the `id:version,id:version` format of the Discord channel map stays).
- Touching output files, the viewer, or TriOS-facing formats.

## Decisions

### 1. Naming scheme: group prefix first, snake_case throughout

Every key starts with the group it belongs to — `modrepo_`, `qb_`, or `llm_` — and only `log_level` stays global. Booleans that switch a whole pipeline or source on/off end in `_enabled`; other booleans are named after the thing they turn on (`llm_summaries`, `qb_use_cached`).

Why prefix-first (`modrepo_forums_enabled`) instead of the current verb-first (`enable_forums`): keys sort and group by pipeline in the file and in logs, and you can see at a glance which pipeline a key affects. QB already proved this style works.

Why `llm_` stays its own group instead of `qb_llm_`: LLM extraction is part of the QB pipeline, but there are ~20 LLM keys and the extra `qb_` on each buys nothing — the section comment says it is QB-only. Alternative considered and rejected as noise.

### 2. Full rename map

| Old key | New key |
|---|---|
| `log_level` | unchanged |
| `enable_mod_repo` | `modrepo_enabled` |
| `use_cached` | `modrepo_use_cached` |
| `less_scraping` | `modrepo_less_scraping` |
| `enable_forums` | `modrepo_forums_enabled` |
| `enable_discord` | `modrepo_discord_enabled` |
| `enable_nexus` | `modrepo_nexus_enabled` |
| `discord_auth_token` | `modrepo_discord_auth_token` |
| `nexus_api_token` | `modrepo_nexus_api_token` |
| `discord_serverId` | `modrepo_discord_server_id` |
| `discord_forumChannelIdsAndGameVersions` | `modrepo_discord_forum_channels` |
| `generate_merge_debug` | `modrepo_merge_debug` |
| `generate_debug_html` (alias) | **removed** |
| `keep_all_game_versions_from_same_source` | `modrepo_keep_all_game_versions` |
| `enable_qb` | `qb_enabled` |
| `qb_use_cached`, `qb_data_path`, `qb_scope`, `qb_boards`, `qb_delay_ms`, `qb_max_pages_main`, `qb_max_pages_libraries` | unchanged |
| `qb_lesser_board_max_pages` | `qb_max_pages_lesser` |
| `enable_llm` | `llm_enabled` |
| `llm_skip_scrape_reprocess_only` | `llm_reprocess_only` |
| `openrouter_api_token` (alias) | **removed** |
| all other `llm_*` keys (incl. fallback) | unchanged |

Auth tokens move under `modrepo_` because only the ModRepo Discord/Nexus readers use them — the "Auth" section disappears and they live in the ModRepo section.

`llm_skip_scrape_reprocess_only` shortens to `llm_reprocess_only`: "reprocess only" already implies no scraping.

### 3. Unknown keys warn instead of being ignored

`readConfig()` keeps a set of the recognized key names. Any key present in the file but not in the set produces a startup warning naming that key (written with the same mechanism `readConfig` already uses for errors, since the logger is not yet configured at that point). This is the migration path that replaces the dropped aliases: someone running an old config sees one warning per stale key, telling them exactly what to rename. It also catches plain typos, which today fail silently.

Alternative considered: keeping the old names as aliases for a release. Rejected — the user asked for the break now, and the warning makes the break self-explaining.

### 4. `qb_scope` values are normalized before matching

Normalize the configured value and each `ScopeType` enum name by lowercasing and stripping underscores before comparing. So `new_data`, `newData`, `libraries_only`, and `librariesOnly` all work. If nothing matches, log a warning naming the bad value and the allowed ones, then use the default (`newData`) — the current silent fallback stays as the behavior, it just stops being silent. Config comments and CLAUDE.md standardize on the snake_case spellings.

### 5. `config.properties` layout

Rewritten in four labeled sections, keys in this order, keeping the real token values and the existing explanatory comments (updated for new names):

1. **Global** — `log_level`
2. **ModRepo pipeline** — `modrepo_enabled` first, then sources (with their tokens next to their enable switches), then options
3. **QB pipeline** — `qb_enabled` first, then scope/boards/paths/limits
4. **QB LLM extraction** — `llm_enabled` first, then the primary settings, then the fallback block

## Risks / Trade-offs

- [Anyone with an out-of-tree config file breaks on update] → The unknown-key warning names every stale key at startup; the rename map above doubles as the migration table. Defaults are unchanged, so a missing key behaves the same as before the rename.
- [A key could be missed in the rename sweep] → All reads live in one function; grep for `properties[` in `common.dart` and cross-check against the committed `config.properties` and this table.
- [Docs drift] → CLAUDE.md's Configuration section and the config file comments are updated in the same change; `dart test` plus a real run with the new file verify behavior.

## Open Questions

None.
