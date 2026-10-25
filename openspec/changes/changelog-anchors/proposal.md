## Why

The model spends about a third of its writing time copying changelogs out of the post word for word. Across the 1,036 mods stored today there are 1,587 changelog entries, holding 806,000 characters of copied text. Writing is about 80% of the time a call takes on the local server, so the changelog is the biggest single thing we can cut. The copying is also not reliable: the run logs show 281 entries that the model did not copy word for word. Today those are kept anyway, with a warning.

The site's descriptions already solved the same problem. There, the model points at the text with its first and last few words, and the code cuts the author's own words out of the post (`descriptionAnchors`, `lib/site/description_slice.dart`). Doing the same for changelogs cuts the copied text to about 142,000 characters, 82% less. We expect a typical call to get about a quarter faster.

Downloads are the next biggest part, about a quarter of the saved answer text. The model writes each download's whole address and copies its link text, although both are already in the prompt's list of the post's links. Numbering that list and asking for the number cuts each download to a few tokens. Both changes need a `promptVersion` bump, so they ship together and the posts are read again only once.

## What Changes

- The prompt asks for each changelog entry as a pointer, not a copy: the version, the first few words of that version's notes and the last few words.
- An entry that is shorter than its two pointers would be is still copied whole, as today.
- The extractor cuts each entry out of the post text the model was shown. It finds the version heading first, then the first words after it, then the last words after those. It cuts at whole lines and takes out our own `[link: …]` notes.
- An entry whose pointers cannot be found is dropped and logged. A copied entry that cannot be found in the post is dropped too. Today both kinds are kept with a warning, so the result can contain words the author never wrote. **BREAKING** only in the sense that some entries kept today will no longer be kept.
- The stored result keeps its shape: a map from version to that version's notes. The bundle, TriOS, the site and the release detector read it as they do now, and none of them change.
- Each link in the prompt's list of the post's links gets a number. The model names a download by that number instead of writing its address and link text. The extractor fills in the address and the link text from the list. An address written out in the post text, which is not in the list, is still copied.
- A download with a number outside the list is dropped and logged.
- `ExtractionPrompt.promptVersion` goes up by one, so every topic is read again once on the next coverage pass.
- The spec is brought up to date on one point while it is open. It still says a changelog link is kept *instead of* copied text. The code has kept both since the prompt was changed to ask for both.
- A new live-model test thread with a long changelog of several versions, chosen because its version numbers trip up a careless search.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `qb-llm-post-extraction`: downloads are named by their number in the prompt's list of links. The model gives text pointers for the changelog, and the extractor cuts it out of the post. Changelog text that cannot be found in the post is no longer kept.

## Impact

- `lib/bot/scraper/qb/llm/prompt.dart`: the changelog and download parts of the answer shape, their rules and the JSON schema; the numbered list of links. `promptVersion` goes up.
- `lib/bot/scraper/qb/llm/post_extractor.dart`: reading the new answer shape, turning link numbers back into addresses, and cutting and checking the entries in place of the "keep anyway" check.
- `test/catalog/golden/forum_prompt.txt`: regenerated, since the forum prompt is meant to change.
- A new small file for the cutting, next to the extractor. It does not live in `lib/site/`: this cut runs on plain post text inside the scraper, while `description_slice.dart` cuts site HTML.
- `test/llm_live/`: one new saved post and its checks, and a line in the README.
- Unit tests for the cutting.
- No change to `LlmChangelog`, the bundle, the mapper files, the viewer, the site or TriOS.
- Cost: one full re-read of every topic after the change ships. It would be worth shipping it with any other planned prompt change.
