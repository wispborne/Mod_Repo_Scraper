## Context

Everything Starmodder and TriOS show is rebuilt from saved files on every run. Keeping a mod off them requires a list the build reads every time. A mod appears in three outputs:

```
saved posts ──► bundle publisher ──► mod-catalog-details.json   (one entry per forum topic or Discord thread)
                       │
                       ▼
                 catalog step ──► mod-catalog.json             (one entry per mod id)
                       │
                       ▼
                  site step ──► outputs/site/                   (pages, mods.json, feeds, sitemap)
```

`ScraperService._rebuildBundle` runs them in that order. The details file has an entry for each post. The catalog and site have an entry for each mod.

What already happens:
- The Discord reader skips a message whose author reacted 🕸️ to it (`DiscordReader.noscrapeReaction`). That removes only the Discord copy, and only on channels we still read. A mod with a forum topic stays.
- A publish deletes any mod file the run did not produce. A mod left out of the build loses its page on the next publish.
- Cloudflare Pages answers every missing address with the front page's `index.html` and status 200, because the site has no `404.html`. That includes `mods/<id>.json` and `style.css` under a missing mod's folder. A removed mod's address shows an unstyled page stuck on "Loading…" today.

The first request is `diable-avionics-tidal-fork`: a Discord-only mod (thread 1507163509224509510, credited to tidal5590). Its id entry links three keys. One is `discord:1507163509224509510#Diable Avionics`, so the LLM has called it "Diable Avionics" at least once. Four other published mods have that name.

## Goals and exclusions

**Goals:**
- Take down one mod, or everything credited to one person, from `mod-catalog.json`, `mod-catalog-details.json` and Starmodder, and keep it removed on every later build.
- Keep the list public. Reserve each taken-down mod's address so restoring it keeps the same address.
- Add and undo takedowns from the viewer, with a preview of what will be removed.
- Give every missing address on Starmodder a "not found" page.

**Outside this change:**
- `ModRepo.json` and `forum-data-bundle.json` after the switch. They are frozen then, and old TriOS installs keep reading their last contents.
- Rewriting git history in StarsectorModRepo.
- Removing mentions of a person from other mods' posts, credits or support links.
- Stopping the scrape or the LLM read of taken-down posts.
- Signing in to the viewer. It still listens on `127.0.0.1` only.

## Decisions

### Mod entries apply before the merge. Author entries apply after it.

Mod entries must be applied before the merge. The merge could join the Tidal fork's thread to another "Diable Avionics" mod by name. Removing the merged mod because it contains a blocked post would remove that other mod too. Removing blocked listings before `ModMerger.mergeListings` prevents this.

Author entries are checked after the merge. Only then do the credits include every source's spelling. An author entry removes the whole merged mod when any listing credits that person.

Alternatives considered:
- Both after the merge: the Diable Avionics risk above.
- Both before: an author check on one listing sees only that source's spelling. A Discord listing credited to "tidal5590" would be removed. A forum listing for the same mod credited to someone else would still be published.

### A mod entry stores post keys from the current catalog

The `takeDown` job reads the mod's `sourcePosts` from the current `mod-catalog.json`. A post used by no other catalog mod is recorded as a whole post (`discord:1507163509224509510`). A post shared with other mods is recorded with this mod's LLM name (`forum:34161#Useful.Tithes`). Both `mod-ids.json` and the details file use post keys. The same list can therefore be used in every step.

The keys are not read from `mod-ids.json`, because an id entry can hold a whole-post key for a post the old site shared between two pages (topic 35988). Storing that as a whole post would block the other mod too.

A named key is matched by name, not by exact text. It blocks every listing on that post whose LLM name matches the key's name by `modNamesMatch`. So `forum:34161#Useful.Tithes` still blocks the listing after the LLM calls it "Useful Tithes".

A name change that does not match by `modNamesMatch` may still be recognised by `ModIdStore._renamedEntry`. If the renamed mod keeps the entry's id, it is removed after the merge. `_renamedEntry` rejects a match when more than one old entry fits the new name, or another new name fits the same old entry. Two renamed mods can each keep their ids when their matches are unambiguous. If no old id is found, the mod can return under a new id. An entry that removes nothing is logged as a warning and shown on the Takedowns page. Take the mod down again using its new id.

### The catalog is built before the details file

`CatalogStep` reads the store and the LLM cache, not the bundle, so it can run first. `_rebuildBundle` becomes: catalog step, then `BundlePublisher.createBundle(leaveOut: …)`, then the site step. The catalog step returns the keys of posts whose listings were all removed. The bundle publisher drops those topics from `index`, `details` and `assumedDownloads`, and those threads from `discordThreads`.

The ModRepo merge jobs build the catalog without rebuilding the bundle. After a merge-only job, the details file can be one run out of date for a new author entry. The `takeDown` job always rebuilds the bundle. This delay only affects author entries matching a new mod between bundle rebuilds. The next bundle rebuild applies the takedown.

