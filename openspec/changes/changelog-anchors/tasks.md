## 1. Shared matching

- [x] 1.1 Move `anchorKey` and its letters-and-numbers pattern out of `lib/site/description_slice.dart` into a small file under `lib/bot/scraper/qb/llm/`, and import it back into `description_slice.dart`. The existing description slice tests still pass unchanged.
- [x] 1.2 Add a key function that also returns, for each kept character, its place in the original text, so a match in the key can be turned back into a cut in the original.

## 2. Cutting a changelog entry

- [x] 2.1 Create `lib/bot/scraper/qb/llm/changelog_slice.dart`. It finds a version as a whole token (no letter or digit on either side; optional "v", "v." or "version " before it; capitals ignored), tries places at the start of a line first, and returns them in order.
- [x] 2.2 For each occurrence of the version, find the first words after it and the last words after those (eight letters-and-numbers minimum). Use the first match with all three in one post.
- [x] 2.3 Cut from the start of the first words to the end of the line holding the last words. Then take out `[link: <url>]` notes, trim line ends, collapse blank-line runs to one, and trim the whole entry.
- [x] 2.4 Return why a cut failed (version, first words or last words not found), so the extractor can log it.
- [x] 2.5 Unit tests in `test/qb/changelog_slice_test.dart`: a plain cut; line breaks kept; the heading line not included; "1.2.1" not matching "1.2.1a"; a version first mentioned inside another version's notes (the topic 9583 case); the same first words repeated under several versions; a `[link: …]` note taken out; punctuation and HTML entities differing between pointer and post; a pointer too short; pointers split across two posts; each kind of failure reported.

## 3. Prompt

- [x] 3.1 In `prompt.dart`, change the answer shape's `changelog.entries` to a list of `{version, text, startsWith, endsWith}`. Change the JSON schema to match, with all four fields required and nullable.
- [x] 3.2 Rewrite the changelog rule. For each of the highest three versions, give the version as the post writes it. Then give the first five or six words of that version's notes and the last five or six words, copied exactly, with the heading left out. Notes of 15 words or fewer go in `text` instead. Keep the existing warning against copying our `[link: …]` notes.
- [x] 3.3 Bump `ExtractionPrompt.promptVersion` by one. Update the number in the `promptVersion` note in `CLAUDE.md` and `AGENTS.md`.

## 3b. Downloads by link number

- [x] 3b.1 In `prompt.dart`, number each line of `=== LINKS IN THE POST ===` by its place in the list (`- [3] <url> "text" [flagged downloadable]`), and give a line in `=== LINKS THE SCRAPER AUTO-DETECTED AS DOWNLOADS ===` the same number when its address is in the list.
- [x] 3b.2 Change each download in the answer shape and the JSON schema to `{link, url, kind}`, with `link` an integer or null and `url` a string or null, all required. Drop `label` from the answer. Rewrite the download rule: give the link's number; copy the address only when the list does not have it.
- [x] 3b.3 In `post_extractor.dart`, read `link` (a number, or a string holding one) and `url`. Keep reading the old `url` and `label` shape.
- [x] 3b.4 In grounding, turn each number into its list item's address and text. Drop and log a number outside the list. Give a copied address the text of the listed link it matches, else an empty label. The existing URL check still runs.
- [x] 3b.5 Extractor tests: a numbered download gets its address and label from the list; a number outside the list is dropped; a copied address not in the list is kept with an empty label; the old shape still parses.
- [x] 3b.6 Regenerate `test/catalog/golden/forum_prompt.txt` (`UPDATE_GOLDEN=1`), and check the diff only shows the numbers.

## 4. Extractor

- [x] 4.1 In `post_extractor.dart`, read the new list shape. Keep reading the old map shape too, so a canned answer in an older test, or a model that ignores the new shape, still parses.
- [x] 4.2 In grounding, replace the "keep anyway" changelog check. A `text` entry is kept only when `_textInPost` finds it. A pointer entry is cut with `changelog_slice.dart` over each opening post's `ReducedPost.text`. A failure drops the entry and logs the topic id, the version and the reason.
- [x] 4.3 Store the result in `changelogEntries` keyed by `plainVersion`, as today. Keep the rule that drops every entry when the answer was truncated.
- [x] 4.4 Count cut, copied and dropped entries over a run, and add one line with the three counts to the coverage pass's summary log.
- [x] 4.5 Update the extractor tests in `test/qb_llm_post_extractor_test.dart`: a pointer entry is cut, a copied short entry is kept, a reworded copy is dropped, unfindable pointers drop only their own entry, and an old-shape answer still parses.

