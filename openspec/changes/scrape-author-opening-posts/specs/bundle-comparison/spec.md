## MODIFIED Requirements

### Requirement: Only fields worth waking somebody up over are compared
The comparison SHALL cover the topic's title, author, category, last post date, work-in-progress and index flags, source board, the post fingerprint, the extra posts (compared by each post's fingerprint and dates), the images, the links, the assumed downloads, and the LLM-extracted facts. It SHALL NOT report a difference for values that move on every run regardless of whether the topic changed, such as when the topic was last scraped.

#### Scenario: The post text changed
- **WHEN** a topic's post fingerprint differs between the two snapshots
- **THEN** the topic is reported as changed with a plain-English note that the post text changed, and no attempt is made to show the old text, which is not kept

#### Scenario: A follow-up post changed
- **WHEN** an extra post's fingerprint differs between the two snapshots
- **THEN** the topic is reported as changed with a note saying which of the author's follow-up posts changed, without showing the text

#### Scenario: A follow-up post appeared
- **WHEN** the newer snapshot has an `extraPosts` entry the older does not (including snapshots saved before the field existed)
- **THEN** the topic is reported as changed, naming the added post — never as a false "post text changed" on the first post

#### Scenario: A re-scrape that changed nothing
- **WHEN** a run re-scrapes a topic and nothing about it differs except when it was scraped
- **THEN** that topic is counted as unchanged and is not listed

#### Scenario: New LLM facts
- **WHEN** a run gets LLM results for a topic that had none
- **THEN** the topic is reported as changed, naming the facts that appeared
