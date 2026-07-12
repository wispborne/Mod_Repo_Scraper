## MODIFIED Requirements

### Requirement: Downloads are a list, combined with the rules in one call
The system SHALL, in the single extraction call, ask the LLM to produce the thread's downloads grouped under the mod each belongs to. It SHALL give the rule-based resolver's found links (as their original post URLs) to the LLM inside that call, so the LLM can confirm them, add ones the rules missed (including links inside spoiler boxes or on unknown hosts), and drop any that are not the mod's download — in one pass, with no separate follow-up call. Each download the LLM keeps SHALL carry the raw post URL, the link text copied word-for-word, and a `kind` of `direct`, `mirror`, or `trios`. The system SHALL then run each kept link through the existing download resolver, so every stored download also carries the resolved direct URL, filename, and requires-manual-step flag. The LLM SHALL NOT make up or resolve a URL. This grouped result SHALL be written into the thread's `llm` output and SHALL NOT overwrite the rule-based `assumedDownloads` list.

#### Scenario: Link the rules missed
- **WHEN** the rules find no download but the LLM finds a grounded one (e.g. inside a spoiler or on an unknown host)
- **THEN** the LLM's download is added under its mod in the `llm` output, and is run through the resolver for its resolved URL and filename

#### Scenario: A mod offers a mirror
- **WHEN** a post offers the same file on two hosts
- **THEN** both links appear under that mod, one with `kind` `direct` and the mirror with `kind` `mirror`

#### Scenario: Install-with-TriOS link
- **WHEN** a post offers an "Install with TriOS" link alongside a plain download for the same mod
- **THEN** both appear under that mod, the TriOS link with `kind` `trios` and the plain download with `kind` `direct`

#### Scenario: A link that is not a download is dropped
- **WHEN** the rules flagged a link as a download but the LLM, seeing the whole post, judges it is not the mod's download
- **THEN** that link SHALL NOT appear in the `llm` output — decided in the single call, with no extra request

#### Scenario: Rule-based list is left intact
- **WHEN** the LLM produces its grouped download result for a thread
- **THEN** the thread's `assumedDownloads` entry SHALL still contain the rule-based candidates, unchanged

## ADDED Requirements

### Requirement: The LLM output is a list of mods for the thread
When the feature is enabled, the system SHALL shape a thread's LLM output as a `mods` list, always — one entry for a single-mod thread, and one entry per mod when a thread carries several mods or a main mod with add-ons. Each mod SHALL carry: a `name`; a `role` of `main`, `addon`, `separate`, or `variant`; a `requires` naming the mod an add-on needs (else null); its grouped `downloads`; and the mod's extras (version, changelog, support links, license, save compatibility, and, when the summaries option is on, a summary). A thread that produced no LLM output SHALL have no `llm` field.

#### Scenario: Single-mod thread
- **WHEN** a thread describes exactly one mod
- **THEN** the `mods` list SHALL contain exactly one entry, with `role` `main`, holding that mod's downloads and extras

#### Scenario: Thread with a main mod and an add-on
- **WHEN** a thread offers a main mod and a separate optional add-on that needs it
- **THEN** the `mods` list SHALL contain two entries: the main mod (`role` `main`) and the add-on (`role` `addon`, `requires` set to the main mod's name), each with its own downloads

#### Scenario: Only mods downloadable from this thread are included
- **WHEN** a post mentions another mod that is only recommended, linked as a successor, or required but hosted elsewhere (for example a post that links to a successor mod and recommends a separate tool)
- **THEN** that other mod SHALL NOT be a `mods` entry; only mods actually downloadable from this thread SHALL be listed

#### Scenario: Each mod owns its own extras
- **WHEN** a thread carries two mods with different versions
- **THEN** each `mods` entry SHALL carry its own version and other extras, not a single set shared across the thread

### Requirement: Each mod may carry its own post image
The system SHALL let each mod in the `mods` list carry an optional `image`: a picture from the post that clearly belongs to that mod, stored in the same `ext:<url>` form as the thread's `thumbnailPath`. The system SHALL offer the post's images (URL and alt text) to the LLM, excluding badges and spinners, and SHALL ask it to pick an image only when one clearly belongs to a specific mod — most useful when a thread carries several mods or a main mod plus add-ons. The system SHALL ground the chosen image against the post's real images: an `image` URL that is not one of the post's images SHALL be dropped, and the stored value SHALL be the exact scraped URL, not the model's copy. A mod with no tied image SHALL have no `image` field. An image alone SHALL NOT keep an otherwise-empty mod.

#### Scenario: A per-mod image the post shows is kept
- **WHEN** a thread with more than one mod shows a picture next to one mod, and the model picks that image
- **THEN** that mod's `image` SHALL hold the post's image URL in `ext:<url>` form, and the other mods SHALL be unaffected

#### Scenario: An invented image is dropped
- **WHEN** the model returns an `image` URL that is not among the post's images
- **THEN** that mod SHALL have no `image`

#### Scenario: A badge is not a mod image
- **WHEN** the post's only images are badges or spinners (for example a shields.io license badge)
- **THEN** no mod SHALL be given an `image`, because badges are not offered to the model or grounded as mod pictures

### Requirement: Each mod copies the post's save-compatibility text
The system SHALL, for each mod, copy word-for-word the post's own statement about whether the mod can be added to an existing/ongoing save or needs a new game (for example "Save compatible", "Can be added to an existing save", or "Requires a new game") into a `saveCompatibility` extra. The system SHALL NOT summarize, paraphrase, or decide save compatibility itself. It SHALL ground the copied text against the post: text that cannot be found in the post SHALL be dropped. A mod SHALL have no `saveCompatibility` when the post does not state it.

#### Scenario: The post states save compatibility
- **WHEN** a post says the mod is save compatible (or that it needs a new game)
- **THEN** that mod's `saveCompatibility` SHALL hold the post's wording copied word-for-word

#### Scenario: The post says nothing about saves
- **WHEN** a post does not state whether the mod can be added to an existing save
- **THEN** that mod SHALL have no `saveCompatibility`

#### Scenario: Save-compatibility text not in the post is dropped
- **WHEN** the model returns save-compatibility text that is not found in the post
- **THEN** that mod SHALL have no `saveCompatibility`

## REMOVED Requirements

### Requirement: All LLM output lives in one per-topic override block
**Reason**: The LLM output no longer sits in a separate top-level `llm` map set up as a per-field override of `assumedDownloads`. It now lives on each `index` item as a list of mods and is the complete, standalone answer for a thread when present. The download origin tags (`source` / `llmReason`) and the per-field download merge are dropped, because a reader takes the whole `llm` block or the whole rules base, not a mix.
**Migration**: Readers SHALL get the thread's LLM output from its `index` item's `llm` field (a `mods` list) and treat it as the full answer when present; when the field is absent, use the rule-based `assumedDownloads`. There are no `source` / `llmReason` tags on downloads.
