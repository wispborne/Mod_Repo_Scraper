## ADDED Requirements

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

### Requirement: Downloads are a list, reconciled with the rules in one call
The system SHALL keep downloads as a per-topic list that may hold more than one link. It SHALL give the rule-based resolver's found links (as their original post URLs) to the LLM inside the single extraction call, so the LLM can confirm them, add ones the rules missed, and drop any that are not downloads, in one pass — with no separate tie-break call. The merged list SHALL be the de-duplicated union of the rule links and the LLM's reconciled links, matched on the normalized original URL (not the resolver's resolved URL). When the LLM drops or overrides a rule link, its one-line reason SHALL be recorded on that entry.

#### Scenario: Only one side finds a link
- **WHEN** the rules find no download but the LLM finds a grounded one (e.g. inside a spoiler or on an unknown host)
- **THEN** the LLM's download is added to the list, tagged `source: llm`

#### Scenario: Both find the same file
- **WHEN** the rules and the LLM point at the same download (the rules' resolved link and the LLM's original post link refer to one file)
- **THEN** the list contains that file once, matched on the normalized original URL, tagged `source: rules+llm`, with no duplicate entry

#### Scenario: The LLM rejects a rule link
- **WHEN** the rules flagged a link as a download but the LLM, seeing the whole post, judges it is not the mod's download
- **THEN** the entry reflects the LLM's decision and its one-line reason is saved — all from the single call, with no extra request

#### Scenario: A mod offers a mirror
- **WHEN** a post offers the same file on two hosts
- **THEN** both links may appear in the downloads list

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

### Requirement: Output stays backwards-compatible
The system SHALL preserve every existing field and shape in `forum-data-bundle.json`. New data SHALL be additive and optional: an optional `source` tag on download entries indicating origin (`rules`, `llm`, or `rules+llm`), an optional `llmReason` when the LLM dropped or overrode a rule link, and a new optional per-topic extras section holding changelog, version, support links, and license. Absent or null fields SHALL be omitted.

#### Scenario: Existing consumers keep working
- **WHEN** a reader that predates this change loads the new bundle
- **THEN** all fields it already understood are present and unchanged, and it can ignore the added optional `source`/`llmReason` tags and extras section

#### Scenario: Feature off produces the old shape
- **WHEN** `enable_llm` is false
- **THEN** the bundle contains no `source` tags and no extras section, matching the pre-change output
