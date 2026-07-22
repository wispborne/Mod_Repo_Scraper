## Why

The Merge Explorer can now show what changed between two merges, and it turns out that is the question people actually have about the QB side too: *this run cost an hour and forty LLM calls — what did it actually change?* Right now there is no way to answer that. `forum-data-bundle.json` is overwritten by every run that publishes it, so the previous answer is gone the moment the new one lands.

## What Changes

- **Every run that writes the bundle saves a snapshot of it** — which turns out to be every job kind except the prompt trial `llmTest`, since even a single-topic re-scrape ends by republishing — under `<qb_data_path>/bundles/<run id>.json.gz`, newest 20 kept.
- **The snapshot leaves out the post HTML**, keeping a short fingerprint of each post instead. That is what makes this affordable: 15.5 MB of bundle becomes 1.2 MB a snapshot rather than 4.3 MB, the same size as the merge snapshots. A post that changed still shows up as changed; the before-and-after words of the post itself are not kept.
- **A what-changed page for bundles**, alongside the merge one: pick two saved bundles, see topics **added**, **gone** and **changed**, with the changed ones naming the fields and both values. Searchable by title and author, paged.
- **"What did this run change?"** — a run's detail page gets a link comparing that run's bundle against the one before it, which is the comparison people want most and takes two clicks otherwise.
- **The comparison code becomes shared.** The merge what-changed and the bundle what-changed differ only in how rows are keyed and which fields are worth looking at, so one helper does both. The merge behaviour does not change.

## Capabilities

### New Capabilities
- `bundle-run-history`: saved bundle snapshots — one per run that publishes a bundle, what is left out of them and why, newest N kept, listed and read back by id.
- `bundle-comparison`: what changed between two saved bundles — topics added, gone and changed, the fields worth comparing, and the shortcut from a run to what it changed.

### Modified Capabilities
- `viewer-output-browsing`: the Bundle view gains a run picker and a what-changed page.
- `scraper-configuration`: a new key for how many bundle snapshots to keep.

## Impact

- **New:** `lib/manager/bundle_snapshot_store.dart`, `lib/viewer/bundle_views.dart`, `web/views/bundle_compare.js`, new bundle routes in `lib/viewer/api.dart`.
- **Changed:** `lib/manager/scraper_service.dart` (`_rebuildBundle` saves a snapshot), `lib/manager/scraper_settings.dart` (the keep-count joins the environment), `lib/viewer/merge_views.dart` (the comparison helper moves out to be shared), `lib/viewer/data_access.dart`, `web/views/bundle.js`, `web/views/run.js`, `config.example.properties`, `CLAUDE.md`.
- **Not changed:** the bundle itself — its shape, what goes in it, and when it is published are all exactly as they were. A snapshot is paperwork about a run, like its log; it is not an output and cannot be published as one.
- **Disk:** about 24 MB for twenty snapshots, on top of the ~23 MB the merge snapshots already use.
