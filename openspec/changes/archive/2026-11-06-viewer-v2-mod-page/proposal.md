## Why

`docs/viewer-redesign-requirements.md` (**Investigate → The mod page**) calls for investigating a mod through its source posts and LLM answers when it looks wrong on Starmodder or in TriOS. Today the viewer is organized by output file (Mod Catalog, Mod Details), and nothing reports where each fact came from. The new viewer's Mods entry, the links from source posts to their mods, and the Control page's "Mods with no download" all lead to placeholders.

## What Changes

- **Mods list** (`#/mods`): every mod in the last build, searchable by name, nickname, author or id, with filters (no download, taken down, has conflicts, AI use stated) and paging in the address.
- **The mod page** (`#/mods/<id>`), in the order the requirements give:
  1. **Header:** name, permanent id, authors, a link to its Starmodder page and to its raw published files, old ids that now lead here, and its takedown status.
  2. **What Starmodder shows:** the key fields of `outputs/site/mods/<id>.json`.
  3. **Where each fact came from:** for each fact, which source post and which LLM answer supplied it, or that the rules or the merge did.
  4. **Source posts:** each forum topic, Discord thread and Nexus page, with how it joined the mod, its LLM name, and whether the rules or the LLM found it.
  5. **History:** the saved runs in which this mod changed, with the fields that changed.
  6. **Raw JSON**, collapsed.
  Plus the per-post job buttons acting on all the mod's posts, Take down, "These are the same person" next to an author name, and "Match this to a mod" next to a requirement the build could not match, each adding a pending change.
- **Collection page** (`#/mods/<id>` for a Collection's id): its name, the post it comes from, and its mods.
- **Server:** `GET /api/mods`, `GET /api/mods/<id>` and `GET /api/mods/<id>/history`, read-only. `chooseFacts` also says which source supplied each field, so the viewer shows the sources recorded by the build.
- Old ids (`movedIds`) open the mod they lead to, with a note saying so.

## Capabilities

### New Capabilities
- `viewer-v2-mod-page`: the Mods list, the mod page and the Collection page.

### Modified Capabilities
- `viewer-server`: the three read-only mod routes.

## Impact

- `lib/catalog/fact_choice.dart` (sources alongside the chosen facts), where the site build calls it, `lib/viewer/api.dart`, a new `lib/viewer/mod_views.dart`, `lib/viewer/data_access.dart`.
- New `web2/views/mods.js`, `web2/views/mod.js`, styles; `web2/app.js`.
- Dart tests for the routes and the fact sources; Node tests for any pure helpers.
