## 1. The list and matching

- [ ] 1.1 Add a `TakedownList` model (`lib/catalog/takedowns.dart`, `dart_mappable`) with mod entries (`id`, `name`, `posts`, `on`) and author entries (`names`, `on`). Treat a missing file as an empty list. Fail if an existing file cannot be read. Write a replacement file first, then move it over the old file. Regenerate mappers.
- [ ] 1.2 Add `ModRepoUtils.samePerson(a, b)` from `_peopleNamedIn`, `_plainName`, `_plainNameWithoutTag` and the `authorAliases` rows. Test: "tidal5590" matches "Tidal" and "TIDAL", "Tidal" does not match "Tidalwave", "Nes" matches "nescom", a credit naming two people matches either.
- [ ] 1.3 Add the code that works out a mod entry's post keys from a `ModCatalog`: the whole post when no other catalog mod comes from it, otherwise the named key. Test with a one-mod Discord thread and a four-mod forum topic.

## 2. The catalog step

- [ ] 2.1 In `CatalogStep`, read the list and remove listings blocked by mod entries before `ModMerger.mergeListings`: every listing of a whole-post key, and the matching LLM-named listing of a named key.
- [ ] 2.2 After merging and assigning ids, drop mods given a taken-down id, and mods with a credited author matching an author entry.
- [ ] 2.3 Give `ModIdStore.movedIds` the taken-down ids and exclude them as both old ids and the ids they lead to. Leave their `mod-ids.json` entries untouched.
- [ ] 2.4 Remove dropped mods' ids from every Collection's `modIds`.
- [ ] 2.5 Return the keys of posts whose listings were all removed. Log what each entry left out, including entries that left out nothing. Save the same report to `<qb_data_path>/takedown-matches.json`.
- [ ] 2.6 Fail before writing anything when `takedowns.json` cannot be read.
- [ ] 2.7 Test the Tidal fork: a catalog with thread 1507163509224509510 (LLM name "Diable Avionics", credited tidal5590) and the five other Diable Avionics mods. With the entry, only `diable-avionics-tidal-fork` is gone, and the others keep the same source posts. With the entry removed, the fork is back under the same id.
- [ ] 2.8 Test a renamed mod on a shared topic: the named key no longer matches, the id store gives it the entry's id, and it is dropped while the topic's other mods stay.
- [ ] 2.9 Test an author entry removing a mod made with others and a mod first seen after the entry was made.

## 3. Build order and the details file

- [ ] 3.1 In `ScraperService._rebuildBundle`, run the catalog step before `BundlePublisher.createBundle`, then the site step.
- [ ] 3.2 Give `BundlePublisher.createBundle` the post keys to leave out, and drop those topics from `index`, `details` and `assumedDownloads`, and those threads from `discordThreads`.
- [ ] 3.3 Test: the Tidal fork's thread is missing from `mod-catalog-details.json`, and a shared topic with one taken-down mod is still there in full.
- [ ] 3.4 Check the existing `_rebuildBundle` tests still pass with the new order, and that a cancelled catalog step still writes nothing.

## 4. The site build

- [ ] 4.1 Check `PublicDataBuilder` leaves a taken-down mod out of `mods.json`, its own files, "Requires" links (name kept as plain text), "same name" panels, `updates.json`, `updates.xml` and `sitemap.xml`. When the release state still contains a taken-down mod, include only releases whose mod ids are in the catalog. Add tests for each.
- [ ] 4.2 Make sure no moved-id redirect page or file points at a taken-down mod.

## 5. The not-found page

- [ ] 5.1 Add `site/404.html` with the site's header, footer and stylesheet through `<base href="/">`, links to the front page and Browse, and the message: "This mod may have been removed at the request of its owner...or it may never have existed in the first place. Or something else."
- [ ] 5.2 In `site/views/mod.js`, show the same message when `mods/<id>.json` is missing or is not JSON.
- [ ] 5.3 Make `bin/site_server.dart` answer a missing file with `site/404.html` and status 404.
- [ ] 5.4 Check in the browser on the local site server: a missing mod folder, a missing `.json`, and `#/mods/no-such-mod`, in both themes and at phone width.
- [ ] 5.5 Check on a Cloudflare Pages preview deployment that a missing address returns status 404 with the page, and that `mods/<id>` without the slash still opens a real mod.

