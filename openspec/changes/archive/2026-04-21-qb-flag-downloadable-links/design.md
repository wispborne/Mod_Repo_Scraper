## Context

The QB forum scraper extracts every anchor tag from a topic's first post into `LinkRef { url, text, isExternal }` and stores the list inside `QbModDetail.links` in the cached forum data bundle. There is no signal on a `LinkRef` indicating whether it actually points at a mod download. The downstream `QbDownloadResolver` does *sophisticated* classification (host-specific resolution, GitHub API calls, MediaFire CDN scraping, etc.), but its output is a separate `DownloadCandidate` list — it is not written back onto the `LinkRef`s and it only runs during the resolve phase, not at scrape time.

Meanwhile the legacy scraper already has a simple "is this a download link?" heuristic:
- `Common.isDownloadable` ([lib/bot/common.dart:28](lib/bot/common.dart:28)) — async; issues a GET and inspects `Content-Disposition` / `Content-Type`.
- `DiscordReader._isDefiniteDownloadLink` ([lib/bot/scraper/discord_reader.dart:497](lib/bot/scraper/discord_reader.dart:497)) — synchronous; checks for `.zip` / `.rar` / `.7z` substrings and known file-hosting hosts (`drive.google.com`, `mega.nz`, `mediafire`).

The user wants the QB scraper to classify each link the same way, flag it on the `LinkRef`, and show the flag in string output. The natural approach is to share the heuristic rather than fork it.

## Goals / Non-Goals

**Goals:**
- Every `LinkRef` produced by the QB topic scraper carries an `isDownloadable` bool.
- A `LinkRef`'s string representation reveals the flag when true.
- The classification heuristic has exactly one source of truth; the legacy scraper and QB scraper call into it.
- Old cached bundles continue to deserialize (missing field defaults to `false`).

**Non-Goals:**
- Replacing `QbDownloadResolver`. The resolver remains the authority for *resolved download candidates*; `isDownloadable` is a per-link classification hint, not a substitute.
- Changing the legacy scraper's behavior. The extracted helper must be a pure refactor w.r.t. legacy semantics.
- Teaching the merger / `ModRepo.json` output about this flag. It is a QB-bundle internal signal for now.
- Exhaustively retrying probe failures. One attempt per link with a bounded timeout; a failed probe falls through to the sync heuristic's answer.

## Decisions

### Decision 1: Reuse the full legacy pipeline — sync heuristic *then* async probe — via a shared helper
Create a new file `lib/bot/scraper/download_link_detector.dart` exporting both:

```dart
/// Synchronous, cheap: extension substring + known-host check.
/// Matches the legacy `DiscordReader._isDefiniteDownloadLink` rules.
bool isLikelyModDownloadUrl(String url);

/// Full classification: cheap check first; if inconclusive, probe
/// `Content-Disposition` / `Content-Type` via HTTP (same logic currently
/// in `Common.isDownloadable`). Returns the final classification.
Future<bool> isDownloadableUrl(String url);
```

QB scraping calls `isDownloadableUrl` per extracted link, fanned out concurrently across a topic's links with `Future.wait` (the same pattern the Discord reader already uses at [discord_reader.dart:388](lib/bot/scraper/discord_reader.dart:388)). The cheap sync check short-circuits the network call for URLs where the answer is obvious (`.zip`, `drive.google.com`, etc.), so we only pay HTTP cost on the uncertain tail.

Rationale:
- The user is right: QB is already I/O-bound. The pipeline already throttles forum requests (`qbDelayMs`, default 1500ms), fetches per-topic HTML, and runs `QbDownloadResolver` which itself issues GitHub API, MediaFire, Google Drive probes. One extra HEAD-ish request per uncertain link is marginal against that budget and gives ground-truth accuracy the heuristic alone can't.
- The probe runs against *external* hosts, not the forum, so it does not contend with the `qbDelayMs` forum throttle.
- We classify once at scrape time and persist the result on `LinkRef`, so re-runs over cached bundles don't re-probe.

