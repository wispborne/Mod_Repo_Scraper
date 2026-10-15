## Context

Right now, a mod can be missing from `ModRepo.json` but still have a page on the site. That's because the site reads the forum bundle and adds mods that the merge didn't find. TriOS has its own code for doing the same thing. We want the merge to produce the whole catalog, so neither reader has to finish the job.

The problem starts with how we handle forum topics. `ModMerger` groups the old forum scraper's results with Discord and Nexus results, treating a forum topic as at most one mod. The site then pulls the topic id out of the forum URL and tries to match each mod against the LLM's answer by name. `_mainLlmMod` chooses an answer for an existing mod, and `_threadOnlyMods` creates mods that haven't been matched. `_releasesByMod` and `_shownNameFor` depend on those choices for release notes and display names. TriOS repeats the matching in `withSynthesizedAddonEntries` and `_isTheCatalogEntry`.

We also have two forum scrapers doing overlapping work. `ForumScraper` reads the mod index and recent board pages, keeping the name, author, game version, URL and category. QB reads those pages and the topics themselves, but only keeps the category from each mod index line. We can use QB alone once it keeps the rest of that information.

Discord gets much less attention. Its reader uses the first message as the description and picks one download link and one forum link from the author's messages. The LLM never reads it. The site later writes that first message to `discord-posts.json`, with the message URL as the key, so it can show the announcement on the mod page. Nexus descriptions are saved too, but Nexus isn't running and there are no Nexus mods in the current output.

These are the counts from the data used to prepare this change:

| What we counted | Result |
| --- | --- |
| Mod index lines | 1,245 lines linking to 545 topics |
| Topics with several index names | 19; mostly different names for one mod, with three or four actual splits, including topic 21968 |
| Topics QB keeps | 1,025 |
| Forum topics in `ModRepo.json` | 737 |
| Discord posts | 624 |
| Discord post length | Median 620 characters; longest 3,954 |
| Discord-only mods | 199 |

A few terms will come up throughout the plan. A **source post** is a forum topic, Discord thread or Nexus page. A **listing** is one mod as that post describes it. The merge joins listings that describe the same **mod**. A **Collection** is a post containing several mods; if it already has a page, that page should link to the individual mods. `CONTEXT.md` defines these and the other shared terms.

## Goals / Non-Goals

We want one catalog that the site and TriOS can both use as it is. Discord mods should get the same information from the LLM as forum mods, and we should only need one forum scraper. Turning the LLM off must still leave a complete catalog from the scraper's rules. Existing mod addresses must keep working even when we find a better name for a mod.

We're leaving a few things for later. There are no Nexus mods in the current output to test a new extractor against, so Nexus will keep its existing rules listings. Release tracking will still follow forum topics through `ThreadVersionState` and `topicId`. A Discord-only mod can show its version on its page, but won't join the release feed. When several mods share a topic, we still won't track their releases separately.

The site will keep showing Discord announcements, but the bundle won't contain their message text. Old TriOS installs will keep reading the old files, which will stop changing when we switch to the new ones.

## Decisions

### Read each post before merging it with other sources

First, work out which mods a post describes. Then compare those listings with listings from the other sources. That gives the merge individual mods to work with, even when one topic describes several of them.

We considered doing it the other way round: merge by the existing rules, then ask the LLM to read each merged group and split it if necessary. But after a split we'd still need to check whether those new mods matched anything elsewhere. We'd need a second merge, much like the extra work the site does now.

It would also make the LLM cache harder to reuse. Adding or removing a post from a group would change the group's input, even when none of the posts had changed. Reading each post separately lets us keep its answer until that post or its prompt changes.

The merge itself will only read saved files: the QB store, Discord and Nexus caches, `discord-posts.json` and the LLM store. It should take seconds and need no network calls. `mergeModRepo` will still merge saved data, and `scrapeAndMerge` will still fetch the chosen sources first. Neither job will scrape the forum or call the LLM.

### Give forum and Discord posts to the same extractor

The extractor currently takes a forum-specific `QbModDetail`. We'll change it to take a `SourcePost`, which has the source kind and id, title, author, link and the author's opening posts. Each of those posts has HTML, links, images and a date.

For a forum topic, build that input from `QbModDetail.title`, `openingPosts`, `allLinks` and `allImages`. The prompt sent to the model must stay exactly the same. We should test the full prompt before and after the change.

For Discord, use the thread's name as the title and the first message's author as the author. Start with the first message that has text, then include the messages straight after it by the same person. Stop as soon as someone else posts, or once we have ten messages. We call this the **opening run**. Authors often post update notes just after the announcement, so those messages can give us a changelog too.

