## 1. Store mod index lines in QB

- [ ] 1.1 Add `QbIndexLine` (name, author, game version, category) and `QbModSummary.indexLines`. Regenerate mappers.
- [ ] 1.2 Retain each topic's lines in mod index order and use the first line's category. Deduplicate lines with the same name and category; retain the same name under different categories. Prefer the current index; use archived indexes only for topics absent from it. Preserve `ForumScraper.parseModIndex`'s current behavior.
- [ ] 1.3 Test topics 21968 (three lines), 29877 (one line), repeats under different categories, and 29674 (TriOS: current "[-]" takes precedence over archived "[0.97a]").
- [ ] 1.4 Check the summary shape in the bundle, viewer working bundle, `site/sample-data` and `test/site/sample_data_test.dart`.

## 2. Save Discord opening runs

- [ ] 2.1 Add `SourcePost`: kind, id, title, author, link and opening posts with HTML, links, images and dates. Regenerate mappers.
- [ ] 2.2 Collect each Discord thread's opening run: first message with text, then consecutive messages by the same author; stop at another author or ten messages. Save source posts by thread id in `discord-posts.json` alongside `discord_cache.json`, only after a successful scrape.
- [ ] 2.3 Remove the `discord-posts.json` write from `PublicSiteStep.afterMerge`. Have the site panel read the first message by thread id, while supporting the old URL-keyed format until it is replaced.
- [ ] 2.4 Test three author messages before a reply, a reply cutting the run short, a standalone message, and a failed scrape preserving the file.

## 3. Extract forum and Discord source posts

- [ ] 3.1 Make `PostExtractor` accept `SourcePost`. Adapt `QbModDetail` without changing the forum prompt; test the prompt text before and after.
- [ ] 3.2 Adapt Discord messages through `discordMarkdownAsHtml` and `cleanPostHtml`. Extract links from the HTML, include image attachments and use the thread name as the title.
- [ ] 3.3 Cache Discord results under `discord:<thread id>` in `llm-extraction-cache.json`; preserve forum keys. Add `ExtractionPrompt.discordPromptVersion` and the Discord user-prompt header.
- [ ] 3.4 Apply grounding and download host rules to Discord opening runs. Cache download results under `discord:<thread id>`.
- [ ] 3.5 Include Discord in `_llmCoveragePass`. Share `llm_max_topics` and `llm_max_concurrent_calls`; report forum and Discord counts separately.
- [ ] 3.6 Add saved Discord cases to `test/llm_live/`: one mod, changelog in later messages, and two mods if a real example exists. Update the README.
- [ ] 3.7 Link the viewer's ModRepo mod page to each Discord thread's LLM result.

## 4. Build listings

- [ ] 4.1 Add `SourcePostRef` (kind, id, optional LLM mod name) and a listing containing `ScrapedMod`, its ref and its origin (`rules` or `llm`).
- [ ] 4.2 Build forum rules listings from mod index lines or cleaned topic titles. Set the source to `Index` or `ModdingSubforum`.
- [ ] 4.3 Implement `SourcePostListings` for forum and Discord. Apply the zero/one/several-main-mod rule using grounding and `modNamesMatch` over names and nicknames. Attach add-ons and variants to their main mod, discard `separate` results, and retain the forum link on Discord LLM listings.
- [ ] 4.4 Test with the LLM on and off: 34161 (Collection), 34457 (Collection with an id), 35651 (forks without a bracketed version), 21968 (index names, library and add-ons), 9035 (one main mod with a different name), a plain single-mod topic, and one- and two-mod Discord threads.
- [ ] 4.5 Wrap existing Nexus results as listings with source refs; preserve their fields.

## 5. Merge all listings once

- [ ] 5.1 Make `ModMerger` accept listings and retain their refs on each mod.
- [ ] 5.2 Replace `forum_cache.json` with QB topics retained by `keepThreadInBundle`. Read Discord LLM listings from the extraction store and `discord-posts.json`.
- [ ] 5.3 Apply fact precedence: forum first, Discord fills empty fields, downloads selected as one field, highest mod version, newer post first within a source kind.
- [ ] 5.4 Record each listing's source post and rules/LLM origin in merge debug. Show them in the viewer's Merge view.
- [ ] 5.5 Finish `fullRun`, `rescrapeTopics`, `extractLlm`, `llmCoveragePass` and `rebuildBundle` with a merge and site build.
- [ ] 5.6 Test that LLM-off output retains one rules listing per kept topic and Discord thread. Check that each Hartley Discord thread joins its own mod.

