## Context

`_threadOnlyMods` in `lib/site/public_data_builder.dart` builds a stand-in `ScrapedMod` for every `main` mod the LLM named on a thread that no already-published mod accounts for. It reaches threads one way: it walks the mods being published, takes each one's forum topic id, and looks that thread up in the bundle. A thread no published mod points at is never looked at.

That was written on purpose. The bundle keeps every thread ever scraped, while the merge walks the mod index and the newest board pages, so the bundle holds old threads no published mod stands for — and publishing out of those hands permanent web addresses to mods nobody vetted. At the time it was measured as the difference between one new mod and six, and the five it left out included three that were really one translation pack whose "names" the LLM had read off zip filenames.

What has changed since is the grounding. A candidate now has to have its name written in the author's own opening run and a download tied to it, and the opening run itself is the author's first post plus their own follow-ups, stopping at the first reply by anybody else. Those rules were added for shared threads, and they turn out to be what makes reading an unvetted thread safe. The translation pack that motivated the original caution is exactly what they throw out.

Two numbers frame the change, both measured against the data on disk on 2026-08-26 (926 published mods, a 1,025-thread bundle, 976 LLM answers):

- 118 threads that nothing published points at hold 173 `main` mods with a grounded name and a download.
- Of those 173, 101 come from threads whose title carries no game version, and 88 come from threads last posted between 2012 and 2015.

## Goals / Non-Goals

**Goals:**

- A mod the LLM found on a scraped thread reaches the site whether or not the merge ever heard of that thread.
- The published shape of such a mod is identical to a thread mod on a shared thread. No second publishing path.
- Where two published mods carry one name, the site says enough about each for a reader to pick — including for the 18 pairs that are on the site already.
- Nothing about the bundle, the merge or TriOS's inputs moves.

**Non-Goals:**

- Changing `ModRepo.json` or the forum scraper's bracket rule. TriOS reads that file; a site problem is not a reason to alter it.
- Judging whether a mod is any good, still maintained, or still downloadable. A dead link is published as a dead link.
- Publishing add-ons or variants as mods of their own. They stay on their parent's page, as today.
- Deduplicating a fork, or an old thread, against the mod it shares a name with. Both are published; the site helps the reader choose instead. Settled below as a deliberate non-goal, not an oversight.
- Deciding for the reader which of two same-name mods is the better one. The facts are published; the judgement is theirs.
- Changing how a same-name pair looks in a list. Cards, browse rows and the search box already show the author under the name, so a pair is already told apart there. Only the mod's own page was silent.

## Decisions

### The gate is the LLM's mod list, not its `isMod` answer

The instinct that started this was to use `isMod` — the model's own yes-or-no on whether a thread is a mod release — in place of the bracket rule. Measured, it decides nothing here.

Across the 976 threads the model has read it says yes 913 times and no 63 times. Of those 63 noes, **none** lists a `main` mod with a download attached. So every thread `isMod` would exclude is already excluded by "a `main` mod, named in the post, with a download". The gate that does the work is the mod list.

`isMod` is also not clean enough to lean on. Among the 63 noes are plain mod threads — "Iron Legion Faction Mod", "Serenity - Firefly Mod", "[WIP] HyperLib", "An Escape Pod Mod", "[TOOL] Starsector Directorate". Among the yeses are threads whose whole title is "Delete." It is a reasonable coarse signal and a poor gate.

Using it would also not be free. `isMod` is read off the LLM store by `BundlePublisher` for the keep-or-drop rule in `keepThreadInBundle` and then dropped; it is not on the bundle at all, which is why `lib/viewer/api.dart` grafts it back on from the cache for the thread page. Publishing it would mean changing the LLM thread-data model and its mapper, the bundle, the working bundle in the viewer (or the changes page reports a difference for as long as a run lasts), the sample data and the test that pins the sample data to the models — for a filter that removes no thread.

*Alternative considered:* publish `isMod` and gate on it as well, as belt and braces. Rejected for the cost above. If a future `promptVersion` ever starts listing downloads on threads it calls non-mods, that is the point to reach for it, and it is a small change to make then.

### Threads are found by walking the bundle, not the published mods

