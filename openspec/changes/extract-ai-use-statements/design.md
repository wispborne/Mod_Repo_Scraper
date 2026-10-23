## Context

The LLM already reads every forum topic and Discord thread once per prompt version and returns a list of mods with extras: downloads, changelog, the three save questions, needs, nicknames, support links and more. Quotes from the author are checked against the post (`_textInPost` in `post_extractor.dart`). The save questions also carry a short answer from a fixed list (`canAdd`, `canRemove`), which is dropped whenever its quote is dropped. The new extra follows the same rules.

A scan of the stored posts found AI-use statements on roughly 50 to 75 topics. They sit in credits lists, in spoilers headed "AI generation disclaimer" or "On AI generated content", in license sections ("excluding AI art"), and in plain sentences in the description. Many nearby mentions of "AI" refer to ship AI, AI cores or AI-core portraits.

## Goals / Non-Goals

**Goals:**

- Quote what the author says about their AI use, and check the quote against the post.
- Sort the uses in the quote into fixed fields for filtering.
- Distinguish an explicit no-AI statement (`usesAi: false`) from no statement (`usesAi: null`).
- Show AI use on the mod page and support filtering in Browse and search.

**Non-Goals:**

- Guessing AI use from the pictures, the file names or the writing style. The site only reports what the author says.
- Judging whether AI use is good or bad. The page reports AI use without comment.
- Reading the mod's own files, such as a README inside the zip. Only stored posts are read.
- Nexus pages. The LLM does not read them yet.
- Changing TriOS. The bundle carries the new field and TriOS can read it later.

## Decisions

### One extra per mod, named `aiUse`

```json
"aiUse": {
  "quote": "<quote from the author on their AI use>",
  "usesAi": true,
  "uses": [
    { "area": "portraits", "how": "edited", "extent": "some", "optional": true },
    { "area": "code", "how": "assisted" }
  ],
  "tools": ["DALL-E 3", "ElevenLabs"]
}
```

- `quote` holds the single quote from the author. It uses the same post check as `saveCompatibility`. If it is missing or can't be found, the whole `aiUse` is dropped.
- `usesAi` is `true` when the quote says AI was used, `false` when it says no AI was used, and `null` when there is no statement. The model answers it for every mod. A `null` answer stores an `aiUse` with no `usesAi` (written `{}`), meaning the post was read and says nothing. A missing `aiUse` means the post has not been read with this prompt yet. The site shows the two differently. `usesAi` avoids the double negative of `noAi: false`.
- When `usesAi` is `true`, `uses` holds at least one entry. A statement that names no part of the mod ("AI was used in making this") gives one entry with the area `other`. When `usesAi` is `false`, `uses` must be empty. If the model returns `false` with uses, the extractor drops the contradictory answer and logs it.
- `uses` lists the AI uses the model found in the quote. Each entry needs an `area`. `how`, `extent` and `optional` are left out when unspecified in the quote.
- Each name in `tools` is kept only when it appears in the post as a whole word, using the same check as `_groundNicknames`. For example, "Midjourney" must appear in the post. A guessed "Stable Diffusion" is dropped.
- Keep at most one quote per mod. If a post has two statements, such as one in the credits and one in a spoiler, choose the longer one or the one headed "AI disclaimer" or similar. A list of quotes would make the site row harder to read. `uses` covers both statements.

A single text field would not support filtering by area.

A yes/no flag would not distinguish different uses of AI.

### Allowed values

- `area`: `portraits`, `illustrations`, `sprites`, `icons`, `music`, `voice`, `writing`, `translation`, `code`, `other`.
- `how`: `generated` (made by AI and used unchanged), `edited` (made by AI, then changed by hand), `assisted` (made by a person with AI help, such as a grammar pass, code completion or translation help).
- `extent`: `all`, `most`, `some`.

Values outside these lists are dropped. An unknown `area` drops the whole entry. The JSON schema enforces these lists when structured output is on. Code always checks them, as it does for `SaveAnswer`.

"Upscaling" is not a separate area. Pictures upscaled with AI go under the picture's area with `how: edited`. "Upscaled" alone does not count as AI use. In these posts it usually means "made bigger".

### Thread-wide statements apply to every mod

A thread holding several mods usually has one disclaimer for all of them. The prompt says a statement written for the whole thread is copied onto every `main` mod it covers. A statement about one mod only stays on that mod.

### Prefer forum facts

