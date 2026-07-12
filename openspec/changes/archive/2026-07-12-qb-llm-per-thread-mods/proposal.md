## Why

A single forum thread can hold more than one mod (separate mods, or a main mod
with add-ons/submods), and one mod can offer several download links (an
"Install with TriOS" link, a plain download, a mirror). Today's LLM output has
no place for any of that: it stores one flat set of facts per thread, so it
cannot say "this thread has two mods" or "this link is a mirror of that one".
The just-applied `qb-llm-override-layer` change also split the LLM data into a
separate top-level map and set it up as a per-field override of the
rules-based downloads — extra plumbing nothing reads yet. We want
the LLM output to be the full, complete answer for a thread, grouped by
mod, and to live right on the thread it describes.

## What Changes

- **The LLM output moves onto each thread in the `index` list.** Each item in
  `index` gains one new optional field, `llm`, holding everything the LLM found
  for that thread. Nothing else in the shipped bundle moves or is renamed.
- **The `llm` object always holds a `mods` list.** Even a normal single-mod
  thread gets a one-item list, so every thread has the same shape. A thread with
  several mods, or a main mod plus add-ons, gets one entry per mod.
- **Each mod carries its own downloads and facts.** Per mod: `name`, `role`
  (`main` / `addon` / `separate` / `variant`), `requires` (the name of the mod
  an add-on needs, else null), a `downloads` list, and the existing extras
  (version, changelog, support links, license, summary).
- **Each mod may carry its own image.** When a thread holds more than one mod (or
  a main mod plus add-ons), a mod can carry an optional `image` — a picture from
  the post that clearly belongs to it, stored in the same `ext:<url>` form as the
  thread `thumbnailPath`. The post's images (minus badges/spinners) are shown to
  the LLM, which picks one only when it clearly belongs to a mod; the choice is
  grounded against the post's real images and the exact scraped URL is stored.
  Absent when the post ties no picture to that mod.
- **Each mod copies the post's save-compatibility note.** A new `saveCompatibility`
  extra holds the post's own words on whether the mod can be added to an existing
  save or needs a new game (e.g. "Save compatible", "Requires a new game"), copied
  word-for-word and grounded against the post. Absent when the post does not say.
- **Each download is complete on its own.** Per download: the raw `url`, the link
  text copied word-for-word (`label`), a `kind` (`direct` / `mirror` / `trios`),
  plus the resolved direct URL, filename, and requires-manual-step flag — filled
  in by the existing download resolver, the same work the current download step
  does. The LLM chooses which links are downloads, which mod each belongs to, and
  the kind; the resolver still resolves each kept link. The LLM never invents or
  resolves a URL.
- **The `llm` block is the complete, standalone answer for a thread.** A consumer
  that trusts it does not need to read `assumedDownloads` at all. **BREAKING**
  (internal, nothing reads this shape yet): this replaces the `qb-llm-override-layer`
  top-level `llm` map and its merge-one-field-at-a-time setup. The per-download
  origin tags (`source` / `llmReason`) and the per-field download merge
  rule are dropped — there is no field-by-field merge, the reader picks the
  whole `llm` block or the whole rules base.
- **`assumedDownloads` is unchanged and stays where it is.** It remains the
  rules-only, top-level list, and is the answer only when the LLM feature is off
  (the default today).
- **The extraction prompt returns a list of mods.** It must include only mods
  that are actually downloadable from *this* thread — never a mod that is merely
  mentioned, recommended, linked as a successor, or required but hosted
  elsewhere. `promptVersion` goes up so every post re-runs.
- **Out of scope:** `ModRepo.json` (unchanged, rules-only); the scrapers and the
  download rules themselves; the TriOS read-side change (coordinated separately —
  this repo only publishes and documents the shape).

## Capabilities

### New Capabilities

(none — this reshapes existing bundle and LLM-extraction behavior)

### Modified Capabilities

- `qb-bundle-publishing`: the LLM data moves from a separate top-level `llm` map
  onto each `index` item as an optional `llm` field; `assumedDownloads` stays a
  pure rules-only, top-level list that the LLM never touches.
- `qb-llm-post-extraction`: the LLM output becomes a per-thread `mods` list, each
  mod carrying grouped downloads (with `kind`, run through the resolver) plus its extras;
  the download origin tags and per-field merge rule are removed; the
  prompt returns a mods list and includes only mods downloadable from the thread.
- `viewer-llm-inspection`: the local results viewer reads the LLM data from its
  new home on each `index` item and shows the per-mod, per-download breakdown.

## Impact

- **Code:** `models/post_extraction.dart` (per-mod model with a `mods` list, mod
  `role`/`requires`, download `kind`), `models/forum_data_bundle.dart` +
  `models/mod_summary.dart` (drop the top-level `llm` map; add the optional `llm`
  field to `QbModSummary`), `bundle_publisher.dart` (attach the `llm` block to
  each index item; stop the override merge), `llm/extraction_store.dart` (stored
  entry shape + bump `schemaVersion`), `llm/prompt.dart` (mods-list output, bump
  `promptVersion`) and `llm/post_extractor.dart` (wire the resolver over the
  LLM's chosen links), plus regenerated `*.mapper.dart` siblings via
  `build_runner` code generation.
- **Output:** `forum-data-bundle.json` — each `index` item may gain an `llm`
  field; the top-level `llm` map is removed. This only adds to the existing
  fields, so old readers are unaffected; the LLM shape is new and nothing reads
  it yet.
- **Docs:** `README.md` end-client section updated to describe the `llm` field on
  index items, the `mods` list, and that it is the full answer when present.
- **Viewer:** `lib/viewer/` + `web/` follow the new shape (project convention:
  keep the viewer in sync with the data).
- **Tests:** `test/qb_llm_post_extractor_test.dart`, `test/bundle_publisher_test.dart`,
  `test/viewer_server_test.dart`.
- **No change:** `ModRepo.json`, the scrapers, the download rules, and the
  resolver's per-host logic.
