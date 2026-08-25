## 1. The field saying which thread a mod is part of

- [x] 1.1 Add `partOfThreadTitle` to `PublicMod` in `lib/site/models/public_mod.dart`, nullable, left out when null
- [x] 1.2 Add the same field to `PublicModDetail` in `lib/site/models/public_mod_detail.dart`
- [x] 1.3 Run `dart run build_runner build --delete-conflicting-outputs` and check both `*.mapper.dart` files changed
- [x] 1.4 Add the field to the matching examples in `site/sample-data/mods.json` and `site/sample-data/mods/*.json`, and make `test/site/sample_data_test.dart` pass

## 2. Building the thread-only mods

- [x] 2.1 In `lib/site/public_data_builder.dart`, add a step that runs before the `joined` loop: walk the mods being published, and for each one's thread take its `llm.mods`, keeping only those with role `main` — a thread no published mod points at is never walked (the bundle holds old threads ModRepo has never heard of, and this is what keeps them out)
- [x] 2.2 Drop any whose name does not appear in the thread's post text (the same grounding `_groundNeeds` does for "what a mod needs"), or that the LLM tied no download to; log the ones dropped for a missing download
- [x] 2.3 Drop any that a published mod on that same thread accounts for, matched TriOS's `modNamesMatch` way: cleaned names first (`ModIdStore.cleanName`), then letters-and-numbers-only as a fallback — `cleanName` keeps punctuation, and a missed match here mints a permanent id for a duplicate page
- [x] 2.4 Skip threads whose LLM list holds one `main` mod: that entry is the merged mod whatever either is called (TriOS's single-main rule), so there is nothing extra to publish
- [x] 2.5 Build a stand-in `ScrapedMod` for each survivor: the LLM's name, the thread's author, the thread's forum URL as `ModUrlType.Forum`, `sources: [ModSource.ModdingSubforum]`, no summary and no description; its game version is the thread's, falling back to the sibling merged mod's, so Browse's game-version filter does not hide it (TriOS's fallback, for the same reason)
- [x] 2.6 Add the stand-ins to the mods the builder walks, and log each one on the run that first publishes it, with its name and topic
- [x] 2.7 Mark each `_JoinedMod` as merged or stand-in — the release rule in section 6 needs to tell them apart
- [x] 2.8 Keep the stand-ins out of `ModRepo.json` — they exist only inside the builder

## 3. Ids and marks

- [x] 3.1 Check `markFor` gives a stand-in `topic:<id>`, so two mods of the same cleaned name on different threads keep separate ids
- [x] 3.2 Test: SirHartley's `Lost.Sector` (topic 34161) and Kissa_Mies's `LOST_SECTOR` (topic 27556) are published as two mods with two ids, and neither takes the other's address
- [x] 3.3 Test: a second run over the same bundle gives every thread-only mod the id it had before
- [x] 3.4 Use the thread's post date for `addedOn` where there is one, so thread-only mods do not all land at the top of "recently added" on the run they arrive
- [x] 3.5 Note in a comment that a stand-in slipping past the name match but landing on a merged mod's id (same cleaned name, same `topic:` mark) is caught by the existing `takenIds` guard and its warning — a safety net, not a bug to fix

## 4. What a shared thread's pages say

- [x] 4.1 In `_detailRecord`, when a thread holds more than one `main` mod, do not use the post as any of those mods' description
- [x] 4.2 Fall back down the existing chain instead: the mod's own merged text first (a Discord-posted mod's announcement is the author's own words about that mod), then that mod's LLM paragraph with `descriptionIsGenerated: true`; where there is neither, publish no description
- [x] 4.3 Fill `partOfThreadTitle` from the thread's title on thread-only mods only — never on a merged mod, matching TriOS's meaning for the field
- [x] 4.4 Leave a single-mod thread exactly as it is — test that a normal mod's description is still the author's post
- [x] 4.5 Rewrite `_mainLlmMod`'s fallbacks as TriOS's `_isTheCatalogEntry` rules: a name match (cleaned, then letters-and-numbers) wins; a thread with exactly one `main` entry gives it to the merged mod whatever the names look like; on a multi-main thread with no match, return nothing — never "the first `main`", which puts a sibling's downloads and changelog on the wrong page
- [x] 4.6 Test: a merged mod on a multi-main thread whose name matches no LLM entry publishes with no LLM facts, and the unmatched entry still becomes its own thread-only mod — the same facts must not appear on two pages
- [x] 4.7 In `_addonsFor`, scope add-ons on a shared thread: an addon whose `requires` names one of the thread's `main` mods is listed only on that mod's page; one that names nothing, or nothing that matches, stays on every `main` mod's page
- [x] 4.8 Check `site/views/mod.js` with AI writing set to "Never": a shared-thread mod whose only text is the AI paragraph should say it has no description, not show a blank

## 5. Sources

- [x] 5.1 Give `_sourcesFor` the thread, and add `forum` to a published mod's sources whenever its thread was scraped and read, whatever the merge said
- [x] 5.2 Test: a mod merged from Discord alone whose thread is in the bundle comes out with both `discord` and `forum`
- [x] 5.3 Check `isDiscordOnly` in `site/lib.js` needs no change — the badge is already gone for mods with a forum link via the `forumUrl` guard, which stays because it also covers a mod whose thread was never scraped; this section is about the published data agreeing with it

## 6. Releases

- [x] 6.1 In `_releasesByMod`, give a thread's releases to the merged mod only when the thread's LLM list holds one `main` entry or none; a thread holding several `main` mods gives them to no mod — today's map keys one mod per topic and the last one silently wins, which is an existing bug this fixes
- [x] 6.2 Test: a thread with several `main` mods contributes nothing to `updates.json` or `updates.xml`, even when only one of them is merged
- [x] 6.3 Test: a single-mod thread's releases are unchanged

## 7. The site

- [x] 7.1 Show `partOfThreadTitle` on the mod page as a line saying which thread the mod is part of, linked to the thread (`site/views/mod.js`)
- [x] 7.2 Decided: the page only, not a card or a browse row. The line explains why the forum thread a mod links is not about it alone, and a card links no thread — so on a card there is nothing for it to explain, and it would cost a line on every card for the one mod in nine hundred that carries it.
- [x] 7.3 Check the download button on a thread-only mod's card shows the right label, since its download comes from the LLM

## 8. Checks over real data

- [x] 8.1 Run the builder over the current `outputs/` and count how many thread-only mods it publishes
- [x] 8.2 Check `outputs/site/mods.json` is still under 2 MB and the pinning test passes
- [x] 8.3 Check `useful-tithes-1-0-a` no longer opens with the other three mods' text, and shows its own Discord announcement as its description
- [x] 8.4 Check Lost.Sector by SirHartley has a page, with its own download, and is told apart from `LOST_SECTOR`
- [x] 8.5 Read the run's log of newly published thread-only mods and check none is something the LLM invented, and read the dropped-for-no-download lines for real mods the LLM missed
- [x] 8.6 `dart test`, and check the whole site by hand with `dart run bin/site_server.dart`

## 9. Loose ends

- [x] 9.1 Update the "The public website" section of `CLAUDE.md` to say a thread can produce several mods, and how they are told apart
- [x] 9.2 Drafted in `trios-issue.md` beside this file, not filed — posting it to the TriOS repo is yours to do. Write up the TriOS defect as an issue over there, from the design's "What TriOS gets wrong" section: the raw-keyed `existingNames` set plus `_isTheCatalogEntry` only comparing the entry the thread was reached through, giving order-dependent duplicate cards on topic 34161; mention the two-Lost.Sectors divergence too
- [x] 9.3 When archiving: `starmodder-4-public-site` must be archived first (it defines the capability), and this change's MODIFIED description requirement will need hand-applying with `--skip-specs` — `openspec archive` fails on MODIFIED deltas
