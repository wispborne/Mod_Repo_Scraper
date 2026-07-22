## Context

The QB pipeline already went through this: it used to be inline in `MainRepoScraper.main`, and now it is a job the manager runs, callable from the CLI or the browser, with a queue, a history, live progress and a lock. The ModRepo pipeline — scrape Forum/Discord/Nexus, merge, write `ModRepo.json` — is the last thing still inline.

The website can already *read* merge results: the Merge Explorer renders `merge-debug.json`. What it can't do is start a merge, and it can only ever see the newest one, because there is only one file and each run overwrites it.

Constraints worth naming up front:

- **`merge-debug.json` is about 12 MB** on a real run, and `ModRepo.json` about 1.3 MB. Keeping a hundred snapshots the way run records are kept would fill a folder fast.
- **The manager core must not read job-shape config keys.** Environment and guardrails go into the service's constructor; what to do arrives with the request. The Discord and Nexus tokens are environment; "scrape Discord this time" is job shape.
- **No config value may be served to the browser**, the data path excepted.
- **Everything costly is saved as the run goes.** A merge is one in-memory pass, so there is nothing to save part-way — but a `scrapeAndMerge` writes each source cache as that source finishes, which is the same rule.
- The merge rules in `mod_merger.dart` are delicate and heavily tested. This change must not touch them.

## Goals / Non-Goals

**Goals:**

- Start a merge from the website, with or without scraping first, and watch it like any other run.
- Keep the last N merges so a rule change can be judged by comparing before with after.
- Show, per mod, what each source contributed and what came out — field by field, with the winner marked.
- Show what changed between any two merges: mods added, mods gone, fields changed. Searchable and paged.
- The CLI keeps working exactly as it does now, including `qb_manager_url` delegation.

**Non-Goals:**

