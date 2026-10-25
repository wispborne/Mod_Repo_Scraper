# ai-use-extraction Specification

## Purpose
TBD - created by archiving change extract-ai-use-statements. Update Purpose after archive.
## Requirements
### Requirement: Extract an AI-use quote for each mod
For each mod, the system SHALL put a quote from the author on their AI use in `aiUse.quote`. The quote SHALL cover whether AI tools were used to make any part of the mod. The system SHALL NOT summarize or paraphrase it. The system SHALL use only the post's statements to determine AI use. It SHALL check the quote against the post. A quote that cannot be found in the post SHALL be dropped, along with the rest of the answer, and the mod SHALL be recorded as read with nothing stated. The quote check SHALL compare words in order and ignore punctuation, list marks, line breaks and the extractor's own link notes.

#### Scenario: AI use stated
- **WHEN** a post says "Some portraits used in this were generated using the SeverianVoid LORA"
- **THEN** that mod's `aiUse.quote` SHALL contain that exact sentence

#### Scenario: No AI-use statement
- **WHEN** a post does not mention whether AI tools were used
- **THEN** that mod's `aiUse` SHALL be recorded as read with nothing stated

#### Scenario: A quote not in the post is dropped
- **WHEN** the model returns an AI-use quote that is not found in the post
- **THEN** that mod's `aiUse` SHALL be recorded as read with nothing stated

#### Scenario: A quote joining list items
- **WHEN** a post lists two uses on lines starting with "- " and the model quotes both lines without the marks
- **THEN** the quote SHALL be found in the post

### Requirement: "AI" meaning game AI is not an AI-use statement
The system SHALL NOT treat text about ship AI, fleet AI, AI cores, AI-core portraits or other game behaviour as a statement about AI use. The prompt SHALL give worked examples of both kinds.

#### Scenario: A mod about ship AI
- **WHEN** a post says "AI Tweaks provides various improvements focused on ship AI and AI-assisted player support" without mentioning tools used to make the mod
- **THEN** that mod's `aiUse` SHALL be recorded as read with nothing stated

#### Scenario: Portraits of AI cores made with an AI tool
- **WHEN** a post offers portraits of AI cores and says "All the portraits were generated using Severian Void's Stable Diffusion model"
- **THEN** that mod SHALL have an `aiUse` with one use whose `area` is `portraits`

### Requirement: Record AI-use status for each mod
The model SHALL answer `usesAi` for each mod with `true`, `false` or `null`:
- `true` when the quote says AI was used;
- `false` when the quote says no AI was used;
- `null` when there is no AI-use statement.

Every mod read with this prompt SHALL carry an `aiUse`. When `usesAi` is `null`, or the answer is dropped, the system SHALL store an `aiUse` with no `usesAi`, which means the post was read and says nothing. A missing `aiUse` SHALL mean the post has not been read with this prompt yet. The two SHALL never be treated as the same. When `usesAi` is `true`, `aiUse.uses` SHALL hold at least one use. A statement that names no part of the mod SHALL give one use with the area `other`. When `usesAi` is `false`, `aiUse.uses` SHALL be empty. An answer with `usesAi: false` that also lists uses SHALL be dropped and logged.

#### Scenario: AI use stated for sprites
- **WHEN** a post says "Other sprites made using AI"
- **THEN** that mod's `aiUse.usesAi` SHALL be `true` and its `aiUse.uses` SHALL include `sprites`

#### Scenario: Explicit no-AI statement
- **WHEN** a post says "This mod contains zero AI generated content"
- **THEN** that mod's `aiUse.usesAi` SHALL be `false` and its `aiUse.uses` SHALL be empty

#### Scenario: Nothing stated
- **WHEN** the model answers `usesAi: null`
- **THEN** that mod SHALL have an `aiUse` with no `usesAi`

#### Scenario: Not read yet
- **WHEN** a mod's stored answer was read before this prompt
- **THEN** that mod SHALL have no `aiUse`