Turn each message's markdown into HTML with `discordMarkdownAsHtml` in `lib/site/discord_markdown.dart`, then run `cleanPostHtml`. Get the links from that HTML and the images from the message's image attachments. This lets the extractor use `PostReducer` for either source. Its `[link: <url>]` markers keep a download beside the words that describe it, which matters when a post has several mods.

When we check the model's answer, use only those opening messages. Names, nicknames, URLs and quoted text must come from the author's own words. A download mentioned only in someone else's reply doesn't count.

We don't need a separate Discord extractor or system prompt. That would mean making every improvement twice, whether it was about support links, tools, nicknames or whether a mod works with an existing save.

### Save Discord messages when we scrape them

The Discord scraper will write `discord-posts.json` when it writes `discord_cache.json`, after the scrape succeeds. Both files follow the same all-or-nothing rule. Each thread will be stored under its thread id, with its title, author, link and opening messages.

`PublicSiteStep.afterMerge` will stop writing this file. The site's Discord panel will use the mod's saved thread reference to find the first message. It must still read the old file format, where a URL points to a single string, until a successful scrape replaces it. That old format is enough to show the announcement, but we won't send it to the LLM.

With the new file saved, the coverage pass and later merges can read Discord threads without fetching them again.

### Keep the cached answers we already paid for

Discord answers will go in `llm-extraction-cache.json` alongside forum answers. Forum keys stay as bare topic ids; Discord keys will be `discord:<thread id>`. The check for whether an answer is still usable stays the same: compare the post's fingerprint, the prompt version and the set of fields we asked for.

The system prompt already talks about a thread, title and posts, so it doesn't need to change. Add a line to the user prompt saying this is a Discord announcement thread and giving its title.

Discord gets its own prompt version, `ExtractionPrompt.discordPromptVersion`, starting at 1. Changing that Discord line only bumps the Discord version. Changing the shared system prompt or the requested fields bumps both versions. This lets us adjust the Discord wording without paying to reread roughly 1,000 forum topics as well as 620 short Discord posts.

`ScraperService._llmCoveragePass` will read saved forum topics first, then saved Discord threads. Both count towards `llm_max_topics`, the limit on new LLM calls, and both share `llm_max_concurrent_calls`, the limit on calls running at once. Report forum and Discord counts separately: how many posts were covered, how many needed a call, and how many still need an answer.

A Discord thread freshly saved by `scrapeAndMerge` will initially have just the listing found by the rules. The next QB coverage pass will read it and finish with another merge. Production already runs ModRepo before QB in one CLI run, so that can happen in the same run without adding LLM calls to the ModRepo jobs.

Discord downloads also need the forum's existing checks. Send both the rules listing's download link and the LLM's download links through `QbDownloadResolver` and `DownloadableProbeCache`. Keep the same rules for each download host and cache the Discord results under `discord:<thread id>`.

### Start with one listing from the rules

For a forum topic, take the first mod index line's name, author, game version and category. Keep the names from its other lines as other names for the same listing. If the topic isn't in the index, use its title with the release information removed. A Discord listing starts with the same fields the Discord reader produces today. Each Nexus result also remains one listing.

We shouldn't make a separate listing for every index name. "Exalted" and "The Exalted" might be the same mod, while "Red" and "Blue" might be different ones. Rules can't reliably tell which case we're looking at. Splitting every name would give different spellings of one mod their own permanent ids. Let the LLM identify the cases where a post really has several mods.

Use the current mod index whenever it lists a topic. Only use the old index posts when the topic isn't in the current one. `ForumScraper.parseModIndex` already does this, and QB needs to keep doing it after that scraper is removed. Otherwise the merge can prefer an old "[0.97a]" over today's "[-]", as it did for TriOS on topic 29674.

Also keep the QB board scraper's rule that a pinned topic stays when the current mod index lists it. That's how TriOS itself gets into QB. We can't lose it when QB becomes the only forum source.

### Combine the rules listing with the LLM's answer

The code for this belongs in one place, `SourcePostListings`, used by both forum and Discord. It takes the source post, its rules listing and its LLM answer.

Only count LLM mods with role `main` whose names appear in the author's opening messages and which have at least one download tied to them. These are the mods the specs call **grounded**. Then apply these rules:

- **No main mods:** keep the rules listing as it is.
- **One main mod:** combine it with the rules listing and use the LLM's facts. They still describe one mod even if their names differ.
- **Several main mods:** make a listing for each. Try to match the rules listing to one of them. If one matches, combine those two. If none matches, the post is a Collection and the rules listing is dropped.

