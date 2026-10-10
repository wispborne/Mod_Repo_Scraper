## Why

The same mod is worked out three times. `mod_merger.dart` merges the forum, Discord and Nexus into `ModRepo.json`. The site builder then matches that file against the forum data bundle by name to find mods the merge missed. TriOS does the same matching a third time. Each copy guesses which LLM mod on a forum topic belongs to which merged mod, and each guesses slightly differently. There are also two forum scrapers. The old one drops every topic without a bracketed game version, which is how all seven of Computica's forks went missing.

## What Changes

- Every source post becomes zero or more **listings**. A forum topic gives one listing from fixed rules, and the LLM can turn it into several (see `CONTEXT.md` for the terms).
- The forum's listings come from the QB store. **`ForumScraper` is deleted.** The QB store keeps every mod index line for a topic (name, author, game version, category), not just the category.
- The LLM still reads each source post once, before the merge. Its grounded main mods become listings and go into the same single merge as everything else. The site builder's own matching (`_threadOnlyMods`, `_mainLlmMod`, the topic-id guessing) is removed.
- On one topic, the rules listing and the LLM's listings combine by a fixed rule. A topic with two or more LLM main mods and no name match becomes a **Collection**, and its rules listing is dropped.
- With the LLM off, the rules still give a full catalog. The LLM can add mods and demote a rules listing to a Collection. It can never silently delete or rename one.
- The merge assigns **permanent ids**. It finds a mod's id by its source posts first and by name only for mods it has never seen. A one-time step records which source posts each current id covers. A Collection whose name already had an id keeps it and gets a page listing the mods it holds.
- New output **`ModRepo-v2.json`**: one record per mod, with its permanent id and exact links to its source posts.
- New output **`forum-data-bundle-v2.json`**: the forum source posts, read by the site and new TriOS by topic id.
- **BREAKING (for nobody already installed):** `ModRepo.json` and `forum-data-bundle.json` are **frozen**. Nothing writes them again. Old TriOS copies keep the catalog as it was on the day of the switch. New TriOS reads the v2 files.
- The merge runs at the end of every job that changes listings, and the site is built straight after it.
- Before the switch, a one-time comparison by permanent id on copied data must show every existing id surviving, apart from the expected Collections.

Out of scope: Discord threads holding several mods (Discord still gives one listing per thread), changes to Nexus, publishing Discord text, and giving releases on a shared topic to the right mod. Release tracking stays per forum topic.

## Capabilities

### New Capabilities
- `mod-catalog`: listings, how a topic's rules and LLM listings combine, Collections, the single merge, permanent ids by source post, `ModRepo-v2.json`, and the switch-over comparison.

### Modified Capabilities
- `qb-forum-scraping`: the mod index scraper keeps every line for a topic (name, author, game version, category), not only the category.
- `modrepo-jobs`: the merge reads forum listings from the QB store instead of a forum scrape, writes `ModRepo-v2.json` instead of `ModRepo.json`, and runs after every job that changes listings.
- `qb-bundle-publishing`: the bundle is written as `forum-data-bundle-v2.json`; `forum-data-bundle.json` is no longer written.
- `output-publishing`: a publish copies the two v2 files and leaves the frozen files in the target repo untouched.

## Impact

- **Removed:** `lib/bot/scraper/forum_scraper.dart`, `forum_cache.json`, the `modrepo_forums_enabled` key and the forum page-count keys; the matching code in `lib/site/public_data_builder.dart`.
- **Changed:** `lib/bot/scraper/qb/mod_index_scraper.dart` and `models/mod_summary.dart` (index lines), `lib/bot/scraper/mod_merger.dart` (takes listings), `lib/manager/modrepo_service.dart` and `scraper_service.dart` (merge after every listing change), `lib/site/mod_id_store.dart` (lookup by source post, owned by the merge), `lib/site/public_data_builder.dart` and `public_site_step.dart` (read the v2 files), `lib/manager/publish_service.dart`, `bundle_publisher.dart`.
- **New:** a listing model, the topic listing rule, the Collection page, a one-time id-to-source-post step, and a one-time comparison command.
- **Viewer:** the ModRepo and Bundle views and both diff pages read the v2 files. Merge debug shows where each listing came from.
- **Site specs:** `public-site-data` and `public-site-pages` live only in unarchived changes, so the rules they state for thread-only mods are replaced in this change's design rather than as deltas.
- **TriOS:** a separate change in the TriOS repo makes it read the two v2 files and drop `withSynthesizedAddonEntries` and `_isTheCatalogEntry`.
- **Data:** `mod-ids.json` gains source post links per id. The LLM prompt is at version 18, so every topic is being read again; the comparison must run after that pass, or on a frozen copy.
