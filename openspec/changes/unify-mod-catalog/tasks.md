# Tasks

Work through these before switching production. Use a copy of the real data for the comparison in section 10, and keep the old pipeline running until every existing mod id is accounted for.

## 1. Keep the mod index information in QB

- [x] 1.1 Add `QbIndexLine` with the mod's name, author, game version and category. Add an `indexLines` list to `QbModSummary`, then regenerate the mappers.
- [x] 1.2 Keep each topic's lines in the order they appear in the mod index. Use the first line's category for the topic. Drop repeated lines with the same name and category, but keep a name that appears under different categories. Use the current index when it lists the topic; only fall back to old index posts when it doesn't. This is the rule `ForumScraper.parseModIndex` already uses.
- [x] 1.3 Test topic 21968's three lines, topic 29877's single line, and repeated names under different categories. For topic 29674, check that TriOS gets the current "[-]" instead of the old "[0.97a]".
- [x] 1.4 Check that the bundle, the viewer's working bundle, `site/sample-data` and `test/site/sample_data_test.dart` all handle the updated summary format.

## 2. Save the author's Discord messages

- [x] 2.1 Add `SourcePost` with the source kind, id, title, author, link and opening posts. Each post needs HTML, links, images and a date. Regenerate the mappers.
- [x] 2.2 In `discord_reader.dart`, start at the first message with text and keep the messages straight after it by the same author. Stop at someone else's message or after ten messages. Save each thread in `discord-posts.json` under its thread id, alongside `discord_cache.json`, only when the scrape succeeds.
- [x] 2.3 Stop `PublicSiteStep.afterMerge` from writing `discord-posts.json`. Have the site's Discord panel find the first message by thread id. Keep it able to read the old format, where each URL points to one string, until a scrape replaces that file.
- [x] 2.4 Test three messages by the author before a reply, a reply that cuts the author's messages short, and a message that isn't in a thread. Check that a failed scrape leaves the saved file alone.

## 3. Have the LLM read Discord too

- [x] 3.1 Change `PostExtractor` to take a `SourcePost`. Build that from `QbModDetail` for forum topics. Add a test that compares the whole forum prompt before and after, so we know it hasn't changed.
- [x] 3.2 Turn Discord markdown into HTML with `discordMarkdownAsHtml`, then `cleanPostHtml`. Take links from the HTML and images from message attachments. Use the thread's name as the title.
- [x] 3.3 Save Discord answers in `llm-extraction-cache.json` under `discord:<thread id>`, leaving forum keys as they are. Add `ExtractionPrompt.discordPromptVersion` and the line in the user prompt that identifies a Discord announcement.
- [x] 3.4 Check the LLM's Discord answers against the author's opening messages. Run downloads through the same host rules as forum downloads and cache the results under `discord:<thread id>`.
- [x] 3.5 Add saved Discord threads to `_llmCoveragePass`. Forum and Discord together must stay within `llm_max_topics` and `llm_max_concurrent_calls`. Report their counts separately.
- [x] 3.6 Add real saved Discord threads to `test/llm_live/`: one announcing a single mod, one with a changelog in later messages, and one with two mods if we can find an example. Update the README to explain those cases.
- [x] 3.7 Let someone viewing a ModRepo mod open the LLM's answer for its Discord thread.

## 4. Work out the listings for each post

- [x] 4.1 Add `SourcePostRef` with kind, id and an optional LLM mod name. An LLM listing must include that name. A listing should hold a `ScrapedMod`, its reference, and whether it came from the rules or the LLM.
- [x] 4.2 Build a forum topic's rules listing from its first mod index line, keeping the other lines' names as other names for the mod. If it isn't in the index, use the cleaned topic title. Set its source to `Index` or `ModdingSubforum` as appropriate.
- [x] 4.3 Write `SourcePostListings` so forum and Discord use the same rule. Count only main mods whose names and downloads we can check against the post.

  If there are none, keep the rules listing. If there's one, combine them. If there are several, join the rules listing to the matching mod or make the post a Collection if none matches. Use `modNamesMatch` for names and verified nicknames.

  Keep add-ons and variants with their main mod, drop `separate` results, and keep the thread's forum link on each Discord LLM listing.

- [x] 4.4 Test the cases below with the LLM on and off:

  | Case | What to check |
  | --- | --- |
  | Topic 34161 | A Collection |
  | Topic 34457 | A Collection that already has an id |
  | Topic 35651 | Several forks with no game version in brackets |
  | Topic 21968 | Several index names, a library and its add-ons |
  | Topic 9035 | One main mod with a different LLM name |
  | A normal one-mod topic | The simple forum case |
  | Discord threads with one and two mods | The same rules work for Discord |

- [x] 4.5 Turn the existing Nexus results into listings with references to their pages. Keep their other fields as they are.

## 5. Merge the listings into the catalog

