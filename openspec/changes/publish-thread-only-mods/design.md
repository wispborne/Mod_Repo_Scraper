## Context

`PublicDataBuilder.build()` walks the merged mods from `ModRepo.json`, gives each one a permanent id, finds its forum thread in the bundle, and writes one list record and one detail file per mod. A thread's LLM mod list is used only twice: `_mainLlmMod` picks which of the thread's mods *is* the merged mod, and `_addonsFor` publishes the rest — but only those the LLM marked `addon` or `variant`.

So a thread holding several separate mods loses all but the ones the merge already knew about. Topic 34161 holds four, all marked `main`. Three are on the site because the author also posted them on Discord; Lost.Sector is nowhere.

TriOS reads the same bundle and does not have this hole. `withSynthesizedAddonEntries` (`lib/catalog/catalog_links.dart` in the TriOS repo) makes an extra `ModRepoEntry` for every LLM mod on a thread that the catalog does not already hold, which is why Lost.Sector has a card there. TriOS is the model to follow for this change: its loop only reaches a thread through a real catalog entry, its `_isTheCatalogEntry` decides which LLM entry a catalog entry stands for, and its synthesized entries carry `partOfThreadTitle` and a game-version fallback. Each decision below says whether it copies TriOS or deviates, and why.

Two problems on the current site belong to this change, because both come from one thread holding several mods:

- Useful.Tithes' page shows the whole thread post as its description — all four mods' text, one after another.
- Whichever mod on the thread came last in the builder's list is silently credited with the whole thread's releases (`_releasesByMod` keys one mod per topic, last one wins), and takes the first LLM entry's facts if its own name matches none (`_mainLlmMod` falls back to "first `main`, then first anything").

A third problem this change was first written against is already fixed: the three mods on that thread were badged "Discord only" while linking to a forum thread. `isDiscordOnly` in `site/lib.js` now stands down for any mod with a `forumUrl`, so the badge is gone. The sources decision below is about the published data, not the badge.

## Goals / Non-Goals

**Goals:**

