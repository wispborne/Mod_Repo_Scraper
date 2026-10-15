## Why

The catalog is matched in three places. `ModMerger` combines forum, Discord and Nexus data into `ModRepo.json`. The site builder then matches those mods to the forum bundle's LLM results and adds mods the merge missed. TriOS repeats that work. Each consumer makes its own name matches, so they can disagree about which mods a topic describes.

The forum is also scraped twice. The older scraper requires a bracketed game version in the title and misses topics such as Computica's seven forks. QB already stores those topics.

Discord-only mods have a separate gap: the LLM never reads their announcements. The 199 Discord-only mods in the current output therefore lack extracted requirements, save compatibility answers, support links, licenses, nicknames, summaries and additional downloads.

This change puts LLM results into the catalog before merging. Forum topics and Discord threads produce listings, and one merge turns those listings into mods. The site and TriOS read that result and use explicit source references to retrieve each mod's facts.

## What Changes

### Scraping and extraction

- Use the QB store as the only forum source and delete `ForumScraper`. Store each topic's mod index lines, including name, author, game version and category.
- Save each Discord thread's opening run: the author's first message and consecutive messages before anyone else replies.
- Read Discord threads with the forum's extractor, system prompt and grounding checks. Forum and Discord calls share the existing spending and concurrency limits.

### Listings and the merge

- Build one rules listing per source post. Grounded LLM `main` mods can add listings. The terms are defined in `CONTEXT.md`.
- Combine rules and LLM results before merging. With no grounded main mod, keep the rules listing. With one, combine them. With several, combine the rules listing with the matching mod; if none matches, classify the source post as a **Collection** and drop its rules listing.
- Keep a complete catalog when the LLM is off. Apart from the Collection rule, LLM results cannot remove, rename or merge away a rules listing.
- Merge all listings once. Remove the site builder's `_threadOnlyMods`, `_mainLlmMod`, name checks and topic-id guessing.
- Prefer forum LLM facts; use Discord facts to fill empty fields. For the mod version, use the higher version.
- Assign permanent ids in the merge. Look up existing ids by source post before falling back to names. Link today's ids to their source posts in a one-time migration. An existing Collection id keeps a page linking to its mods.
- After every job that changes listings, run the merge and then build the site.

### Outputs and compatibility

| File | Contents and readers |
| --- | --- |
| `ModRepo-v2.json` | One record per mod, with its permanent id and source post references. Read by the site and updated TriOS. |
| `forum-data-bundle-v2.json` | Existing forum data plus Discord LLM results, looked up by source reference. Contains no Discord message text. |
| `ModRepo.json`, `forum-data-bundle.json` | Frozen at the switch. Existing TriOS installs keep this catalog and receive no later updates. |

Before production switches, compare the new catalog against published data by permanent id. Every existing mod id must survive, except ids that become Collection pages.

### Out of scope

- New Nexus extraction. No Nexus mods appear in the current output, so there is no production data to validate it against. Existing Nexus results remain rules listings.
- Discord message text in the bundle.
- Discord-only mods in the release feed.
- Assigning releases to individual mods on a shared topic. Release tracking remains per forum topic.

## Capabilities

### New Capabilities

- `mod-catalog`: source listings, rules/LLM combination, Collections, one merge, fact precedence, permanent ids, v2 catalog output and the migration comparison.

### Modified Capabilities

- `qb-forum-scraping`: retain every mod index line for each topic.
- `qb-llm-post-extraction`: extract Discord threads, cache them separately and include them in coverage counts.
- `modrepo-jobs`: save Discord opening runs, read forum listings from QB, write the v2 catalog and merge after listing changes.
- `qb-bundle-publishing`: write the v2 bundle with Discord results; freeze the old bundle.
- `output-publishing`: publish both v2 files and preserve the frozen files. Archive `starmodder-4-public-site` first: its publishing requirement defines the site files this delta retains.

## Impact

| Area | Changes |
| --- | --- |
| Forum scraping | Remove `lib/bot/scraper/forum_scraper.dart`, `forum_cache.json`, `modrepo_forums_enabled` and the forum page-count keys. Extend `qb/mod_index_scraper.dart` and `models/mod_summary.dart` with index lines. |
| Discord scraping | `lib/bot/scraper/discord_reader.dart` saves opening runs in `discord-posts.json`, keyed by thread id. The site stops writing that file. |
| LLM extraction | Adapt `post_extractor.dart`, `extraction_store.dart` and `prompt.dart` to source posts of either kind. Add Discord coverage in `scraper_service.dart`. |
| Catalog | Add listing and source post models, the listing combination step and `bin/link_mod_ids.dart`. Adapt `mod_merger.dart` and `modrepo_service.dart` to listings. Move `ModIdStore` into the merge. |
| Site | `public_data_builder.dart` and `public_site_step.dart` read v2 files and source references. Remove their matching code; add Collection pages. |
| Viewer | Read v2 files in the ModRepo, Bundle and comparison views. Show listing origins in merge debug and each source post's LLM result on the mod page. |
| Publishing | Update `publish_service.dart`, `bundle_publisher.dart` and `tool/update-mod-repo.sh` to use v2 filenames. The script currently requires and names the old files; leaving it unchanged would prevent publication. |
| TriOS | A separate TriOS change reads v2 files and removes `withSynthesizedAddonEntries` and `_isTheCatalogEntry`. |

`public-site-data` and `public-site-pages` exist only in unarchived changes. Their thread-only mod rules are superseded in this design rather than through spec deltas.

`mod-ids.json` gains source post references. The first Discord coverage pass adds roughly 620 cached answers and live calls. Adding Discord does not invalidate forum answers. The separate forum prompt-version-23 pass is already re-reading topics; finish that pass and the first Discord pass before comparison, or use a frozen copy.
