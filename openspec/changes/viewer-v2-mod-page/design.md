## Context

The catalog (`outputs/mod-catalog.json`) holds each mod's permanent id, its fields and `sourcePosts` (kind, id, LLM name, found by rules or LLM), plus `collections` and `movedIds`. The website build writes `outputs/site/mods/<id>.json` (the page record) and `mods.json`. `chooseFacts` (`lib/catalog/fact_choice.dart`) combines the LLM answers of a mod's posts field by field (forum first, Discord where the forum left a field empty; downloads as one list; the highest mod version; the newer of two posts of one kind). The merge debug data (`merge-debug.json`, and each merge snapshot) records why each group of listings formed. Bundle snapshots (`qb_data/bundles/`) and merge snapshots (`qb_data/merges/`) are kept per run.

## Goals / Non-Goals

**Goals:** the three pages; fact sources recorded by the build; history by permanent id.

**Non-Goals:** What changed (later change; history links to the old diff pages until then); editing facts by hand.

## Decisions

### Sources are recorded where the facts are chosen
`chooseFacts` returns the chosen `LlmMod` and a map from field name to the source it came from (`{ kind, id, llmName }`, or `rules`, or `merged` for fields made from several). The site build saves this per mod in a new file that is never published, `<qb_data_path>/fact-sources.json` (`{ builtAt, mods: { <id>: { <field>: source } } }`), the same way the takedown report and `catalog-left-out.json` are saved. The viewer reads it only when its `builtAt` matches the catalog's. Fields the site builds from something other than `chooseFacts` (the name, the picture, the categories, the description) get their source written where the builder picks them, if that is a small change; otherwise they are listed without a source.

Alternative: have the viewer choose the facts again to find their sources. This would duplicate the rules. The two copies could give different results.

### How a post joined
`GET /api/mods/<id>` gives each source post a `joinedBy`: `forumLink` (a Discord or Nexus listing whose link points at the mod's forum topic), `name` (name and author matched), `download` (a shared download), `sameId` (the posts already shared a permanent id), or `first` (the post the mod started from). Read from the merge debug data of the build the catalog came from; when that is missing, `joinedBy` is left out.

### Routes
- `GET /api/mods?q=&filters=&sort=&page=&pageSize=`: rows `{ id, name, displayName, authors, sources, gameVersion, modVersion, hasDownload, takenDown, conflicts, usesAi }` from the catalog and `mods.json`, the usual page rules.
- `GET /api/mods/<id>`: `{ id, kind: "mod"|"collection"|"moved"|"takenDown"|"unknown", movedTo?, catalog, site, sourcePosts: [{ kind, id, title, llmName, foundBy, joinedBy? }], facts: { <field>: { value, source } }, oldIds, takedown?, unmatchedNeeds: [written] }`. A moved id answers `kind: "moved"` with `movedTo`, and the page opens the target with a note.
- `GET /api/mods/<id>/history`: one entry per kept bundle or merge snapshot in which this mod's record changed, newest first, `{ runId, at, fields: [names], diff: [...] }`, matched by permanent id where the snapshot has ids and by the mod's posts where it does not. Uses the same field comparison as the topic history (`compare_rows.dart`), so the pages describe a change the same way.

### Pages
`#/mods` and `#/mods/<id>`, the nav entry Mods. Breadcrumbs: Mods › name (› History if history becomes its own page; on the page it is a section). The source post links go to `#/posts/<kind>/<id>`. The per-post jobs on the mod page act on all its forum topics (and Discord threads for Re-run LLM), through the same confirm sentences as the Source posts list.

### Correction buttons
- Take down → `takeDownMod` via the Takedowns page's preview (`previewAndAdd`).
- "These are the same person" next to each author name when the mod credits two or more: a small dialog to pick the two names, then `sameAuthor`.
- "Match this to a mod" next to each requirement the build left unmatched (`unmatchedNeeds`), opening the Dependency names page's mod picker, then `matchRequirement`. The picker is moved into a shared module so both pages use one copy.

## Risks / Trade-offs

- [`fact-sources.json` only exists after the next build] → The section says "Run Rebuild from saved to see where each fact came from." until then.
- [History over 500 bundle snapshots is slow on a cold server] → Cached per mod until the snapshot list changes, as the topic history is; the page says it can take a minute.