- Every `main` mod the LLM names on a published mod's thread gets published, once, with a permanent id.
- The site and TriOS broadly agree about which mods exist. (Not exactly: the site deliberately publishes both mods where two threads' mods share a name, and deliberately does not publish add-ons as mods — see the decisions below.)
- A page for one mod on a shared thread reads as being about that mod: its own facts, its own description, never a sibling's.
- A shared thread's releases are never credited to the wrong mod.

**Non-Goals:**

- Changing `ModRepo.json` or `forum-data-bundle.json`. Both keep their shape and TriOS keeps reading them as it does.
- Changing the merge. A thread-only mod is built at publish time, not merged into ModRepo.
- Fixing the gallery on a shared thread. Each mod's page will still show the whole post's screenshots, all four mods' worth. Scoping pictures to one mod needs per-mod picture data the LLM does not produce today.
- Fixing TriOS's own duplicate-card behaviour. Worth raising there separately — see the last decision for what the actual defect is.
- Teaching the release detector about threads with several mods. It believes one version per thread and that stays; this change only decides who a believed release is credited to.

## Decisions

### Reach threads only through the mods being published

TriOS's loop is `for mod in realMods`: a thread is only ever processed because a real catalog entry points at it. The builder does the same — the extra mods come from walking the published mods' threads, not from walking every thread in the bundle.

This matters because the two disagree about coverage. The QB store is cumulative over every run, while ModRepo's forum scrape is the curated index plus a limited number of recent board pages — so the bundle holds old and unindexed threads no merged mod points at. Walking all of those would publish an unknown and probably large number of mods from threads nobody vetted, and every one gets a permanent id. Walking only the published mods' threads keeps the count small and every new mod one hop from a mod that already earned its place.

### Build a stand-in `ScrapedMod` and put it through the same loop

For each thread-only mod, make a `ScrapedMod` carrying the LLM's name, the thread's authors and forum URL, and `sources: [ModSource.ModdingSubforum]`. Its game version is the thread's, falling back to the sibling merged mod's — TriOS does exactly this (`index.gameVersion ?? mod.gameVersionReq`) so a synthesized entry stays visible under the default game-version filter, and the site's Browse page hides older-game-version mods the same way. Add the stand-ins to the `mods` list before the `joined` loop runs.

Everything downstream then works untouched: `idStore.idFor` gives it an id, `markFor` marks it with `topic:<id>`, `_mainLlmMod` picks its own LLM entry out of the thread, `_listRecord` and `_detailRecord` build its records, and the "what this mod needs" name index picks it up like any other mod. The stand-in carries no summary and no description of its own, so the only text it publishes is the LLM's, labelled as AI — the same reasoning as TriOS's comment on why its synthesized entries carry no description.

The alternative — a second publishing path for thread-only mods — means every rule in the builder written twice and drifting. The stand-in is how TriOS does it too, and for the same reason.

`_JoinedMod` records whether its mod is merged or a stand-in. The release decision below needs to tell them apart, and nothing else can after the lists are mixed.

### Matching needs its own cleaner, and it cannot be `ModIdStore.cleanName`

**Corrected while building this.** The plan said to match on `ModIdStore.cleanName` first and letters-and-numbers second. Run against the real names on topic 34161, that matches nothing at all:

| merged name | `cleanName` gives | LLM name |
| --- | --- | --- |
| `Useful.Tithes 1.0.a` | `useful.tithes 1.0.a` | `Useful.Tithes` |
| `Big Pilum Energy 1.0.d` | `big pilum energy 1.0.d` | `Big Pilum Energy` |
| `Disco.Balls 1.1.c - More Lamp Colour Options` | unchanged | `Disco.Balls` |

`cleanName` does not strip a version of the form `1.0.a`. Its `_trailingVersion` pattern reads digits-with-dots followed by up to two letters, and `1.0.a` puts the letter behind another dot, so nothing matches. That is why the live page for that mod is `useful-tithes-1-0-a` — the version is in the id. Matching on it would have published all four mods a second time, each with a permanent address nobody could take back.

`cleanName` **cannot** be fixed to handle it. The id file is keyed on its output and a mod's web address is built from it, so making it keener gives a new address to every mod whose name carries a version in that shape. That is a migration of its own, not part of this change.

So matching gets its own cleaner, `lib/site/mod_name_match.dart`, used only ever to compare two names and never to name anything. TriOS draws exactly this line — `cleanModDisplayName` is separate from the slug its records are filed under — and this is its pair of steps, cleaned names then letters-and-numbers-only, with one addition: TriOS strips a version off the *end* of a name, and the forum writes "Disco.Balls 1.1.c - More Lamp Colour Options" with the version in the middle and a subtitle behind it. So the name is **cut at the first version wherever it sits** rather than trimmed at the end. A lone number is not a version, or "Ship Pack 2" would lose its name.

The match is used in three places, and has to be the same in all three or they disagree about what one mod is: deciding whether a thread mod is already published, `_mainLlmMod` picking a mod's own facts, and `_addonsFor` deciding whose add-on is whose.

The id itself stays keyed on `cleanName`, unchanged, so no existing address moves.

One thing this leaves behind: because `displayName` also builds on `stripReleaseParts`, those mods still *show* their version — the card reads "Useful.Tithes 1.0.a". Fixing that means separating the shown name from the id name, which is worth doing and is its own change.

The match is scoped to the thread: a thread mod is compared against the published mods on that same thread. A name already published from a *different* thread does not block it — that is how SirHartley's `Lost.Sector` and Kissa_Mies's `LOST_SECTOR` both get published. The id store keeps them apart, because their marks are different topics. This deviates from TriOS, which dedups synthesized names across all threads, first one wins, and would show one Lost.Sector card where the site has two pages. For a site handing out permanent addresses, two real mods deserve two pages; the goal of agreeing with TriOS bends here.

If a stand-in slips past the matching but still lands on the merged mod's id (same cleaned name, same `topic:` mark, so the id store returns the same entry), the builder's existing `takenIds` guard drops it with a warning. That warning is a safety net working as intended, not a bug.

### On a shared thread, a mod's facts are never guessed

`_mainLlmMod` currently falls back, when no name matches, to the first `main` entry and then to the first entry of any kind. On a shared thread that puts one mod's downloads, changelog, version, image and paragraph on another mod's page — and since that entry matched nothing, it would *also* be published as a thread-only mod, so the same facts appear twice and once under the wrong name.

The rule becomes TriOS's `_isTheCatalogEntry`, both halves: a mod takes the LLM entry whose name matches its own (matched as above); and a thread whose LLM list holds exactly one `main` entry gives that entry to the merged mod whatever either is called — a catalog entry pointing at a single-mod thread *is* that mod, even when the names look nothing alike (TriOS's example: the entry "Red" against the thread "[0.98a] Red - the Oculian Armada (0.10.2-RC4) Mod"). On a multi-main thread, no name match means no chosen entry: the mod publishes with no LLM facts rather than a sibling's.

