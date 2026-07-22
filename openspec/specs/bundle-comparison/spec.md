# bundle-comparison

## Purpose

Show what changed between two saved bundles, so a run can be judged on what it actually altered rather than guessed at.
## Requirements

### Requirement: What changed between two bundles
The system SHALL be able to compare two saved bundle snapshots and report topics **added** (in the newer, not the older), **gone** (in the older, not the newer), and **changed** (in both, with at least one differing field, naming the fields and both values). Topics that are the same in both SHALL be counted but not listed. The comparison SHALL be searchable by topic title and author and served paged, and MUST NOT return a whole snapshot to the browser.

#### Scenario: Judging what a run did
- **WHEN** the user compares the bundle from before a run with the one after it
- **THEN** they see which topics were added, which are gone, and which changed, with the changed fields named

#### Scenario: Searching the differences
- **WHEN** the user types a mod name into the comparison search box
- **THEN** only differences involving a topic whose title or author matches are shown, paged

#### Scenario: Comparing a bundle with itself
- **WHEN** the same snapshot id is given twice
- **THEN** nothing is added, gone or changed, and the same-count equals the topic count

### Requirement: Topics are lined up by topic id
When matching topics between two bundle snapshots, the system SHALL use the forum topic id. A topic id present in one snapshot and not the other SHALL be reported as added or gone, never as changed.

#### Scenario: A newly scraped topic
- **WHEN** a topic appears in the newer snapshot only
- **THEN** it is reported as added, with its title and author

### Requirement: Only fields worth waking somebody up over are compared
The comparison SHALL cover the topic's title, author, category, last post date, work-in-progress and index flags, source board, the post fingerprint, the images, the links, the assumed downloads, and the LLM-extracted facts. It SHALL NOT report a difference for values that move on every run regardless of whether the topic changed, such as when the topic was last scraped.

#### Scenario: The post text changed
- **WHEN** a topic's post fingerprint differs between the two snapshots
- **THEN** the topic is reported as changed with a plain-English note that the post text changed, and no attempt is made to show the old text, which is not kept

#### Scenario: A re-scrape that changed nothing
- **WHEN** a run re-scrapes a topic and nothing about it differs except when it was scraped
- **THEN** that topic is counted as unchanged and is not listed

#### Scenario: New LLM facts
- **WHEN** a run gets LLM results for a topic that had none
- **THEN** the topic is reported as changed, naming the facts that appeared

### Requirement: A run says what it changed
A run's detail page SHALL offer a link to what that run changed, when the run saved a bundle snapshot and an older snapshot exists to compare against. Following it SHALL open the comparison with that run's snapshot and the one before it already chosen.

#### Scenario: Asking what a run did
- **WHEN** the user opens a finished run that published a bundle and follows the what-changed link
- **THEN** the comparison opens with that run as the newer side and the run before it as the older side

#### Scenario: The first run ever
- **WHEN** a run's snapshot is the only one saved
- **THEN** no link is offered, because there is nothing to compare against
