## ADDED Requirements

### Requirement: The LLM catch-up job can read every post again
A `llmCoveragePass` request SHALL accept `llmRereadAll` (default false). When it is false, the job SHALL behave as before: only posts with no answer, or whose post or prompt changed, are sent to the LLM. When it is true, the job SHALL also treat every saved answer made before the job started, and every saved answer with no time, as out of date. It SHALL walk forum topics and Discord threads together as one list, in order of their saved answer's time: posts with no answer or no time first, then oldest first. The per-run LLM call limit SHALL still apply. A saved answer SHALL NOT be moved to a new fingerprint in place of a call when it is older than the job's start.

#### Scenario: Only changed
- **WHEN** a `llmCoveragePass` runs without `llmRereadAll`
- **THEN** a post whose saved answer is up to date requires no LLM call

#### Scenario: All, under the call limit
- **WHEN** a `llmCoveragePass` with `llmRereadAll` runs and the call limit is higher than the number of saved posts
- **THEN** every saved post is sent to the LLM once

#### Scenario: All, stopped by the call limit
- **WHEN** an "All" run is stopped by the call limit after reading the oldest 200 posts, and another "All" run starts
- **THEN** the second run starts with the posts the first run did not reach