- [x] 5.1 Have `ModMerger` take listings and keep their source references on the mods it produces.
- [x] 5.2 Read forum listings from the QB topics kept by `keepThreadInBundle`, instead of `forum_cache.json`. Read Discord LLM listings from the LLM store and `discord-posts.json`.
- [x] 5.3 Choose each fact from the forum answer first, then try Discord if that field is empty. For downloads, take the forum LLM list if there is one, otherwise the Discord LLM list, otherwise the Discord rules link. Use the higher mod version. Between two posts of the same kind, try the newer one first.
- [x] 5.4 Record which post each listing came from and whether rules or the LLM found it. Show that information in the viewer's Merge view.
- [x] 5.5 Finish `fullRun`, `rescrapeTopics`, `extractLlm`, `llmCoveragePass` and `rebuildBundle` by running the merge and then building the site.
- [x] 5.6 Test that, with the LLM off, every kept forum topic and Discord thread still gives one rules listing. Also check that each of Hartley's Discord threads joins its own mod on the shared forum topic.

## 6. Keep each mod's existing id

- [x] 6.1 Store source post references in `mod-ids.json`. Continue to read older entries that don't have them yet.
- [x] 6.2 Look for a mod's id through its source posts first. Only use its name when none of those posts has an id. If the posts point to different ids, keep the older id and log the clash.
- [x] 6.3 Move id assignment out of `PublicDataBuilder` and into the merge.
- [x] 6.4 Write `bin/link_mod_ids.dart` to fill in the references from `outputs/site/mods/<id>.json`. For topics with several main mods, save the LLM name chosen by today's `_mainLlmMod`. Test that running it twice gives the same file and that topic 34161's mods get different references.
- [x] 6.5 Check that a mod keeps its id when its name changes, its topic is retitled, or the LLM first gives its Discord announcement a better name. Test that an id is never reused for another mod and that an unreadable `mod-ids.json` fails the run.

## 7. Write the v2 files

- [ ] 7.0 Archive `starmodder-4-public-site` first. Its publishing spec lists the site files that this change's `output-publishing` spec builds on.
- [x] 7.1 Add the `ModRepo-v2.json` model with the permanent id, current catalog fields and source post references. Write it from the merge. A cancelled merge must leave the existing output alone and write no snapshot.
- [x] 7.2 Write `forum-data-bundle-v2.json` locally and in the clone. Include the Discord answers in `discordThreads`, without message text.
- [x] 7.3 Have `publishOutputs` copy the two v2 files and leave `ModRepo.json` and `forum-data-bundle.json` alone.
- [x] 7.4 Check that no published output includes config values, tokens, local paths, run ids, confidence scores or Discord message text.

## 8. Have the site use the new catalog

- [x] 8.1 Point `PublicSiteStep` and `PublicDataBuilder` at the v2 files. Read permanent ids from the catalog.
- [x] 8.2 Look up a mod's facts using its saved topic or thread id and LLM mod name. Remove `_threadOnlyMods`, `_mainLlmMod` and topic-id guessing, including the calls from `_releasesByMod` and `_shownNameFor`. Get the display name from the LLM listing, keeping the check that it agrees with the title.
- [x] 8.3 If a Collection already has an id, publish a page at that address linking to its mods. Use the same HTML-head replacement as the mod pages.
- [x] 8.4 Update the sample data and its test for the new formats. Include a Discord-only mod with LLM facts, and check that release detection still reads forum topics as before.

## 9. Update the viewer

- [x] 9.1 Have the ModRepo view, Bundle view, both comparison pages and topic history read the v2 files.
- [x] 9.2 Show each mod's source posts on its ModRepo page, with links to the forum topic or the LLM's Discord answer.

## 10. Compare with the published site

- [x] 10.1 Write `bin/compare_catalog.dart` to run the new pipeline on a copy of the data and compare mods by permanent id. List missing ids, ids whose posts changed, new Collections, Discord threads with several listings and new mods.
- [ ] 10.2 Wait for the forum version-23 pass and the first Discord LLM pass to finish, or use a frozen copy. Run the comparison and fix differences until no existing mod id is missing, apart from the expected ids that become Collection pages.
- [ ] 10.3 Check every new Collection and every Discord thread with several listings by hand. Look through a sample of new mods and Discord-only mods' LLM answers. Check how often the first mod index line gives a worse name than the current site.

## 11. Switch production over

- [ ] 11.1 Delete `forum_scraper.dart` and remove forum scraping from the ModRepo service. Remove `modrepo_forums_enabled` and the forum page-count keys, including their entries in `config.example.properties` and `Common._recognizedKeys`.
- [ ] 11.2 Stop writing `ModRepo.json` and `forum-data-bundle.json`.
- [ ] 11.3 Make `tool/update-mod-repo.sh` check for `outputs/ModRepo-v2.json` and `outputs/forum-data-bundle-v2.json` before publishing. Change its commit message to name those files too.
- [x] 11.4 Update CLAUDE.md and AGENTS.md to explain the combined pipeline, Discord LLM calls, topics with several mods, caches and new outputs.
- [ ] 11.5 Back up production `mod-ids.json`, run `bin/link_mod_ids.dart` on the real `qb_data`, then run the new pipeline. Keep the backup in case we need to roll back.
- [ ] 11.6 Open a separate TriOS change to read the two v2 files, including `discordThreads`, and remove `withSynthesizedAddonEntries` and `_isTheCatalogEntry`.
