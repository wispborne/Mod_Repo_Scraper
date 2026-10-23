## 1. The list and matching

- [ ] 1.1 Add a `TakedownList` model (`lib/catalog/takedowns.dart`, `dart_mappable`) with mod entries (`id`, `name`, `posts`, `on`) and author entries (`names`, `on`). Treat a missing file as an empty list. Fail if an existing file cannot be read. Write a replacement file first, then move it over the old file. Regenerate mappers.
- [ ] 1.2 Add `ModRepoUtils.samePerson(a, b)` from `_peopleNamedIn`, `_plainName`, `_plainNameWithoutTag` and the `authorAliases` rows. Test: "tidal5590" matches "Tidal" and "TIDAL", "Dreadnought70" matches "Dreadnought", "Tidal" does not match "Tidalwave", "Nes" matches "nescom", a credit naming two people matches either.
- [ ] 1.3 Add the code that works out a mod entry's post keys from a `ModCatalog`: the whole post when no other catalog mod comes from it, otherwise the named key. A Collection's id gives an entry with no posts. Test with a one-mod Discord thread, a four-mod forum topic and a Collection.

## 2. The catalog step

- [ ] 2.1 In `CatalogStep`, take the list read at the start of the job. Remove listings blocked by mod entries before `ModMerger.mergeListings`: every listing of a whole-post key, and each listing on a named key's post whose LLM name matches the key's name by `modNamesMatch`.
- [ ] 2.2 Pass the blocked listings' source-post references to `ModIdStore.beginRun` with the rest. Make the id store treat stored names matched by blocked listings as still present, including when the current spelling differs from the stored key.
- [ ] 2.3 After merging and assigning ids, drop mods given a taken-down id, and mods with a credited author matching an author entry.
- [ ] 2.4 Give `ModIdStore.movedIds` every id named by a mod entry and every id removed by an author entry in this build. Include mod-entry ids whose listings were blocked before ids were assigned. Exclude these ids as both old ids and destinations. Save no move involving them in `mod-ids.json`. Keep their ids and existing post links.
- [ ] 2.5 Remove dropped mods' ids from every Collection's `modIds`. Leave out a Collection with no mods left, and a Collection whose id has a mod entry.
- [ ] 2.6 Return the keys of posts whose listings were all removed. Log the mods or Collection pages each entry left out. Warn when an entry removed neither. Save the same report to `<qb_data_path>/takedown-matches.json`.
- [ ] 2.7 Test the Tidal fork: a catalog with thread 1507163509224509510 (LLM name "Diable Avionics", credited tidal5590) and the five other Diable Avionics mods. With the entry, only `diable-avionics-tidal-fork` is gone, and the others keep the same source posts. With the entry removed, the fork is back under the same id.
- [ ] 2.8 Test renames on a shared topic: "Useful.Tithes" renamed to "Useful Tithes" is blocked before the merge; a bigger rename is given the entry's id by the id store and dropped; a rename the id store declines is published under a new id and warned about. The topic's other mods stay in every case.
- [ ] 2.9 Test that a new mod on the same topic is not given the blocked mod's id when its name is similar but does not match by `modNamesMatch`. Run the test with the blocked listing's stored spelling and with a punctuation change that still matches the takedown key.
- [ ] 2.10 Test an author entry removing a mod made with others and a mod first seen after the entry was made.
- [ ] 2.11 Test that an author entry removing one of two mods on a forum topic leaves its id out of `movedIds` and saves no move.
- [ ] 2.12 Test Collections: one with every mod removed is gone from the catalog and has no page; a Collection taken down by its id is gone while its mods stay.

## 3. Build order and the details file

- [ ] 3.1 In `ScraperService._rebuildBundle`, run the catalog step before `BundlePublisher.createBundle`, then the site step.
- [ ] 3.2 Give `BundlePublisher.createBundle` the post keys to leave out, and drop those topics from `index`, `details` and `assumedDownloads`, and those threads from `discordThreads`.
- [ ] 3.3 Test: the Tidal fork's thread is missing from `mod-catalog-details.json`, and a shared topic with one taken-down mod is still there in full.
- [ ] 3.4 Check the existing `_rebuildBundle` tests still pass with the new order, and that a cancelled catalog step still writes nothing.