Every job that uses the list reads it when the job starts, before any step writes a file. In a combined job, `mergeModRepo` with `oldRepoOnly` writes `ModRepo.json` before the catalog is built. Reading the list only during the catalog step could therefore discover an unreadable list after `ModRepo.json` had already changed.

### Takedowns apply to `ModRepo.json` until the switch

Production has not switched to the catalog. The cron script still publishes `ModRepo.json` and `forum-data-bundle.json`, and TriOS reads `ModRepo.json`. A takedown that skipped it would leave the Tidal fork in TriOS.

Both files are written from the same bundle, so removing a forum topic applies to both. `forum-data-bundle.json` already excludes all Discord answers. Removing a Discord thread therefore changes only `mod-catalog-details.json`.

`ModRepo.json` comes from the old merge. `ModRepoService` leaves mods out of it just before writing it. It leaves out a merged mod when any of its credited authors matches an author entry. It also leaves out a mod whose forum topic or Discord thread is a whole-post key in a mod entry. The topic and thread are read from the mod's forum and Discord links. A named key is not applied to `ModRepo.json`. The old merge makes one mod per forum topic and has no LLM names, so blocking the topic would also remove the other mods on it. Each entry not applied to `ModRepo.json` is logged.

After the switch, `ModRepo.json` is frozen and this filter does nothing.

### Author matching uses the merge's name rules

`ModRepoUtils` gets one public check, `samePerson(a, b)`, built from what `tidyAuthorNames` already uses: `_peopleNamedIn` to split a credit, `_plainName` and `_plainNameWithoutTag` to compare spellings, and the `authorAliases` rows. Exact matches only. Using the merge's name rules keeps takedowns consistent with the site's credits.

`_plainNameWithoutTag` drops digits from the end of any name, not only a Discord name, when at least three characters are left. So "Dreadnought70" and "Dreadnought" count as one person. The preview lists every credited name that matched, so a match like that is seen before the takedown is sent.

Forum profile numbers and Discord user ids would still identify people after a name change. They are not saved today. The forum's topic starter link contains `u=<number>`, and the Discord message has `author.id`. Saving them needs model changes and another scrape. This is left for later. For now, an entry can list several names.

### Taken-down ids stay in `mod-ids.json`

The id entry stays unchanged. Its posts stay linked to it, and `idForPosts` never gives it to another mod. The site step needs nothing extra: it builds from the catalog, which no longer has the mod.

Blocked listings stay out of the merge, but their source-post references are still passed to `ModIdStore.beginRun`. The id store must also treat a stored name matched by a blocked listing as still present. Passing only the current reference is not enough when the spelling changed: `_goneFrom` compares exact keys. Otherwise, `_renamedEntry` could give the blocked mod's id to another mod on the post. That other mod would then be removed because it received a taken-down id. A rename that was not blocked before the merge still uses the id check described above.

`ModIdStore.movedIds` is given every id named by a mod entry and every id removed by an author entry in this build. This includes mod-entry ids whose listings were blocked before ids were assigned. None of these ids can be an old id or a destination in `movedIds`. No move involving them is saved in `mod-ids.json`. Without this exclusion, the id of a removed mod could redirect to the only remaining mod on its post.

### Collections

A Collection with every mod removed is left out of the catalog's `collections` and gets no page. Its id stays held back, so its address shows the not-found page.

A mod entry can also name a Collection's id. That entry records no posts. It removes only the Collection's record and page, and the Collection's mods stay. To remove the mods as well, take each one down or use an author entry.

### Takedown and restore are manager jobs

Only manager jobs write data. The viewer's own routes never do. This keeps the list from changing during a catalog build. Every change appears in run history with its log. `JobRouter` runs each as steps of one job, the same way `rebuildFromSaved` runs: write or remove the entry under the data lock, `mergeModRepo` with `oldRepoOnly` so `ModRepo.json` is written again, `rebuildBundle`, then `publishOutputs` when the request asks. Request fields: `takedownModId`, `takedownAuthors`, `takedownEntry` (for restore), `publishAfter`.

A publish from the viewer copies the catalog files and the website. It leaves the published `ModRepo.json` and `forum-data-bundle.json` unchanged. Those files are updated by the next successful cron publish. Cron is scheduled twice a day. The confirmation dialog explains this delay.

The preview is a read-only viewer route. It reads the current `mod-catalog.json` and `mod-ids.json`. It uses the catalog step's matching code so the preview and the build agree.

### Where the list is stored and how publishing checks it

`qb_data/takedowns.json` is the working copy, because the server runs from an unpacked release and cannot write into the scraper repo. The publish copies it to StarsectorModRepo's root, where it is public and its git history records every change.

