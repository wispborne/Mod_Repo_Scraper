## Why

We currently work out which mods exist in three different places. The scraper merges the forum, Discord and Nexus results into `ModRepo.json`. Then the website reads the LLM's answers and adds mods that the merge missed. TriOS does much the same thing again. Each has its own code for matching names, so they don't always agree.

A forum topic can describe several mods, and that's where this gets especially awkward. The merge treats the topic as one mod. The website and TriOS then have to work out which individual mods the author actually posted and which downloads belong to each one. We should do that once and give both apps the answer.

We also scrape the forum twice. The older scraper skips titles without a game version in brackets, which is why it missed all seven of Computica's forks. QB already has that topic saved. Meanwhile, the LLM never reads Discord announcements. The 199 mods we currently know only from Discord get none of the extra information it could find: requirements, whether an existing save will still work, support links, licenses, other names, summaries or additional downloads.

This change brings those pieces together. Read each post, work out which mods it describes, and then merge those mods across the forum and Discord. The website and TriOS can use the finished catalog instead of each trying to complete it themselves.

## What Changes

### Work out what's in each post before merging

We'll use **listing** to mean one mod as described in one place. A mod's forum topic gives us one listing, and its Discord announcement gives us another. If a topic contains four mods, it can give us four listings. The merge's job is to join listings that describe the same mod.

The scraper's existing rules still give us one listing for each post. We'll call that the rules listing. When the LLM has read the post too, we combine the two answers:

- If the LLM finds no main mod we can verify, keep the listing from the rules.
- If it finds one, use its information for that listing, even if it used a different name.
- If it finds several, make a listing for each. The rules listing joins the mod whose name matches. If none matches, the post is a **Collection**: its title names the group, and we keep the individual mods instead of treating that title as another mod.

To count, an LLM mod must have its name in the author's opening run and a download tied to it. The opening run is the first post and any posts straight after it by the same author, before anyone else replies. The design explains the matching rules in full. The shared terms are in `CONTEXT.md`.

Turning the LLM off still leaves a complete catalog from the rules. Outside the Collection case, the LLM can't rename a rules listing, drop it, or merge it into a different mod.

There is then one merge. The website no longer needs to invent missing mods or guess which LLM answer belongs to a mod. It still checks that an LLM display name agrees with the post's title. Any job that changes the listings finishes with a merge and a site build.

### Read Discord as well as the forum

QB will be our only forum scraper. It will save all the mod index lines for each topic, including the names, authors, game versions and categories. We can then delete the older `ForumScraper`.

The Discord scraper will save the author's announcement and the messages they post straight after it, stopping when someone else replies. The LLM will read those messages through the same extractor and system prompt used for the forum. The checks against the author's text, the limit on new LLM calls and the limit on calls running at once will apply to both sources.

If both a forum topic and a Discord thread describe a mod, use the forum's answer first. Discord fills in anything the forum answer leaves blank. The version is the exception: use whichever version is higher.

### Keep the existing addresses

A better mod name shouldn't break a link to its page. We'll move permanent-id assignment into the merge and remember which posts belong to each id. The merge will look for an existing id through those posts before trying the mod's name.

Before switching over, a one-time command will fill in those links for the ids we already have. If an existing page turns out to be a Collection, it keeps its address and becomes a page linking to the mods in that Collection.

We'll compare the new catalog with the published site before using it in production. Every existing id must still lead to its mod or, where expected, to a Collection page.

### Give the new data its own filenames

`mod-catalog.json` will contain the mods, their permanent ids and the exact posts they came from. `mod-catalog-details.json` will contain the forum data we publish today, plus the LLM's answers for Discord threads. It won't include Discord message text. The site and updated TriOS will use each mod's saved post references to look up its details.

We'll stop updating `ModRepo.json` and `forum-data-bundle.json`. Old TriOS installs will still be able to read them, but their catalog will stay as it was on the day of the switch. A separate TriOS update will read the new files.

### Leave Nexus extraction and release tracking for later

Existing Nexus results will still produce listings from the rules. There are no Nexus mods in the current output, so we don't have data to test LLM extraction for it yet.

Releases will still be tracked by forum topic. This change won't put Discord-only mods in the release feed or decide which mod a release belongs to when several share a topic. It also won't publish Discord message text in the bundle.

## Capabilities

### New Capabilities

- `mod-catalog`: how we turn posts into listings, combine the rules with LLM answers, recognise Collections, merge the listings, choose facts, keep permanent ids, and compare the catalog file before switching.

### Modified Capabilities

- `qb-forum-scraping`: save the mod index lines for each topic.
- `qb-llm-post-extraction`: read saved Discord threads, cache their answers under separate keys, and include them in the coverage report.
- `modrepo-jobs`: save Discord opening messages, take forum listings from QB, write the catalog file, and merge after jobs that change listings.
- `qb-bundle-publishing`: write the mod details file with Discord answers and stop updating the old bundle.
- `output-publishing`: publish the new files and leave the old files alone. Archive `starmodder-4-public-site` first, since its publishing requirement lists the site files this change must keep publishing.

## Impact

The main code changes are:

- Remove `lib/bot/scraper/forum_scraper.dart`, `forum_cache.json`, `modrepo_forums_enabled` and the forum page-count settings. Save index lines in `qb/mod_index_scraper.dart` and `models/mod_summary.dart` instead.
- Have `lib/bot/scraper/discord_reader.dart` write the author's opening messages to `discord-posts.json`, using thread ids as keys.
- Update `post_extractor.dart`, `extraction_store.dart` and `prompt.dart` so the same code can read forum and Discord posts. Include Discord in `scraper_service.dart`'s coverage pass.
- Add the source post and listing models, the code that combines a post's listings, and `bin/link_mod_ids.dart`. Update `mod_merger.dart` and `modrepo_service.dart` to use listings, and move `ModIdStore` into the merge.
- Have `public_data_builder.dart` and `public_site_step.dart` read the new files and their ids. Remove `_threadOnlyMods`, `_mainLlmMod` and topic-id guessing. Stop the site from writing `discord-posts.json`, and build pages for Collections that already have ids.
- Update the viewer's ModRepo, Bundle and comparison pages. Merge debug should show where each listing came from, and a mod's page should show its source posts and their LLM answers, including Discord.
- Update `publish_service.dart`, `bundle_publisher.dart` and `tool/update-mod-repo.sh`. The script must check for the new files and name them in its commit message. If it keeps checking for the old filenames, it won't publish the new run.
- In the TriOS repo, switch to the new files and remove `withSynthesizedAddonEntries` and `_isTheCatalogEntry`.

The `public-site-data` and `public-site-pages` specs only exist in unarchived changes. This design replaces their rules about adding thread-only mods; there are no archived specs to write deltas against yet.

`mod-ids.json` will gain the post references for each id. The first Discord pass will take about 620 live LLM calls, with the answers saved in the existing cache. Adding Discord won't make the LLM reread forum topics. There is already a separate forum pass running for prompt version 23, though. Finish that and the first Discord pass before comparing the catalogs, or use a frozen copy of the data.
