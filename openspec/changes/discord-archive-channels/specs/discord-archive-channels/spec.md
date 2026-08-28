## ADDED Requirements

### Requirement: Incomplete Discord reads fail instead of returning partial mods

The Discord reader SHALL fail the Discord source when any required channel,
thread, message, or author opt-out request cannot finish. It SHALL NOT return the
mods collected before that failure as a successful scrape.

#### Scenario: A message page fails

- **WHEN** Discord does not return a message list while reading a channel
- **THEN** the Discord read fails with `DiscordReadException` and returns no
  successful partial result

#### Scenario: A forum thread cannot be read

- **WHEN** one listed forum thread cannot provide its required channel details
- **THEN** the Discord read fails instead of silently leaving that thread out

#### Scenario: An archived-thread walk cannot finish

- **WHEN** archived forum-thread pagination reaches its safety limit while
  Discord still says more pages exist
- **THEN** the Discord read fails instead of returning the earlier pages

### Requirement: A Discord channel is read according to its supported type

The Discord reader SHALL read channel types 0 and 5 as message channels and
types 15 and 16 as thread channels. Nothing in `config.properties` SHALL declare
the channel type.

#### Scenario: A thread channel is read thread by thread

- **WHEN** a configured channel has Discord type 15 or 16
- **THEN** the reader walks its active and archived threads and reads at most the
  same 100 messages per thread that it read before this change

#### Scenario: A message channel is read message by message

- **WHEN** a configured channel has Discord type 0 or 5
- **THEN** the reader walks that channel's own messages and does not walk threads
  attached to those messages

#### Scenario: An old recording has no channel type

- **WHEN** a channel answer carries no `type` field
- **THEN** the reader uses the old forum path for compatibility with recorded
  Discord answers

#### Scenario: Discord returns an unsupported channel type

- **WHEN** a channel answer carries a present type other than 0, 5, 15, or 16
- **THEN** the Discord read fails and the log names the channel id and type

### Requirement: Only ordinary messages become mod announcements

The Discord reader SHALL create mods only from ordinary Discord messages with
message type 0 when reading a message channel. It SHALL ignore replies and
system messages even when they contain text.

#### Scenario: An ordinary message is read

- **WHEN** a message channel contains a type 0 message with nonempty text
- **THEN** that message is passed to `parseAsSingleMessage`

#### Scenario: A reply contains text

- **WHEN** a message channel contains a type 19 reply
- **THEN** the reply produces no mod

#### Scenario: A system message contains text

- **WHEN** a message channel contains a nonzero system-message type
- **THEN** the system message produces no mod

### Requirement: The author's opt-out is checked completely

A mod SHALL be left out when the person who wrote its announcement reacted with
the 🕸️ emoji. Reaction users SHALL be paged until Discord returns a short page.
A failed reaction request SHALL fail the Discord read rather than count as no
opt-out.

#### Scenario: The author appears on a later reaction page

- **WHEN** the announcement author appears after the first 100 reaction users
- **THEN** the reader fetches the later page and leaves the mod out

#### Scenario: Somebody else reacts

- **WHEN** the reaction pages finish and none of the users is the announcement
  author
- **THEN** the message produces a mod and the log says the reaction was ignored

#### Scenario: A reaction page fails

- **WHEN** Discord cannot complete the reaction-user walk
- **THEN** the Discord read fails and no archive answer is saved from that run

### Requirement: One parsed value holds each configured Discord channel

Each entry in `modrepo_discord_channels` SHALL be
`<channel id>:<game version>[:archive]` and SHALL become one named settings value
containing those three facts. A missing third part SHALL mean live. The only
accepted third part SHALL be `archive`.

#### Scenario: A live channel

- **WHEN** an entry is `1354895288422236362:0.98a`
- **THEN** the parsed setting is live with fallback game version `0.98a`

#### Scenario: An archive channel

- **WHEN** an entry is `305506161615175680:0.9.1a:archive`
- **THEN** the parsed setting is an archive with fallback game version `0.9.1a`

#### Scenario: An unknown third part

- **WHEN** an entry ends in a value such as `:archvie`
- **THEN** that entry is skipped, a warning names the bad value, and neighboring
  entries are still parsed

#### Scenario: A duplicate channel id

- **WHEN** two entries use the same channel id
- **THEN** the duplicate is skipped and a warning names the id

#### Scenario: A malformed entry

- **WHEN** an entry has fewer than two colon-separated parts
- **THEN** that entry is ignored and neighboring entries are still parsed

