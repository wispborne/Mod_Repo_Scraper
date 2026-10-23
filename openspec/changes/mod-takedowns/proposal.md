## Why

Authors and other people ask for mods to be taken off Starmodder. There is no way to do that today. Everything is automatic, so a removed mod comes back on the next run. The first request is the Tidal fork of Diable Avionics (`diable-avionics-tidal-fork`). It must be removed without changing the four other mods called "Diable Avionics".

## What Changes

- A takedown list, `takedowns.json`, kept in `qb_data` and copied to StarsectorModRepo on every publish, so it is public. An entry records what it removes and the date. It never includes a reason.
- Two kinds of entry:
  - **One mod**: entered by its permanent id. The entry records the source posts linked to the mod at that time. Only those posts are blocked, so other mods on a shared post stay.
  - **One author**: every mod that credits that person, now and in the future, including mods made with others and forks that still credit them. Names are compared using the same rules the merge uses to combine author spellings. Similar names alone do not count as a match.
- A taken-down mod is left out of `mod-catalog.json`, so TriOS stops listing it. It is also left out of everything Starmodder builds: its page, `mods.json`, the release feed, the sitemap, other mods' "Requires" links and "same name" panels, Collection pages, and redirects from old ids.
- A forum topic or Discord thread whose only mods were taken down is left out of `mod-catalog-details.json`. To make that possible, the catalog is built before the details file instead of after it.
- A taken-down id stays reserved in `mod-ids.json`. No other mod is ever given it. Restoring the entry brings the mod back at its old address.
- Starmodder gets a `404.html` and a matching "no such mod" view, both saying: "This mod may have been removed at the request of its owner...or it may never have existed in the first place. Or something else." A taken-down mod looks the same as a mistyped address. This also fixes the broken, unstyled page every missing mod address shows today.
- The results viewer gets a new sidebar group for manual corrections, with a Takedowns page. The Mod Catalog mod page and the thread page each get a "Take down" button. Taking down and restoring are manager jobs. They wait in the queue and appear in run history. They rebuild the outputs and can publish immediately. Before confirming, the viewer lists exactly which mods would be removed.
- Not changed: the frozen `ModRepo.json` and `forum-data-bundle.json`. Takedowns do not affect old TriOS installs that read them. Git history in StarsectorModRepo is not rewritten.

## Capabilities

### New Capabilities
- `mod-takedowns`: the takedown list, how mod and author entries are matched, what a taken-down mod is left out of, how ids are kept, and the take-down and restore jobs.
- `takedown-viewer`: the viewer's Takedowns page, the "Take down" buttons, the preview of what would be removed, and the read-only API behind them.
- `missing-mod-page`: what Starmodder shows when an address has no mod.

### Modified Capabilities
- `output-publishing`: publishing copies `takedowns.json`. It fails when the published list has entries missing from the local list.

## Impact

- Catalog: `lib/catalog/catalog_step.dart`, `catalog_inputs.dart`, `mod_catalog.dart`, `lib/site/mod_id_store.dart` (reserved ids, `movedIds`).
- Build order: `ScraperService._rebuildBundle` builds the catalog before `BundlePublisher` writes the details file. `BundlePublisher` takes the posts to leave out.
- Site: `lib/site/public_data_builder.dart`, `public_site_step.dart`, `sitemap.dart`; new `site/404.html`; `site/views/mod.js` not-found view; `bin/site_server.dart` serves `404.html` for missing files.
- Manager: new job kinds and request fields in `lib/manager/job.dart` (regenerate `job.mapper.dart`), routing in `modrepo_service.dart`'s `JobRouter`, `publish_service.dart`.
- Viewer: new read-only routes in `lib/viewer/api.dart`; new `web/views/takedowns.js`; sidebar in `web/index.html`; buttons in the Mod Catalog and thread pages; `web/manager.js` `describeJob`.
- Docs: `CLAUDE.md`, and the About page's moderation section on Starmodder.
- No new config keys. TriOS needs no change.
