## Context

The current catalog is assembled in three places:

1. `ModMerger` combines `ForumScraper`, Discord and Nexus results into `ModRepo.json`. Grouping by forum topic limits a topic to one mod.
2. `PublicDataBuilder` joins that catalog to `forum-data-bundle.json`. It extracts topic ids from URLs, matches LLM mods by name (`_mainLlmMod`) and adds unmatched grounded main mods (`_threadOnlyMods`). Release notes and display names also depend on those matches through `_releasesByMod` and `_shownNameFor`.
3. TriOS repeats the matching and synthesis through `withSynthesizedAddonEntries` and `_isTheCatalogEntry`.

The two forum scrapers retain different data. `ForumScraper` reads the mod index and recent board pages for names, authors, versions, URLs and categories. QB also reads each topic, but retains only its category from the mod index.

The Discord reader stores the first message as a description and selects one download and one forum link from the author's messages. The LLM reads none of them. `PublicSiteStep.afterMerge` writes that first message to `discord-posts.json`, keyed by URL, for the site's post panel.

Current data provides the migration baseline:

| Data | Size |
| --- | --- |
| Mod index | 1,245 lines across 545 topics |
| Topics with several index names | 19; mostly alternate names, with three or four real splits such as topic 21968 |
| Topics kept by QB | 1,025 |
| Forum topics in `ModRepo.json` | 737 |
| Discord posts | 624; median 620 characters, maximum 3,954 |
| Discord-only mods in `ModRepo.json` | 199 |

The Nexus reader retains page descriptions, but no Nexus mods appear in the current output; that source is not running.

Use the terms in `CONTEXT.md`: source post, opening run, mod index, listing, mod, Collection, add-on, variant and permanent id.

## Goals / Non-Goals

**Goals:**

- Merge listings once, then let the site and TriOS retrieve facts by explicit references.
- Give Discord-only mods the same LLM extraction as forum mods.
- Use one forum scraper.
- Preserve every existing permanent address.
- Keep a complete catalog with the LLM off.

**Non-Goals:**

- New Nexus extraction. The source post model can support a Nexus builder later; there is no current production data to validate it.
- Discord message text in the bundle. The site continues to show the local Discord post panel.
- Discord-only releases in the feed. Their versions can appear on mod pages, but the release detector still uses forum `ThreadVersionState` keyed by `topicId`.
- Per-mod releases on shared topics. Release tracking remains per forum topic.
- Updates for old TriOS installs. Their files are frozen.

## Decisions

### Extract source posts before merging

Each source post's LLM result becomes listings. Those listings join the rules listings in one merge.

Merging first and asking the LLM to enrich or split each merged group would require another merge after a split. It would recreate the site's current synthesis step. It would also invalidate cached extraction whenever a group gained or lost a source post, even if no post text changed. Per-source extraction avoids both problems and lets Discord use the existing cache model.

### Use one extractor for forum and Discord

`PostExtractor` will accept a `SourcePost` instead of `QbModDetail`. The model contains a source kind and id, title, author, link and opening run. Each post has HTML, links, images and a date.

The forum adapter uses `QbModDetail.title`, `openingPosts`, `allLinks` and `allImages`. It must produce the same prompt as today.

The Discord adapter supplies:

| Field | Value |
| --- | --- |
| Title | Thread name |
| Author | First message's author |
| Opening run | First message with text, then consecutive messages by that author. Stop at the first other author or ten messages. |
| HTML and links | Convert each message through `discordMarkdownAsHtml` in `lib/site/discord_markdown.dart`, then `cleanPostHtml`. |
| Images | Message image attachments |

Discord updates often follow the announcement, so the opening run can supply a changelog. `PostReducer` retains links beside their text as `[link: <url>]`. Grounding checks names, nicknames, URLs and quoted text against that same opening run.

A separate Discord extractor would duplicate the prompt. Fixes for support links, tools, nicknames and save compatibility answers would then need to be made in both extractors.

### Cache Discord results separately without invalidating forum results

Use the existing `llm-extraction-cache.json`. Forum keys remain bare topic ids; Discord keys are `discord:<thread id>`. Freshness still depends on the post fingerprint, prompt version and field set.

Keep the system prompt unchanged when adding Discord. It already describes a thread, title and posts. Add a user-prompt header identifying a Discord announcement thread and its title.

Discord uses `ExtractionPrompt.discordPromptVersion`, starting at 1. Changing its header bumps only that version. Changing the shared system prompt or field set bumps both forum and Discord versions. A shared version would make a Discord wording fix reprocess about 1,000 forum topics as well as 620 short Discord posts.

### Save Discord opening runs during scraping

The Discord scrape owns `discord-posts.json`. It writes the file with `discord_cache.json` only after a successful scrape, under the same all-or-nothing rules. The file is keyed by thread id and contains each thread's source post: title, author, link and opening run.

`PublicSiteStep.afterMerge` stops writing the file. The site's panel retrieves the first message through the mod's Discord source reference. It can still read the old URL-keyed string format until the next scrape replaces it; that old format supplies no LLM input.

