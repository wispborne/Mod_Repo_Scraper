## Why

The final piece of the QBMBAMM port: assemble all scraped data into a `forum-data-bundle.json` matching the schema consumed by QBMBAMM clients, and wire the QB pipeline into the existing scraper entry point. This is part 3 of 3 — it depends on `qb-forum-scraping` (data store, models) and `qb-download-resolution` (resolved download candidates).

## What Changes

- Add `ForumDataBundle` model (updatedAt, index, details, assumedDownloads)
- Add bundle assembly: load index + details + download candidates, sort by topicId for stable diffs, strip local image paths
- Add git publisher: write bundle JSON to local repo clone, `git add/commit/push`
- Add QB config fields to `BotConfig` in `lib/bot/common.dart`: `enableQb`, `qbDataPath`, `qbScope`, `qbBoards`, `qbDelayMs`, `qbRepoPath`, `qbLesserBoardMaxPages`
- Add config parsing for new `config.properties` entries
- Add QB pipeline invocation in `main_repo_scraper.dart` after existing Forum/Discord/Nexus pipeline
- Add new default entries to `config.properties`

## Capabilities

### New Capabilities

- `qb-bundle-publishing`: Bundle assembly, git publishing, config integration, entry point wiring

### Modified Capabilities

(none)

## Impact

- **New files**: 2 Dart files (`models/forum_data_bundle.dart`, `bundle_publisher.dart`)
- **Edited files**: `lib/bot/common.dart` (BotConfig + parsing), `lib/bot/scraper/main_repo_scraper.dart` (QB pipeline call), `config.properties` (new entries)
- **Disk**: Writes `forum-data-bundle.json` to data dir and optionally to repo clone
- **Network**: Git push to configured remote (only if `qb_repo_path` is set)
- **Depends on**: `qb-forum-scraping` (store, models, engine), `qb-download-resolution` (resolver)
