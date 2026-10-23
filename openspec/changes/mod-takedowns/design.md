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
- The frozen `ModRepo.json` and `forum-data-bundle.json`. Takedowns do not affect old TriOS installs that read them. Until the switch, `forum-data-bundle.json` is still written from the same bundle, so takedowns also apply to it. `ModRepo.json` comes from the old merge, so takedowns do not apply to it.
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

A named key stops matching if the LLM renames the mod. After the merge, `ModIdStore._renamedEntry` gives the renamed listing the entry's id. A mod given a taken-down id is then removed.

### The catalog is built before the details file

`CatalogStep` reads the store and the LLM cache, not the bundle, so it can run first. `_rebuildBundle` becomes: catalog step, then `BundlePublisher.createBundle(leaveOut: …)`, then the site step. The catalog step returns the keys of posts whose listings were all removed. The bundle publisher drops those topics from `index`, `details` and `assumedDownloads`, and those threads from `discordThreads`.

The ModRepo merge jobs build the catalog without rebuilding the bundle. After a merge-only job, the details file can be one run out of date for a new author entry. The `takeDown` job always rebuilds the bundle. This delay only affects author entries matching a new mod between bundle rebuilds. The next bundle rebuild applies the takedown.

### Author matching uses the merge's name rules

`ModRepoUtils` gets one public check, `samePerson(a, b)`, built from what `tidyAuthorNames` already uses: `_peopleNamedIn` to split a credit, `_plainName` and `_plainNameWithoutTag` to compare spellings, and the `authorAliases` rows. Exact matches only. Using the merge's name rules keeps takedowns consistent with the site's credits.

Forum profile numbers and Discord user ids would still identify people after a name change. They are not saved today. The forum's topic starter link contains `u=<number>`, and the Discord message has `author.id`. Saving them needs model changes and another scrape. This is left for later. For now, an entry can list several names.

### Taken-down ids stay in `mod-ids.json`

The id entry stays unchanged. Its posts stay linked to it, and `idForPosts` never gives it to another mod. `ModIdStore.movedIds` is given the taken-down ids and excludes them as both old ids and the ids they lead to. The site step needs nothing extra: it builds from the catalog, which no longer has the mod.

### Takedown and restore are manager jobs

Only manager jobs write data. The viewer's own routes never do. This keeps the list from changing during a catalog build. Every change appears in run history with its log. `JobRouter` runs each as steps of one job, the same way `rebuildFromSaved` runs: write or remove the entry under the data lock, `rebuildBundle`, then `publishOutputs` when the request asks. Request fields: `takedownModId`, `takedownAuthors`, `takedownEntry` (for restore), `publishAfter`. Takedowns will not apply to the old `ModRepo.json`. No `mergeModRepo` step is needed.

The preview is a read-only viewer route. It reads the current `mod-catalog.json` and `mod-ids.json`. It uses the catalog step's matching code so the preview and the build agree.

### Where the list is stored and how publishing checks it

`qb_data/takedowns.json` is the working copy, because the server runs from an unpacked release and cannot write into the scraper repo. The publish copies it to StarsectorModRepo's root, where it is public and its git history records every change.

The risk is losing `qb_data` and publishing again with no list, which would put every taken-down mod back. So the publish compares the clone's list with the local one before copying, and fails when an entry has gone missing. A restore records the entry it removed in `qb_data/takedowns-restored.json`, which the publish reads to tell a restore from a loss. Entries in that file are cleared once the restore has been published.

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

`site/404.html` is at the site root. A publish copies everything in `site/` there. Cloudflare Pages serves the nearest `404.html` for any missing address, with status 404. It no longer serves the front page for missing addresses. GitHub Pages and Netlify do the same. The page uses `<base href="/">` so its files load from any folder depth. Starmodder is always at the root of its domain, so this works. This is the only page on the site that does not use relative addresses. It is a separate small page, not a copy of `index.html`. It loads no data and runs no scripts.

`views/mod.js` shows the same message when `mods/<id>.json` is missing or is not JSON. The message is the user's own wording and is kept exactly.

## Risks and limits

- The 404 page changes how the host answers every missing address. Every page is a file or is reached through a `#` link on the front page. Nothing needs the host to serve the front page for missing addresses. Before publishing, check on a Pages preview deployment that `mods/<id>` without the slash still opens the mod.
- An author entry may match more people than intended because "Tidal" and "tidal5590" count as the same name. The confirmation dialog lists every mod that would be removed and the credit that matched. The build logs what each entry left out.
- An author may change their name and have new mods published. The build logs an author entry that matched nothing. Add the new name to the entry.
- A mod entry does not block the same mod posted in a new thread. This is accepted. Add a second mod entry, or use an author entry.
- The public list names every taken-down mod and author. This is accepted. Entries include no reason. The dialog says the list is public.
- Old TriOS installs keep showing the mod from the frozen files. This is accepted.
- Building the catalog before the bundle changes the order of every publishing job. The catalog never read the bundle. The site step still runs last. Existing tests on `_rebuildBundle` cover the order.

## Deployment steps

1. Deploy the code. With no `takedowns.json`, every build is the same as today, apart from the new 404 page.
2. Check the 404 page on a Pages preview deployment before first publishing it.
3. Take down `diable-avionics-tidal-fork` from the viewer with "Publish when done". Check that the address shows the not-found page. Check that the thread is absent from `mod-catalog-details.json`. Check that the five other Diable Avionics pages are unchanged.

To undo this: restore the entry, or delete `takedowns.json` and the published copy together. Removing the code leaves the list unused.

## Open Questions

- ADR 0002 says a later opt-out in an archived Discord channel needs a reader version increase and another Discord read. A mod entry is quicker and needs no Discord read. Should the ADR point to it?