**Parallelism / budget:**
- Per-topic: all external links classified concurrently with `Future.wait`.
- Global: cap with the same unthrottled HTTP client the QB resolver already uses; reuse the resolver's client if convenient so we share connection reuse and any user-set concurrency limits.
- Timeout: each probe bounded (e.g. 10s) so one slow host can't stall a topic. On timeout or any error, fall back to whatever the sync heuristic said (`false` if it said no).

**Alternatives considered:**
- *Sync heuristic only.* Rejected per user feedback — we have the time budget, and the heuristic has known false negatives (file-host pages, unusual CDNs) that the probe catches.
- *Async probe only.* Rejected — obvious cases (`.zip` URL) don't need a network round trip, and the sync short-circuit is free.
- *Move the probe into a background job after bundle publish.* Rejected — classification is per-link data that belongs on the `LinkRef`, and doing it at scrape time keeps the bundle self-consistent.

### Decision 2: Store the flag as a new field on `LinkRef`, default `false`
Add `final bool isDownloadable` to `LinkRef`, default `false`, include in constructor and `dart_mappable` serialization.

Rationale:
- Persisting on the model means the flag survives the bundle cache round-trip and is available to every downstream consumer for free.
- Defaulting to `false` + `dart_mappable`'s tolerance for missing fields handles pre-existing cache entries without a migration step.

**Alternatives considered:**
- *Compute lazily at read time.* Rejected: every consumer would need the heuristic wired in, and we lose the "one source of truth at scrape time" property.
- *A separate parallel list.* Rejected: drifts out of sync with `links` and complicates the bundle schema.

### Decision 3: Classify at topic-scrape time, in a post-pass after `_extractLinks`
`_extractLinks` is synchronous; the async probe cannot run inside it. Split into two passes:
1. `_extractLinks` builds `LinkRef`s with `isDownloadable = false` (default).
2. Immediately after, `TopicScraper` runs an async post-pass that classifies each link via `isDownloadableUrl` with `Future.wait` and replaces the list with `copyWith(isDownloadable: result)` values.

This post-pass lives inside the existing per-topic scrape future, so it parallelizes naturally with other topics in the pipelined scraper and is covered by the same cache: once a topic's `QbModDetail` is persisted, its `isDownloadable` flags are sticky and we never re-probe on subsequent runs.

Rationale: keeps the hot sync path of `_extractLinks` unchanged; gives us one clean `await Future.wait(...)` for the probe fan-out; avoids threading futures up into HTML parsing.

### Decision 4: String formatting — let `dart_mappable` regenerate `toString` additively
**Constraint (user):** the change to `LinkRef`'s string form must be backward compatible. Interpretation agreed with the user: *additive* is compatible — the existing three fields continue to appear in the same positions; the new `isDownloadable` field is appended to the end of the generated `toString` output.

Approach:
- Add `isDownloadable` as a normal mappable field. Let the `dart_mappable` generator regenerate `toString` to include it at the end (e.g. `LinkRef(url: ..., text: ..., isExternal: ..., isDownloadable: ...)`).
- No override, no `toFormattedString()`, no snapshot pinning. The "flag in the string" requirement is satisfied directly by the generator output: `isDownloadable: true` is visible to any reader of the string.
- Any callsite that specifically wants `[downloadable]`-style human wording can format it ad-hoc; we do not bake that in.

Rationale:
- Simplest possible change — one field, regenerate, done.
- Additive field placement (always last, after pre-existing fields) preserves any reader that substring-matches the old prefix.
- Avoids a second API (`toFormattedString`) that every callsite would need to opt into.

**Alternatives considered:**
- *Dedicated `toFormattedString()` that appends `[downloadable]`.* Rejected as over-engineering; the generator already surfaces the flag.
- *Hide `isDownloadable` from `toString`.* Rejected: then the flag is NOT in the string representation, which violates the spec.

