## Context

The QB pipeline publishes `forum-data-bundle.json`, read by TriOS. It has three
top-level parts keyed by topic id: `index` (a list of thread summaries),
`details` (the full scraped record per thread), and `assumedDownloads` (the
rule-based download list per thread). TriOS consumes this shipped shape today.

The recently applied `qb-llm-override-layer` change added a fourth top-level part,
`llm` (a map keyed by topic id), holding the LLM's combined download list plus
extras, and set it up so a reader merges it onto `assumedDownloads`
one field at a time. Nothing reads any of that yet.

Two real cases do not fit the current LLM shape: a thread can hold more than one
mod (separate mods, or a main mod with add-ons/submods), and one mod can offer
several download links (an "Install with TriOS" link, a plain download, a
mirror). The flat per-thread LLM record cannot handle either case.

This change keeps the shipped bundle exactly as is and instead hangs the LLM
output off each thread in `index`, as a list of mods, where each mod owns its own
downloads and facts. The LLM block becomes the full, standalone answer for a
thread; the rules-based `assumedDownloads` stays put as the answer used only when
the LLM feature is off.

## Goals / Non-Goals

**Goals:**
- Keep every shipped field and location in `forum-data-bundle.json` unchanged.
- Add one optional `llm` field to each `index` item, holding all LLM output for
  that thread.
- Always shape that output as a `mods` list, so one thread can carry several mods
  or a main mod plus add-ons, and a single-mod thread is just a one-item list.
- Give each mod its own downloads and facts; give each download a kind and the
  resolver's resolved URL, filename, and manual-step flag, so the block stands
  alone.
- Make the LLM block the complete answer when present; drop the field-by-field
  download merge and the per-download origin tags.

**Non-Goals:**
- Changing `ModRepo.json`, the scrapers, or the download rules/resolver logic.
- The TriOS read-side change (coordinated separately).
- Keeping the `qb-llm-override-layer` LLM shape (nothing reads it yet).

## Decisions

### Decision: The LLM output hangs off each `index` item, not a top-level map

Add an optional `llm` field to `QbModSummary` (the `index` item type). Remove the
top-level `llm` map that `qb-llm-override-layer` added.

- **Why:** The user wants the LLM data to live on the thread it describes, and the
  shipped bundle is frozen otherwise, so this is the one place it can go without
  moving or renaming anything. Adding a field to an existing object is safe — old
  readers ignore it, and when the feature is off the field is absent, so the file
  matches today's release byte for byte.
- **Alternative — keep the top-level `llm` map:** rejected. It sits apart from the
  thread it belongs to and forces a second lookup by id; putting the field on the
  thread itself is what the user asked for and reads more directly.
- **Note:** `assumedDownloads` stays a top-level map because it is shipped and
  frozen. That leaves the rules downloads top-level and the LLM downloads on the
  index item, but the two are never read together (see the replacement decision),
  so the split does not matter in practice.

### Decision: The `llm` object is always a `mods` list

`llm` holds `mods: List<LlmMod>`, always — one entry for a single-mod thread, more
when a thread carries several mods or a main mod plus add-ons.

- **Why:** A consistent shape means every reader walks the same list, and a new mod
  on a busy thread is just another list entry. A flat list (not a nested tree)
  handles "two unrelated mods" and "main plus add-on" equally, and is easier for
  the LLM to produce reliably.
- **Relationships:** each mod carries `role` (`main` / `addon` / `separate` /
  `variant`) and `requires` (the name of the mod an add-on needs, else null),
  rather than nesting add-ons under a parent. A flat list with a name reference
  has a well-defined shape even when there is no single main mod.

### Decision: The LLM groups and judges; the resolver still resolves

The LLM decides which links are real downloads, which mod each belongs to, and the
kind (`direct` / `mirror` / `trios`). Each link the LLM keeps is then run through
the existing `download_resolver.dart`, so the stored download carries the resolved
direct URL, filename, and manual-step flag — the same work the current download
step does. The LLM never invents or resolves a URL.

- **Why:** The resolver does per-site work (Google Drive, Dropbox, MediaFire,
  GitHub…) the LLM cannot. Reusing it is what makes each `llm` download complete
  enough to use without reading `assumedDownloads`.
