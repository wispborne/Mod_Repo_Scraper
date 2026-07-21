## ADDED Requirements

### Requirement: Every stored post is covered by the LLM

When the feature is enabled, the system SHALL ensure that every topic held in the mods index either already has fresh LLM output or is sent to the LLM during the run — regardless of whether that topic was scraped in this run. Coverage SHALL be decided by the extraction store's freshness check (the post content, the prompt version, and the requested field set), not by whether the scraper happened to fetch the topic. A topic whose stored output is already fresh SHALL be served from the store without a live call. The post content sent SHALL include spoiler-box contents (which the regex link extractor drops).

The system SHALL supply each topic's rule-based download candidates alongside the post, taking them from the resolver's cache for topics that were not scraped this run.

#### Scenario: A topic scraped in an earlier run is picked up

- **WHEN** the feature is enabled and the store holds a topic that has never been sent to the LLM, and that topic is not scraped this run (for example because the incremental scope found it unchanged)
- **THEN** that topic's stored post is sent to the LLM during this run and its output is written to the store and the bundle

#### Scenario: A topic scraped this run is not paid for twice

- **WHEN** a topic is scraped this run and its post is sent to the LLM as part of the run's coverage
- **THEN** the topic SHALL result in exactly one live LLM call, not one per visit

#### Scenario: An unchanged, already-extracted topic costs nothing

- **WHEN** a topic's stored LLM output is fresh for the current post content, prompt version, and field set
- **THEN** the topic SHALL be served from the store with no live LLM call

#### Scenario: A changed post is re-extracted

- **WHEN** a topic's post content changed since its LLM output was stored, or the prompt version or field set changed
- **THEN** the topic SHALL be sent to the LLM again and its stored output replaced

### Requirement: A run may cap how many live LLM calls it makes

The system SHALL honor `llm_max_topics` as a cap on the number of live LLM calls a single run may make. When the cap is reached, the run SHALL stop making calls, SHALL keep the results it already obtained, and SHALL complete normally (writing the store and the bundle) rather than failing. Because stored results are reused across runs, a later run SHALL continue from where the capped run stopped. When `llm_max_topics` is unset, the run SHALL cover every stored topic that needs a call.

#### Scenario: Backlog worked through in bounded chunks

- **WHEN** `llm_max_topics` is set to 100 and 950 stored topics need extraction
- **THEN** the run SHALL make at most 100 live calls, save them, and finish; the next run SHALL pick up the remaining topics rather than repeating the first 100

#### Scenario: No cap set

- **WHEN** `llm_max_topics` is unset
- **THEN** the run SHALL send every stored topic that lacks fresh output to the LLM

### Requirement: The run reports LLM coverage

The system SHALL report, at the end of an enabled LLM run, how many stored topics were covered, how many required a live call, and how many still lack output (for example because the per-run cap was reached), so that an incomplete bundle is visible in the log rather than silent.

#### Scenario: Incomplete coverage is stated

- **WHEN** a run ends with stored topics still lacking LLM output because `llm_max_topics` was reached
- **THEN** the log SHALL state how many topics remain without output

## REMOVED Requirements

### Requirement: Each scraped post is read once by the LLM

**Reason**: The coverage rule was tied to whether a topic was scraped in the current run. Because the normal scope (`new_data`) scrapes only changed topics, topics already stored before the feature was enabled were never visited and so never extracted, leaving the bundle permanently incomplete (79 of 1030 mods). Coverage is now defined over the store rather than over the current run's scrape.

**Migration**: Replaced by "Every stored post is covered by the LLM", which keeps the once-per-run-per-topic and cache-hit behavior but decides coverage from the extraction store's freshness check instead of the scrape. No config keys change. The first enabled run after this change extracts the previously-skipped backlog; `llm_max_topics` bounds it.
