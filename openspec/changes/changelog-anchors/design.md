## Context

Each LLM call reads the author's opening run of posts and answers with one JSON object per thread. The changelog part of that answer is `{"link": …, "entries": {"<version>": "<notes copied word for word>"}}`, at most the three highest versions (`prompt.dart`). `PostExtractor` turns `entries` into `changelogEntries`, a `Map<String, String>`, takes the "v" off each version (`plainVersion`), and checks each copied text against the post (`_textInPost`). An entry that fails the check is kept anyway with a warning (`post_extractor.dart`, around line 860). On a truncated answer every entry is dropped.

Measured on today's data:

- 1,587 entries, 806,000 characters, about a third of everything the model writes.
- The median entry is 173 characters; one in ten is over 1,100.
- 281 logged entries were not copied word for word, out of about 8,500 successful calls.
- On the local server, writing the answer is about 80% of a call's time. Reading the prompt is mostly cached.

The same problem was solved for descriptions on shared threads: the model gives `descriptionAnchors` (`startsWith` / `endsWith`), and `lib/site/description_slice.dart` cuts the author's HTML out between them when the site is built.

Who reads the stored changelog: the bundle (`LlmChangelog.entries`, read by TriOS), the site builder (`PublicModDetail.changelog`), the release detector (`_notesFor`, the notes for a release) and the viewer. All of them read the map.

## Goals / Non-Goals

**Goals:**

- The model writes a few dozen tokens per changelog entry instead of the whole entry.
- Every stored entry is the author's own words, or it is not stored.
- The stored shape does not change, so nothing that reads it changes.

**Non-Goals:**

- Update notes (`updateNotes.quote`). They are copied word for word too, but are usually one sentence, so pointers would save little.
- Changing how many versions are asked for (three).
- Parsing changelogs with rules and no model. Changelog layouts vary too much from one author to the next.
- Cutting the changelog as HTML. The site shows the notes as plain text in a `<pre>`, and TriOS reads plain text.

## Decisions

### 1. The model points; the extractor cuts and stores the text

The answer's `entries` becomes a list, one item per version:

```json
{"version": "1.2.1", "text": null, "startsWith": "Campaign stuff: - Campaign rig", "endsWith": "now spawn less often."}
```

`text` is used instead of the two pointers when the notes are short (see decision 2). All four fields are always present and may be null, which the strict JSON schema needs.

The extractor cuts the text out right away and stores it in `changelogEntries` exactly as today.

*Considered instead:* store the pointers and cut at publish time, the way descriptions do. That was rejected. It would change `LlmChangelog`, its mapper, the bundle TriOS reads, the sample data, the release detector and the viewer, all to move work that has nothing to gain from waiting. Descriptions are cut at build time because they need the cleaned post HTML, which lives in the site code. A changelog is plain text the extractor already holds.

### 2. Short entries are still copied whole

When an entry is 15 words or fewer, the model puts it in `text` and leaves the pointers null. Pointers of five or six words each would be about as long as the entry, and a very short pointer matches almost anywhere. A copied `text` is checked with `_textInPost` as today, but **a miss now drops the entry** instead of keeping it.

The 15-word line is for the model's benefit only. The code accepts either form for any entry: `text` when present, otherwise the pointers.

### 3. What is cut, and from where

The cut is made from `ReducedPost.text` for each post in the opening run. That is the text the model was shown, with the line breaks the `<pre>` display needs. It is taken before any `llm_max_input_chars` trimming, which only shortens what the model sees and never adds text. All three finds must land in **one** post. An entry split across two posts is not cut, the same rule descriptions follow.

Steps for one entry:

