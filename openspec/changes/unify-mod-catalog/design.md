## Context

Today two pipelines each produce a file, and three places merge them:

1. `ModMerger` merges forum board and index listings (`ForumScraper`), Discord threads and Nexus pages into `ModRepo.json`. It groups by forum topic id first, so one forum topic is at most one mod.
2. `PublicDataBuilder` reads `ModRepo.json` and `forum-data-bundle.json`, finds each mod's topic by pulling `topic=<id>` out of its forum URL, and then decides by name which LLM mod on that topic is which merged mod (`_mainLlmMod`). It invents a stand-in mod for every grounded LLM main mod nothing accounts for (`_threadOnlyMods`). Since the save-notes change, `_releasesByMod` also calls `_mainLlmMod`.
3. TriOS does its own version of step 2 (`withSynthesizedAddonEntries`, `_isTheCatalogEntry`).

The forum is scraped twice. `ForumScraper` reads the mod index and the newest board pages and keeps only a name, author, game version, URL and category. QB reads the same pages and then every topic, but keeps only "topic → category" from the index. Measured on current data: the mod index has 1,245 lines over 545 topics, and 19 topics have more than one name (mostly spellings of one mod; three or four real splits such as topic 21968). The QB store has 1,025 kept topics, against the 737 forum topics in `ModRepo.json`.

Terms used here are defined in `CONTEXT.md`: source post, opening run, mod index, listing, mod, Collection, add-on, variant, permanent id.

## Goals / Non-Goals

**Goals:**
- One merge, over listings from every source, whose result the site and TriOS read without matching anything by name.
- One forum scraper.
- Every permanent id that exists today keeps its address.
- With the LLM off, the catalog is still complete.

**Non-Goals:**
- Discord threads holding several mods. Discord still gives one listing per thread. The listing model leaves room for it later.
- Any change to Nexus.
- Publishing Discord message text.
- Giving releases on a shared topic to the right mod. Release tracking stays per forum topic (`ThreadVersionState` by `topicId`), as today.
- Keeping old TriOS copies up to date. Their two files are frozen.

## Decisions

### The LLM reads each source post before the merge, not the merged groups after it

The LLM's answer for a topic is turned into listings, and those go into the one merge with everything else.

*Alternative considered:* merge first by rules, then give the LLM each merged group (the mod plus all its forum and Discord posts) and let it enrich and split. Rejected for two reasons. First, when the LLM splits a group into several mods, those new mods have to be matched against Discord and Nexus again, which needs a second merge — today's `_threadOnlyMods` under another name. Second, the LLM cache is keyed per topic on the post's text. A merged group changes whenever the merge pulls a Discord post in or out, so keying on groups would make the model read topics again for no new information, and that costs money.

### One rules listing per forum topic; the LLM does the splitting

The mod index names more than one mod for 19 topics, but most of those are spellings of one mod ("Exalted" / "The Exalted"), and no rule can tell them from a real split ("Red" / "Blue"). So the rules give one listing per topic, and the other index names are kept as other names on it. That matches today's `ModRepo.json`, because `ModMerger` already groups by topic.

*Alternative considered:* one listing per different index name. Rejected because it would split spellings of one mod into separate mods with separate permanent ids.

### How a topic's listings combine

This is the rule from the `mod-catalog` spec (no main mods: rules listing alone; one: they are one listing; two or more: the rules listing joins the one whose name matches, otherwise the topic is a Collection). It is today's site and TriOS behaviour moved to before the merge, so what it decides does not change, only where.

Grounding is the existing check: the name must appear in the opening run, and a download must be tied to it. Matching uses `modNamesMatch`, never `ModIdStore.cleanName` (see CLAUDE.md, "Matching is `mod_name_match.dart`, not `cleanName`").

The new code lives in one place, a `ForumListings` step that takes a `QbModSummary` (with its index lines and LLM answer) and the topic's detail, and returns listings. `ModMerger` is given listings and does not know where they came from.

### What a listing is in code

A listing is a `ScrapedMod` plus a `SourcePostRef` saying where it came from (`kind`: forum / discord / nexus, `id`, and for an LLM listing `llmModName`) and how it was found (`rules` / `llm`). Keeping `ScrapedMod` as the body means `ModMerger`'s grouping, matching, author tidying and category tidying all keep working unchanged. A merged mod keeps the refs of every listing that went into it.

*Alternative considered:* a new listing model from scratch. Rejected for this change: it would mean rewriting `ModMerger` at the same time as changing what goes into it, and the comparison step could not tell which change caused a difference.

### Permanent ids are found by source post, not by name

`ModIdStore` moves out of the site build and into the merge. Each entry in `mod-ids.json` gains a list of source post refs. To find a mod's id, the merge looks through the mod's refs for one that already has an id; only if none does is the id worked out from the name, as today. If a mod's refs point at two different ids, the older id wins and the clash is logged — that is two pages becoming one, and someone should look at it.