- Changing any merge rule, score, or alias. This change only watches.
- Editing merge results by hand, or an override file. (The known hard cases still need one; that's a separate change.)
- Running merges on a schedule, or two jobs at once.
- Serving `merge-debug.json` whole to the browser. It is 12 MB; every view stays paged and server-side, as the viewer already requires.

## Decisions

### One job manager, two services, joined by a router

`JobManager` takes a single `JobRunner`. Rather than growing `ScraperService` (already 800 lines, and holder of the QB store, resolver, probe cache and LLM store) a second pipeline, add `ModRepoService implements JobRunner` and a tiny `JobRouter implements JobRunner` that looks at `request.kind` and forwards.

Why: the two pipelines share nothing — different sources, different files, different outputs. The QB service has no business holding a Discord token, and the ModRepo service has no business holding an LLM client. One queue and one lock still cover both, which is what we actually wanted from sharing a manager.

*Alternative considered:* put the merge kinds inside `ScraperService`. Rejected — it makes one class the owner of every secret in the config file, and the constructor already takes two settings objects.

### Two new job kinds, not one with a flag

`JobKind.mergeModRepo` merges from the source cache files already on disk. `JobKind.scrapeAndMerge` fetches the sources first, then merges. Both end the same way: write `ModRepo.json`, write the snapshot.

Why two kinds rather than `mergeModRepo` with `scrapeFirst: true`: the run history shows the kind as a badge and the "run again" button re-posts the stored request. A glance at the history should say whether a run cost network time. A boolean hidden inside the request doesn't do that.

`scrapeAndMerge` carries which sources to fetch (`sources: {forum, discord, nexus}`) as request fields, because that is job shape. A source with no token set is skipped, with a line in the log saying so — the request asking for it is not an error.

### `ModRepoEnvironment` and `ModRepoGuardrails`, mirroring the QB split

- **Environment:** where the source caches live (the working folder today), where `ModRepo.json` goes (`outputs/`), where snapshots go (`<qb_data_path>/merges/`), the Discord token, server id and channel ids, the Nexus token.
- **Guardrails:** per-source scrape timeout (2 minutes today), how many snapshots to keep.
- **Job shape (request only):** which sources, how many forum pages, whether to replay the Discord raw cache, `keepAllGameVersionsFromSameSource`.

`modrepo_less_scraping` maps to page counts on the request, exactly as `_buildQbRequest` maps `qb_scope`.

### Snapshots: one gzipped file per run, keyed by run id

A merge run writes `<qb_data_path>/merges/<run id>.json.gz` — the same `MergeDebugData` as today, JSON with no indentation, gzipped. 12 MB of indented JSON with heavy repetition compresses to roughly 1 MB, so the default of 20 kept snapshots costs tens of megabytes rather than a quarter of a gigabyte.

The newest snapshot is *also* written to `merge-debug.json` in the working folder, uncompressed, exactly as today. Nothing that reads that file has to change, and the CLI's behaviour is unchanged for anyone not using the website.

`MergeSnapshotStore` handles listing, reading by id, and trimming, and follows `RunHistoryStore`'s deletion rules to the letter: only files directly inside `merges/`, only names ending `.json.gz`, and a snapshot belonging to a run that hasn't ended is never dropped. Snapshots are paperwork about a run, like log files — no scraped data and no output ever lives in `merges/`.

*Alternative considered:* keep snapshots in `runs/` next to the log files. Rejected — `RunHistoryStore` trims `runs/` on its own schedule (`qb_runs_to_keep`, default 100), and snapshots need a much smaller number. Two folders, two limits, no surprise deletions.

### Debug collection is always on for website-started merges

`modrepo_merge_debug` stays the switch for CLI runs, so production keeps writing nothing extra. A merge started from the browser always collects, because a run you can't look at afterwards is not worth the button. The request carries the flag; `_buildModRepoRequest` reads the config key for CLI runs, and `web/manager.js` always sends `true`.

### Before/after is worked out on the server from what the collector already records

The collector records, per group: the members that went in, the match reasons, and the merge steps (`left`, `right`, which had priority, `result`). That is enough to answer "which source won this field" without changing the collector: for each field of the final mod, walk the steps and find the last one whose `result` value for that field differs from its `left` — that step's winning side is the source that supplied it.

So the "before and after" view is a new endpoint, `GET /api/merge/groups/<id>/fields`, returning one row per field: the value each member had, the final value, and which source it came from. No change to `mod_merger.dart` or `MergeDebugCollector`.

*Alternative considered:* have the collector record field provenance directly. Rejected for now — it means editing the merge code to serve a viewer feature, and the answer is already derivable. If the derivation turns out to be wrong in some case, that's a follow-up change with a test.

### Comparing two runs: keyed by forum topic, then by name and authors

`GET /api/merge/compare?a=<run id>&b=<run id>` reads both snapshots' final output lists and reports:

- **added** — in B, not in A;
- **gone** — in A, not in B;
- **changed** — in both, with at least one differing field, listing the fields and both values;
- **same** — counted only, never listed.

The key is the forum topic id when the mod has one, otherwise the mod's name and authors run through the same `_prepForMatching` normalizing the merger uses, so a mod whose name gained a version suffix still lines up. Mods that key the same way inside one run (it happens) are compared as a set under that key and reported as changed if the set differs.

The result is computed on demand and held in memory keyed by the two ids, since snapshots never change once written. Search and paging happen on the computed list, like every other list endpoint.

*Alternative considered:* diff the raw JSON. Rejected — it produces noise (list ordering, timings) and nothing a person can search by mod name.

### Cancel, progress and honesty about part-done merges

`ModRepoService` checks the cancel token between sources and between merge phases. A merge cancelled part-way writes **nothing** — no `ModRepo.json`, no snapshot — because a half-merged repo is worse than an old one. The run is recorded as cancelled and the log says the output was left alone. A `scrapeAndMerge` cancelled after a source finished keeps that source's cache file, which is the point of the caches.

Progress is reported as phases (`Forum`, `Discord`, `Nexus`, `Merge`, `Save`) with `itemsDone`/`itemsTotal` over the mods being merged, so the bar means something on the long step.

### Frontend: the Merge Explorer grows a run picker, two tabs, and a start panel

`web/views/merge.js` gains:

- a run picker at the top of every merge page (`?run=<id>`, default newest), reading `GET /api/merge/runs`;
- **Before/after** — reachable from a group, showing the per-field table;
- **What changed** — pick two runs, see added/gone/changed, search by mod name or author, paged.

`web/views/runs.js` gains a start-a-merge panel next to the existing start-a-job one, with the source tick boxes visible so the form says what it will do. `web/manager.js` gains `describeJob` sentences for the two kinds — the confirm box for `scrapeAndMerge` says plainly that it will fetch from three websites and can take a few minutes.

With the manager off, the picker and the views still work (they read files), and no buttons are drawn. That is the existing rule, unchanged.

## Risks / Trade-offs

- **Snapshots fill the disk** → gzipped, small default (20), trimmed on every save, and the limit is a config key. The trim is written against the same rules that keep `RunHistoryStore` from deleting anything it shouldn't, and gets the same test.
- **Moving the ModRepo pipeline out of `main()` breaks the CLI** → the move is mechanical and the CLI's observable behaviour (log lines, files written, exit code) is pinned by a test before the move, not after.
- **Field-level "who won" is derived, not recorded** → it can only be as good as the steps the collector saved. Where a field's origin can't be pinned to one step, the view says "couldn't tell" rather than guessing. A guessed answer here would be worse than no answer, since the whole point is judging the rules.
- **One queue means a merge waits behind a long QB scrape** → accepted. They don't share files, but they do share the machine, and one queue is far simpler than two. The queue is visible on the Runs view, so the wait is never a mystery.
- **`scrapeAndMerge` from the browser spends network time and uses real tokens** → it is behind a confirm box that says so, and the tokens come from the environment, so no request can point it somewhere else.
- **Comparing two big snapshots costs memory** → both are read, compared, and the result cached; the snapshots themselves are dropped after. Roughly 25 MB peak for two decompressed snapshots, on a local tool that already reads a 12 MB file.

## Migration Plan

1. Add the new job kinds and the ModRepo service, with the CLI still calling the old inline code. Nothing changes for anyone.
2. Switch the CLI's ModRepo block to build a request and submit it, deleting the inline code. Behaviour pinned by the test written in step 1.
3. Add the snapshot store and start writing `merges/`, keeping the `merge-debug.json` write.
4. Add the API endpoints, then the frontend.

Rolling back at any step means not taking the next one; the only irreversible bit is deleting the inline pipeline in step 2, which is a revert away.

## Open Questions

- Should a merge run also be offered on the Topics view (merge just these mods)? Probably not — merging is whole-repo by nature — but worth asking once the views exist.
- Where should the default of 20 snapshots settle after real use? It is a config key, so it can move without a code change.