The risk is losing `qb_data` and publishing again with no list, which would put every taken-down mod back. So the publish compares the clone's list with the local one before copying, and fails when an entry has gone missing. A missing local file counts as an empty list for this check. That is the case the check exists for: a new or replaced `qb_data` has no list at all. A restore records the entry it removed in `qb_data/takedowns-restored.json`, which the publish reads to tell a restore from a loss. A recorded restore is cleared at a later publish, once the clone's list no longer has that entry.

Production does not publish through `PublishService`. The cron script, `tool/update-mod-repo.sh`, clones the repo and copies the files itself. So the check and the copy are one function, used in two places:
- `PublishService`, for a publish from the viewer.
- A new `mod_repo_scraper --publish-takedowns <clone folder>` step, which the cron script runs after it copies the outputs and before it commits. When the check fails, the program exits with an error and the script stops before it commits anything.

Putting the check in the scraper program, not in the shell script, keeps one copy of the rule. The script only has to call it.

Format:

```json
{
  "mods": [
    { "id": "diable-avionics-tidal-fork", "name": "Diable Avionics (TIDAL FORK)",
      "posts": ["discord:1507163509224509510"], "on": "2026-10-22" }
  ],
  "authors": [
    { "names": ["tidal5590"], "on": "2026-10-22" }
  ]
}
```

An author entry is identified by the first name in its list, using the merge's name rules. A mod entry is identified by its id.

### The not-found page

`404.html` sits at the site root. Cloudflare Pages serves the nearest `404.html` for any missing address, with status 404. It no longer serves the front page for missing addresses. GitHub Pages and Netlify do the same.

The site step builds the page from the site's own `index.html`, using the same approach as mod pages in `mod_page_html.dart`. It replaces the region between `<!--page-head-->` and `<!--/page-head-->` with a "Not found" title, `noindex`, and `<base href="/">`. The header, nav, search box, footer and scripts stay shared with `index.html`, including the script that applies the reader's theme. The page is written to `outputs/site/404.html`. The cron script already copies that folder. Add `404.html` to `PublishService.websiteFiles` so a publish from the viewer copies it too.

`<base href="/">` makes its files load from any folder depth. Starmodder is always at the root of its domain, so this works. This is the only page on the site with an absolute base.

The replaced head region marks the document as a not-found page. On startup, `app.js` keeps the requested address and shows the not-found view instead of choosing a view from that address. The mark applies to the address that returned 404. Following Home, Browse or a search result uses normal routing, and returning to the missing address shows the not-found view again. When `index.html` cannot be read or its head markers are missing, the site step writes a small plain page with the message and a link to the front page, and logs the fallback.

`views/mod.js` shows the not-found message when `mods/<id>.json` returns 404. It also shows that message when a successful response is not JSON, to support hosts that return the front page for a missing file. Other failures show an error with its reason. This includes connection failures and server errors, even when the server's error response is HTML. The not-found message stays exactly as the user wrote it.

## Risks and limits

- The 404 page changes how the host answers every missing address. Every page is a file or is reached through a `#` link on the front page. Nothing needs the host to serve the front page for missing addresses. Before publishing, check on a Pages preview deployment that `mods/<id>` without the slash still opens the mod.
- An author entry may match more people than intended because "Tidal" and "tidal5590" count as the same name, and so do "Dreadnought" and "Dreadnought70". The confirmation dialog lists every mod that would be removed and the credit that matched. The build logs what each entry left out.
- An author may change their name and have new mods published. The build logs an author entry that matched nothing. Add the new name to the entry.
- A mod entry does not block the same mod posted in a new thread. This is accepted. Add a second mod entry, or use an author entry.
- The public list names every taken-down mod and author. This is accepted. Entries include no reason. The dialog says the list is public.
- A mod entry for one of several mods on a shared forum topic is not applied to `ModRepo.json`, so TriOS keeps listing that mod until the switch. This is accepted. An author entry, or a mod entry that blocks a whole post, is applied.
- After the switch, old TriOS installs keep showing the mod from the frozen files. This is accepted.
- Building the catalog before the bundle changes the order of every publishing job. The catalog never read the bundle. The site step still runs last. Existing tests on `_rebuildBundle` cover the order.

## Deployment steps

1. Deploy the code and the updated `tool/update-mod-repo.sh`. With no `takedowns.json`, every build is the same as today, apart from the new 404 page.
2. Check the 404 page on a Pages preview deployment before first publishing it.
3. Take down `diable-avionics-tidal-fork` from the viewer with "Publish when done". Check that the address shows the not-found page. Check that the thread is absent from `mod-catalog-details.json`. Check that the five other Diable Avionics pages are unchanged.
4. After the next cron publish, check that the published `ModRepo.json` no longer has the mod, and that the published repo has `takedowns.json`.

To undo this: restore the entry, or delete `takedowns.json` and the published copy together. Removing the code leaves the list unused.

## Open Questions

- ADR 0002 says a later opt-out in an archived Discord channel needs a reader version increase and another Discord read. A mod entry is quicker and needs no Discord read. Should the ADR point to it?
