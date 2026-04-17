## Context

The QB scraper package pulls mod data from forum topics, resolving download URLs from multiple hosting providers (GitHub, Bitbucket, Dropbox, Google Drive, etc.). Currently, per-item processing uses `Future.wait` (which fail-fasts on any exception) and unprotected `Uri.decodeFull` calls. There are ~5 identified crash points across 3 QB files where a single item's error propagates up and halts the run.

Affected files:
1. **`download_resolver.dart`** — 3 bare `Uri.decodeFull` calls (lines ~506, ~551, ~701); `Future.wait` in `resolveForTopic` (~line 200)
2. **`scraper_engine.dart`** — pipelined batch loop (~line 249-266) and `Future.wait(pending)` (~line 268) with no per-topic error handling
3. **`mod_index_scraper.dart`** — per-post category extraction loop (~line 54-79) with no try-catch

## Goals / Non-Goals

**Goals:**
- Every per-topic/per-URL/per-post processing loop in the QB package SHALL isolate errors so one item's failure cannot crash the batch.
- All caught errors SHALL be logged at warning level with enough context (topic ID, URL) to diagnose.
- The scraper SHALL complete its full run and produce output for all items that succeeded.

**Non-Goals:**
- Error isolation in non-QB scrapers (forum_scraper, discord_reader, nexus_reader, mod_merger).
- Retrying failed items or implementing circuit breakers.
- Partial data recovery within a single item.

## Decisions

### Decision 1: Safe URL decode helper in download_resolver.dart

Add `_tryDecodeFull(String encoded)` that wraps `Uri.decodeFull` in try-catch, returns `null` on `ArgumentError`/`FormatException`. Used at 3 call sites. This is a targeted helper because the same decode pattern repeats in one file.

**Why not pre-validation regex?** Fragile — would need to replicate Dart's percent-encoding validation exactly.

### Decision 2: Per-item try-catch inside existing loops

Wrap the body of each `Future.wait` / `for` callback with try-catch. On error, log a warning and return `null` (or skip). Filter nulls from results. This is the minimal change that isolates errors without restructuring the code.

**Why not a generic `tryOrNull<T>()` helper?** Return types and error context vary per site. Per-site try-catch with specific log messages is clearer.

### Decision 3: Error-tolerant Future.wait in scraper_engine.dart

Replace bare `Future.wait(pending)` with individual future error handling so failed topics don't prevent successful ones from completing.

## Risks / Trade-offs

- **[Silent data loss]** → If many items fail, output could be incomplete with only log warnings as signal. Mitigation: log a count of failures at the end of the run.
- **[Over-catching]** → Per-item try-catch could mask programming bugs. Mitigation: log full stack traces at warning level so bugs remain visible.
