## ADDED Requirements

### Requirement: Every page exists
Every page in the nav rail SHALL exist. The Control page SHALL show the real queue and the most recent runs in side panels. When the manager is off, the Control page SHALL say "Viewing only" and how to turn the manager on, in one sentence.

#### Scenario: Unknown address
- **WHEN** the reader opens an address that does not match any page
- **THEN** the page says the address does not match any page, and the frame remains visible

### Requirement: Addresses of the previous viewer
An address of a page in the previous viewer SHALL open the matching page, and the address bar SHALL show the new address without adding a history entry. `#/home` SHALL open Control. `#/topics/<id>` and `#/bundle/<id>` SHALL open that topic's source post page, and the same with `/history` SHALL open its history. `#/discord/<id>` SHALL open that thread's source post page. `#/topics`, `#/bundle` and `#/modrepo` SHALL open Source posts or Mods with the same search. `#/bundle/changes` and `#/merge/changes` SHALL open What changed on the Facts or Mods tab with the same sides. `#/merge` and its group and removal pages SHALL open the matching Catalog explorer page. `#/log` SHALL open Files.

#### Scenario: An old bookmark to a topic
- **WHEN** the reader opens `#/topics/18011`
- **THEN** the source post page for topic 18011 opens, and the address reads `#/posts/topic/18011`

#### Scenario: An old comparison link
- **WHEN** the reader opens `#/bundle/changes?a=x&b=working`
- **THEN** What changed opens on the Facts tab comparing `x` with the data on disk

## REMOVED Requirements

### Requirement: Temporary search
**Reason**: The viewer has its own search (`viewer-v2-search`), and the old viewer is deleted.
**Migration**: None.

### Requirement: Pages not built yet
**Reason**: Every page is built, and the old viewer is deleted.
**Migration**: See "Every page exists".