#### Scenario: The statement names no part of the mod
- **WHEN** a post says "AI was used in making this mod" and nothing more
- **THEN** that mod's `aiUse.uses` SHALL be one use with the area `other`

#### Scenario: Contradictory answer
- **WHEN** the model returns `usesAi: false` together with one or more uses
- **THEN** that mod's `aiUse` SHALL be recorded as read with nothing stated and the run log SHALL record the reason

### Requirement: Each AI use is sorted into fixed fields
The system SHALL sort the quoted statement into a list of uses. Each use SHALL have an `area`, one of `portraits`, `illustrations`, `sprites`, `icons`, `music`, `voice`, `writing`, `translation`, `code` or `other`. Each use MAY have:
- `how`, one of `generated`, `edited` or `assisted`;
- `extent`, one of `all`, `most` or `some`;
- an `optional` flag, written only when `true`.

A value outside these lists SHALL be dropped. A use with an unknown `area` SHALL be dropped. Fields the quote does not support SHALL be left out.

#### Scenario: Several areas in one statement
- **WHEN** a post says the portraits "were generated with DALL·E 3 and edited by hand" and "LLMs were used for grammar and syntax passes on written text, and code assistance"
- **THEN** that mod's uses SHALL include `portraits` with `how: edited`, `writing` with `how: assisted`, and `code` with `how: assisted`

#### Scenario: An optional AI part
- **WHEN** a post says its AI-generated portraits are an optional extra the player can install
- **THEN** the `portraits` use SHALL have `optional: true`

#### Scenario: The amount is not stated
- **WHEN** a post says AI was used for music and gives no amount
- **THEN** the `music` use SHALL have no `extent`

#### Scenario: An unknown area
- **WHEN** the model returns a use whose `area` is not one of the listed values
- **THEN** that use SHALL be dropped

### Requirement: Named tools are checked against the post
The system SHALL keep each tool name in `aiUse.tools` only when it appears in the post as a whole word. At most five tool names SHALL be kept. Repeated names SHALL be dropped.

#### Scenario: Tool named in the post
- **WHEN** a post says illustrations "were created using MidJourney"
- **THEN** `aiUse.tools` SHALL include "MidJourney"

#### Scenario: Tool absent from the post
- **WHEN** the model returns "Stable Diffusion" for a post that only says "made with AI"
- **THEN** `aiUse.tools` SHALL NOT include it

### Requirement: A thread-wide statement applies to each mod it covers
When a thread offers several mods and its AI-use statement is written for the whole thread, the system SHALL give each `main` mod on the thread the same `aiUse`. A statement about one mod only SHALL stay on that mod.

#### Scenario: One disclaimer for a collection
- **WHEN** a thread offers three mods and one statement says "AI generation was used for most of the images"
- **THEN** each of the three mods SHALL carry that `aiUse`

### Requirement: Forum and Discord answers are not merged
For a mod with both a forum topic and a Discord thread, the system SHALL use the whole forum `aiUse` when it states something. It SHALL use the Discord `aiUse` only when the forum answer states nothing. When neither states anything but one was read, the mod SHALL be recorded as read with nothing stated. The two SHALL NOT be combined.

#### Scenario: Both sources have an answer
- **WHEN** the forum answer says no AI was used and the Discord answer lists AI portraits
- **THEN** the mod's `aiUse` SHALL be the forum answer

#### Scenario: Only Discord has an answer
- **WHEN** the forum answer has no `aiUse` and the Discord answer has one
- **THEN** the mod's `aiUse` SHALL be the Discord answer

### Requirement: The new field requires reading every post again
The change SHALL raise `ExtractionPrompt.promptVersion` and the Discord prompt version. The next coverage pass SHALL read every stored topic and Discord thread again. Answers read before the change SHALL be treated as having no `aiUse`.

#### Scenario: An old answer
- **WHEN** a mod's stored answer was read with an older prompt version
- **THEN** that mod SHALL have no `aiUse` until it is read again