### Decision 5: Regenerate `*.mapper.dart` via build_runner
`mod_detail.mapper.dart` is generated. After editing `mod_detail.dart` we must run `dart run build_runner build --delete-conflicting-outputs`. The generated delta is part of the change's footprint; no hand-edits to `.mapper.dart`.

## Risks / Trade-offs

- **[Risk] Heuristic false positives/negatives at the sync short-circuit.** The sync rule is substring-based (e.g. any URL containing `.zip` is flagged). A link like `.../something.zip.old/page.html` would match without a probe. → **Mitigation:** sync says-yes wins (we trust it), but sync says-no falls through to the async probe, so the probe catches both false negatives (non-obvious download hosts) and doesn't care about the false positives (we don't re-run the probe on a confident yes).
- **[Risk] Async probe is slow / rate-limits us on external hosts.** → **Mitigation:** per-link timeout (e.g. 10s); errors and timeouts fall back to the sync answer; Future.wait fans out concurrently within a topic so wall time is bounded by the slowest link, not sum of links; results are persisted on `LinkRef` so cached topics don't re-probe on later runs.
- **[Risk] The probe's GET may pull large bodies.** `Common.isDownloadable` calls `HttpClient.getUrl().close()` and reads response headers without draining the body. For a real archive URL this can leave a large download streaming on the connection. → **Mitigation:** in the shared helper, switch to a bounded approach — prefer a HEAD request first; if the server rejects HEAD, fall back to GET but close/abort the response after headers are read. Validate behavior against the existing Discord usage (no regression).
- **[Risk] A caller is brittle-parsing the old `toString` with `endsWith(')')` or exact-length assumptions.** → **Mitigation:** grep the codebase for any such parsing on `LinkRef.toString()` output before merging. None is expected (it's a debug/log format) but worth verifying.
- **[Risk] Existing cached bundle files fail to load because of the new field.** → **Mitigation:** `dart_mappable` with the existing `@MappableClass(ignoreNull: true)` and a default-valued constructor parameter will treat missing JSON keys as the default. Add an integration test that loads a bundle without the key.
- **[Trade-off] We duplicate classification work vs. `QbDownloadResolver`.** The resolver is still the source of truth for *resolved* download candidates; `isDownloadable` is a cheap annotation, not a replacement. In practice the resolver's decision about whether to even try a URL is a superset of the heuristic, so agreement will be high.

## Migration Plan

1. Add the shared helper (`download_link_detector.dart`) with both `isLikelyModDownloadUrl` (sync) and `isDownloadableUrl` (async: sync-short-circuit → HEAD/GET probe with timeout).
2. Switch `discord_reader._isDefiniteDownloadLink` → `isLikelyModDownloadUrl` and `Common.isDownloadable` callers → `isDownloadableUrl`, behavior-preserving.
3. Add `isDownloadable` to `LinkRef` with default `false` (last field); regenerate mapper.
4. In `TopicScraper`, after `_extractLinks`, run `await Future.wait(links.map((l) => isDownloadableUrl(l.url)))` and build the final link list with the resolved flags.
5. Let `dart_mappable` regenerate `LinkRef.toString()` with the new field appended; no manual override.
6. Grep for any callers that parse `LinkRef.toString()` output and confirm none break on the additive change.

Rollback: revert commits; old cached bundles remain loadable because the field was additive and defaulted.

## Open Questions

- Should the flag feed into `QbDownloadResolver`'s pre-filter (skip links where `isDownloadable == false`)? Probably yes as a small follow-up, but out of scope here — the resolver today already filters to `isExternal && !forum-hosted && !ignored-host`, which overlaps but is not identical.
- Do we also want to surface the flag on `ModRepo.json` output (for consumers of the merged repo)? Deferred; the spec intentionally does not require it.
