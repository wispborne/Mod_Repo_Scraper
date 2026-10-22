## 1. Live tests first

- [x] 1.1 Save the real posts for the new live tests into `test/llm_live/posts/`: topic 25905 (AI-core portraits made with Stable Diffusion), the AI Tweaks topic (ship AI only), the topic whose credits list DALL·E 3, ElevenLabs and LLMs, the topic that says "zero AI generated content", and the translation topic that lists DeepL, ChatGPT and DeepSeek. Remove the scrape time and local image paths
- [x] 1.2 Write live tests with strict checks for `area` and loose checks for `how`. Print the model's answer in each test
- [x] 1.3 Describe what each new thread tests in `test/llm_live/README.md`

## 2. Model and prompt

- [x] 2.1 Add `LlmAiUse` (`quote`, `usesAi`, `uses`, `tools`) and `LlmAiUseEntry` (`area`, `how`, `extent`, `optional`) to `lib/bot/scraper/qb/models/post_extraction.dart`, with enums for `area`, `how` and `extent`. Write the fields only when present, as with `isTool` and `nicknames`
- [x] 2.2 Regenerate the mapper files with `dart run build_runner build --delete-conflicting-outputs`
- [x] 2.3 Add `aiUse` to the answer shape and JSON schema in `lib/bot/scraper/qb/llm/prompt.dart`, with the rules and worked examples from the design (game AI is not AI use; topic 25905 is both; thread-wide statements apply to every `main` mod; "upscaled" alone does not count)
- [x] 2.4 Raise `ExtractionPrompt.promptVersion` and `discordPromptVersion`, and update `test/catalog/forum_prompt_unchanged_test.dart` to the new prompt

## 3. Reading and checking the answer

- [x] 3.1 Read `aiUse` in `post_extractor.dart`. Check the quote with `_textInPost` and drop the whole field if the check fails. Store nothing when `usesAi` is `null`. Drop and log answers with `usesAi: false` and `uses`. Add one use with the area `other` when a `usesAi: true` answer has no uses
- [x] 3.2 Drop uses with an unknown `area`. Drop unknown `how` and `extent` values. Keep `optional` only when `true`
- [x] 3.3 Check that each tool name appears as a whole word in the author's text, as `_groundNicknames` does. Drop repeats and keep at most five names
- [x] 3.4 Add unit tests for 3.1 to 3.3 with canned answers

## 4. Catalog and site data

- [x] 4.1 In `lib/catalog/fact_choice.dart`, take the whole `aiUse` from the forum answer if present, otherwise from Discord. Do not merge the answers. Add a test for each case
- [x] 4.2 Add `usesAi` and `aiAreas` to `PublicMod` and the whole `aiUse` to `PublicModDetail`. Regenerate mappers
- [x] 4.3 Fill these fields in `public_data_builder.dart`. Check that the internal-fields test still passes and `mods.json` stays under its size limit
- [x] 4.4 Add examples of all three states to `site/sample-data/` and keep `test/site/sample_data_test.dart` passing

## 5. Site pages

- [x] 5.1 Add the "AI use" row to the Details card in `site/views/mod.js`, with the quote on hover through `quickTip`
- [x] 5.2 Add the "Hide AI use" panel to `site/views/browse.js` for both layouts, with selected areas saved in the address as `hideai=`. Add the help text "Mods with unknown AI use stay visible."
- [x] 5.2a Replace the "Hide AI use" panel with the "AI use" filter. Stack the "Don't show AI-gen…" and "Only show AI-gen…" mode buttons. Start on "Don't show AI-gen…" with nothing checked. This hides nothing. "Don't show AI-gen…" never hides a mod whose author says nothing about AI. Provide no off button. Group the parts without a "Parts" heading. Put All and None in the side panel's heading and in a small "AI use" heading row in the top layout's box. Pressing them must not fold the panel. Add AI use levels and an option to ignore AI content that is optional. Keep the logic in `site/ai_filter.js`. Test it in `test/site/ai_filter_test.mjs`. Publish `aiUses` in place of `aiAreas`. Keep old `hideai=` links working.
- [x] 5.3 Add `ai` and `noai` to `FLAGS` in `site/search.js`, and cases to `test/site/search_test.mjs` (including that `-has:ai` keeps mods with no statement)
- [x] 5.4 Document the new search terms and the AI use row on the About page
- [x] 5.5 Check the row, the panel and the search in the browser with `?data=sample`, in dark and light themes and at phone width

## 6. Viewer and docs

- [x] 6.1 Show `aiUse` on the viewer's thread page in `web/views/extraction_views.js`
- [x] 6.2 Describe the new field in `CLAUDE.md`'s LLM and public-site sections

## 7. Check

- [x] 7.1 Run `dart test`
- [x] 7.2 Run the new live tests with `dart test test/llm_live --tags llm --run-skipped` and tighten the prompt where they fail
- [x] 7.3 Run an `llmTest` job on a few of the scanned topics and read the answers in the viewer