*Alternative considered:* keep looking ids up by name and make the new merge choose names exactly as the old one did. Rejected because the new merge will choose names differently (index names and LLM names are now in play), and it would tie every future change to the merge to "don't change which name wins".

A one-time command (`bin/link_mod_ids.dart`) fills in the refs for every existing id from the current published site data (`outputs/site/mods/<id>.json` already holds each mod's forum URL, Discord URL and, for thread-only mods, its LLM name). It is safe to run again.

### A Collection that had an id keeps a page

When a topic becomes a Collection and its rules listing had an id, the id stays reserved and the site publishes a small page at that address that names the topic and links to each mod on it. It uses the same `index.html` head swap as mod pages (`mod_page_html.dart`). A Collection that never had an id gets no page.

*Alternatives considered:* let the page disappear (breaks shared links), or keep publishing the collection as a mod (it isn't one, and its download button would offer whichever mod came first).

### Two new files; the old ones are frozen

`ModRepo-v2.json` holds one record per mod: its permanent id, the fields `ModRepo.json` holds, and its source post refs. Facts that live in the forum bundle (the post, downloads, LLM extras) are not copied in; readers look them up in `forum-data-bundle-v2.json` by topic id and LLM mod name. `forum-data-bundle-v2.json` starts as the same shape as today's bundle.

Being new files, neither is tied to the value lists in old TriOS (`ModSource`, `ModUrlType`), which make old TriOS fail to read a file containing a value it doesn't know.

*Alternative considered:* add fields to `ModRepo.json` and keep writing it. Old TriOS skips unknown fields, so this would have worked, but it would tie the file to old TriOS's value lists for ever. The user chose a clean new file and a frozen old one.

Freezing means old TriOS copies show the catalog as it was on the day of the switch, and get no later LLM fixes either. That is accepted.

### The merge runs after every job that changes listings

`fullRun`, `rescrapeTopics`, `extractLlm`, `llmCoveragePass` and `rebuildBundle` end with: rebuild bundle → merge → site build. The merge reads the QB store and the Discord and Nexus caches, makes no network call and takes seconds. `mergeModRepo` and `scrapeAndMerge` stay as job kinds, minus the forum source.

## Risks / Trade-offs

- [An existing id disappears or moves] → The one-time id linking, plus the switch-over comparison that refuses to switch while any existing id disappears other than the expected Collections.
- [The LLM wrongly calls a topic a Collection and drops a real mod's rules listing] → Only grounded main mods count, and it takes two of them with no name match. The comparison lists every new Collection for a person to check before the switch. The patch-file prompt rule (`b5d5e86`) already cuts the commonest fake mods.
- [About 290 more forum topics become mods, some of which are not mods] → They already appear on the site through `_threadOnlyMods`, so the site's count barely moves. The comparison lists every new mod.
- [Comparison runs on a mix of LLM answers] → The prompt is at version 18 and every topic is being read again. Run the comparison after that pass finishes, or on a frozen copy.
- [Old TriOS copies drift out of date] → Accepted. New TriOS reads the v2 files.
- [`ModRepo-v2.json` merges a Discord listing to the wrong one of several mods on a topic] → The same risk the merge has today for any two mods with similar names. Merge debug now records which listing came from which source post, so it can be seen in the viewer.

## Migration Plan

1. Store mod index lines on `QbModSummary` and re-run a QB scrape so every topic has them.
2. Build the listing model and the forum listing step. Feed `ModMerger` from the QB store and the existing Discord and Nexus caches. Keep writing `ModRepo.json` the old way side by side during development only, so the two can be compared.
3. Run `bin/link_mod_ids.dart` on a copy of `qb_data`.
4. Move id assignment into the merge, write `ModRepo-v2.json` and `forum-data-bundle-v2.json`, and point the site builder at them. Remove `_threadOnlyMods`, `_mainLlmMod` and the topic-id guessing.
5. Run the switch-over comparison on a copy of the real data. Fix and repeat until no existing id disappears other than the expected Collections.
6. Switch production: stop writing the old files, delete `ForumScraper` and its config keys, run the linking step on the real `qb_data`, then the first real run.
7. Separately, in the TriOS repo: read the v2 files and drop `withSynthesizedAddonEntries` and `_isTheCatalogEntry`.

Rollback before step 6 is free: production still runs the old code. After step 6, rolling back means restoring `mod-ids.json` from before the linking step and reverting the commit. The frozen old files are still in the target repo, untouched.

## Open Questions

- Is the first index line always the best name for a topic? Index order is the forum staff's, not ours. The comparison will show how often this picks a worse name than today; if it is often, prefer the line whose name best matches the topic title.
- Does any real Discord thread link to a Collection topic rather than to one of its mods? If so, its listing has no single mod to join. Proposed: it joins nothing by topic and goes through the ordinary name matching. Check on real data during step 5.