## 4. ModRepo.json until the switch

- [ ] 4.1 In `ModRepoService`, read the list when the job starts, and fail the job before `ModRepo.json` is written when it cannot be read.
- [ ] 4.2 Just before writing `ModRepo.json`, leave out merged mods credited to an author entry, and mods whose forum topic or Discord thread (read from their links) is a whole-post key. Log each mod entry with named keys as not applied to `ModRepo.json`.
- [ ] 4.3 Test: the Tidal fork leaves `ModRepo.json` and the other Diable Avionics mods stay; an author entry removes its mods; a named key removes nothing and is logged.

## 5. The site build

- [ ] 5.1 Check `PublicDataBuilder` leaves a taken-down mod out of `mods.json`, its own files, "Requires" links (name kept as plain text), "same name" panels, `updates.json`, `updates.xml` and `sitemap.xml`. When the release state still contains a taken-down mod, include only releases whose mod ids are in the catalog. Add tests for each.
- [ ] 5.2 Make sure no moved-id redirect page or file points at a taken-down mod.

## 6. The not-found page

- [ ] 6.1 In the site step, build `outputs/site/404.html` from `site/index.html` the way `mod_page_html.dart` builds mod pages. The swapped head region holds a "Not found" title, `noindex`, `<base href="/">` and the not-found mark. When `index.html` cannot be read or has lost its marks, write a small plain page with the message and a link to the front page, and log it.
- [ ] 6.2 In `site/app.js`, use the mark to show the not-found view at the requested address on startup. Keep that address unchanged. Let Home, Browse and search results use normal routing, and show the not-found view again when returning to the missing address. The view links to the front page and Browse, and shows the message: "This mod may have been removed at the request of its owner...or it may never have existed in the first place. Or something else."
- [ ] 6.3 In `site/views/mod.js`, show the same message only when `mods/<id>.json` returns 404 or a successful response is not JSON. Keep the response status available when handling failures. Show an error with its reason for every other failure, including an HTML response with status 500.
- [ ] 6.4 Make `bin/site_server.dart` answer a missing file with the built `404.html` and status 404.
- [ ] 6.5 Check in the browser on the local site server: a missing mod folder, a missing folder two levels deep, a missing `.json`, `#/mods/no-such-mod`, and a mod page with the connection dropped. Check in two themes the reader picked and at phone width, and that the nav and search box work on the not-found page.
- [ ] 6.6 Check on a Cloudflare Pages preview deployment that a missing address returns status 404 with the page, and that `mods/<id>` without the slash still opens a real mod.

## 7. Jobs

- [ ] 7.1 Add `takeDown` and `restoreTakedown` to `JobKind`, and `takedownModId`, `takedownAuthors`, `takedownEntry` and `publishAfter` to `JobRequest`. Regenerate `job.mapper.dart`.
- [ ] 7.2 Run them in `JobRouter` as steps of one job: write or remove the entry under the data lock, `mergeModRepo` with `oldRepoOnly`, `rebuildBundle`, then `publishOutputs` when `publishAfter` is set.
- [ ] 7.3 Refuse with a reason: an id that is not a mod or Collection in `mod-catalog.json`, an id already taken down, an empty author list, and a restore of an entry that does not exist.
- [ ] 7.4 Record each restored entry in `<qb_data_path>/takedowns-restored.json`.
- [ ] 7.5 Add both kinds to `describeJob` in `web/manager.js`.
- [ ] 7.6 Test that cancelling a job after it writes the entry keeps that entry. Test that neither job scrapes or calls the LLM.

## 8. Publishing