Coverage and saved-data merges read this file without fetching Discord.

### Include Discord in the coverage pass

`ScraperService._llmCoveragePass` visits forum topics, then saved Discord threads. Both sources share `llm_max_topics` for live calls and `llm_max_concurrent_calls` for concurrency. Report coverage, live calls and missing answers separately for each source.

ModRepo jobs continue to make no LLM calls. A thread fetched by `scrapeAndMerge` gets extraction in the next QB coverage pass, followed by a merge. Production already runs ModRepo before QB in one CLI invocation, so new Discord threads can be extracted in that run.

Resolve both the Discord rules listing's download and LLM downloads through `QbDownloadResolver` and `DownloadableProbeCache`, using the forum's host rules. Cache Discord results under `discord:<thread id>`.

### Build one rules listing per source post

A forum topic gets one rules listing. Its other mod index names remain alternate names on that listing. Nineteen topics have several index names, but fixed rules cannot reliably distinguish an alternate spelling such as "Exalted" / "The Exalted" from two different mods such as "Red" / "Blue". Creating a listing for each name would assign different permanent ids to spellings of one mod.

A Discord rules listing retains today's Discord `ScrapedMod` fields.

### Prefer the current mod index

When the current index lists a topic, use only its current lines. Fall back to older index posts only for topics absent from the current index. This preserves `ForumScraper.parseModIndex`'s existing rule when that scraper is removed.

Without this rule, the merge's highest-version selection lets an archived "[0.97a]" override the current "[-]" for TriOS, topic 29674.

The QB board scraper keeps pinned topics listed in the current mod index. This is how TriOS itself enters the QB store, which becomes the only forum source.

### Combine rules and LLM listings before the merge

`SourcePostListings` takes a rules listing, the LLM result and the source post. It applies the same rule to forum and Discord:

| Grounded LLM main mods | Result |
| --- | --- |
| None | Keep the rules listing. |
| One | Combine it with the rules listing, even if their names differ. |
| Two or more, with a name match | Create one listing per main mod; combine the rules listing with the matching mod. |
| Two or more, with no name match | Create one listing per main mod; classify the source post as a Collection and drop the rules listing. |

A grounded main mod has a name in the opening run and a download tied to it. Match names and grounded nicknames with `modNamesMatch`, including the rules listing's alternate names. Do not use `ModIdStore.cleanName` for matching; see CLAUDE.md. For example, topic 21968's index name "Pirate Collection" can match a mod whose post identifies it as a former name.

For forum topics, this moves the site's and TriOS's existing combination rule before the merge. For Discord, it adds support for several mods in one thread.

Each Discord LLM listing retains the thread's forum link. It can then enter the existing topic bucket, where `_namesLookRelated` distinguishes mods sharing a topic. Hartley's Discord threads already use this path to reach their individual mods on Collection topic 34161.

### Retain ScrapedMod as the listing body

A listing contains a `ScrapedMod`, a `SourcePostRef` and its origin (`rules` or `llm`). The ref holds `kind` (`forum`, `discord` or `nexus`), `id` and, for LLM listings, `llmModName`. The merged mod retains all contributing refs.

This preserves the merge's grouping, matching, author cleanup and category cleanup. Replacing `ScrapedMod` too would add a second source of differences to the migration comparison. `ModMerger` receives listings without needing to know how they were extracted.

### Choose facts by source precedence

For each field, prefer the forum LLM result. Discord fills fields the forum leaves empty. The forum usually holds the full write-up; Discord usually holds a short announcement.

Downloads are one field, selected in this order:

1. Forum LLM downloads, if present.
2. Discord LLM downloads, if present.
3. The existing Discord rules-link fallback in `discord_download.dart`.

The mod version is an exception: choose the higher version using TriOS's `compareVersions`, since Discord may announce a release before the forum is updated. When two results come from the same source kind, prefer the newer source post.

### Assign permanent ids in the merge

Move `ModIdStore` from the site build into the merge. Add source post refs to `mod-ids.json`. Look up a mod's refs first; use name-based assignment only when none has an id. If refs point to two ids, retain the older id and log the conflict for review.

Keeping name-based lookup would make every naming improvement risk a changed address. Source references let index and LLM names change while the id stays fixed.

Before removing the site's matching code, run `bin/link_mod_ids.dart` to link existing ids using `outputs/site/mods/<id>.json`. Those files contain forum and Discord URLs and the LLM names of thread-only mods. For a merged mod on a topic with several LLM main mods, use today's `_mainLlmMod` result to include its LLM name in the ref.

That name distinguishes mods sharing a topic: Hartley's three Discord mods would otherwise all receive bare topic 34161 refs. The linking command is safe to repeat.

### Preserve existing Collection addresses

A Collection whose rules listing had an id keeps that id reserved. Publish a page at its existing address, naming the source post and linking to its mods. Use `mod_page_html.dart` to replace the page template's HTML head, as mod pages do. A Collection without an existing id gets no page.