## 6. Preserve permanent ids

- [ ] 6.1 Add source refs to `mod-ids.json`; continue reading older entries without them.
- [ ] 6.2 Look up ids by ref before name. If refs point to different ids, keep the older id and log the conflict.
- [ ] 6.3 Move id assignment from `PublicDataBuilder` into the merge.
- [ ] 6.4 Add `bin/link_mod_ids.dart` to populate refs from `outputs/site/mods/<id>.json`. For topics with several main mods, include the LLM name selected by today's `_mainLlmMod`. Test repeatability and distinct refs for topic 34161's mods.
- [ ] 6.5 Test id preservation after a mod rename, topic rename and Discord-only mod's first LLM name. Check that ids are never reassigned and unreadable `mod-ids.json` fails the run.

## 7. Write v2 outputs

- [ ] 7.0 Archive `starmodder-4-public-site` before applying this change's `output-publishing` delta, which relies on its site-file requirement.
- [ ] 7.1 Add the v2 catalog model: permanent id, existing catalog fields and source refs. Write `ModRepo-v2.json` from the merge; cancellation writes nothing.
- [ ] 7.2 Write `forum-data-bundle-v2.json` locally and in the clone. Include `discordThreads` results without message text.
- [ ] 7.3 Make `publishOutputs` copy v2 files and preserve `ModRepo.json` and `forum-data-bundle.json`.
- [ ] 7.4 Test that outputs contain no config values, tokens, local paths, run ids, confidence scores or Discord message text.

## 8. Read v2 outputs in the site

- [ ] 8.1 Switch `PublicSiteStep` and `PublicDataBuilder` to v2 files. Read permanent ids from the catalog.
- [ ] 8.2 Retrieve facts by source refs (topic/thread id and LLM mod name). Remove `_threadOnlyMods`, `_mainLlmMod` and topic-id guessing, including their uses in `_releasesByMod` and `_shownNameFor`. Read display names from LLM listings while retaining the title-agreement check.
- [ ] 8.3 Publish pages for Collections with existing ids. Use the same HTML-head replacement as mod pages.
- [ ] 8.4 Update sample data and its test, including a Discord-only mod with LLM facts. Verify that release detection still reads forum topics.

## 9. Update the viewer

- [ ] 9.1 Switch ModRepo, Bundle, both comparison pages and topic history to v2 files.
- [ ] 9.2 Show each mod's source posts, linking to its forum topic or Discord LLM result.

## 10. Compare before switching

- [ ] 10.1 Add `bin/compare_catalog.dart`. Run the new pipeline on copied data and compare by published permanent id. Report lost ids, changed source refs, new Collections, Discord threads producing several listings and new mods.
- [ ] 10.2 Finish the forum version-23 coverage pass and first Discord LLM coverage pass, or freeze a copy. Compare and fix differences until no existing mod id is lost, except ids becoming Collection pages.
- [ ] 10.3 Review every new Collection and Discord thread producing several listings. Sample new mods and Discord-only facts; assess whether the first index line chooses worse names than today.

## 11. Switch production and remove old code

- [ ] 11.1 Remove `forum_scraper.dart`, the ModRepo service's forum source, `modrepo_forums_enabled` and forum page-count keys. Update `config.example.properties` and `Common._recognizedKeys`.
- [ ] 11.2 Stop writing `ModRepo.json` and `forum-data-bundle.json`.
- [ ] 11.3 Update `tool/update-mod-repo.sh` to check for `outputs/ModRepo-v2.json` and `outputs/forum-data-bundle-v2.json` before publishing and name both files in its commit message.
- [ ] 11.4 Update CLAUDE.md and AGENTS.md for the unified pipeline, Discord extraction, several mods per topic, caches and outputs.
- [ ] 11.5 Back up production `mod-ids.json`, run `bin/link_mod_ids.dart` on production `qb_data`, then run the new pipeline.
- [ ] 11.6 Open a separate TriOS change to read both v2 files, including `discordThreads`, and remove `withSynthesizedAddonEntries` and `_isTheCatalogEntry`.