- [ ] 8.1 Write one function that checks and copies the list. Read the freshly fetched clone's list before changing it. Treat a missing local file as an empty list. Fail and name any published entries missing locally unless they are recorded in `takedowns-restored.json`. When the check passes, copy the local list to the clone's root, or write an empty list there if the local file is missing. Clear only recorded restores whose entries were already absent from the freshly fetched list before copying.
- [ ] 8.2 Call the shared check-and-copy function from `PublishService` before committing. Push nothing when it fails. Add `404.html` to `PublishService.websiteFiles` and test that a viewer publish copies `outputs/site/404.html` to the clone's root.
- [ ] 8.3 Add a `--publish-takedowns <clone folder>` step to `mod_repo_scraper` that calls the same function and exits with an error when it fails.
- [ ] 8.4 In `tool/update-mod-repo.sh`, run that step after copying the outputs into the clone and before `git add`. Stop the script when it fails.
- [ ] 8.5 Test that published entries missing locally stop publishing unless recorded restores account for them. Cover a missing local file and a local list that lost an entry. Test that a missing local file with no published entries writes an empty list. Test that a recorded restore survives a failed push and is cleared only after a later fetch confirms its entry is absent. Also test that `PublishService` still never touches `ModRepo.json` and `forum-data-bundle.json` in the clone.

## 9. Viewer

- [ ] 9.1 Add read-only `GET /api/takedowns` (the list plus `takedown-matches.json`) and `GET /api/takedowns/preview?mod=<id>` / `?author=<name>` in `lib/viewer/api.dart`, using the same matching code as the catalog step.
- [ ] 9.2 Test the preview: "tidal5590" lists the fork and "lpc editor" under "tidal5590", "Diable Avionics: Original Flavor" under "Tidal", and "Project Solar Tail" under "TIDAL". A mod on a shared topic is shown as a named key. Nothing is written.
- [ ] 9.3 Add a corrections group to the sidebar in `web/index.html`, with a Takedowns page (`web/views/takedowns.js`). List each entry and the mods or Collection pages it left out of the last build. Mark an entry as a warning only when it removed neither. Give each entry a Restore button.
- [ ] 9.4 Add an author takedown form on the Takedowns page, and a "Take down" button on the Mod Catalog mod page and the thread page. On the thread page, list the catalog's mods from that thread and make the reader pick one; go straight to the preview when there is one; show no button when there is none.
- [ ] 9.5 Build the confirmation dialog from the preview. Show what would be removed and whether each blocked key covers a whole post or a named listing. List Collections that lose the mod and old ids that lead to it. For author entries, show the credit that matched. Say whether `ModRepo.json` is affected. Offer "Publish when done" and explain that `ModRepo.json` is updated by the next successful cron publish. Say that the list is public.
- [ ] 9.6 With the manager off, show no buttons or form. Still list the entries.
- [ ] 9.7 Check the pages in the browser: preview, take down from a mod page and from a thread with several mods, restore, and manager off. Check that icons line up vertically with the text beside them.

## 10. Docs and wording

- [ ] 10.1 Update `CLAUDE.md`: the takedown list, the two kinds of entry, the build order change, `ModRepo.json` until the switch, the cron publish step, the 404 page, the jobs and the viewer page.
- [ ] 10.2 Update the About page's "Why not let people upload mods?" section to say takedown requests are handled, and how to ask.
- [ ] 10.3 Run Codex's declaudify over every new piece of text: viewer labels and dialogs, the About page, `CLAUDE.md` and these docs. Review its changes for meaning only. Leave the 404 message exactly as the user wrote it.

## 11. First takedown

- [ ] 11.1 After deploying the code and the updated cron script, take down `diable-avionics-tidal-fork` from the viewer with "Publish when done".
- [ ] 11.2 Check that `https://starmodder.wispborne.com/mods/diable-avionics-tidal-fork/` shows the not-found page with status 404. Check that thread 1507163509224509510 is absent from the published `mod-catalog-details.json`. Check that the five other Diable Avionics pages are unchanged.
- [ ] 11.3 After the next successful cron publish, check that the published `ModRepo.json` no longer lists the Tidal fork and that the published repo has `takedowns.json`. Check that `forum-data-bundle.json` continues to exclude all Discord answers.
