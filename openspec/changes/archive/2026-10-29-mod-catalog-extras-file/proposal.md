## Why

TriOS is porting several Starmodder features to its Catalog page: release history, the same-name warning, the gallery with AI captions, the Discord post, the 13 tidy categories, and filters on requirements, dates, tools, save safety and AI use.

The data for those features is worked out only by the site build. TriOS reads `mod-catalog.json` and `mod-catalog-details.json`, and neither has it. Some of it can't be worked out by TriOS at all, because it needs files the scraper keeps between runs: release history (`mod-releases.json`), picture captions (`picture-captions.json`) and hand-matched requirement names (`requirement-names.json`).

The details file is the wrong home for it. That file is organised by forum topic, and these facts are organised by mod. The site build also runs after the details file is written. And the details file's own rules say it carries no Discord message text.

## What Changes

- The site build also writes `outputs/mod-catalog-extras.json`. One record per mod, keyed by the mod's permanent id, with the fields listed in the spec.
- It is written by every site build. That includes the build after a bundle and the build after a merge or a requirement-names change. So it is never older than the site.
- Both publish paths copy it next to `mod-catalog.json` and `mod-catalog-details.json`.
- Discord message text (`discordPostHtml`) is allowed in this file. The rule that keeps message text out of `mod-catalog-details.json` stays, with its tests.
- `CLAUDE.md` describes the new file.
- The results viewer's home page lists it with a mod count.

## Out of scope

- Download order and the best download. TriOS keeps its own rule, which also uses the version checker.
- The updates feed (`updates.json`).
- Summaries, descriptions and images that TriOS already gets from the other two files.
- Any change to `mod-catalog.json`, `mod-catalog-details.json`, the frozen `ModRepo.json` / `forum-data-bundle.json`, or the website's own files.
- Reading the file in TriOS. That is TriOS's `catalog-extras-data` change.

## Capabilities

### New Capabilities
- `catalog-extras-file`: a per-mod file of site-built facts, published for TriOS.

### Modified Capabilities
None.

## Impact

`lib/site/public_data_builder.dart`, a new model under `lib/site/models/`, `lib/manager/publish_service.dart`, `tool/update-mod-repo.sh` (check only), the viewer's home page, `CLAUDE.md`, new tests. Old TriOS installs don't read the new file, so they are unaffected.
