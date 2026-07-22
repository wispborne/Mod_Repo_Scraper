## Why

Tuning the ModRepo matching rules means running the CLI, waiting, then squinting at whatever `merge-debug.json` happens to hold. There is only ever one file, so you can never see what a rule change actually did — the old picture is gone the moment the new run finishes. The website already runs QB jobs and shows their history; merging is the one pipeline still stuck on the command line.

This change puts merging on the website: press a button, watch it run, then look at what went in, what came out, and what changed since last time.

## What Changes

- **Merging becomes a job the manager can run.** Two new job kinds: `mergeModRepo` (merge from the source files already saved on disk — no network) and `scrapeAndMerge` (fetch Forum, Discord and Nexus fresh, then merge). Both write `ModRepo.json` and a merge debug snapshot.
- **The ModRepo pipeline moves out of `main_repo_scraper.dart` and into the manager core**, alongside the QB pipeline. The CLI keeps behaving exactly as it does now — it just asks the manager for the job instead of doing it inline, the same way the QB pipeline already does.
- **Merge results are kept per run, not overwritten.** Each merge run saves its own snapshot under `<qb_data_path>/merges/<run id>.json`, and the newest N are kept (older ones dropped, same rule as run history). `merge-debug.json` in the working folder stays as the "latest" file, so nothing outside this change has to move.
- **The Runs view gains a start-a-merge panel** and merge runs show up in the same history, with the same live progress, cancel button and log.
- **The Merge Explorer learns three new things:**
  - it can show any saved merge run, not just the latest, with a picker at the top;
  - a **before and after** page per mod — the raw entries each source contributed on the left, the single merged mod that came out on the right, field by field, with the winning source marked;
  - a **what changed** page comparing any two merge runs — mods added, mods gone, and fields that changed — searchable and paged like everything else.
- Merge debug collection is always on for website-started merges, so a run you asked for from the browser can always be looked at afterwards. `modrepo_merge_debug` still decides it for CLI runs.
- **Manager off is still a mode.** With the manager off, the Merge Explorer reads the latest snapshot and shows no buttons, exactly as it does today.

## Capabilities

### New Capabilities
- `modrepo-jobs`: merging (and optional scraping) as manager job kinds — what each kind does, what it writes, what it never touches, and how the CLI hands its ModRepo work to the manager.
- `merge-run-history`: saved merge snapshots — one file per merge run, newest N kept, listed and read back by id, and never confused with the run paperwork in `runs/`.
- `merge-comparison`: the before/after picture — per-mod inputs versus merged output, and the difference between two merge runs.

### Modified Capabilities
- `viewer-merge-explorer`: the explorer reads a chosen merge run rather than always the newest file, and gains the before/after and what-changed views alongside the existing ones.
- `merge-debug-json`: a merge run also writes a snapshot under the data folder keyed by run id, not only `merge-debug.json`; website-started merges always collect debug data regardless of `modrepo_merge_debug`.
- `scraper-configuration`: a new key for how many merge snapshots to keep, and `modrepo_merge_debug` narrowed to CLI runs only.

## Impact

- **New:** `lib/manager/modrepo_service.dart` (or the ModRepo half of `scraper_service.dart`), `lib/manager/merge_snapshot_store.dart`, `web/views/merge.js` additions, new merge routes in `lib/viewer/api.dart`.
- **Changed:** `lib/manager/job.dart` (two new `JobKind` values — regenerate `job.mapper.dart`), `lib/manager/scraper_service.dart`, `lib/manager/scraper_settings.dart` (source tokens and cache paths become environment), `lib/manager/manager_api.dart` (job submission accepts the new kinds), `lib/bot/scraper/main_repo_scraper.dart` (ModRepo block becomes a job request), `lib/viewer/data_access.dart`, `web/manager.js` (`describeJob` sentences), `web/views/runs.js`, `config.example.properties`, `CLAUDE.md`.
- **Not changed:** `mod_merger.dart` and the merge rules themselves, the QB pipeline, the output shape of `ModRepo.json`.
- **Cost:** `scrapeAndMerge` hits the network and needs the Discord and Nexus tokens; `mergeModRepo` costs nothing but disk and CPU. Neither ever calls an LLM.
