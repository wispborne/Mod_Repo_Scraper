## ADDED Requirements

### Requirement: All LLM output lives in one per-topic override block
The system SHALL write every LLM-produced field for a topic into a single per-topic `llm` block, keyed by topic ID: the reconciled `downloads` list and the extras (version, changelog, support links, license, summary). Adding a future LLM-extracted field SHALL mean adding it to that block only, with no change to the rule-based base layer. Fields that the LLM did not produce SHALL be omitted, and a topic with no LLM output SHALL have no entry in the block.

#### Scenario: Downloads and extras share one block
- **WHEN** the LLM extracts both a download and a version for a topic
- **THEN** both SHALL appear under the same `llm.<topicId>` entry

#### Scenario: New LLM field is additive
- **WHEN** a new LLM-extracted field is introduced later
- **THEN** it SHALL appear under `llm.<topicId>` alongside the existing fields, and the rule-based base layer SHALL be unaffected

#### Scenario: Empty result yields no entry
- **WHEN** the LLM returns nothing grounded for a topic
- **THEN** that topic SHALL have no entry in the `llm` block

## MODIFIED Requirements

### Requirement: Downloads are a list, reconciled with the rules in one call
The system SHALL keep downloads as a per-topic list that may hold more than one link. It SHALL give the rule-based resolver's found links (as their original post URLs) to the LLM inside the single extraction call, so the LLM can confirm them, add ones the rules missed, and drop any that are not downloads, in one pass — with no separate tie-break call. The merged list SHALL be the de-duplicated union of the rule links and the LLM's reconciled links, matched on the normalized original URL (not the resolver's resolved URL). When the LLM drops or overrides a rule link, its one-line reason SHALL be recorded on that entry. This reconciled list SHALL be written into the topic's `llm` block (as `llm.<topicId>.downloads`) and SHALL NOT overwrite the rule-based `assumedDownloads` list.

#### Scenario: Only one side finds a link
- **WHEN** the rules find no download but the LLM finds a grounded one (e.g. inside a spoiler or on an unknown host)
- **THEN** the LLM's download is added to the reconciled list in the `llm` block, tagged `source: llm`

#### Scenario: Both find the same file
- **WHEN** the rules and the LLM point at the same download (the rules' resolved link and the LLM's original post link refer to one file)
- **THEN** the reconciled list contains that file once, matched on the normalized original URL, tagged `source: rules+llm`, with no duplicate entry

#### Scenario: The LLM rejects a rule link
- **WHEN** the rules flagged a link as a download but the LLM, seeing the whole post, judges it is not the mod's download
- **THEN** the reconciled entry in the `llm` block reflects the LLM's decision and its one-line reason is saved — all from the single call, with no extra request

#### Scenario: A mod offers a mirror
- **WHEN** a post offers the same file on two hosts
- **THEN** both links may appear in the reconciled downloads list

#### Scenario: Rule-based list is left intact
- **WHEN** the LLM produces a reconciled download list for a topic
- **THEN** the topic's `assumedDownloads` entry SHALL still contain the rule-based candidates, unchanged, so a consumer with LLM downloads turned off sees the rules result

## REMOVED Requirements

### Requirement: Output stays backwards-compatible
**Reason**: This requirement made LLM data additive *inside* the shared `assumedDownloads` list (optional `source`/`llmReason` tags) plus a separate extras section, so that pre-change readers kept working. The change separates the layers instead: `assumedDownloads` is now pure rules-based and all LLM output moves into a dedicated `llm` block. Since no consumer reads LLM data yet, the overlay-compatibility contract is unnecessary and the shared-list tagging no longer applies. Provenance (`source`/`llmReason`) still exists, but only on entries inside the `llm` block.
**Migration**: Consumers SHALL read rule-based downloads from `assumedDownloads` and LLM-sourced downloads and extras from `llm.<topicId>`. There are no `source`/`llmReason` tags on `assumedDownloads` entries; those fields appear only on `llm.<topicId>.downloads` entries. Turning LLM data off means ignoring the `llm` block entirely.
