## Context

The QB pipeline publishes `forum-data-bundle.json`, consumed by TriOS. Rule-based downloads live in `assumedDownloads` (a per-topic list). When the LLM feature is on, the extractor reconciles the rule links with what it finds in the post and — today — that merged list *overwrites* `assumedDownloads` in `bundle_publisher.dart` (the `llmEntry.downloads` branch at [bundle_publisher.dart:95](../../../lib/bot/scraper/qb/bundle_publisher.dart)). The LLM's other facts (version, changelog, support links, license, summary) already sit apart in an optional `llmExtraction` map.

We want each end user to toggle LLM-sourced data on or off, per field, in the TriOS UI. That only works if the published bundle keeps *both* answers. TriOS reads no LLM data yet, so there is no deployed LLM shape to stay compatible with — we can pick the cleanest layout now.

## Goals / Non-Goals

**Goals:**
- The published bundle carries a pure rules-based base layer and a separate LLM override layer, so a consumer can show either.
- `assumedDownloads` is always exactly what the rules produced — never touched by the LLM.
- One per-topic `llm` block holds every LLM field (downloads included), and adding a future LLM field needs no structural change.
- Document the layout and the consumer merge rule in the README for end clients.

**Non-Goals:**
- Implementing the toggle UI or the read change in TriOS (separate project, coordinated).
- Any change to `ModRepo.json`, the scrapers, the download rules, or the LLM prompt/grounding.
- Backwards compatibility for the LLM data shape (nothing consumes it yet). Backwards compatibility of the *rules base* is preserved by definition, since `assumedDownloads` returns to its original pure-rules meaning.

## Decisions

### Decision: One per-topic `llm` block, keyed by topic ID, holding downloads + extras

The bundle gets a single optional map `llm: Map<String, LlmModData>` where `LlmModData` carries `downloads` (the reconciled list) and the existing extras fields (`version`, `changelog`, `supportLinks`, `license`, `summary`). This is the one home and the extension point for all LLM output.

- **Why:** A single per-topic block makes the merge rule uniform ("look in `llm.<id>.<field>`") and makes a new field a one-line addition to a model plus the prompt — no new top-level map, no publisher branching.
- **Alternative considered — keep `llmExtraction` for extras and add a parallel `llmDownloads` map:** rejected. Two parallel LLM maps re-create the split we are trying to remove and mean every new field must choose a map.
- **Alternative considered — per-entry envelopes (`{rules, llm}`) on every field:** rejected as over-engineered; only downloads have a rules counterpart, and the base/override split already expresses the override cleanly.

### Decision: `assumedDownloads` is pure rules-based, always

The publisher stops choosing between the rules list and the LLM list. It always emits the rule-based candidates into `assumedDownloads`, and always emits the LLM's reconciled list (when present) into `llm.<id>.downloads`.

- **Why:** This is the whole point — the base layer must be a faithful, stable "LLM off" view. It also restores `assumedDownloads` to the meaning its spec originally gave it.
- **Consequence:** The same file may be listed in both places (rules-resolved in `assumedDownloads`, LLM-reconciled in `llm.<id>.downloads`). That duplication is intended: it is what lets the consumer switch. The LLM list remains self-contained (it already carries its own `source`/reason detail per entry), so a consumer that turns LLM downloads on simply swaps lists.

### Decision: Drop the "additive tags + backwards-compatible overlay" contract from the LLM spec

The archived LLM change required optional `source`/`llmReason` tags on `assumedDownloads` entries and an "old readers keep working" overlay. With the clean split, `assumedDownloads` has no LLM-origin entries at all, so those tags do not belong there. Per-entry provenance still exists inside `llm.<id>.downloads` (the `AssumedDownloadCandidate.source`/`llmReason` fields already model it).

- **Why:** The overlay contract existed to sneak LLM data into a shared list without breaking readers. We no longer share the list, so the contract is dead weight and slightly misleading.

### Decision: Consumer merge rule is documented, not enforced

The scraper publishes both layers and nothing more. The README states the rule for consumers: for any field, if `llm.<id>` has it and the user's per-field switch is on, use it; else use the base value, else nothing. The per-field switches live only in the consumer UI.

- **Why:** Keeps the scraper a pure data producer; TriOS owns presentation and user preference.

## Risks / Trade-offs

- **Bundle shape break for TriOS** → TriOS currently reads the merged list from `assumedDownloads` (or will once it adopts LLM data). Mitigation: TriOS reads no LLM data yet, so the only real coupling is the download list location; document the new location and coordinate the TriOS read change. The rules-only `assumedDownloads` remains valid for any reader that ignores `llm`.
- **Duplicated download data inflates the file** → the same file can appear in both layers. Mitigation: it is only duplicated for topics where the LLM ran and found downloads; the bundle is already large and this is bounded by topic count, not post size.
- **Viewer drifts out of sync** → the local results viewer renders LLM provenance. Mitigation: update `lib/viewer/` + `web/` to read the `llm` block as part of this change (project convention: keep the viewer in sync).
- **Stored cache reshape** → `llm-extraction-cache.json` entries currently store `downloads` + `extras`; the on-disk entry maps almost 1:1 to the new `LlmModData`, so migration is mostly a rename/regroup. Mitigation: bump the store `schemaVersion` so stale entries are ignored and re-derived rather than mis-read.

## Migration Plan

1. Reshape the models (`LlmModData` on the bundle; adjust the stored entry), regenerate mappers with `build_runner`.
2. Change `bundle_publisher.dart` to always emit rules into `assumedDownloads` and the LLM data into `llm`.
3. Bump `LlmExtractionStore.schemaVersion` so old cache entries are skipped and rebuilt.
4. Update the viewer to read the new block; update tests; update the README.
5. Coordinate the TriOS read change separately (out of this repo).

Rollback: revert the publisher change; the LLM store re-derives on the next run.

## Open Questions

- Exact name for the per-topic model/field: `llm` (short, matches "LLM off/on") is the working choice; confirm during apply.