`chooseFacts` already takes each field from the forum answer first and from Discord only where the forum answer has none. `aiUse` follows this rule as a whole field. The answers are never merged. Merging a forum "no AI" with a Discord "AI portraits" would misrepresent both sources.

### What the site publishes

- On the list record (`PublicMod`, in `mods.json`): `usesAi`, `true` or `false`, left out when `null`; and `aiUses`, written only when `usesAi` is `true`. Each use has `area`, `how` and `optional`. Uses are sorted by area, with duplicates removed and `extent` omitted. Most mods have neither field. Expected growth is a few KB.
- In the mod's own file (`PublicModDetail`): the whole `aiUse`, with the tools.
- Missing list fields mean the author said nothing, or the mod has not been read yet. The mod's own file tells the two apart: an empty `aiUse` is "read, nothing stated", and no `aiUse` is "not read yet".

### How the site shows it

- Mod page, in the Details card, one row headed "AI use":
  - "Portraits (edited, optional) · Code (assisted)" when AI was used;
  - "None" when `usesAi` is `false`;
  - "Unknown" when the posts were read and say nothing;
  - "Not checked yet" when the posts have not been read for this yet.
- The author's quote shows on hover, through `quickTip`, the way the save rows work.
- Browse: an "AI use" filter has two modes, "Don't show AI-gen…" and "Only show AI-gen…". The mode buttons are stacked. The filter starts on "Don't show AI-gen…" with nothing checked. This hides nothing. There is no off button. Parts are grouped as Art, Sound, Text, Code and Other. There is no "Parts" heading. Under "If AI did…", readers pick how much AI work counts: "all of the work", "some, but edited by a human" or "anything at all". The All and None links sit in the side panel's heading. In the top layout's box, they sit in a small "AI use" heading row. Pressing them does not fold the panel. A checkbox lets readers ignore optional parts. In this mode, mods with no statement stay visible unless the reader checks that box. The logic is in `site/ai_filter.js`, which has no DOM so Node can test it. The address carries `ai`, `aiparts`, `ailevel`, and `aioptional`, and old `hideai=` links still work. `how` and `optional` are published on the list record because the filter needs them; `extent` is not, to keep `mods.json` small.
- Search: `has:ai` keeps mods whose `usesAi` is `true`, `is:noai` keeps mods whose `usesAi` is `false`, and a minus in front of either leaves those mods out. Both are added to `FLAGS` in `search.js`. Search terms for individual areas (`ai:music`) are left out for now. The Browse panel already filters by area. Additional search terms would be harder to learn.

### The prompt

The prompt gets:

- a short explanation of what counts: the author saying a part of the mod was made with, or helped by, an AI tool, or saying no AI was used;
- examples of game AI: "AI Tweaks provides various improvements focused on ship AI and AI-assisted player support", "AI Portraits of AI Cores (As People)" when the post only talks about the cores, and "AI fleets";
- one example of game AI and AI use: topic 25905, where the portraits of AI cores were made with Stable Diffusion.

The line explaining Discord threads stays exclusive to the Discord prompt. Only the new section changes the forum prompt.

## Risks / Trade-offs

- [The model reads ship AI as AI use.] → Worked examples in the prompt, the quote check, and live tests on AI Tweaks and on an AI-core portrait pack.
- [Readers mistake unknown AI use for no AI use.] → The site shows "Unknown" or "Not checked yet" without a mark when there is no statement. These mods stay visible when Browse filters by AI use.
- [Undisclosed AI use remains unknown.] → The site can only report author statements.
- [Sorting errors, such as `edited` read as `generated`.] → Readers can hover to see the author's quote. The live tests check the area most strictly because filters depend on it.
- [Reading every topic again takes a full LLM pass.] → Ship it with the next prompt change, such as `changelog-anchors`, so one pass covers both changes.
- [The site could appear to take a side on AI use.] → The labels describe AI use ("Portraits (edited)") and add no colour, warning icon or comment.

## Migration Plan

1. Ship the code. Old answers have no `aiUse`, so every mod shows "Not checked yet" until it is read again.
2. The prompt version bump makes the next coverage pass read every topic again. `llm_max_topics` spreads that over several runs as configured.
3. Reverting the code needs no manual cleanup. The stored answers keep the extra field, which the old code ignores.

## Open Questions

- Should the Browse panel start with no selections (proposed), or remember the last selection in `localStorage`, like other settings?
- Should TriOS show the same row? That requires a separate TriOS change.