The current code builds `publishedByTopic` and iterates it. The change keeps that map and iterates the bundle's threads instead, treating `publishedByTopic[topicId]` as an empty list when nothing points at the thread. Everything after that — the grounding checks, the sibling-name check, the stand-in — is the same code on both paths.

This matters for one behaviour. `published.any((m) => modNamesMatch(m.name, name))` is what stops a thread mod being published twice when the merge already has it. On an unmerged thread that list is empty, so nothing is skipped, which is the intent: nothing on that thread is published yet.

*Alternative considered:* a separate loop for unmerged threads. Rejected — two loops building the same object is how the two halves drift apart, and the sibling-name and claimed-name checks would have to exist in both.

### The `mainMods.length < 2` guard applies only where a merged mod exists

Today the function returns early for a thread with fewer than two `main` mods, because one `main` mod on a thread a published mod points at *is* that published mod, whatever either of them is called. That is TriOS's `_isTheCatalogEntry` rule and it must stay.

With no merged mod behind the thread there is nothing for the single entry to be, so the guard has to stand down. This is not an edge case: ExtendedControls, Custom Start, Ship Editor, Cult Of The Circle and most of the other 45 recent misses are single-mod threads.

### No liveness cut-off

An earlier draft gated on the thread's last post date. Dropped on the user's decision: publish everything the rules admit, whatever its age.

The consequence is stated rather than mitigated. 88 of the 173 come from threads last posted 2012-2015, and two 2012 threads account for 46 on their own — "MOD - The LARGE MOD collection" gives 21 pages of portrait and background bundles, "MOD - The TINY MOD collection" gives 25 like "Slower Battles" and "Fog-of-war Disabler Mod". Every one is a real mod thread with a download the LLM found; the links are simply fourteen years dead. The site becomes a fuller record of what was ever posted, and a reader browsing by current game version does not meet most of them.

The one place they are met is Browse's default view, because `browse.js:460` reads a mod with no game version as passing the current-release filter, and 101 of the 173 have no game version to read. That is a pre-existing rule about missing data, not something this change introduces, and changing it would move existing merged mods in and out of the default view too. So it is left alone, and the first run's Browse count is something to look at rather than something to pre-empt.

### Every mod is published, and the site says which is which

18 of the 173 carry a name that already belongs to a published mod, and they are two different things wearing one name.

Five are forks. Computica's thread forks other people's mods and keeps their names: Junk Pirates, Valkyrians, Blackrock Drive Yards, Stellar Networks and Farsight Drive. The other 13 are a mod's own older or duplicate thread — Scy from topic 8010 where the published Scy comes from 29535, Unknown Skies from 12041 against 29876, Diable Avionics from 8147 and 10046 against 29432, and the same shape for ApproLight, Outer Rim Alliance, Bushi, Autonomous Ships, Gladiator Society, ED Shipyard, Star Lords and Cloning.

Both are published. An old thread often carries the last build that ran on an old game version, and a fork is often the only build that runs on the current one; a site that silently drops either is worse for the reader than one that carries both. So no name check is added, and a clash falls through to `ModIdStore`, which gives the second mod of a name the same id with a number on the end. That is already live: `lost-sector` is Kissa_Mies', `lost-sector-2` is SirHartley's. Which one keeps the plain id is stable and in the existing page's favour, because `everyMod` is walked merged mods first and stand-ins second, and because a merged mod's entry is already in `mod-ids.json` from earlier runs.

What has to change is that the reader can tell them apart. Today nothing on either page acknowledges the other, and that is already wrong for the 18 same-name pairs on the site before this change — two "Kadur Remnant", two "CarrierUI", two "Lost.Sector". This change takes it to 35 groups covering 71 mods, which is enough to stop treating it as an oddity.

