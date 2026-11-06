## ADDED Requirements

### Requirement: A saved answer records when it was made
Every answer saved to `llm-extraction-cache.json` SHALL record the time it was made, in UTC, as `answeredAt`. An answer moved to a new fingerprint without a call SHALL keep its time. An answer saved before this field existed SHALL load with no time. The time SHALL NOT be published.

#### Scenario: New answer
- **WHEN** the LLM answers about a post
- **THEN** the saved answer has `answeredAt` set to the time it was saved

#### Scenario: Old cache file
- **WHEN** a cache file written before `answeredAt` existed is read
- **THEN** every answer reads as before, with no time