The current example is topic 34457, published as `derelict-start-remnant-start-omega-start-threat-start`, which contains four start-option mods. Dropping the page would break shared links. Keeping it as a mod would give it an arbitrary member's download button.

### Write v2 files and freeze the old files

| File | Contents |
| --- | --- |
| `ModRepo-v2.json` | Permanent id, existing catalog fields and source post refs for each mod. Bundle facts are looked up by ref rather than copied here. |
| `forum-data-bundle-v2.json` | Existing forum bundle shape plus `discordThreads`: thread id, link, title and LLM mods with downloads and extras. No Discord message text. |

Keep the name "Forum Data Bundle" for reader familiarity. A separate Discord bundle would require readers to fetch and join another file for the same source-ref lookup.

Old TriOS ignores unknown fields but fails on unknown `ModSource` or `ModUrlType` enum values. New filenames remove that compatibility constraint. After the switch, no code writes `ModRepo.json` or `forum-data-bundle.json`. Old TriOS installs retain their last catalog and receive no later LLM fixes; this is accepted.

### Merge after jobs that change listings

`fullRun`, `rescrapeTopics`, `extractLlm`, `llmCoveragePass` and `rebuildBundle` finish with:

`rebuild bundle → merge → build site`

The merge reads the QB store, `discord-posts.json`, LLM store and Discord/Nexus caches. It takes seconds and makes no network calls. Keep `mergeModRepo` and `scrapeAndMerge`, removing their forum scraping source.

### Read display names from listings

Today `_shownNameFor` uses an LLM name only when it agrees with the topic title. This helps with titles such as "Sea of Stars 0.5.1 - Go Beyond the Persean Sector", while keeping "Red" from becoming "Red - the Oculian Armada".

After this change, the site reads that name from the mod's LLM listing instead of calling `_mainLlmMod`. Keep the title-agreement check, including for Discord thread names.

## Risks / Trade-offs

| Risk | Response |
| --- | --- |
| An existing id disappears or changes address | Link ids first. Block the switch if comparison loses an existing mod id, except ids becoming Collection pages. |
| The LLM classifies a real mod as a Collection | Require two grounded main mods and no name match. Review every new Collection. The patch-file prompt rule in `b5d5e86` already prevents a common source of false mods. |
| Forum-tested prompts perform poorly on Discord | Add saved Discord threads to live-model tests. Review every Discord Collection and thread producing several listings. |
| Discord replaces a better forum fact | Only fill empty forum fields, except version, which takes the higher value. |
| About 290 more forum topics become mods, including some that may not be mods | Their LLM mods already appear through `_threadOnlyMods`, so the site count should change little. Compare every new mod. |
| Comparison uses mixed extraction versions | Finish the forum version-23 pass and first Discord pass, or compare a frozen copy. |
| Old TriOS installs become stale | Accepted; updated TriOS reads v2 files. |
| A Discord listing joins the wrong mod on a shared topic | Existing similar-name matching risk remains. Include listing origins in merge debug so the viewer exposes these matches. |

## Migration Plan

1. Add mod index lines to `QbModSummary` and scrape QB again to populate them.
2. Save Discord opening runs and run a Discord scrape.
3. Adapt the extractor to `SourcePost`, add Discord coverage and run until every Discord thread has an answer.
4. Build listings and feed them to `ModMerger` from QB, Discord/Nexus caches and LLM results. During development only, keep the old pipeline writing `ModRepo.json` alongside it for comparison.
5. Run `bin/link_mod_ids.dart` on a copy of `qb_data`.
6. Move id assignment into the merge, write v2 files and switch the site builder. Remove `_threadOnlyMods`, `_mainLlmMod` and topic-id guessing.
7. Compare copied real data against the published site. Fix differences and repeat until every existing mod id survives, except ids becoming Collection pages.
8. Switch production:
   - Stop writing the old files.
   - Delete `ForumScraper` and its config keys.
   - Update `tool/update-mod-repo.sh` to check and name the v2 files.
   - Run id linking on real `qb_data`, then run the new pipeline.
9. In a separate TriOS change, read v2 files and remove `withSynthesizedAddonEntries` and `_isTheCatalogEntry`.

The cron script deletes local `outputs/` before each run. After the switch, the frozen files therefore exist only in the publish repo. The script copies new files into that repo without deleting old ones, so the frozen files remain.

Steps 2 and 3 can reach production early. They add cached Discord answers that no consumer uses until step 6, allowing coverage to finish before comparison.

Before step 8, rollback needs no migration: production still uses the old code. After step 8, restore `mod-ids.json` from before linking and revert the implementation commit. The frozen output files remain in the publish repo.

## Open Questions

- Does the first mod index line provide a good name? Compare its choices with today's names. If it often chooses poorly, prefer the line matching the topic title. Topic 21968 is a likely case: its first line may name the whole Yunru pack "Midline Expansion".
- Should Discord-only mods enter the release feed? That requires version tracking per source post instead of per forum topic and belongs in a later change.