### Requirement: Only a complete live archive read is saved

An archive channel SHALL be saved only after its metadata, thread lists, thread
details, allowed message pages, and author opt-out checks all finish. Archive
results SHALL NOT be saved while raw Discord answers are being replayed.

#### Scenario: A first complete live read

- **WHEN** an archive has no current saved entry and every required live request
  finishes
- **THEN** its unstamped mods are saved under the channel id and current reader
  version

#### Scenario: A required request fails

- **WHEN** any required request fails after some mods have been collected
- **THEN** no entry is written for that channel

#### Scenario: Raw replay has no archive answer

- **WHEN** the archive store has no current entry and the HTTP client is replaying
- **THEN** the Discord read fails, the archive store is unchanged, and the
  manager may use the last complete `discord_cache.json`

#### Scenario: A known archive unexpectedly produces nothing

- **WHEN** metadata reports a last message or thread but the completed parser
  result is empty
- **THEN** the result is treated as incomplete and is not saved

#### Scenario: Discord proves an archive is empty

- **WHEN** metadata reports no last message or thread and the first history
  response is empty
- **THEN** an empty complete entry may be saved

### Requirement: Completed channels are saved immediately and atomically

The archive store SHALL save each completed channel before the next channel is
read. It SHALL write a complete replacement file beside the old file and replace
the old file atomically.

#### Scenario: A later channel fails

- **WHEN** one archive was saved and a later archive fails
- **THEN** the earlier completed entry remains available for the next run

#### Scenario: Saving is interrupted

- **WHEN** the process stops while writing the replacement file
- **THEN** the old complete archive file remains readable

### Requirement: Cache recovery and reader versions are explicit

`discord_archive_cache.json` SHALL have a schema version and per-channel reader
versions. A missing, corrupt, or unknown-schema file SHALL be logged and treated
as an empty rebuildable cache. The reader version SHALL change whenever parsing,
message eligibility, cleanup, URL or image extraction, or opt-out behavior can
change saved mods.

#### Scenario: The cache is corrupt

- **WHEN** the archive file cannot be decoded
- **THEN** the run logs the problem and attempts complete live archive reads

#### Scenario: The schema is unknown

- **WHEN** the file's schema version is not supported
- **THEN** the run logs the version and attempts complete live archive reads

#### Scenario: The reader version changes

- **WHEN** a saved entry's reader version differs from the code
- **THEN** that channel is read live again before its entry is replaced

### Requirement: Configured fallback game versions are applied after archive storage

Archive entries SHALL store mods before the configured channel fallback game
version is applied. The current setting SHALL be applied whenever live or saved
mods are added to the run.

#### Scenario: A channel label is corrected

- **WHEN** an archive entry is current and only its configured fallback game
  version changes
- **THEN** the saved mods use the new label without a Discord call

### Requirement: A message-channel ceiling never becomes permanent partial data

A message channel SHALL keep at most 200 pages of 100 messages. When page 200 is
full, the reader SHALL make one probe request for an older message. A nonempty
probe SHALL fail the archive read and SHALL NOT save its partial result.

#### Scenario: A channel has fewer than 20,000 messages

- **WHEN** a short page appears before page 200
- **THEN** the message walk is complete and no ceiling warning is logged

#### Scenario: A channel has exactly 20,000 messages

- **WHEN** page 200 is full and the one-message probe is empty
- **THEN** the message walk is complete with 20,000 messages

#### Scenario: A channel has more than 20,000 messages

- **WHEN** page 200 is full and the one-message probe is nonempty
- **THEN** the read fails, the log names the channel and count, and no archive
  entry is saved

### Requirement: Archive mods remain available to merge-only jobs

Mods loaded from complete archive entries SHALL be included in
`discord_cache.json` beside live Discord mods whenever a Discord scrape succeeds.

#### Scenario: A merge touches no network

- **WHEN** a later merge-only job reads the saved source caches
- **THEN** the archive mods are among the Discord mods it merges

### Requirement: A later author opt-out has a recorded refresh process

The read-once decision SHALL use a manual refresh when an author adds the 🕸️
reaction after the archive was saved. The maintainer SHALL bump the reader
version, rerun Discord once, rebuild outputs, and publish the removal.

#### Scenario: An author opts out after the first archive read

- **WHEN** the maintainer is told that an author added the opt-out reaction
- **THEN** the archive is refreshed through a reader-version bump before the
  removal is published