For the match, compare the rules listing's name and other names against each LLM mod's name and verified nicknames. Use `modNamesMatch`, not `ModIdStore.cleanName`; CLAUDE.md explains why those serve different purposes. A former name can be the right match. On topic 21968, for example, the index's "Pirate Collection" can match a mod whose post gives that as its old name.

Add-ons and variants stay with their main mod rather than getting listings of their own. Results marked `separate` don't become listings either. For the forum, we're moving the decisions already made by the site and TriOS to an earlier step. For Discord, this is what lets one announcement describe several mods.

When the LLM is off, every kept post still has its listing from the rules. The Collection rule is the only case where the LLM can cause that listing to be dropped. It can't otherwise remove, rename or merge it away.

### Keep track of where each listing came from

A listing will contain the existing `ScrapedMod`, a `SourcePostRef`, and whether the rules or the LLM found it. The reference records the source kind (`forum`, `discord` or `nexus`), its id, and `llmModName` when it came from an LLM answer.

Keeping `ScrapedMod` means we can keep the merge's grouping, name matching, author cleanup and category cleanup. Replacing that model at the same time would make it harder to tell why the new catalog differs from the old one. `ModMerger` just takes the listings and keeps all their references on the mod it produces.

Every Discord LLM listing must also keep the thread's forum link, if it has one. The merge uses that link to group it with listings from the same forum topic. `_namesLookRelated` then helps find the right mod within that topic. Hartley's Discord threads already use this to join their own mods on Collection topic 34161. Losing the link would lose that useful match.

### Choose the facts to show for a mod

A forum post is usually the full write-up, while Discord is usually a short announcement. So use the forum LLM answer for each field when it has one. If that field is empty, try the Discord answer. When there are two answers from the same kind of source, try the newer post first.

Treat the downloads as one list. If the forum answer has downloads, use those. Otherwise use the Discord LLM downloads. If neither has any, use the Discord reader's existing download-link fallback in `discord_download.dart`.

The mod version is the one exception to preferring the forum. Discord may announce a release before the forum post is updated, so use the higher version according to TriOS's `compareVersions`.

The displayed name keeps its current check too. An LLM name can help with a title like "Sea of Stars 0.5.1 - Go Beyond the Persean Sector", but it shouldn't turn "Red" into "Red - the Oculian Armada" just because the model used that name. `_shownNameFor` will read the name from the LLM listing instead of asking `_mainLlmMod`, and still require it to agree with the title. Check Discord names against their thread titles the same way.

### Find an existing id before making a new one

Move `ModIdStore` from the site build into the merge. Each `mod-ids.json` entry will remember the source posts that belong to it. When the merge needs a mod's id, it first looks for one through those posts. It only falls back to the name when none of them has an id.

If two of the mod's posts point to different ids, keep the older id and log the clash. That means two pages are being combined, and someone should check it. Looking up ids by post lets us improve a mod's name without changing its address. If we kept looking up by name alone, every naming change would risk moving a page.

Before removing the old matching code, run `bin/link_mod_ids.dart` to fill in those post references for existing ids. It reads `outputs/site/mods/<id>.json`, which already has the forum and Discord URLs and the LLM names used for thread-only mods. For a merged mod on a topic with several main mods, use the current `_mainLlmMod` result to record its LLM name too. Running the command again on the same data must give the same file.

The name matters on shared topics. Without it, Hartley's three Discord mods would all get the same reference to topic 34161, with nothing saying which one each id belongs to.

A Collection that already had an id keeps that address. Reserve the id and put a page there naming the post and linking to its individual mods. Use the same HTML-head replacement in `mod_page_html.dart` that mod pages use. A Collection that never had an id doesn't get an id or a page.

Topic 34457 shows why we need this. Its current address is `derelict-start-remnant-start-omega-start-threat-start`, but the topic has four start-option mods. Removing the page would break links people have shared. Keeping it as a mod would leave its download button pointing at whichever member happened to come first. A page listing the four mods keeps the link useful.

### Write new files and have the site read them directly

`ModRepo-v2.json` will have one record per mod: its permanent id, the fields in the current catalog and its source post references. Don't copy the bundle's detailed facts into it. The site and TriOS can use those references to find the facts in `forum-data-bundle-v2.json`.

The v2 bundle starts with the current forum bundle and adds `discordThreads`. Each entry has the thread id, link, title and the LLM's mods, with their downloads and extras. It has no Discord message text. We'll keep calling it the Forum Data Bundle because that's the name its readers already know. A separate file for Discord would mean fetching and joining another bundle for the same lookup.

