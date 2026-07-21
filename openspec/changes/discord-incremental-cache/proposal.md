## Why

Every run, the Discord scraper re-fetches every thread in each mod-updates channel: one "full channel info" call plus one paginated messages call per thread, plus reaction checks. On a channel with hundreds of mod threads that is hundreds of API calls, even though most threads have not changed since the last run. The Forum scraper already avoids repeat work by keeping a saved result cache; Discord has no equivalent for production (its only cache is an all-or-nothing raw-HTTP record/replay meant for local debugging). We can cut most of those calls by remembering each thread's last result and only re-fetching threads that actually changed.

## What Changes

- Add a saved Discord result cache (one file, keyed by thread) that stores the parsed mod for each thread plus a small "has this thread changed?" fingerprint (last message id, message count, and thread timestamp — all of which the thread listing already returns for free).
- On each run, list the threads (cheap), then for each thread compare its current fingerprint to the cached one. If it matches, reuse the saved mod and skip the per-thread channel-info call, the messages call, and the reaction checks. If it is new or changed, fetch and parse it fully and update the cache.
- Drop threads from the cache that no longer appear in the channel listing, so removed/deleted mods do not linger.
- Add a config switch to turn this on, and a way to force a full refresh (ignore the cache for one run) so edits that the fingerprint cannot detect can still be picked up on demand.
- Document the known limit: editing an existing message without posting a new one does not change the thread's last-message fingerprint, so such edits are only picked up on a forced full refresh (or a periodic full refresh).
- Leave the existing `discord_raw_cache.json` record/replay layer untouched; the new cache is a separate, higher-level layer, matching the "two independent cache layers" model the project already uses.

## Capabilities

### New Capabilities
- `discord-incremental-caching`: Save each Discord thread's parsed mod and a change fingerprint, and on later runs re-fetch only threads whose fingerprint changed, so unchanged threads cost no per-thread API calls.

### Modified Capabilities
<!-- No existing spec's requirements change. Discord has no current spec file; this is net-new behavior. -->

## Impact

- **Code**: `lib/bot/scraper/discord_reader.dart` (thread listing keeps its lightweight metadata; message fetch and reaction checks become conditional on the fingerprint), a new small store class for the Discord result cache, and the Discord job wiring in `lib/bot/scraper/main_repo_scraper.dart`.
- **Config**: new keys in `config.properties` / `BotConfig` (`lib/bot/common.dart`) to enable the cache and to force a full refresh.
- **Files on disk**: a new derived cache file (for example `discord_cache.json`) alongside the existing `discord_raw_cache.json`.
- **Behavior**: fewer Discord API calls on steady-state runs; unchanged. output for unchanged threads. One trade-off — message edits with no new post are not detected until a forced/periodic full refresh.
- **Not affected**: the ModRepo merge, the QB pipeline, and the results viewer (the Discord cache is an internal scraper detail; the merged `ModRepo.json` shape is unchanged).
