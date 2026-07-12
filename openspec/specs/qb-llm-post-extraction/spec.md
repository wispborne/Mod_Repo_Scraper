### Requirement: Each scraped post is read once by the LLM
When the feature is enabled, the system SHALL send each scraped topic's post content to the LLM once per run (subject to caching) and receive a single structured answer covering all requested fields, so the extra fields are captured on every post, not only those where the download rules struggled. The post content sent SHALL include spoiler-box contents (which the regex link extractor drops).

#### Scenario: Every post is covered
- **WHEN** the feature is enabled and a topic is scraped
- **THEN** its post content (spoilers included, reduced to text plus links) is sent to the LLM once, or served from cache, producing one structured answer

### Requirement: The LLM may only return facts grounded in the post
The system SHALL discard any LLM output not supported by the post: any returned URL that does not appear in the post SHALL be dropped, and any copied text (license, changelog text) that is not found in the post SHALL be treated as not stated.

#### Scenario: Invented URL is dropped
- **WHEN** the LLM returns a download or support URL that does not appear anywhere in the post
- **THEN** that URL is removed from the result and not written to the bundle

#### Scenario: Unstated fact is left blank
- **WHEN** the LLM returns a version, license, or changelog text that cannot be found in the post
- **THEN** that field is treated as not stated and left blank rather than saved

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

### Requirement: The LLM extracts changelog, version, support links, and license
When the feature is enabled, the system SHALL extract, when present and grounded in the post: a changelog (a link, or the post text copied word-for-word), the mod's own current version (kept separate from the game version), support links (e.g. Patreon, Ko-fi, donate), and the license as stated. A changelog link SHALL be preferred over copied changelog text when the post offers one.

#### Scenario: Changelog in a spoiler box
- **WHEN** the post has changelog text inside a spoiler box and no changelog link
- **THEN** the changelog text is copied word-for-word into the extras (not summarized)

#### Scenario: Changelog as a link
- **WHEN** the post links to a changelog
- **THEN** the changelog link is stored in preference to copied text

#### Scenario: Version separated from game version
- **WHEN** the post states both the mod's version and the game version it targets
- **THEN** the mod's own version is captured as the version field, not the game version

#### Scenario: License only when stated
- **WHEN** the post does not state a license
- **THEN** the license field is left blank (never guessed)

### Requirement: Test mode sends a limited number of requests and writes an inspection report
When `llm_test_mode` is enabled, the system SHALL make at most `llm_test_limit` LLM calls (default 5), call the LLM live (ignoring the answer cache), and SHALL NOT modify the real bundle or the answer cache. It SHALL instead write a verbose inspection report to a separate file containing, per topic: the exact input sent (post plus the rule-link/game-version hints), the raw answer, the parsed-and-grounded result, the items grounding dropped, the rules-vs-LLM comparison and any drop/override reason, and token usage. When `llm_test_topic_ids` is given, those topics SHALL be used; otherwise the system SHALL sample the hard posts (no download or only low-confidence downloads from the rules).

#### Scenario: Limited trial run
- **WHEN** `llm_test_mode` is true with `llm_test_limit` = 5 and no topic IDs given
- **THEN** at most 5 hard posts are sent to the LLM, results are written to the inspection report, and the real bundle and answer cache are left unchanged

#### Scenario: Target specific posts
- **WHEN** `llm_test_mode` is true AND `llm_test_topic_ids` lists specific topics
- **THEN** only those topics are sent to the LLM, up to `llm_test_limit`

#### Scenario: Repeatable while tuning
- **WHEN** test mode is run twice with the same posts
- **THEN** both runs call the LLM live (the answer cache is not used or written), so fresh output is produced each time
