## 1. Bundle Model

- [x] 1.1 Create `lib/bot/scraper/qb/models/forum_data_bundle.dart` — `ForumDataBundle` with updatedAt (DateTime), index (List<QbModSummary>), details (Map<String, QbModDetail>), assumedDownloads (Map<String, List<AssumedDownloadCandidate>>); @MappableClass() with camelCase keys
- [x] 1.2 Create `lib/bot/scraper/qb/models/assumed_download.dart` — `AssumedDownloadCandidate` with 7 fields (originalUrl, resolvedDirectUrl, sourceHost, fileName, confidence, requiresManualStep, linkText); @MappableClass()
- [x] 1.3 Run `dart run build_runner build` to generate mapper files

## 2. Bundle Assembly and Publishing

- [x] 2.1 Create `lib/bot/scraper/qb/bundle_publisher.dart` — `createBundle()` that loads index sorted by topicId, loads all details, strips image localPaths, collects assumed downloads sorted by topicId, sets updatedAt to max scrapedAt
- [x] 2.2 Implement `publish()` — write JSON to {repoPath}/forum-data-bundle.json, git add/commit/push, skip push if nothing to commit
- [x] 2.3 Implement local bundle write to {qbDataPath}/forum-data-bundle.json

## 3. Config Integration

- [x] 3.1 Edit `lib/bot/common.dart` — add to BotConfig: enableQb (bool), qbDataPath (String), qbScope (String), qbBoards (Set<String>), qbDelayMs (int), qbRepoPath (String?), qbLesserBoardMaxPages (int)
- [x] 3.2 Edit `lib/bot/common.dart` readConfig() — parse enable_qb, qb_data_path, qb_scope, qb_boards, qb_delay_ms, qb_repo_path, qb_lesser_board_max_pages with defaults
- [x] 3.3 Add default entries to `config.properties`

## 4. Entry Point Integration

- [x] 4.1 Edit `lib/bot/scraper/main_repo_scraper.dart` — after existing pipeline, conditionally run QB: create scope from config, instantiate store/resolver/engine, run engine with download resolution callback, create bundle, publish, log results
- [x] 4.2 Wrap QB pipeline in try/catch for error isolation

## 5. Verify

- [x] 5.1 Run `dart run build_runner build` and `dart analyze`
- [x] 5.2 Run full pipeline with enable_qb=true, qb_scope=pages (limited), verify forum-data-bundle.json is created
- [x] 5.3 Compare bundle JSON schema against current forum-data-bundle.json from theRoastSuckling/QBForumModData