### Only `main` mods become mods; `addon` and `variant` stay add-ons

The LLM already says which is which. An add-on published as a mod of its own would be a page for something that cannot be installed alone, and would drop it off the page of the mod it belongs to. This deviates from TriOS knowingly: `withSynthesizedAddonEntries` makes cards for every role.

On a shared thread the add-on list needs scoping too: `_addonsFor` currently lists every addon and variant on the thread, so four `main` mods would each show the same add-ons. An addon whose `requires` names one of the thread's `main` mods (matched the same way names are matched everywhere else in this change) is listed only on that mod's page. One that names nothing, or nothing that matches, stays on every `main` mod's page — a wrong omission is worse than a repeat.

### A shared thread's description is the mod's own, never the whole post

Today the description is the thread's post, rebuilt from safe tags. That is right for a thread about one mod and wrong for a thread about four — it is why Useful.Tithes' page currently opens with three other mods' text.

So: when a thread holds more than one `main` mod, no mod on it takes the post as its description. Each falls back down the rest of the existing chain: first the mod's own merged text — for a Discord-posted mod that is its own announcement, written by the author about exactly that mod — then the LLM's paragraph for that mod, marked `descriptionIsGenerated: true`; where there is neither, the mod has no description and the page says so. This applies to the merged mods on such a thread as well as the thread-only ones — otherwise the fix only lands on half of them.

A single-mod thread is untouched. This changes a requirement in the in-flight `starmodder-4-public-site` spec ("The description is the author's own post, kept formatted"), so the delta carries a MODIFIED requirement, not just added ones.

One side effect worth checking on the site: a reader who set AI writing to "Never" and lands on a shared-thread mod whose only text is the AI paragraph should see "no description" said plainly, not a blank.

### A shared thread's releases go to nobody

`_releasesByMod` files releases by topic and today keys one mod per topic — so on a shared thread, whichever mod came last in the list silently takes them all. That is an existing bug this change fixes in passing.

The rule: a thread's releases go to its one mod — the merged mod on a thread whose LLM list holds one `main` entry or none. A thread holding several `main` mods gives its releases to no mod and contributes nothing to the feed. The detector believes one version per thread and cannot say which of four mods released; on this thread the version it reads is whichever the LLM last agreed with itself about. Guessing would announce the wrong mod's release, and a wrong entry in the feed is worse than a missing one. That includes the case where only one of the thread's mods is merged — one merged mod among four `main` entries is no likelier than its siblings to be the one that released. A better answer needs per-mod version tracking, which is its own change.

### Say which thread a mod is part of

A new `partOfThreadTitle` field on `PublicMod` and `PublicModDetail`, filled only for thread-only mods — the made-up entries — never for a merged mod. That is TriOS's semantics exactly, and in TriOS the field is load-bearing: `entry.isPartOfThread` switches off thread-id matching so an add-on card is not linked to the parent's installed mod. Same name, same meaning, so the two stay recognisable to each other and the field can grow the same uses.

The cost accepted: a merged mod on a shared thread carries no marker, so Useful.Tithes' page says "part of" nothing even though its thread holds three other mods. Its page still links the thread, and with the description and facts rules above there is no longer wrong text there to explain away. If that page turns out to need a line too, that is a display question for the site, not a reason to give a TriOS-shaped field a different meaning.

