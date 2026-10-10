## 1. Mod index lines in the QB store

- [ ] 1.1 Add a `QbIndexLine` model (name, author, game version, category) and a `indexLines` list on `QbModSummary`; regenerate mappers
- [ ] 1.2 Make `mod_index_scraper.dart` keep every line per topic in index order, dropping exact repeats, and keep the topic's category as its first line's
- [ ] 1.3 Test: topic 21968's three lines, topic 29877's one line, and repeated lines under two categories
- [ ] 1.4 Check the bundle, the viewer's working bundle, `site/sample-data` and `test/site/sample_data_test.dart` still agree on the summary shape

## 2. Listings

- [ ] 2.1 Add `SourcePostRef` (kind, id, optional LLM mod name) and a listing type (a `ScrapedMod` plus its ref and whether rules or the LLM found it)
- [ ] 2.2 Write the forum listing step: rules listing from index lines or the cleaned title, with `Index` / `ModdingSubforum` as its source
- [ ] 2.3 Add the combine rule (no main mods / one / two or more, with `modNamesMatch` and grounding), attaching add-ons and variants to their main mod and dropping `separate`
- [ ] 2.4 Fixture tests for topics 34161 (Collection), 35651 (forks, no bracketed version), 21968 (index lines plus library and add-ons), 9035 (one main mod, different name) and one single-mod topic, each with the LLM on and off
- [ ] 2.5 Make Discord and Nexus results into listings with their refs, unchanged otherwise

## 3. One merge over listings

- [ ] 3.1 Give `ModMerger` listings instead of source lists; keep each listing's ref on the merged mod
- [ ] 3.2 Make the merge read forum listings from the QB store (every topic `keepThreadInBundle` keeps) instead of `forum_cache.json`
- [ ] 3.3 Record each listing's source post and whether rules or the LLM found it in merge debug, and show it in the viewer's Merge view
- [ ] 3.4 Run the merge, then the site build, at the end of `fullRun`, `rescrapeTopics`, `extractLlm`, `llmCoveragePass` and `rebuildBundle`
- [ ] 3.5 Test: with the LLM off, every kept topic gives exactly one mod's worth of forum listing and nothing is lost compared with the rules alone

## 4. Permanent ids by source post

- [ ] 4.1 Add source post refs to each `mod-ids.json` entry, reading old entries that have none
- [ ] 4.2 Look ids up by ref first, then by name; log a clash when one mod's refs point at two ids and keep the older
- [ ] 4.3 Move id assignment from `PublicDataBuilder` into the merge
- [ ] 4.4 Write `bin/link_mod_ids.dart` that fills in refs for every existing id from `outputs/site/mods/<id>.json`; test that running it twice gives the same file
- [ ] 4.5 Test: a renamed mod and a re-titled topic keep their ids; a used id is never handed to another mod; an unreadable `mod-ids.json` fails the run

## 5. New output files

- [ ] 5.1 Add the `ModRepo-v2.json` model (id, today's `ModRepo.json` fields, source post refs) and write it from the merge; a cancelled merge writes nothing
- [ ] 5.2 Write the bundle as `forum-data-bundle-v2.json`, locally and in the clone
- [ ] 5.3 Make `publishOutputs` copy the two v2 files and leave `ModRepo.json` and `forum-data-bundle.json` untouched
- [ ] 5.4 Test that no output carries a config value, token, local path, run id or confidence score

## 6. The site reads the new files

- [ ] 6.1 Point `PublicSiteStep` and `PublicDataBuilder` at the v2 files, reading ids from `ModRepo-v2.json`
- [ ] 6.2 Look up each mod's forum facts by its refs (topic id and LLM mod name); remove `_threadOnlyMods`, `_mainLlmMod` and the topic-id guessing, including the call in `_releasesByMod`
- [ ] 6.3 Publish a Collection page at the address of any Collection that already had an id, built with the `index.html` head swap
- [ ] 6.4 Update `site/sample-data` and its test for the new shapes; check the release detector still reads topics as before

## 7. Viewer

- [ ] 7.1 Make the ModRepo and Bundle views, both diff pages and the topic history read the v2 files
- [ ] 7.2 Show a mod's source posts on the viewer's ModRepo mod page, each linking to its topic page

## 8. Switch-over comparison

- [ ] 8.1 Write `bin/compare_catalog.dart`: run the new pipeline on a copy of the data and compare with the published site by id, listing ids lost, ids whose source posts changed, new Collections and new mods
- [ ] 8.2 Wait for the version-18 LLM pass to finish (or freeze a copy), then run the comparison and fix until no existing id is lost other than the expected Collections
- [ ] 8.3 Check by hand: every new Collection, a sample of new mods, how often the first index line gave a worse name than today, and any Discord thread that links to a Collection topic

## 9. Switch and clean up

- [ ] 9.1 Delete `forum_scraper.dart`, the forum source from `ModRepoService`, `modrepo_forums_enabled` and the forum page-count keys; update `config.example.properties` and `Common._recognizedKeys`
- [ ] 9.2 Stop writing `ModRepo.json` and `forum-data-bundle.json`
- [ ] 9.3 Update CLAUDE.md and AGENTS.md: the pipeline section, the site's "A thread can be several mods" section, the caching section and the outputs
- [ ] 9.4 Run `bin/link_mod_ids.dart` on production `qb_data` (after a backup of `mod-ids.json`), then the first real run
- [ ] 9.5 Open a TriOS change: read `ModRepo-v2.json` and `forum-data-bundle-v2.json`, drop `withSynthesizedAddonEntries` and `_isTheCatalogEntry`