## 6. Jobs

- [ ] 6.1 Add `takeDown` and `restoreTakedown` to `JobKind`, and `takedownModId`, `takedownAuthors`, `takedownEntry` and `publishAfter` to `JobRequest`. Regenerate `job.mapper.dart`.
- [ ] 6.2 Run them in `JobRouter` as steps of one job: write or remove the entry under the data lock, `rebuildBundle`, then `publishOutputs` when `publishAfter` is set.
- [ ] 6.3 Refuse with a reason: an id not in `mod-catalog.json`, an id already taken down, an empty author list, and a restore of an entry that does not exist.
- [ ] 6.4 Record each restored entry in `<qb_data_path>/takedowns-restored.json`.
- [ ] 6.5 Add both kinds to `describeJob` in `web/manager.js`.
- [ ] 6.6 Test that cancelling a job after it writes the entry keeps that entry. Test that neither job scrapes or calls the LLM.

## 7. Publishing

- [ ] 7.1 Copy `takedowns.json` to the clone's root in `PublishService`. Leave a published copy alone when there is no local list.
- [ ] 7.2 Before copying, fail if an entry in the clone's list is missing locally and is not recorded in `takedowns-restored.json`. Name the missing entries and push nothing. Clear the recorded restores once they have been published.
- [ ] 7.3 Test both cases. Also test that the frozen `ModRepo.json` and `forum-data-bundle.json` in the clone are still never touched.

## 8. Viewer

- [ ] 8.1 Add read-only `GET /api/takedowns` (the list plus `takedown-matches.json`) and `GET /api/takedowns/preview?mod=<id>` / `?author=<name>` in `lib/viewer/api.dart`, using the same matching code as the catalog step.
- [ ] 8.2 Test the preview: "tidal5590" lists the fork and "lpc editor" under "tidal5590", "Diable Avionics: Original Flavor" under "Tidal", and "Project Solar Tail" under "TIDAL". A mod on a shared topic is shown as a named key. Nothing is written.
- [ ] 8.3 Add a corrections group to the sidebar in `web/index.html`, with a Takedowns page (`web/views/takedowns.js`) listing entries and what each left out of the last build. Give each entry a Restore button.
- [ ] 8.4 Add an author takedown form on the Takedowns page, and a "Take down" button on the Mod Catalog mod page and the thread page.
- [ ] 8.5 Build the confirmation dialog from the preview: what would be removed, whole post or named listing, Collections that lose the mod, old ids that lead to it, the matched credit for author entries, a "Publish when done" choice, and a line saying the list is public.
- [ ] 8.6 With the manager off, show no buttons or form. Still list the entries.
- [ ] 8.7 Check the pages in the browser: preview, take down, restore, and manager off. Check that icons line up vertically with the text beside them.

## 9. Docs and wording

- [ ] 9.1 Update `CLAUDE.md`: the takedown list, the two kinds of entry, the build order change, the 404 page, the jobs and the viewer page.
- [ ] 9.2 Update the About page's "Why not let people upload mods?" section to say takedown requests are handled, and how to ask.
- [ ] 9.3 Run Codex's declaudify over every new piece of text: viewer labels and dialogs, the About page, `CLAUDE.md` and these docs. Review its changes for meaning only. Leave the 404 message exactly as the user wrote it.

## 10. First takedown

- [ ] 10.1 After deploying, take down `diable-avionics-tidal-fork` from the viewer with "Publish when done".
- [ ] 10.2 Check that `https://starmodder.wispborne.com/mods/diable-avionics-tidal-fork/` shows the not-found page with status 404. Check that thread 1507163509224509510 is absent from the published `mod-catalog-details.json`. Check that the five other Diable Avionics pages are unchanged.