*Alternatives considered:* skipping any thread mod whose name is already published (loses Computica's forks, and loses old threads that hold the last build for an old game version); skipping only where the existing page comes from a newer thread (would have caught all 13 duplicates and none of the 5 forks, but it decides for the reader which build they want, and it makes the answer depend on a date the forum sometimes reports as a necro reply). Both rejected: the reader can pick, given the facts.

### The deciding fact is when the thread was last posted on

Between two pages called "Scy", everything already published is either the same on both or unhelpful. The names match, the authors are often the same person, the game version is missing on many of these threads, and `addedOn` says when the thread started, which is the wrong end.

The thread's last post date is what separates a live thread from an archive, and the bundle already carries it on every index entry as `lastPostDate`. It is a plain forum fact, no more internal than the thread's own start date, so publishing it breaks no rule. It goes on the list record so a browse row could use it later, and on the mod's page.

*Alternative considered:* publishing the newest download's date instead. Rejected — the resolver does not have a date for most hosts, and a GitHub archive link has no date at all.

### The grouping is worked out in the browser, not stored per mod

A mod's page needs to know the other published mods of its name. `mods.json` already holds every mod's name, display name, authors, game version and mod version, and both the browse page and the mod page already fetch it whole. So the grouping is a pass over that list in the browser, on the same cleaned-name comparison the builder uses.

Storing it per mod instead would put a list of ids on 71 records and grow the one file the browse page fetches whole — for something the browser can work out from data it is already holding.

The builder still fills `PublicModDetail.olderVersions` for the mod's own page. That field was added for exactly this, has been published empty since, and `mod.js` already renders it in a panel that hides itself while the list is empty. It gains an optional `id`, so an entry can link to a page on the site instead of only out to the forum, and the panel's heading stops saying "Older versions", which is wrong for a fork.

*Alternative considered:* a new field and a new panel, leaving `olderVersions` empty for ever. Rejected — it is the same list under a different name, and two fields meaning one thing is how the site and TriOS drift apart.

### Nothing else in the builder changes

A stand-in from an unmerged thread is the same `ScrapedMod` as one from a shared thread, so `_mainLlmMod`, `_addonsFor`, `_releasesByMod`, the description slicing and the sources list all behave as they already do. Two consequences follow from rules already written, and both are correct here:

- A thread holding several `main` mods contributes nothing to `updates.json`, because the release detector believes one version per thread and cannot say which mod moved. Computica's thread is one of those, so his forks get pages and no feed entries.
- Each mod's description is sliced out of the shared post by `descriptionAnchors` where the model pointed at one, and falls back to the AI paragraph labelled as AI where it did not.

## Risks / Trade-offs

- **A permanent id given to something that is not a mod** → The three grounding rules are the whole defence, and they are the ones already trusted on shared threads: a `main` role, a name the author's own post writes, and a download tied to it. Verified against the current data — every thread the rules admit is a mod thread. There is no way to withdraw an id once published, so a bad one is a bad address for ever.
- **173 mods appear on the site in one run, most of them old** → Expected and chosen. The first run after this ships should be checked against the numbers in this document; a count far above 173 means a rule is not doing what it is written to do.
- **About a hundred old mods land in Browse's default view**, because they have no game version and `browse.js` reads that as current → Named above, deliberately not fixed here, because the rule is about missing data in general and touching it would move existing mods too.
- **35 groups of same-name mods, 71 pages between them** → Each page names the others, with the author, both versions and when its thread was last posted on. The reader picks. This is also the first time the 18 pairs that were already there say anything about each other.
- **A reader lands on the wrong "Scy" from an outside link** and never sees the panel → The panel is on the page, not only in a list, precisely so that an arrival from a search engine or a Discord link meets it. It is worth checking it sits high enough on the page to be seen without scrolling past the downloads.
- **The same-name grouping uses a cleaned name, so it can group two mods that are genuinely unrelated** — the two "Kadur Remnant" threads are different mods by different people → That is the right outcome anyway: a reader who found one and meant the other needs to be told the other exists. The panel names the author, which is what separates them.
- **`mods.json` grows to about 1.4 MB against a 2 MB limit** → The test still passes with room, but the margin is now the thing to watch, since the file is fetched whole by the browse page. If a later change adds a field to the list record, this is the file that runs out of room first.
- **The new date is one more published field on a file with a size limit** → About 25 KB across 1,099 mods, against a 2 MB limit and about 1.4 MB used. Worth knowing, not worth avoiding.
- **The change rests on `_threadOnlyMods` being the only door** → It is: everything downstream reads `joined`, which is built from merged mods plus stand-ins. A test that a thread with no grounded mod publishes nothing pins the door shut.
