## ADDED Requirements

### Requirement: A Discord channel is read according to its shape

The Discord reader SHALL work out whether a channel keeps one mod per thread or one mod per message from the `type` field Discord returns for that channel, and SHALL read it accordingly. Nothing in `config.properties` SHALL declare a channel's shape. A channel whose type Discord does not give SHALL be read as a forum channel, which is what every channel read before this change was.

#### Scenario: A forum channel is read thread by thread

- **WHEN** a configured channel's type says it is a forum channel
- **THEN** the reader walks that channel's active and archived threads and reads each thread's messages, exactly as it did before this change

#### Scenario: A text channel is read message by message

- **WHEN** a configured channel's type says it is a plain text channel
- **THEN** the reader walks that channel's own messages, and each message that has any text in it becomes one mod

#### Scenario: A text channel's threads are left alone

- **WHEN** a plain text channel has threads hanging off it
- **THEN** those threads are not read, so a mod announced in the channel cannot arrive twice from the same channel

#### Scenario: Discord does not say what kind of channel it is

- **WHEN** the answer for a channel carries no type
- **THEN** the reader treats it as a forum channel

### Requirement: The author's opt-out works the same in both shapes

A mod SHALL be left out when the person who wrote the post reacted to their own post with the 🕸️ emoji, whether that post is a message in a text channel or a message in a forum thread. A 🕸️ from anybody other than the post's own author SHALL leave the mod in.

#### Scenario: The author opts a message out

- **WHEN** a message in a text channel carries a 🕸️ reaction and the person who reacted is the person who wrote it
- **THEN** that message produces no mod, and the run's log says which mod was skipped and why

#### Scenario: Somebody else reacts

- **WHEN** a message carries a 🕸️ reaction and nobody who reacted wrote it
- **THEN** the message produces a mod as usual, and the run's log says the reaction was ignored

### Requirement: A channel entry says its id, its game version and whether it is an archive

Each entry in `modrepo_discord_channels` SHALL be `<channel id>:<game version>[:archive]`. The game version SHALL be given to every mod read from that channel that does not carry one of its own. The optional third part SHALL mark the channel as one nobody posts in any more. An entry with fewer than two parts SHALL be ignored, as it is today.

#### Scenario: A live channel

- **WHEN** an entry is `1354895288422236362:0.98a`
- **THEN** the channel is read on every run, and its mods are labelled `0.98a`

#### Scenario: An archive channel

- **WHEN** an entry is `305506161615175680:0.9.1a:archive`
- **THEN** the channel is treated as an archive, and its mods are labelled `0.9.1a`

#### Scenario: A malformed entry

- **WHEN** an entry has no colon in it
- **THEN** that entry is ignored and the rest of the list is still read

### Requirement: An archive channel is read once and its answers are kept

A channel marked `archive` SHALL be read from Discord only when there is no saved answer for it, and its mods SHALL be saved to `discord_archive_cache.json` in the working folder, keyed by channel id. On every later run its mods SHALL come from that file with no calls to Discord. The saved mods for an archive channel SHALL be included in the Discord source's own `<name>_cache.json` alongside the live channels' mods, so that a merge which touches no network still sees them.

#### Scenario: First run over an archive channel

- **WHEN** an archive channel is configured and `discord_archive_cache.json` holds nothing for it
- **THEN** the channel is read from Discord and its mods are written to that file under its channel id

#### Scenario: Later runs over the same archive channel

- **WHEN** an archive channel is configured and `discord_archive_cache.json` already holds its mods for the current reader version
- **THEN** those mods are used and no call is made to Discord for that channel

#### Scenario: A merge that touches no network

- **WHEN** a merge runs against what is already saved, with no scrape
- **THEN** the archive channels' mods are among the Discord mods it merges

### Requirement: A version number in the code forces archives to be read again

The saved answers for an archive channel SHALL be keyed on a version number held in the code as well as on the channel id. When that number does not match the one a saved answer was written under, the channel SHALL be read from Discord again and the saved answer replaced. Nothing on the machine running the scraper SHALL have to be edited or deleted for this to happen.

#### Scenario: The reader is changed

- **WHEN** the version number in the code is raised and a run starts
- **THEN** every archive channel is read from Discord again and its saved answers are written afresh

#### Scenario: The version number is unchanged

- **WHEN** a run starts and the version number matches what the saved answers were written under
- **THEN** no archive channel is read from Discord

### Requirement: The message walk says when it stops early

The number of pages of messages the reader will ask for SHALL be set by whoever calls it: at most 25 pages for one forum thread and at most 200 pages for a text channel. When the walk stops because it reached that ceiling rather than because it ran out of messages, the run's log SHALL say so, naming the channel and how many messages were read.

#### Scenario: A channel with fewer messages than the ceiling

- **WHEN** a text channel holds 1,400 messages
- **THEN** all 1,400 are read, the walk stops because a short page came back, and nothing is logged about a ceiling

#### Scenario: A channel with more messages than the ceiling

- **WHEN** a text channel holds more messages than 200 pages can carry
- **THEN** the walk stops at the ceiling and the log says the channel was cut short and how many messages were read
