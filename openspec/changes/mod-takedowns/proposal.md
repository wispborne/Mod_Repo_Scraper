## Why

Authors and other people ask for mods to be taken off Starmodder. There is no way to do that today. Everything is automatic, so a removed mod comes back on the next run. The first request is the Tidal fork of Diable Avionics (`diable-avionics-tidal-fork`). It must be removed without changing the four other mods called "Diable Avionics".

## What Changes

- A takedown list, `takedowns.json`, kept in `qb_data` and copied to StarsectorModRepo on every publish, so it is public. An entry records what it removes and the date. It never includes a reason.
- Two kinds of entry:
  - **One mod**: entered by its permanent id. The entry records the source posts linked to the mod at that time. Only those posts are blocked, so other mods on a shared post stay.
  - **One author**: every mod that credits that person, now and in the future, including mods made with others and forks that still credit them. Names are compared using the same rules the merge uses to combine author spellings. Similar names alone do not count as a match.
- A taken-down mod is left out of `mod-catalog.json`. It is also left out of everything Starmodder builds: its page, `mods.json`, the release feed, the sitemap, other mods' "Requires" links and "same name" panels, Collection pages, and redirects from old ids.
- Production has not switched to the catalog yet. The cron job still publishes `ModRepo.json` and `forum-data-bundle.json`, and TriOS reads `ModRepo.json`. So until the switch, takedowns apply to those two files as well. In `ModRepo.json` they apply to author entries and to mod entries that block a whole post. A mod entry for one of several mods on a shared post cannot be applied there, because the old merge makes one mod per forum topic.
- A forum topic whose only mods were taken down is left out of `mod-catalog-details.json` and `forum-data-bundle.json`. A Discord thread whose only mods were taken down is left out of `mod-catalog-details.json`. `forum-data-bundle.json` already excludes all Discord answers. The catalog is built before the details file so it can tell the bundle publisher which posts to leave out.
- A taken-down id stays reserved in `mod-ids.json`. No other mod is ever given it. Restoring the entry brings the mod back at its old address.
- Starmodder gets a `404.html` and a matching "no such mod" view, both saying: "This mod may have been removed at the request of its owner...or it may never have existed in the first place. Or something else." A taken-down mod looks the same as a mistyped address. The page is built from the site's own `index.html`, the way each mod's page is. This also fixes the broken, unstyled page every missing mod address shows today.
- Both ways of publishing copy the list and check it: the cron script and a publish from the viewer. A publish fails when the published list has an entry the local list does not, unless a restore removed it.
- The results viewer gets a new sidebar group for manual corrections, with a Takedowns page. The Mod Catalog mod page and the thread page each get a "Take down" button. Taking down and restoring are manager jobs. They wait in the queue and appear in run history. They rebuild the outputs and can publish immediately. Before confirming, the viewer lists exactly which mods would be removed.
- Not changed: git history in StarsectorModRepo is not rewritten. Old TriOS installs keep reading `ModRepo.json` after the switch, and that file is frozen from then on.

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
- Site: `lib/site/public_data_builder.dart`, `public_site_step.dart`, `sitemap.dart`, `mod_page_html.dart` (builds `404.html` from `index.html`); `site/app.js` and `site/views/mod.js` not-found view; `bin/site_server.dart` serves `404.html` for missing files.
- Old files: `ModRepoService` leaves taken-down mods out of `ModRepo.json` until the switch.
- Manager: new job kinds and request fields in `lib/manager/job.dart` (regenerate `job.mapper.dart`), routing in `modrepo_service.dart`'s `JobRouter`, `publish_service.dart`.
- Cron publishing: `tool/update-mod-repo.sh` runs a new `mod_repo_scraper --publish-takedowns <clone folder>` step before it commits.
- Viewer: new read-only routes in `lib/viewer/api.dart`; new `web/views/takedowns.js`; sidebar in `web/index.html`; buttons in the Mod Catalog and thread pages; `web/manager.js` `describeJob`.
- Docs: `CLAUDE.md`, and the About page's moderation section on Starmodder.
- No new config keys. TriOS needs no change.
