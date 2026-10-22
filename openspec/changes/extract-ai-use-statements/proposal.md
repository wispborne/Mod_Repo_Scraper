## Why

Some players want to know which parts of a mod were made with AI. Some players avoid AI art but accept AI-assisted code. Others care only about voice and music. About 50 to 75 of the stored forum topics contain AI-use statements. These statements vary in wording and are often buried in credits and spoilers. The site shows none of them. Extracting quotes and sorting uses adds little cost to the existing LLM pass.

A scan of `qb_data` found statements about:

- What was made with AI: portraits (most often), market and dialogue illustrations, ship and weapon sprites, achievement icons, music, voice lines, translation, written text and code.
- How much: "All images are AI-generated", "most of the images", "a small portion of the portraits".
- How: generated outright, generated and then edited by hand, or used only to help ("grammar and syntax passes", "code completion", translation "reviewed for correctness").
- Optional content: Junk Yard Dogs ships its AI portraits as an optional extra.
- Which tool: Midjourney, Stable Diffusion with a named model or LoRA, DALL·E 3, NovelAI, ElevenLabs, Suno, ChatGPT, DeepSeek, Claude.
- No AI use: "This mod contains zero AI generated content", "No AI Generation."

## What Changes

- The prompt asks for a quote from the author on each mod's AI use, including statements that no AI was used.
- The model sorts each quoted use by:
  - what it was used for: portraits, illustrations, sprites, icons, music, voice, writing, translation, code or other;
  - how: generated, edited or assisted;
  - how much: all, most or some, left empty when unspecified;
  - whether that part is optional.
- A tool name is kept only if it appears in the post as a whole word.
- The quote is checked against the post, like the save-compatibility quote. If it can't be found, the quote and its sorted uses are dropped.
- Each mod gets `usesAi`: `true` when the author says AI was used, `false` when the author states no AI was used, and `null` when there is no statement. A `null` is never shown or filtered as "no AI".
- The prompt explains that "AI" in Starsector usually means ship AI or AI cores, with worked examples. These are not AI-use statements.
- `ExtractionPrompt.promptVersion` goes up by one, so every topic and Discord thread is read again on the next coverage pass.
- The site publishes the sorted answer:
  - `usesAi` (`true` or `false`, left out when there is no statement) and a short list of areas in the list record;
  - the full answer, with the author's quote, in the mod's own file.
- The mod page shows an "AI use" row in Details, with the author's quote on hover.
- Browse gets an "AI use" filter. It can hide or show mods by the parts that use AI, the type of AI use, and whether the author stated any AI use. Search gets `has:ai` and `is:noai`.
- The results viewer's thread page shows the new answer next to the other LLM extras.
- New live-model test threads cover an AI-use statement, a "no AI" statement, a translation-only statement, and two threads where "AI" means game AI.

## Capabilities

### New Capabilities

- `ai-use-extraction`: extracting and checking quotes from the author on their AI use, including an explicit "no AI" statement. Uses are sorted by area, how, how much, whether they are optional and which tools were used.
- `ai-use-on-site`: how Starmodder publishes, shows, filters and searches the sorted answer, including the three states.

### Modified Capabilities

None. The public site's specs are still in the unarchived `starmodder-4-public-site` change. The site changes here are a new capability.

## Impact

- `lib/bot/scraper/qb/llm/prompt.dart`: the answer shape, the rules, the worked examples and the JSON schema. `promptVersion` goes up.
- `lib/bot/scraper/qb/models/post_extraction.dart`: new `LlmAiUse` and `LlmAiUseEntry` models on `LlmMod`'s extras. The mapper files are regenerated.
- `lib/bot/scraper/qb/llm/post_extractor.dart`: reading and checking the new answer.
- `lib/catalog/fact_choice.dart`: the new field follows the existing rule of forum first, and Discord only where the forum left it empty.
- `lib/site/models/public_mod.dart`, `public_mod_detail.dart`, `lib/site/public_data_builder.dart`: the published fields. `site/sample-data/` and its test are updated to match.
- `site/views/mod.js`, `site/views/browse.js`, `site/search.js`, `site/lib.js`: the row, the filter and the search terms. Tests go in `test/site/search_test.mjs`.
- `web/views/extraction_views.js`: the viewer's thread page.
- `test/llm_live/`: new saved posts, tests and README entries.
- `mods.json` grows by a few KB and stays below its 2 MB limit.
- Cost: reading every topic again. The `changelog-anchors` change also raises the prompt version, so the two should ship together if both are ready.
- TriOS keeps reading the bundle as before. Support for the new field can be added later.