### `sources` comes from the thread as well as the merge

Once the builder knows a mod's thread was scraped and read, `forum` belongs in its sources whatever the merge said, and a thread-only mod's sources are `["forum"]`. `_sourcesFor` gains the thread as an input to say so.

This is about the data, not the badge. The "Discord only" badge is already gone from mods with a forum link — `isDiscordOnly` in `site/lib.js` stands down for any mod with a `forumUrl`, and that guard stays, because it also covers a mod whose forum link points at a thread the scraper has not read. What this fixes is the mod page's "found on" list, and any future reader of `mods.json` that trusts `sources` at face value.

## Risks / Trade-offs

- **The LLM invents a mod that is not on the thread, and it becomes a page with a permanent id.** → Publish a thread mod only when its name actually appears in the thread's post text — the same grounding `_groundNeeds` already does for "what a mod needs", and stricter than TriOS, which grounds nothing but also hands out no permanent ids — and only when the LLM tied at least one download to it. Log the ones dropped for a missing download too: a real mod whose download the LLM missed should be findable in the log, not silently gone.
- **A thread mod and a merged mod are the same thing under names too different to match, so the mod is published twice.** → The two-step match above, the single-main rule (which needs no name agreement at all), the scope to one thread, and a log line for every thread-only mod on its first run so a wrong one is noticeable before it is permanent.
- **`mods.json` grows.** → It is about 990 KB against a 2 MB limit, and with threads reached only through published mods the count stays small. Worth counting on the first run; if it ever approaches the limit that is a separate problem about the file, not about this change.
- **Pages for mods with little to say.** → A thread-only mod has a name, a download, an image and an AI paragraph. That is more than the site offers today for the several hundred mods with no LLM data at all, and the download is the thing a reader came for.
- **Two sources of truth for "which mods exist".** → Already true: TriOS synthesizes, the site did not. This change closes most of the gap. The remaining, deliberate differences: the site publishes both same-named mods from different threads where TriOS shows one, and the site does not publish add-ons as mods where TriOS does. The rule is written once in `public_data_builder.dart` and TriOS keeps its own copy; if they drift, the site is the one that publishes ids, so the site's answer is the one that matters.

## Migration Plan

No migration. Thread-only mods get ids on the run after this ships and keep them from then on. `mod-ids.json` grows by one entry per thread-only mod. Existing mods are untouched — none of their ids, names or marks change.

Rolling back means the new mods stop being published and their per-mod files are cleaned up by the existing "remove files this run did not produce" step. Their ids stay in `mod-ids.json`, so rolling forward again gives them the same addresses.

`addedOn` for a thread-only mod falls back to the day it was first seen, which is the day this ships — so they would all arrive together at the top of "recently added". Use the thread's post date instead where there is one, the way `_addedOn` already does for merged mods.

## What TriOS gets wrong, for the write-up over there

Reading `withSynthesizedAddonEntries` settles the open question about duplicate cards: yes, TriOS can draw one, but order-dependently, and not simply because "it compares raw names". Its per-thread check (`_isTheCatalogEntry`, via `modNamesMatch`) cleans version decoration fine. The defect is the combination of two things: the global dedup set (`existingNames`) is keyed on raw lowercased names, so "Big Pilum Energy" does not match the entry "Big Pilum Energy 1.0.d" there; and `_isTheCatalogEntry` only compares an LLM mod against the one entry the loop reached the thread through. Three entries share topic 34161, so when the loop arrives via the Useful.Tithes entry, "Big Pilum Energy" misses both checks and gets a synthesized twin — whether that happens depends on list order. The fix on their side is either cleaned keys in `existingNames` or comparing against every real entry on the thread. Worth also raising that TriOS shows one card where the site will have two pages for the two Lost.Sectors, in case they want the same topic-scoped behaviour.

## Open Questions

- Should a thread-only mod appear in "recently added" at all on the run it first appears, given they could arrive together? The `addedOn` post-date rule above probably settles it, but it is worth looking at the first run's output before deciding.
