## ADDED Requirements

### Requirement: One topic's history across the saved bundles
The system SHALL be able to build one topic's history from the kept bundle snapshots: walking them oldest to newest, pulling that topic's record from each, and reporting an entry for every neighbouring pair where the record changed. Each entry SHALL name the run that saved the newer snapshot, when it was saved, and the changed fields with their values — list fields excepted, see below. Runs where the topic did not change SHALL produce no entry. Only the fields the bundle comparison already compares SHALL be looked at, using the same labels, so the two pages never disagree about what changed or what to call it.

#### Scenario: A run changed the topic
- **WHEN** a topic's downloads differ between one saved bundle and the next
- **THEN** the history holds an entry naming that run, with "downloads" among its changed fields

#### Scenario: A run did not change the topic
- **WHEN** a run's saved bundle holds the same record for the topic as the one before it
- **THEN** the history holds no entry for that run

#### Scenario: A noisy field moved on its own
- **WHEN** only fields the bundle comparison ignores (such as `scrapedAt`, `replies`, `views`) differ between two saved bundles
- **THEN** the history holds no entry for that run

#### Scenario: The topic entered or left the bundle
- **WHEN** the topic is absent from one saved bundle and present in the next, or the other way round
- **THEN** the history holds an entry saying the topic was first seen in, or dropped from, the saved bundle at that run

#### Scenario: A topic in none of the bundles
- **WHEN** the topic is in none of the kept snapshots
- **THEN** the answer says the topic was never in a bundle, which is a distinct state from a topic that sat unchanged through every one

### Requirement: The history is served by the viewer API
The viewer SHALL serve one topic's history on a route beside the other topic routes. The answer SHALL carry the entries newest first, how many snapshots were readable, and the date of the oldest one — so the page can say where history ends. The answer MUST NOT contain a whole snapshot. Computed histories SHALL be held and reused until the set of kept snapshots changes, without disturbing the two-snapshot cache the compare page relies on.

#### Scenario: Asking for a topic's history
- **WHEN** the browser asks for the history of a topic that changed in two of the kept runs
- **THEN** it receives those two entries, newest first, with the count of snapshots read and the oldest one's date

#### Scenario: A snapshot cannot be read
- **WHEN** one of the kept snapshot files is corrupt
- **THEN** it is skipped, its neighbours are compared across the gap, and the answer's readable-snapshot count reflects the skip

#### Scenario: A new snapshot arrives
- **WHEN** a run saves a new bundle snapshot after a topic's history was already computed
- **THEN** the next ask recomputes the history and the new run's changes appear

### Requirement: List fields are reported item by item
For a changed list field, the history entry SHALL report added, removed and changed items rather than the two whole lists. Rule-based downloads SHALL be lined up by their original URL; a download present in both sides with differing details SHALL report only the details that moved. LLM facts SHALL be lined up by mod name, and within a mod report per part — a download added or dropped, an extra whose value changed shown as old and new for that part alone.

#### Scenario: A download link was added
- **WHEN** the newer saved bundle has one download the older lacks, by original URL
- **THEN** the entry reports that one download as added, and says nothing about the unchanged ones

#### Scenario: A download resolved differently
- **WHEN** a download with the same original URL has a different resolved URL in the newer saved bundle
- **THEN** the entry reports that download once, showing the old and new resolved URL only

#### Scenario: The LLM's version answer moved
- **WHEN** the same mod's version extra differs between the two saved bundles
- **THEN** the entry reports that mod's version as old → new, not the whole LLM answer

### Requirement: The history page
The viewer SHALL show the history as a standalone page reached from the thread page, rendered as a log, newest first: a vertical rail with one entry per changing run, each collapsed to a summary line built from the changed fields' labels and expanded on click to the diff. The foot of the rail SHALL say that older runs are not kept and when history starts. The page SHALL be reachable at both `#/topics/<id>/history` and `#/bundle/<id>/history`, with the breadcrumb running back through the matching list and the thread page.

#### Scenario: Opening a topic's history
- **WHEN** the user clicks History on a thread page
- **THEN** the history page opens for that topic, entries newest first, each summarised in field labels ("post text, downloads")

#### Scenario: Reading one entry
- **WHEN** the user expands an entry
- **THEN** they see the changed fields with old and new values, and list fields item by item

#### Scenario: Nothing ever changed
- **WHEN** the topic is the same in every kept snapshot
- **THEN** the page says so in those words, naming how many saved bundles were checked and the date of the oldest

#### Scenario: Never in a bundle
- **WHEN** the topic is in none of the kept snapshots
- **THEN** the page says the thread is not in any saved bundle, worded apart from "the same in all of them"

#### Scenario: Where history ends
- **WHEN** the user scrolls to the foot of the log
- **THEN** it says older runs are not kept and names the date history starts

### Requirement: Unpublished changes lead the log
When the topic's on-disk data is newer than the published bundle, or the topic is not in the published bundle at all, the history page SHALL show a leading entry styled as unpublished — visually distinct from the saved runs — saying the data on disk has not been published. When the manager is on, this entry SHALL offer the existing Rebuild bundle action. When the bundle is current for this topic, no such entry SHALL appear.

#### Scenario: The topic was re-scraped and not yet published
- **WHEN** the topic's saved data is newer than the published bundle
- **THEN** the log opens with an unpublished entry offering Rebuild bundle (manager on)

#### Scenario: Everything is published
- **WHEN** the published bundle is up to date for this topic
- **THEN** the log opens with the newest saved run, and no unpublished entry is shown

#### Scenario: Viewing only
- **WHEN** the manager is off and the topic has unpublished changes
- **THEN** the unpublished entry appears without a Rebuild button