## 5. Live test

- [x] 5.1 Save topic 9583 (Tiandong Heavy Industries) as `test/llm_live/posts/9583.json`, prepared the same way as the other saved posts. It has a long changelog of several versions in a spoiler, and "1.2.1" appears inside the 1.2.1a notes before its own heading.
- [x] 5.2 Add a live test. It checks: entries for 1.2.1a and 1.2.1 come back, each holding words from under its own heading only; no entry holds another listed version's heading; and the 1.2.1 entry arrived as pointers, not as copied text.
- [x] 5.3 Add the thread and why it is there to `test/llm_live/README.md`, and update the count of test threads in `CLAUDE.md`.
- [x] 5.4 Run `dart test test/llm_live --tags llm --run-skipped` against the local model and record the result. If the last words match under the next version's heading, build the guard from the design's first risk.

## 6. Check and document

- [x] 6.1 Run `dart test` and fix anything that fails.
- [x] 6.2 Add a paragraph to the QB LLM section of `CLAUDE.md` (and `AGENTS.md`): the model points at changelog entries and the extractor cuts them out; short entries are copied; anything not found is dropped. Say where the cut lives.
- [x] 6.3 Run an `llmTest` job on a handful of topics with changelogs. Compare the answer lengths in tokens with today's for the same topics, and note the result in the change.

## Results (2026-10-25)

Live tests run against `qwen3.8-flash-next-iq3xxs-strata`, one at a time: 9583, 35651, 34161, 21968 and 9175 all passed. The rest of the live suite was not run, because the server was busy with a scrape.

Answer lengths in tokens before and after this change, using the same topics with summaries on. The saved answers used prompt version 26 or 27:

| Topic | Before | After | Change |
| --- | --- | --- | --- |
| 9583 Tiandong (long changelog) | 8,235 | 860 | -90% |
| 35651 Computica's Faction Forks (7 mods) | 2,651 | 2,504 | -6% |
| 34161 Hartley's Miscellaneous Mods (4 mods) | 1,461 | 1,341 | -8% |
| 21968 Yunru Mods (6 mods) | 2,371 | 2,018 | -15% |
| 9175 Nexerelin | 612 | 532 | -13% |

Writing 9583's answer went from 66 s to 8 s. Threads without a changelog save 6–15%, from the link numbers alone.

### Second round of testing

- **Replay over today's data, no model calls.** Every saved changelog entry was cut again with its own first and last six words as the pointer. Of 1,619 long entries still in their post, 1,591 came out exactly as saved. This found four problems, now fixed: `[close]` pulled in at a spoiler's end, `&nbsp;` blocking the match, notes written before their version or in another message, and a version written only in the title. `PostReducer` also ran a Discord code block into the next line; `</pre>` now ends a line.
- **14 real changelog posts with the live model** (forum and Discord, picked from topics with long changelogs): answers went from 31,938 tokens to 9,560 (-70%). 34 entries cut, 5 copied, 5 dropped. Three drops were the model putting whole notes in `startsWith` with no `endsWith`; a lone pointer of more than 10 words is now treated as copied notes. Two were versions the model wrote with the game version added ("0.96a-RC4" for the post's "RC4"), which are not in the post and stay dropped.
- **Two live tests broke on the new prompt and were fixed**, each checked by running old and new code side by side. Hiver Swarm lost its "v1.1.7 - Save compatible" update note, because the heading is now left out of the changelog entry; the update-note rule now says a note on a release's heading still counts. MagicLib gained two "add-ons" whose only links go to their own forum threads, because naming a link by number made any link look like a download; the download rule now says a link to another thread, a wiki or a page about a mod is never a download.
- Extra Systems (36143) and the see-through picture test fail on the old code as well, so they are not part of this change.