Old TriOS ignores fields it doesn't know, but fails if it encounters an unknown `ModSource` or `ModUrlType` enum value. New filenames let us change those without breaking an installed copy. When we switch, stop writing `ModRepo.json` and `forum-data-bundle.json`. Old TriOS will keep reading their last contents and won't get later catalog updates or LLM corrections. That's the trade-off we've chosen.

The jobs `fullRun`, `rescrapeTopics`, `extractLlm`, `llmCoveragePass` and `rebuildBundle` must finish in this order: rebuild the bundle, merge the catalog, then build the site. The site reads the ids and facts from the v2 files. Remove `_threadOnlyMods`, `_mainLlmMod` and topic-id guessing, including the lookups that `_releasesByMod` and `_shownNameFor` currently make through them.

## Risks / Trade-offs

The most important check is that we don't lose an existing address or give it to the wrong mod. Link the existing ids to their posts first, then compare the new output against the published site by id. A missing mod id stops the switch unless it is one of the expected Collection pages.

The LLM might also mistake a real mod for a Collection. Requiring two verified main mods and no matching rules name reduces the risk, but we still need to review every new Collection. The prompt's patch-file rule in `b5d5e86` already prevents a common kind of false mod. Add real Discord examples to `test/llm_live/` too: the prompt was developed on longer forum posts, so we need to check how it handles announcements. Review every Discord thread that becomes a Collection or gives several listings.

Using QB brings about 290 more forum topics into the catalog, some of which may not be mods. Their LLM mods already appear on the site through `_threadOnlyMods`, so the site's count should change little. Even so, the comparison must list every new mod. Check the chosen names as well; taking the first index line may produce a worse name than the site uses now.

Don't compare halfway through an LLM pass. The forum is currently being reread for prompt version 23, and Discord still needs its first pass. Finish both, or use a frozen copy, so we're not mixing pipeline differences with changes in which posts the LLM has read.

The merge can still match similar names incorrectly, especially when several mods share a forum topic. Merge debug must show which post each listing came from so we can inspect those matches in the viewer. Preferring forum facts limits how much a worse Discord answer can change a page: it can fill an empty field or supply a higher version, but can't replace the other facts we already have from the forum.

Old TriOS copies will become out of date after the switch. The separate TriOS update is what moves them to the new files.

## Migration Plan

### Get the saved data ready

Save mod index lines on `QbModSummary` and run a QB scrape to fill them in. Make the Discord scraper save opening messages, then run a Discord scrape. Change the extractor to read `SourcePost`, add Discord to the coverage pass, and let it run until every saved thread has an answer.

The Discord saving and extraction changes can go to production before the rest. They just add answers to the cache; the current site doesn't use those answers yet. That gives us time to finish the first pass before comparing catalogs.

### Try the new pipeline on a copy

Build the listings and feed the new merge from QB, the Discord and Nexus caches, and the LLM store. During development only, keep the old pipeline writing `ModRepo.json` as well, so we can compare them.

Run `bin/link_mod_ids.dart` on a copy of `qb_data` while the old site matching code is still available. Move id assignment into the merge, write both v2 files, and have the site read them. Once the linking command can save the old matches, remove the site's code for making missing mods and guessing their matches.

Run `bin/compare_catalog.dart` on copied real data and compare with the published site. It needs to list missing ids, ids linked to different posts, new Collections, Discord threads with several listings and new mods. Fix the differences and repeat until every existing mod id survives, apart from the expected ids that become Collection pages.

### Switch the production run

Archive `starmodder-4-public-site` before applying the publishing spec changes that depend on it. Once the comparison is good, stop writing the old files, delete `ForumScraper` and remove its config keys. Update `tool/update-mod-repo.sh` to check for the v2 files and name them in its commit message. Back up production `mod-ids.json`, run the linking command on the real `qb_data`, and run the new pipeline.

The script deletes local `outputs/` before each run. After the switch, the frozen old files will only be in the publish repo. The script copies files into that repo without deleting the old ones, so they stay available there.

In a separate TriOS change, read the two v2 files and remove `withSynthesizedAddonEntries` and `_isTheCatalogEntry`.

Before the production switch, we can abandon the new code without changing production data. After the switch, rolling back means restoring `mod-ids.json` from before the linking step and reverting the implementation commit. The old published files will still be there.

## Open Questions

Is the first mod index line usually a good name? On topic 21968 it could call the whole Yunru pack "Midline Expansion". The comparison should tell us how often that happens. If it often makes names worse, we could use the line whose name best matches the topic title instead.

Discord-only mods could join the release feed in a later change. That would mean tracking versions per source post instead of per forum topic.
