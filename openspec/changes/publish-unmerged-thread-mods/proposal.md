## Why

The site only reads a forum thread if a merged ModRepo mod already points at it. That was the safe rule when the change that introduced thread mods went in, and it turns out to leave real mods off the site entirely.

Topic 35651, "Computica's Faction Forks", is the case that showed it. The thread is scraped, it is in `forum-data-bundle.json`, and the LLM has read seven mods off it with a download each. None of them reach the site, because no merged mod points at that thread. Two doors are shut at once: the thread's title carries no bracketed game version, so the ModRepo forum scraper drops it from the board listing ([`forum_scraper.dart:266`](../../../lib/bot/scraper/forum_scraper.dart)), and Computica never posted the forks on Discord.

Measured over the current data, 118 threads in the bundle hold 173 mods that nothing on the site accounts for — each one a `main` mod the LLM named, with a download tied to it and its name written in the author's own post. Most of them are not the bracket case at all. They are ordinary mod threads with a proper `[0.98a]` tag that have simply fallen outside the newest 15 and 12 board pages the merge reads, whose authors never posted them on Discord: ThirstSector, Nijigen Extend, ExtendedControls, Custom Start, Ship Editor, Cult Of The Circle, safeTravels, BetterSaves, and Shoey's three.

Publishing them all brings a second problem to the surface, and this change fixes that too. 18 of the 173 carry a name that already belongs to a published mod. Five are forks that kept the original's name — Computica's Junk Pirates, Valkyrians, Blackrock Drive Yards, Stellar Networks and Farsight Drive. The other 13 are a mod's own older or duplicate thread: Scy from topic 8010 beside the Scy already published from 29535, Unknown Skies from 12041 beside 29876, Diable Avionics twice over, ApproLight, Outer Rim Alliance, Bushi, Autonomous Ships, Gladiator Society, ED Shipyard, Star Lords and Cloning.

Every one of those is worth publishing — an old thread often has the last build that ran on an old game version, and a fork is often the only version that runs on the current one. What is not acceptable is showing two pages called "Scy" and leaving the reader to guess. So the site has to say which is which.

This is not a new problem. 18 pairs of same-name mods are on the site today — two "Kadur Remnant", two "CarrierUI", two "Lost.Sector" — with nothing on either page acknowledging the other. This change roughly doubles that, from 18 groups to 35, and pays off the debt at the same time.

The obvious fix for the first half — loosening the bracket rule in the forum scraper — is the wrong one. That scraper sees a title and an author and nothing else, it has no LLM answer at that point, and the two pipelines deliberately share no files. It would also change `ModRepo.json`, which TriOS reads, to fix a site problem.

## What Changes

**Publishing the missing mods**

- The site's data builder reads bundle threads that no published mod points at, and publishes their `main` LLM mods as mods of their own, exactly the way it already publishes the extra mods on a shared thread. Same stand-in `ScrapedMod`, same permanent id, same `partOfThreadTitle`, same loop, same published shape.
- The gate is the LLM's mod list under the grounding rules already written: at least one `main` mod, whose name appears in the author's own opening run, with at least one download tied to it. A thread that produces nothing under those rules publishes nothing, which is what keeps the help threads out.
- The `isMod` judgement is deliberately **not** used, and stays unpublished. On the current data it decides nothing: of the 63 threads the model called non-mods, not one lists a `main` mod with a download. The reasoning is in the design so the option can be picked up if a later prompt version ever changes that.
- The "a thread with fewer than two `main` mods is accounted for by the merged mod" rule stands down when there is no merged mod. On a thread nothing points at, a single `main` mod is precisely the mod nobody has published.
- An `addon` or a `variant` is still never published as a mod of its own.
- No liveness rule and no date cut-off. A thread last posted in 2012 publishes on the same terms as one last posted last week.
- No name check against the rest of the site. A mod whose name already belongs to a published mod is published and given a numbered id, which is what `ModIdStore` already does.

**Telling same-name mods apart**

- The site publishes when each mod's forum thread was last posted on (`threadLastPostOn`, a `YYYY-MM-DD` day — the forum writes its times with no time zone on them, so a published moment would be read as the reader's own local time and some readers would land on the wrong day). This is the one fact that separates a live thread from an archive, and it is the fact a reader needs most when two pages carry one name. It is a plain forum fact, like the thread's own date, and it goes on both the list record and the mod's own page.
- A mod's page carries a panel naming every other published mod of the same name, with the author, the game version, the mod version, when its thread was last posted on, and a link to each. It fills `PublicModDetail.olderVersions`, which was added for this and has sat empty since — the shape is already published, already rendered, and already hidden while the list is empty. It gains an optional `id` so an entry can link to a page on the site rather than only out to the forum, and the heading changes from "Older versions" to wording that fits a fork as well as an archive.
- Grouping is worked out from the published data, not stored per mod: `mods.json` already holds every mod's name, authors and versions, and the browse page and mod page already load it whole. So the grouping costs no extra field on the list record and no extra fetch.
- Not changed: the search box already shows the author under each suggested mod, and cards and rows already show the author, so a same-name pair is already distinguishable everywhere a mod is listed. Only the mod's own page was silent about it.

**Not changed at all**: `ModRepo.json` and TriOS's catalog, the forum scraper's bracket rule, the bundle, the viewer, the merge and the release detector.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `public-site-data`: modifies the requirement that threads are only reached through the mods being published, so that a thread nothing points at is read too and its `main` mods published; modifies the single-`main`-mod rule, which only holds where a merged mod is there to be accounted for; and adds requirements that a mod publishes when its thread was last posted on, and that a mod sharing a name with another published mod carries a list of the others.
- `public-site-pages`: adds a requirement that a mod's page names the other published mods of the same name, with the facts needed to choose between them.

Both capabilities are defined by in-flight changes and are not yet in `openspec/specs/` — `starmodder-4-public-site` and then `publish-thread-only-mods` have to be archived before these deltas can be applied, and MODIFIED deltas have to be hand-applied (see tasks).

## Impact

- `lib/site/public_data_builder.dart` — `_threadOnlyMods` gains a second source of threads and drops the `mainMods.length < 2` guard for those; the list record gains the thread's last post date; `olderVersions` is filled from the same-name grouping.
- `lib/site/models/public_mod.dart` and `public_mod_detail.dart`, plus their generated mappers — one new field on the list record, one new optional field on `PublicOlderVersion`.
- `site/views/mod.js` and `site/style.css` — the same-name panel, and the wording change from "Older versions".
- `site/sample-data/` and `test/site/sample_data_test.dart` — the examples are pinned to the models.
- `test/site/public_data_builder_test.dart` — new cases for unmerged threads, for the single-`main`-mod case, and for the same-name grouping.
- `outputs/site/mods.json` grows from 926 mods to about 1,099, and from about 1.19 MB to about 1.4 MB, plus about 25 KB for the new date. The test pinning it under 2 MB stands, with less room than before.
- 101 of the 173 new mods come from threads whose title carries no game version, and Browse shows a mod with no game version whatever the current-release switch says ([`browse.js:460`](../../../site/views/browse.js)). Browse's default view gains about a hundred mods, most from 2012-2015 threads with long-dead links. The design says what to watch after the first run.
- `mod-ids.json` gains about 173 permanent entries, which can never be withdrawn.
- Not touched: `ModRepo.json`, `forum_scraper.dart`, the merge, the bundle, the release detector, and the viewer.