1. **Find the version.** It must be a whole token: it may not be preceded or followed by a letter or digit, so "1.2.1" does not match inside "1.2.1a" or "11.2.1". A leading "v", "v." or "version " before it is allowed. Matching ignores capitals, and the model's spelling is tried first, then the plain version without the "v". Every place the version appears is a candidate, tried in order of where it sits in the post. A place at the start of a line, the way a heading sits, is tried before any other.
2. **Find the first words** after that place, then the **last words** after those. Both use `anchorKey` matching from `description_slice.dart` (letters and numbers only, lower case), with a map from each kept character back to its place in the original text, so the cut is made in the original. A pointer shorter than eight letters and numbers is rejected, as with descriptions.
3. **The first candidate where all three are found wins.** In topic 9583 this is what saves "1.2.1": its first whole-token appearance is inside the 1.2.1a notes ("a save made on 1.2.1"), but the first words "Campaign stuff" only follow its real heading.
4. **Cut** from the start of the first words to the end of the line holding the last words. Starting at the first words, not at the start of their line, keeps a heading like "1.2.1a - Fixed X" from bringing the version into the notes.
5. **Clean** the cut. Take out every `[link: <url>]` note, trim spaces at line ends, collapse runs of blank lines to one, and trim the whole entry.

The matching helpers move to a place both callers can use. `anchorKey` and its "letters and numbers" pattern sit in `lib/site/description_slice.dart` today. The scraper should not import from `lib/site/`, so the key function moves to a small shared file under `lib/bot/scraper/qb/llm/`, and `description_slice.dart` imports it from there. The cutting itself goes in a new `changelog_slice.dart` next to the extractor, with unit tests of its own.

### 4. A failed entry is dropped and counted

Any entry whose version, first words or last words cannot be found is dropped. The drop is logged with the topic id, the version and which of the three was missing. The other entries for that mod are kept.

Each run's coverage summary gets one more line: how many entries were cut, how many copied short and how many dropped. That number tells us whether the prompt needs work, without reading logs by hand.

### 5. One `promptVersion` bump

Changing the answer shape bumps `ExtractionPrompt.promptVersion`. Every topic is read again on the next coverage pass. The bundle reads every stored answer whatever its prompt version, so a topic keeps its old changelog until the pass reaches it. There is no gap on the site or in TriOS.

## Risks / Trade-offs

- **[The last words land under the next version]** The model could give last words that sit after the next version's heading, so one entry swallows the next. → Mitigation: the live test checks that no stored entry holds another listed version's heading. If it shows up in practice, add a guard: when another listed version's heading sits between the first and last words, drop the entry.
- **[A changelog with no version headings]** A post like "Changes: fixed X, added Y" has nothing for step 1 to find. → Those already came back with a version the model made up or took from the title. If the version is not in the post, the entry is dropped, which matches the rule that only grounded facts are kept. The drop count shows how often it happens.
- **[More entries dropped than today]** Today's 281 non-matching entries were kept; they will now be dropped. → That is intended, because they were not the author's words. The drop count after the first full pass shows the real rate, and the prompt can be tightened if it is high.
- **[The model copies long entries anyway]** If the model keeps writing `text` for long notes, nothing is saved. → The code still checks and keeps them, so nothing breaks. The cut/copied counts show it, and the live test checks that a long entry came back as pointers.
- **[Pointer text with our link notes in it]** The model might copy a `[link: …]` note into its first or last words. → `anchorKey` drops the brackets and the colon, but keeps the letters of the address. So the cut text also has its notes taken out after cutting, and the prompt already forbids copying them. A pointer holding one still matches, because the note is really in the text the model saw.
- **[A full re-read]** One full coverage pass is the cost. → Ship it with any other planned prompt change.

## Migration Plan

1. Land the code and the prompt change together with the `promptVersion` bump.
2. Run the live tests (`dart test test/llm_live --tags llm --run-skipped`), including the new thread.
3. The next scheduled run's coverage pass re-reads topics, within `llm_max_topics` if it is set. Old answers stay published until each topic is re-read.
4. After the first full pass, read the cut/copied/dropped counts. Compare the average answer length with today's.

Rollback is reverting the commit. Lowering `promptVersion` back is not needed: answers written under the new version have the same stored shape and stay valid.

## Open Questions

- Is 15 words the right line between copying and pointing? It is a guess from the data: the median entry is 173 characters, about 30 words. The counts after the first pass will say.
- Should the guard in the first risk be built straight away rather than waiting for the live test? It is a few lines, but every guard is one more way to drop a good entry.
