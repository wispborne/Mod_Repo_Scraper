## Context

`PublicSiteStep._rebuild` (`lib/site/public_site_step.dart`) builds a `PublicSiteData` and hands it to `PublicDataBuilder.write` (`lib/site/public_data_builder.dart:854`). Both `afterBundle` and `afterMerge` go through `_rebuild`. `afterMerge` is called by the merge job (`lib/manager/modrepo_service.dart:199`) and by the requirement-names job (`lib/manager/scraper_service.dart:893`).

`PublicSiteData.details` already holds a finished `PublicModDetail` for every published mod, keyed by its id. Each detail carries its `PublicMod` as `listing`. Collections, moved ids and taken-down ids are kept apart from it. Every field the new file needs is already on one of those two models. So the new file is a copy of selected fields, with no new rules.

Today all 1,290 site ids are also ids in `mod-catalog.json`. The in-flight `publish-unmerged-thread-mods` change may publish thread mods the catalog doesn't list. Their ids would still be permanent ids from `ModIdStore`. TriOS ignores ids it doesn't know.

## Decisions

### Build the file from `PublicSiteData`, inside `write`
A pure function, `buildCatalogExtras(PublicSiteData data)`, makes the file's model from `data.details`. `write` saves it to `<outputPath>/mod-catalog-extras.json`, after `mods.json`.

Why: the record is a copy of fields the build has already worked out. Copying from the finished models means the file and the site can't disagree. Writing inside `write` means every build that writes the site also writes this file.

### New models in `lib/site/models/catalog_extras.dart`
- `CatalogExtras {schemaVersion, generatedAt, mods: Map<String, CatalogExtrasMod>}`
- `CatalogExtrasMod` with the spec's fields.

Both use `@MappableClass(ignoreNull: true)`, like `PublicMod`. The field types reuse the site's own classes: `PublicNeededMod`, `ModRelease`, `SaveAnswer`, `LlmAiUse`, `PublicSameNameMod`, `PublicImage`.

`schemaVersion` starts at 1. It goes up when a field is renamed or changes shape. Adding a field does not bump it.

### Field names that differ from the brief
- `otherAuthorNames` is a map from the credited name to that person's other names (`Map<String, List<String>>`), not a flat list. It is kept that way. One flat list would make two people on the same mod read as two spellings of one name.
- The add-to-save quote is `saveCompatibilityText`, not `canAddText`. Its partners are `updateCompatibilityText` and `removalCompatibilityText`.
- `lastReleaseDate` is a full date-time. `addedOn` and `editedOn` are `YYYY-MM-DD` text, as on the site.
- `releases` reuses `ModRelease`, which also has `modId`, `modName` and `gameVersion`. The id and name are repeated per release. That costs little (the whole release list is about 0.14 MB), and it avoids a second release class.

### Encoding and size
The file is written with two-space indent, like the other outputs, so commits show readable diffs.

Measured from today's outputs (1,289 mods): 3.7 MB indented, 2.8 MB compact. `discordPostHtml` is about 0.5 MB of that, and `gallery` about 1.7 MB. If size becomes a problem, compact encoding is the first step.

### Publishing
- `PublishService` (`lib/manager/publish_service.dart`): add the file to the copy step, but not to `outputFiles`. `outputFiles` fails the publish when a file is missing. The extras file is copied when present, and a missing one is logged.
- `tool/update-mod-repo.sh` already copies `outputs/*.json` into the clone (line 96), so the cron path needs no change. Check it and say so in the task.

### Discord text
`discordPostHtml` is the same cleaned HTML the site shows. The no-message-text rule stays on the details file. `test/catalog/v2_outputs_test.dart` keeps its two checks unchanged. The "nothing internal reaches the published files" test (`test/site/public_data_builder_test.dart:2974`) is extended to the new file.

### Docs and viewer
- `CLAUDE.md`, line 16: say that the site build writes `mod-catalog-extras.json` for TriOS, and still changes neither of the other two outputs. Add an entry to the "What it publishes" list in **The public website**.
- `lib/site/public_site_step.dart`, class comment: the same wording.
- Results viewer: add the file to `OUTPUTS` in `web/views/home.js`, with a mod count. This follows the CLAUDE.md rule to keep the viewer in step with output shapes. It needs a small count route in `lib/viewer/api.dart` / `data_access.dart`.

## Risks

- **TriOS reads a file the site build is free to change.** The site's field names are reused here. A rename on the site would silently rename it here too. Mitigation: a test pins the record's field names, so a rename fails the test and forces a `schemaVersion` bump.
- **A build that fails halfway** could leave an extras file from the last build next to newer outputs. This is the same risk `mods.json` has today. No extra handling.