- **Alternative — store only the raw link and label in the `llm` block:** rejected.
  It would force a consumer back to `assumedDownloads` to get a usable URL, which
  defeats "the block is the full answer".

### Decision: Replacement, not a field-by-field merge

When the `llm` block is present, it is the whole answer for that thread's mods and
downloads; a reader does not need `assumedDownloads` for that thread. When the
LLM feature is off, the block is absent and `assumedDownloads` is the answer.

- **Why:** The user wants the LLM output correct enough to stand alone. Picking
  the whole block or the whole rules base is simpler than merging each field, and it means
  the `llm` downloads no longer need per-entry origin tags.
- **Result:** Drop the `source` / `llmReason` tags and the per-field download
  merge rule that `qb-llm-override-layer` added. Extras (version, changelog,
  support links, license, summary) stay LLM-only, present or absent — the rules
  side has no matching fields, so there is nothing to merge.

### Decision: The prompt returns a list of mods, only for mods on this thread

Change the extraction prompt to return `{ "mods": [ ... ] }` and to include only
mods actually downloadable from *this* thread. A mod that is merely mentioned,
recommended, linked as a successor, or required but hosted elsewhere is not an
entry. Bump `promptVersion` so every post re-runs.

- **Why:** The main risk with a mods list is splitting too much — turning a
  mentioned mod into its own entry. The ShaderLib post is the test: it mentions
  GraphicsLib (successor) and Version Checker (recommended), both hosted
  elsewhere, and must still produce exactly one mod (ShaderLib, with its download
  and its mirror).

## Risks / Trade-offs

- **Overlaps the unarchived `qb-llm-override-layer` change** → both touch the same
  bundle and LLM-extraction requirements. Mitigation: this change is written
  against the override-layer end-state and replaces its LLM shape; archive
  `qb-llm-override-layer` first (it is applied and complete) so the base reflects
  it before this change is applied. See Open Questions.
- **The LLM splits too much and creates ghost mods** → a mentioned or successor
  mod becomes its own entry. Mitigation: the prompt's "downloadable from this thread
  only" rule and the ShaderLib check; the link-checking step still drops any URL
  not present in the post.
- **The LLM mis-groups a download** → puts a mirror under the wrong mod, or calls
  an add-on a mirror. Mitigation: keep the `kind` set small and the add-on-vs-mirror
  line explicit in the prompt (different file that extends the mod = a mod entry;
  same file elsewhere = a mirror download); the viewer shows the grouping for
  spot-checking.
- **Prompt version change re-runs every post** → one full LLM pass worth of cost.
  Mitigation: expected and one-time; the cache absorbs later runs.
- **Viewer drifts out of sync** → it reads the LLM data location. Mitigation: update
  `lib/viewer/` + `web/` as part of this change (project convention).
- **Cache entries change shape** → `llm-extraction-cache.json` entries have a new
  structure. Mitigation: raise `LlmExtractionStore.schemaVersion` so old entries
  are skipped and re-created, not mis-read.

## Migration Plan

1. Change the models: `LlmMod` (name, role, requires, downloads, extras) and an
   `llm` container with a `mods` list; add the optional `llm` field to
   `QbModSummary`; remove the top-level `llm` map from `ForumDataBundle`. Give each
   download a `kind` and the resolver-filled fields. Regenerate mappers with
   `build_runner`.
2. Wire `post_extractor.dart` to run the resolver over the LLM's chosen links and
   group them per mod; store the result in the reshaped cache entry.
3. Update `bundle_publisher.dart` to attach the `llm` block to each `index` item
   and stop emitting the top-level `llm` map and the override merge.
4. Bump `LlmExtractionStore.schemaVersion` and `ExtractionPrompt.promptVersion`.
5. Update the viewer, tests, and README.

Rollback: undo the model and publisher changes; the LLM store re-creates its
entries on the next run.

## Open Questions

- **Archive order vs. `qb-llm-override-layer`.** This change replaces that one's
  LLM shape. The intended order is: archive `qb-llm-override-layer` first, then
  apply this. Confirm before applying, so the spec base is up to date.
- **`trios` download kind.** Included on the assumption TriOS-install links appear
  in posts; confirm they occur often enough to classify, or fold them into
  `direct` for now.
