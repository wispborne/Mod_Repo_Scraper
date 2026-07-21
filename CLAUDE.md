# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Dart CLI that scrapes Starsector mod metadata from several sources and produces two outputs consumed by the TriOS launcher:

- `outputs/ModRepo.json` — merged, deduplicated mods from Forum + Discord + Nexus (the "ModRepo" pipeline).
- `outputs/forum-data-bundle.json` — a richer per-topic bundle with images, download links, and optional LLM-extracted facts (the "QB" pipeline).

Both pipelines run from one entry point and are toggled independently in `config.properties`.

## Commands

```bash
dart pub get                       # install deps
dart run bin/scraper_main.dart     # run the scraper (reads config.properties)
dart test                          # run all tests
dart test test/mod_merger_test.dart            # run one test file
dart test --name "substring of test name"      # run tests matching a name
dart analyze                       # lint (see analysis_options.yaml for extra rules)
dart run bin/viewer_server.dart    # local read-only results viewer at http://127.0.0.1:8085
dart compile exe bin/scraper_main.dart -o mod_repo_scraper   # what CI ships
```

### Code generation (dart_mappable)

JSON models use `dart_mappable`. Every `*.dart` model has a generated `*.mapper.dart` sibling that is committed to the repo. After changing any `@MappableClass` model, regenerate:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Do not hand-edit `*.mapper.dart` files — they are overwritten by the build.

## Configuration

Everything is driven by `config.properties` (read by `Common.readConfig()`; fields live on `BotConfig` in `lib/bot/common.dart`). This file holds real auth tokens and is committed — do not paste its contents anywhere external. Every key is snake_case and starts with its group prefix (`modrepo_`, `qb_`, `llm_`); only `log_level` is global. Unknown keys are warned about at startup, so a typo or an old (pre-rename) key name is caught right away. Key switches:

- `modrepo_enabled`, `modrepo_forums_enabled`, `modrepo_discord_enabled`, `modrepo_nexus_enabled` — the ModRepo pipeline and its sources.
- `qb_enabled`, `qb_scope` (`new_data` / `all` / `pages` / `topics` / `libraries_only`; camelCase spellings like `newData` also work), `qb_boards` (`main`/`lesser`/`libraries`) — the QB pipeline.
- `modrepo_use_cached` / `qb_use_cached` — replay from the on-disk raw-HTTP caches instead of hitting the network (see Caching below).
- `llm_enabled` and the `llm_*` keys — optional LLM post-extraction (off in production by default).
- `modrepo_merge_debug` — write `merge-debug.json` for the viewer's Merge view.

## Architecture

Orchestration lives in `lib/bot/scraper/main_repo_scraper.dart` (`MainRepoScraper.main`), which runs the two pipelines in sequence.

### ModRepo pipeline (Forum / Discord / Nexus → merge → ModRepo.json)

- Scrapers: `forum_scraper.dart`, `discord_reader.dart`, `nexus_reader.dart`. Forum and Nexus run through `_loadOrRun` (per-source `<name>_cache.json`); Discord uses a raw-HTTP `CachingClient` (`discord_raw_cache.json`).
- Merge: `mod_merger.dart` — buckets by forum `topic=<id>`, then a trigram index narrows candidates, then subsequence fuzzy match (`fuzzy/fuzzy.dart`) + author aliases (`mod_repo_utils.dart`), then same-source dedup / merge / validate. Optional `MergeDebugCollector` records why each group formed, written to `merge-debug.json`.
- Model: `scraped_mod.dart` (`ScrapedMod`, `ModSource`, `ModUrlType`, `Image`).

### QB pipeline (`lib/bot/scraper/qb/`)

Adapted from a separate C# project (theRoastSuckling's QBMBAMM); its scraper was ported, but this repo is the consumer's fork. Flow driven by `QbScraperEngine.run(scope, onTopicSaved:)`:

1. `mod_index_scraper.dart` / `board_scraper.dart` walk the configured forum boards for topic summaries.
2. `topic_scraper.dart` + `html_processor.dart` fetch and parse each topic page.
3. `download_resolver.dart` turns links into download candidates using host-specific rules (Google Drive, Dropbox, MediaFire, GitHub, forum attachments…); cached in `assumed-downloads-cache.json`.
4. Results are persisted incrementally by `json_data_store.dart` into `qb_data_path` as `mods-index.json` plus `mods/<id>/detail.json`.
5. `bundle_publisher.dart` assembles `forum-data-bundle.json` from the store + resolver + LLM store.

