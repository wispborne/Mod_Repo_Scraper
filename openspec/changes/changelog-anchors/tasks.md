## 1. Shared matching

- [ ] 1.1 Move `anchorKey` and its letters-and-numbers pattern out of `lib/site/description_slice.dart` into a small file under `lib/bot/scraper/qb/llm/`, and import it back into `description_slice.dart`. The existing description slice tests still pass unchanged.
- [ ] 1.2 Add a key function that also returns, for each kept character, its place in the original text, so a match in the key can be turned back into a cut in the original.

## 2. Cutting a changelog entry

- [ ] 2.1 Create `lib/bot/scraper/qb/llm/changelog_slice.dart`. It finds a version as a whole token (no letter or digit on either side; optional "v", "v." or "version " before it; capitals ignored), tries places at the start of a line first, and returns them in order.
- [ ] 2.2 For each version place, find the first words after it and the last words after those (eight letters-and-numbers minimum). The first place where all three are found wins, all within one post.
- [ ] 2.3 Cut from the start of the first words to the end of the line holding the last words. Then take out `[link: <url>]` notes, trim line ends, collapse blank-line runs to one, and trim the whole entry.
- [ ] 2.4 Return why a cut failed (version, first words or last words not found), so the extractor can log it.
- [ ] 2.5 Unit tests in `test/qb/changelog_slice_test.dart`: a plain cut; line breaks kept; the heading line not included; "1.2.1" not matching "1.2.1a"; a version first mentioned inside another version's notes (the topic 9583 case); the same first words repeated under several versions; a `[link: …]` note taken out; punctuation and HTML entities differing between pointer and post; a pointer too short; pointers split across two posts; each kind of failure reported.

## 3. Prompt

- [ ] 3.1 In `prompt.dart`, change the answer shape's `changelog.entries` to a list of `{version, text, startsWith, endsWith}`. Change the JSON schema to match, with all four fields required and nullable.
- [ ] 3.2 Rewrite the changelog rule. For each of the highest three versions, give the version as the post writes it. Then give the first five or six words of that version's notes and the last five or six words, copied exactly, with the heading left out. Notes of 15 words or fewer go in `text` instead. Keep the existing warning against copying our `[link: …]` notes.
- [ ] 3.3 Bump `ExtractionPrompt.promptVersion` by one. Update the number in the `promptVersion` note in `CLAUDE.md` and `AGENTS.md`.

## 4. Extractor

- [ ] 4.1 In `post_extractor.dart`, read the new list shape. Keep reading the old map shape too, so a canned answer in an older test, or a model that ignores the new shape, still parses.
- [ ] 4.2 In grounding, replace the "keep anyway" changelog check. A `text` entry is kept only when `_textInPost` finds it. A pointer entry is cut with `changelog_slice.dart` over each opening post's `ReducedPost.text`. A failure drops the entry and logs the topic id, the version and the reason.
- [ ] 4.3 Store the result in `changelogEntries` keyed by `plainVersion`, as today. Keep the rule that drops every entry when the answer was truncated.
- [ ] 4.4 Count cut, copied and dropped entries over a run, and add one line with the three counts to the coverage pass's summary log.
- [ ] 4.5 Update the extractor tests in `test/qb_llm_post_extractor_test.dart`: a pointer entry is cut, a copied short entry is kept, a reworded copy is dropped, unfindable pointers drop only their own entry, and an old-shape answer still parses.

## 5. Live test

- [ ] 5.1 Save topic 9583 (Tiandong Heavy Industries) as `test/llm_live/posts/9583.json`, prepared the same way as the other saved posts. It has a long changelog of several versions in a spoiler, and "1.2.1" appears inside the 1.2.1a notes before its own heading.
- [ ] 5.2 Add a live test. It checks: entries for 1.2.1a and 1.2.1 come back, each holding words from under its own heading only; no entry holds another listed version's heading; and the 1.2.1 entry arrived as pointers, not as copied text.
- [ ] 5.3 Add the thread and why it is there to `test/llm_live/README.md`, and update the count of test threads in `CLAUDE.md`.
- [ ] 5.4 Run `dart test test/llm_live --tags llm --run-skipped` against the local model and record the result. If the last-words-under-the-next-version problem shows up, build the guard from the design's first risk.

## 6. Check and document

- [ ] 6.1 Run `dart test` and fix anything that fails.
- [ ] 6.2 Add a paragraph to the QB LLM section of `CLAUDE.md` (and `AGENTS.md`): the model points at changelog entries and the extractor cuts them out; short entries are copied; anything not found is dropped. Say where the cut lives.
- [ ] 6.3 Run an `llmTest` job on a handful of topics with changelogs. Compare the answer lengths in tokens with today's for the same topics, and note the result in the change.
