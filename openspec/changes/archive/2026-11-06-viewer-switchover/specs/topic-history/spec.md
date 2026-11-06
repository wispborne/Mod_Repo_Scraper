## MODIFIED Requirements

### Requirement: The history page
The viewer SHALL show the history as a standalone page reached from the topic's source post page, rendered as a log, newest first: a vertical rail with one entry per changing run, each collapsed to a summary line built from the changed fields' labels and expanded on click to the diff. The foot of the rail SHALL say that older runs are not kept and when history starts. The page SHALL be at `#/posts/topic/<id>/history`, with the breadcrumb running back through Source posts and the source post page.

#### Scenario: Opening a topic's history
- **WHEN** the user clicks History on a topic's source post page
- **THEN** the history page opens for that topic, entries newest first, each summarised in field labels ("post text, downloads")

#### Scenario: Reading one entry
- **WHEN** the user expands an entry
- **THEN** they see the changed fields with old and new values, and list fields item by item

#### Scenario: Nothing ever changed
- **WHEN** the topic is the same in every kept snapshot
- **THEN** the page says so in those words, naming how many saved bundles were checked and the date of the oldest

#### Scenario: Never in a bundle
- **WHEN** the topic is in none of the kept snapshots
- **THEN** the page says the thread is not in any saved bundle, using different wording from "the same in all of them"

#### Scenario: Where history ends
- **WHEN** the user scrolls to the foot of the log
- **THEN** it says older runs are not kept and names the date history starts