Scraping is pipelined: `onTopicSaved` runs download resolution (and LLM extraction) per topic as it is saved, rather than in separate passes.

### QB LLM extraction (`lib/bot/scraper/qb/llm/`, optional)

When `llm_enabled=true`, `PostExtractor` sends each post once to any OpenAI-compatible chat endpoint (`openai_client.dart` / `llm_client.dart`, prompt in `prompt.dart`) to pull out facts the rules miss: extra downloads, changelog, mod version, support links, license, and optional summaries. `post_reducer.dart` trims post HTML first. Results are cached in `llm-extraction-cache.json` via `extraction_store.dart`, so re-runs only pay for new/changed posts.

Coverage is over the **store**, not over this run's scrape. `MainRepoScraper._runLlmCoveragePass` walks the whole mods index after the scrape and calls `extractForTopic` on every stored topic, so a topic that was scraped before the LLM was switched on still gets picked up. Topics scraped this run were already extracted inside the pipelined `onTopicSaved` loop and come back as free store hits in the pass, so they are not paid for twice — that rests on `extractForTopic` doing its freshness check *before* `_reserveSlot()`. `llm_max_topics` caps live calls per run (not topics visited), so a big backlog can be worked through in bounded chunks; each run resumes where the last stopped, and logs how many topics still have no results.

Two special modes in `main_repo_scraper.dart`: `llm_reprocess_only` (the same coverage pass, minus the scrape, then rebuild the bundle) and `llm_test_mode` (small non-persisting trial → `llm-test-output.json`).

### Caching model (important)

Two independent cache layers — do not conflate them:

- **Raw-HTTP caches** (`CachingClient`): `discord_raw_cache.json`, `<qb_data_path>/qb_raw_cache.json`. When `use_cached`/`qb_use_cached` and the file exists, the client *replays* recorded responses (`isReplaying == true`) and the throttle delay drops to 0. Caches are only re-saved when not replaying. When recording, each response is written to the file as it arrives (one JSON object per line), so an interrupted run keeps what it fetched; `CachingClient.fromFile` also reads the older "one big JSON list" format.
- **Derived caches**: per-source `<name>_cache.json` (ModRepo), `assumed-downloads-cache.json`, `link-downloadable-cache.json` (per-URL "is this a direct download?" probe results), `llm-extraction-cache.json`. These store processed results so pipeline stages can re-run without recomputation. Note the `link-downloadable-cache.json` probes are live network HEAD/GET calls that bypass the raw-HTTP replay layer, so without this cache every topic re-probes the network even when `qb_use_cached=true`.

**Everything that costs money or network time is saved as the run goes, not at the end.** A run killed with Ctrl-C, or one that dies part-way, must not throw away the work it already did — the next run should pick up where it left off. So: `mods-index.json` is written every 10 topics (it names the `detail.json` files, which are written per topic — an unsaved index orphans them and the next run re-scrapes them all), `assumed-downloads-cache.json` every 10 resolved topics, `link-downloadable-cache.json` every 10 probes, `llm-extraction-cache.json` every 5 topics or 5 seconds. Each also gets a final save at the end, on the failure path too. Keep it that way when adding a cache: the only end-of-run writes should be *derived outputs* (`ModRepo.json`, `forum-data-bundle.json`, `merge-debug.json`), which can always be rebuilt from the caches. The ModRepo per-source caches (`<name>_cache.json`) are still all-or-nothing.

### Results viewer (`bin/viewer_server.dart`, `lib/viewer/`, `web/`)

A local `shelf` server that serves the static `web/` frontend plus a JSON API (`lib/viewer/api.dart`, `data_access.dart`) over the output files. Read-only, binds to `127.0.0.1` only, and never reads `config.properties` — so tokens can't reach the browser. When output/bundle shapes change, keep this viewer in sync. Default dirs: `--data-dir qb_data`, `--outputs-dir outputs`, `--root-dir .`.

## Conventions

- **Plain English** in all user-facing copy (viewer text, FAQ, docs) and in explanations. Avoid jargon.
- `analysis_options.yaml` enforces `avoid_print` (use the `timber`/`logging` helpers, not `print`), required return types, and prefer-final/const rules.
- Spec-driven changes live under `openspec/` (`specs/` are current capabilities, `changes/` are proposals). Use the `opsx:*` skills to propose/apply/archive changes here.
- For any Starsector game/API/modding question, use the `starsector-knowledge` skill — never answer from memory, since the API changes between game versions.
