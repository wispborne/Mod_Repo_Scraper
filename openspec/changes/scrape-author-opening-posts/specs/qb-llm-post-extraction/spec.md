## MODIFIED Requirements

### Requirement: Every stored post is covered by the LLM

When the feature is enabled, the system SHALL ensure that every topic held in the mods index either already has fresh LLM output or is sent to the LLM during the run — regardless of whether that topic was scraped in this run. Coverage SHALL be decided by the extraction store's freshness check (the content of every opening post, the prompt version, and the requested field set), not by whether the scraper happened to fetch the topic. A topic whose stored output is already fresh SHALL be served from the store without a live call. The content sent SHALL be the author's whole opening run — the first post plus every `extraPosts` entry, each reduced the same way and labelled as a follow-up post by the same author — and SHALL include spoiler-box contents (which the regex link extractor drops).

The system SHALL supply each topic's rule-based download candidates alongside the posts, taking them from the resolver's cache for topics that were not scraped this run.

#### Scenario: A topic scraped in an earlier run is picked up

- **WHEN** the feature is enabled and the store holds a topic that has never been sent to the LLM, and that topic is not scraped this run (for example because the incremental scope found it unchanged)
- **THEN** that topic's stored posts are sent to the LLM during this run and its output is written to the store and the bundle

#### Scenario: A topic scraped this run is not paid for twice

- **WHEN** a topic is scraped this run and its posts are sent to the LLM as part of the run's coverage
- **THEN** the topic SHALL result in exactly one live LLM call, not one per visit

#### Scenario: An unchanged, already-extracted topic costs nothing

- **WHEN** a topic's stored LLM output is fresh for the current posts' content, prompt version, and field set
- **THEN** the topic SHALL be served from the store with no live LLM call

#### Scenario: A changed post is re-extracted

- **WHEN** any of a topic's opening posts changed since its LLM output was stored, or the prompt version or field set changed
- **THEN** the topic SHALL be sent to the LLM again and its stored output replaced

#### Scenario: A changed follow-up post is re-extracted

- **WHEN** a topic's first post is unchanged but a follow-up post in `extraPosts` changed
- **THEN** the topic SHALL be sent to the LLM again

### Requirement: The LLM may only return facts grounded in the post
The system SHALL discard any LLM output not supported by the author's opening posts: any returned URL that does not appear in any opening post SHALL be dropped, and any copied text (license, changelog text) that is not found in any opening post SHALL be treated as not stated. Grounding SHALL cover the first post and every `extraPosts` entry, and nothing else — a URL that appears only in another user's reply is not grounded, because replies are never scraped.

#### Scenario: Invented URL is dropped
- **WHEN** the LLM returns a download or support URL that does not appear anywhere in the opening posts
- **THEN** that URL is removed from the result and not written to the bundle

#### Scenario: A URL in the author's second post is grounded
- **WHEN** the LLM returns a download URL that appears in an `extraPosts` entry but not in the first post
- **THEN** that URL is kept and resolved like any other

#### Scenario: Unstated fact is left blank
- **WHEN** the LLM returns a version, license, or changelog text that cannot be found in any opening post
- **THEN** that field is treated as not stated and left blank rather than saved

## ADDED Requirements

### Requirement: Each mod may carry the author's own description, located by anchors
The system SHALL let each mod in the `mods` list carry optional `descriptionAnchors`: the exact opening words and closing words (a few words each, copied verbatim) of the single contiguous section, within one opening post, where the author describes that mod. The model SHALL only point at post text this way; it SHALL NOT return description text of its own. The system SHALL ground the anchors against the opening posts: both anchors must be found in the same post, in order, using a comparison tolerant of HTML entities and whitespace (letters and digits only). Anchors that cannot be located, are out of order, or span posts SHALL be dropped, leaving the mod without `descriptionAnchors`. The prompt SHALL instruct the model to return anchors only when a contiguous section clearly describes one specific mod — most useful on threads carrying several mods.

#### Scenario: A per-mod section in the Downloads post
- **WHEN** a thread's second post describes each of its mods in its own paragraph and the model returns anchors for one mod's paragraph
- **THEN** that mod's `descriptionAnchors` SHALL hold the verbatim opening and closing words, and grounding SHALL confirm both appear in that post in order

#### Scenario: Anchors that do not match the posts
- **WHEN** the model returns anchor words that cannot be found in any opening post
- **THEN** that mod SHALL have no `descriptionAnchors`

#### Scenario: Anchors spanning two posts
- **WHEN** the opening anchor is found in one post and the closing anchor only in another
- **THEN** that mod SHALL have no `descriptionAnchors`

#### Scenario: A single-mod thread
- **WHEN** a thread describes exactly one mod
- **THEN** the mod MAY carry anchors, but consumers are not required to use them — a single-mod thread's description remains the first post
