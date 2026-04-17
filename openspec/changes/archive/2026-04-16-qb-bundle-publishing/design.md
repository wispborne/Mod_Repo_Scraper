## Context

This is the final piece of the QBMBAMM port. It assembles all scraped data (from `qb-forum-scraping`) and resolved downloads (from `qb-download-resolution`) into a `forum-data-bundle.json` matching the schema consumed by QBMBAMM clients. It also wires the QB pipeline into the existing entry point.

**C# source files being ported:**
- `QBModsBrowser.Server/Models/ForumDataBundle.cs` — bundle model
- `QBModsBrowser.Server/Services/ForumDataBundler.cs` — assembly logic
- `QBModsBrowser.Server/Services/ForumDataPublisher.cs` — git commit/push

**Existing files being edited:**
- `lib/bot/common.dart` — add QB fields to BotConfig
- `lib/bot/scraper/main_repo_scraper.dart` — add QB pipeline invocation
- `config.properties` — add new entries

## Goals / Non-Goals

**Goals:**
- Produce `forum-data-bundle.json` with identical schema to C# output
- Sort by topicId for stable git diffs
- Git add/commit/push to configured repo clone
- Integrate QB pipeline into existing entry point, controlled by config

**Non-Goals:**
- Remote bundle fetching (that's a QBMBAMM client feature)
- Auto-scrape scheduling (the existing cron job handles timing)

## Decisions

### Sequential execution after existing pipeline
Both pipelines hit the same forum. Running them in parallel would double request rate. The existing pipeline is fast (~2 min), so sequential adds acceptable time.

### Bundle written locally regardless of publish config
The bundle is always written to `{qbDataPath}/forum-data-bundle.json` for local access. Git publishing is optional (only when `qb_repo_path` is configured).

### Config in existing config.properties
Adds 7 new entries to the existing file rather than a separate config. Keeps things simple for a single cron job.

### Git via Process.run
The C# version shells out to `git`. We do the same with `Process.run` from `dart:io`. Simple and reliable.

### File layout

```
lib/bot/scraper/qb/
  models/
    forum_data_bundle.dart    ← ForumDataBundle model
  bundle_publisher.dart       ← assembly + git publish
```

## Risks / Trade-offs

**[Risk] Bundle JSON format drift** → Dart's JSON encoder may produce slightly different whitespace. Mitigated by comparing against the published C# bundle during verification.

**[Trade-off] Config parsing is simple string-based** → Matches existing pattern in `readConfig()`. No validation beyond type parsing.
