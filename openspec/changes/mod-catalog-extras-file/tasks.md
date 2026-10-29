## 1. Model and builder

- [x] 1.1 Add `CatalogExtras` and `CatalogExtrasMod` in `lib/site/models/catalog_extras.dart` (`@MappableClass(ignoreNull: true)`), reusing the site's field classes. Run `build_runner`.
- [x] 1.2 Add `buildCatalogExtras(PublicSiteData data)`, which copies the spec's fields from each `PublicModDetail` and its `listing`. Leave out empty lists.
- [x] 1.3 Add `catalogExtrasFilePath` (`<outputPath>/mod-catalog-extras.json`) to `PublicDataBuilder`, and write the file in `write`, after `mods.json`.

## 2. Publishing

- [x] 2.1 In `PublishService`, copy the file into the clone when it exists. Log it when it doesn't. Don't add it to `outputFiles`.
- [x] 2.2 Check that `tool/update-mod-repo.sh` already publishes it through `cp outputs/*.json`. Change nothing there unless that's wrong.

## 3. Tests

- [x] 3.1 Builder test: a fixture mod's record has its id as the key, and holds the same `releases`, `gallery`, `needs`, `aiUse` and `discordPostHtml` as its site file.
- [x] 3.2 Builder test: collections, moved ids and taken-down mods have no record.
- [x] 3.3 Builder test: the record's field names are exactly the spec's list, so a rename fails.
- [x] 3.4 Site step test: `afterMerge` writes the file, and a renamed mod's new `displayName` shows up in it.
- [x] 3.5 Extend "nothing internal reaches the published files" to the new file.
- [x] 3.6 Publish test: the file is copied when present; a publish without it logs and still succeeds.
- [x] 3.7 Confirm `test/catalog/v2_outputs_test.dart` still passes unchanged (no Discord text in the details file).

## 4. Docs and viewer

- [x] 4.1 `CLAUDE.md`: update line 16, and add the file to "What it publishes" under **The public website**.
- [x] 4.2 Update the `PublicSiteStep` class comment the same way.
- [x] 4.3 Results viewer: list the file on the home page (`OUTPUTS` in `web/views/home.js`) with a mod count.
- [x] 4.4 Run `dart analyze` and `dart test`.
