## Context

`DiscordReader.readAllMessages` (in `lib/bot/scraper/discord_reader.dart`) scrapes each configured mod-updates forum channel like this:

1. `_getChannel` for the channel itself (tags lookup).
2. `_getThreads(getFullChannelInfo: true)` — lists active threads (1 call) and archived threads (paginated), then calls `_getChannel` **once per thread** to get full info.
3. For each thread, `_getMessages` (paginated, up to 100 messages).
4. Reaction checks: for any message carrying the 🕸️ no-scrape reaction, an extra `_getReacters` call.
5. Parse each thread's messages into a `ScrapedMod`.

So per steady-state run the cost is roughly `2 × threads` calls (full-info + messages) plus pagination and reaction calls, even though almost nothing changed since yesterday.

Today's only Discord cache is `discord_raw_cache.json` via `CachingClient` — a raw-HTTP record/replay layer intended for local debugging (`use_cached`), which is all-or-nothing and off in production. The Forum and Nexus scrapers instead keep a *derived* result cache (`<name>_cache.json`) through `_loadOrRun`, but that is also all-or-nothing (load the whole file or scrape everything). Neither existing pattern does per-item incremental refresh.

The thread listing (`_getThreads`, before the per-thread `_getChannel`) already returns, for each thread, a `Channel` object with `lastMessageId`, `messageCount`, and `timestamp` — enough to tell whether a thread has likely changed without fetching its messages.

## Goals / Non-Goals

**Goals:**
- Cut Discord API calls on steady-state runs by skipping unchanged threads.
- Reuse the exact parsed `ScrapedMod` a fresh scrape would have produced for unchanged threads.
- Keep the change opt-in and off by default, so production behavior is unchanged until turned on.
- Keep the new cache clearly separate from the raw-HTTP replay layer.

**Non-Goals:**
- Detecting in-place message edits that post no new message (see Risks). We accept a forced/periodic full refresh as the answer for those.
- Changing the merged `ModRepo.json` shape or the QB pipeline or the viewer.
- Replacing or reworking the existing `discord_raw_cache.json` record/replay layer.
- Incremental caching for Forum or Nexus (out of scope; this is Discord-only).

## Decisions

### Decision: A separate derived cache file keyed by thread id

Add a small store (e.g. `DiscordResultCache` / a `discord_cache.json` file) holding a map of `threadId → { fingerprint, scrapedMod }`. This mirrors the "derived cache" layer already described in the architecture notes and keeps it independent from `CachingClient`.

- *Alternative considered:* extend the existing `<name>_cache.json` used by `_loadOrRun`. Rejected because that cache stores a flat mod list with no per-thread key or fingerprint, and Discord's job is wired separately from `_loadOrRun` already. A purpose-built store is simpler than overloading the shared one.
- *Alternative considered:* reuse the raw-HTTP cache and make replay smarter. Rejected — the raw layer has no notion of "this thread is unchanged"; it would still replay every recorded call, and it is a debugging tool, not a production incremental layer.

### Decision: Fingerprint = last message id + message count + thread timestamp

These three come free from the thread listing. `lastMessageId` changes whenever a new message is posted; `messageCount` guards against deletions; `timestamp` is a cheap tiebreak. If any differ from the cached fingerprint, treat the thread as changed.

- *Alternative considered:* fetch each thread's OP message and compare its `editedTimestamp`. Rejected — that requires a per-thread call, which defeats the purpose (the whole point is to avoid per-thread calls for unchanged threads).
- *Alternative considered:* compare only `lastMessageId`. Rejected as slightly too weak — including `messageCount` catches a deletion that leaves `lastMessageId` unchanged.

### Decision: Skip the per-thread `_getChannel` for cached threads too

The `getFullChannelInfo: true` path spends one `_getChannel` call per thread. For threads that match the fingerprint we skip this along with `_getMessages` and reaction checks, because the parsed mod (including tags/categories) is already stored. Full info is only fetched for new/changed threads.

### Decision: Rebuild the result list from listing ∩ cache each run

The run's Discord result = for every thread currently listed, either its reused cached mod or a freshly scraped one. Threads no longer listed are dropped from both the output and the rewritten cache, so deleted mods do not linger.

### Decision: Two config switches

- An enable flag (default off) — when off, behavior is exactly as today.
- A force-full-refresh flag — ignore fingerprints for one run and rewrite the cache from fresh scrapes, so operators can recover edits the fingerprint cannot see. This can be run on a schedule (e.g. weekly) to bound how stale an in-place edit can get.

### Decision: Write the cache as the run goes, not at the end

Save the cache in small batches as threads are scraped, and once more at the end (including on the failure path). A cache whose only purpose is to avoid re-fetching threads must not throw away a part-finished run's fetches: the first run, which fetches everything, is exactly the one most likely to be interrupted.

This follows the QB stores that already do it — `LlmExtractionStore` (every few topics, or every few seconds) and `DownloadableProbeCache` (every few probes). Batching keeps the cost of rewriting the file down while bounding what an interrupted run loses to a handful of threads.

- *Alternative considered:* write only after a run finishes without error (the original plan here). Rejected — it repeats the weakness of the existing end-of-run-only caches, and the raw-HTTP layer's habit of skipping the save entirely on the error path.
- Note: dropping entries for threads that are no longer listed still needs the full listing, but the listing is known up front, so it can happen before the scraping starts. An interrupted run simply leaves stale entries for one more run, which is harmless.

### Decision: Wiring stays in the existing Discord job closure

The incremental logic lives inside `DiscordReader` (it owns thread listing and fetching). `main_repo_scraper.dart` only passes the new config through and continues to own the separate raw-HTTP `CachingClient` decision as it does now. The two cache layers stay orthogonal.

## Risks / Trade-offs

- **In-place message edits are invisible to the fingerprint** → Documented limit. Mitigation: the force-full-refresh flag, intended to be run periodically, picks them up. Most Discord mod updates post a new message (bumping `lastMessageId`), so this is a narrow case.
- **A stale cache could serve a wrong mod if fingerprint logic is buggy** → Mitigation: keep the fingerprint derivation in one small, unit-tested function; default the feature off; force-refresh always rewrites from scratch.
- **Cache file corruption / schema drift** → Mitigation: on any read/parse error, log and fall back to a full scrape (treat as no cache), same spirit as `_loadOrRun`'s try/catch. Version the cache file so a format change invalidates cleanly.
- **`ScrapedMod` shape changes later** → the cache stores serialized mods; a model change needs the cache format version bumped so old entries are discarded rather than mis-parsed.
- **Interaction with `discord_raw_cache.json`** → When `use_cached` replays raw HTTP, the incremental cache still works on top (fingerprints come from replayed listings); no conflict, but tests should cover the combination.

## Migration Plan

1. Ship with the enable flag defaulting to off — no behavior change on deploy.
2. Turn the flag on in `config.properties` for the production run once verified.
3. First on run does a full scrape and writes `discord_cache.json`; subsequent runs are incremental.
4. Rollback: set the flag off (falls back to full scrape every run) and/or delete `discord_cache.json`. No data migration needed.

## Open Questions

- Cache file name/location: `discord_cache.json` in the repo root (next to `discord_raw_cache.json`) vs. under a data dir — proposing repo root for consistency with the current Discord cache.
- Should force-full-refresh be its own config key or reuse an existing "less scraping / full run" style switch? Leaning toward a dedicated key for clarity.
- Do we want a max-age so the cache auto-forces a full refresh after N days without an explicit flag? Could be a follow-up; not required for the first version.
