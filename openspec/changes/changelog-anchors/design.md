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
4. **If the first words cannot be found after any candidate**, search all posts: first those that contain the version, then the rest. Some authors write the notes first and the version after them, on the download link (topic 30736), and a Discord thread often names the version in one message and gives the notes in another. The version must still appear in a post or in the thread's title, which is the only place many authors write it ("Star Wars Mod 2.05").
5. **Cut** from the start of the first words to the end of the line holding the last words. Starting at the first words, not at the start of their line, keeps a heading like "1.2.1a - Fixed X" from bringing the version into the notes.
6. **Clean** the cut. Our `[link: <url>]` notes, the forum's spoiler end marks (`[close]`) and `&nbsp;` were taken out of the post before step 1. Trim spaces at line ends, collapse runs of blank lines to one, and trim the whole entry.

A dash, underscore or space between a version's parts can match any of those characters or no character. For example, the model writes "0.3.8-RC1" for the post's "0.3.8 RC1". Dots must match as written.

**Tested against today's data before shipping.** Replaying the cutter over all 2,397 saved changelog entries, with the first and last six words of each saved entry as a perfect pointer: 752 are short enough to be copied, and 26 are no longer in their post. Of the remaining 1,619, 1,591 are cut to exactly the saved words. 18 versions are not found (most from one thread listing other people's mods), 5 cuts end early because the last words also appear earlier in the entry, and 3 pointers are too short. The replay turned up four problems, all fixed: `[close]` pulled in at a spoiler's end, `&nbsp;` left in the text blocking the match, notes written before their version or in another message, and a version written only in the title. It also showed the post reducer ran a Discord code block straight into the next line, so `</pre>` now ends a line in `PostReducer` too.

The matching helpers move to a place both callers can use. `anchorKey` and its "letters and numbers" pattern sit in `lib/site/description_slice.dart` today. The scraper should not import from `lib/site/`, so the key function moves to a small shared file under `lib/bot/scraper/qb/llm/`, and `description_slice.dart` imports it from there. The cutting itself goes in a new `changelog_slice.dart` next to the extractor, with unit tests of its own.

### 4. A failed entry is dropped and counted

Any entry whose version, first words or last words cannot be found is dropped. The drop is logged with the topic id, the version and which of the three was missing. The other entries for that mod are kept.

Each run's coverage summary gets one more line: how many entries were cut, how many copied short and how many dropped. That number tells us whether the prompt needs work, without reading logs by hand.

### 5. Downloads are named by their number in the list of links

The user prompt's `=== LINKS IN THE POST ===` list is `read.combined.links`: every link in the opening run, once each, in the order they first appear. Each line now starts with its number in that list: `- [3] https://… "Download" [flagged downloadable]`. The address stays on the line, because the model needs it to judge the host and to match the inline `[link: <url>]` notes in the post text. Lines in `=== LINKS THE SCRAPER AUTO-DETECTED AS DOWNLOADS ===` whose address is in the list carry the same number.

A download in the answer becomes `{"link": <number or null>, "url": <string or null>, "kind": …}`. `label` is gone from the answer. The model gives the number when the link is in the list, and copies `url` only for an address the list does not have, which is an address written out in the post text with no link around it. All three fields are always present, for the strict schema.

The extractor turns a number back into that list item's address and its text, trimmed, as the label. That is the same label the prompt asked the model to copy, so the stored `LlmDownload` keeps its shape. A copied `url` that matches a listed link (by `PostReducer.normalizeForMatching`) also gets that link's text; otherwise its label is empty. A download with a number outside the list is dropped, and the number is logged. The URL check that every download already goes through (`_urlInPost`) still runs after.

The old answer shape (`url` and `label`) is still read, so canned answers in older tests keep working.

*Considered instead:* number the inline `[link: <url>]` notes too (`[link 3: <url>]`), so the model need not look the address up in the list. Rejected for now: the notes are taken out of text in three other places (the AI-use cut, the nickname check, the new changelog cut), and the model already ties each note to the list by address. The live tests check downloads by address, so a wrong number shows up there.

### 6. One `promptVersion` bump

Changing the answer shape bumps `ExtractionPrompt.promptVersion`. Every topic is read again on the next coverage pass. The bundle reads every stored answer whatever its prompt version, so a topic keeps its old changelog until the pass reaches it. There is no gap on the site or in TriOS.

## Risks / Trade-offs

- **[The last words land under the next version]** The model could give last words that sit after the next version's heading, so one entry swallows the next. → Mitigation: the live test checks that no stored entry holds another listed version's heading. If it shows up in practice, add a guard: when another listed version's heading sits between the first and last words, drop the entry.
- **[A changelog with no version headings]** A post like "Changes: fixed X, added Y" has nothing for step 1 to find. → Those already came back with a version the model made up or took from the title. If the version is not in the post, the entry is dropped, which matches the rule that only grounded facts are kept. The drop count shows how often it happens.
- **[More entries dropped than today]** Today's 281 non-matching entries were kept; they will now be dropped. → That is intended, because they were not the author's words. The drop count after the first full pass shows the real rate, and the prompt can be tightened if it is high.
- **[The model copies long entries anyway]** If the model keeps writing `text` for long notes, nothing is saved. → The code still checks and keeps them, so nothing breaks. The cut/copied counts show it, and the live test checks that a long entry came back as pointers.
- **[Pointer text with our link notes in it]** The model might copy a `[link: …]` note into its first or last words. → The notes are taken out of the post before matching, the same as `cutQuote` does for AI-use statements, so a pointer never has to skip over one. A pointer containing one will not match, and its entry is dropped. The prompt already forbids copying them.
- **[The model gives the wrong link number]** A wrong number is a real address from the post, so the URL check does not catch it, and a support or thread link could be stored as a download. → The live tests check each download by the part of its address that names the mod, so they catch it. If it happens in practice, number the inline notes too (decision 5).
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
