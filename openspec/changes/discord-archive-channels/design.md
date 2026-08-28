## Context

`DiscordReader.readAllMessages` currently treats every configured channel as a
forum channel. It lists threads and reads up to 100 messages from each thread.
Three of the four channels added by this change hold mod announcements as direct
messages instead. The current reader silently finds no mods in message channels.

`parseAsSingleMessage` already turns one direct message into one `ScrapedMod`.
It came from the older scraper that read these channels. It is unreachable in
the current path and has no direct-message fixtures.

The scraper runs twice a day. Re-reading fixed archives would waste thousands
of Discord calls each week. The first accepted run also creates permanent site
ids, so an incomplete or badly parsed first result is expensive to repair.

## Goals / Non-Goals

**Goals:**

- Read message channels as one mod announcement per ordinary message.
- Keep the existing forum path at one page of at most 100 messages per thread.
- Save only complete live archive reads.
- Save each completed archive channel before starting the next one.
- Let parser and filtering changes refresh archives through a code-held version.
- Make the first real run reversible until publication is approved.

**Non-Goals:**

- Deciding whether an old mod is still useful or alive.
- Changing merge rules.
- Marking archive-found mods in output files.
- Reducing the cost of live forum channels.
- Rewriting `parseAsSingleMessage` before real fixtures show a problem.

## Existing Groundwork

The current forum reader now fails the Discord source instead of returning a
partial answer when message reads, thread-detail reads, archived-thread walks,
or author opt-out checks do not finish. Reaction users are read in pages of 100.
A test enforces the existing one-page, 100-message forum limit. The archive feature
must keep those guarantees.

## Decisions

### Discord supplies the channel type; config supplies archive status

Discord type 0 (`GUILD_TEXT`) and type 5 (`GUILD_ANNOUNCEMENT`) hold messages.
Types 15 (`GUILD_FORUM`) and 16 (`GUILD_MEDIA`) hold threads. The reader handles
those four values explicitly.

Old raw recordings do not contain `Channel.type`. A missing value therefore
uses the old forum path. A present value that is not supported logs the channel
id and type, then fails the Discord source. Sending an unsupported value down
the forum path could silently produce no mods.

Direct-message history also contains replies and system messages. `Message`
gains its required Discord `type` field. Only ordinary type 0 messages become
mods. Replies, thread notices, pin notices, boosts, and other system messages
are ignored. Threads attached to a message channel are side conversations and
are not read.

### One named config value describes one channel

`modrepo_discord_channels` contains comma-separated entries in this form:

`<channel id>:<game version>[:archive]`

Parsing produces a `DiscordChannelSettings` value with `channelId`,
`gameVersion`, and `isArchive`. A missing third part means live. The only valid
third part is `archive`. Unknown third parts and duplicate channel ids are
warned about and skipped. An entry with fewer than two parts is still ignored,
and one bad entry does not hide its neighbors.

Archive status stays in config because Discord does not expose it. Channel type
stays out of config because Discord does expose it.

The old key remains unsupported, matching the repository's last config rename.
The production migration has an explicit backup and startup check.

### A complete read is required before an archive can be saved

One channel read is complete only when all work required for that channel
finishes:

- channel metadata was read;
- active and archived thread lists finished when the channel holds threads;
- every required thread detail was read;
- every allowed message page finished;
- every author opt-out lookup finished; and
- the walk did not find more direct messages beyond its ceiling.

Any failure throws `DiscordReadException`. The manager then uses the last
complete `discord_cache.json`, as it does for other Discord scrape failures.

The archive store is never written while `CachingClient.isReplaying`. A replay
miss must fail the Discord scrape and fall back to the saved Discord source
cache. It must not create a permanent answer from an old recording.

The four configured archives are known to contain messages. An empty result is
accepted only when Discord channel metadata says there is no last message or
thread and the first history request also returns empty. Any other empty result
is treated as incomplete and is not saved.

### The manager owns the archive store path

`ModRepoService` constructs `DiscordArchiveStore` from
`ModRepoEnvironment.workingPath` and passes it to the reader. `BotConfig` never
supplies a filesystem path.

The file has a small schema version and one entry per channel. Each entry holds
the reader version and unstamped `ScrapedMod` values. A missing file is an empty
store. Invalid JSON or an unknown schema is logged and treated as an empty
store so the live read can rebuild it.

Each complete channel replaces its entry and saves immediately. Saving writes a
temporary file beside the cache and atomically replaces the old file. A crash
cannot leave half a JSON document, and a later channel failure does not lose an
earlier completed channel.

### Reader version covers every saved behavior

The reader version is bumped when any change can alter stored mods. This
includes direct-message parsing, message eligibility, cleanup, URL and image
extraction, and author opt-out handling.

The archive store keeps mods before the channel's fallback game version is
applied. Loading an entry applies the current config value to mods that do not
carry their own game version. Correcting an approximate channel label therefore
does not require a reader-version bump or another Discord read.

### Direct-message pagination proves whether it finished

Forum threads keep the current total limit of 100 messages. This change does not
increase their cost or change which replies their parser sees.

A message channel may keep 200 pages of 100 messages. If page 200 is full, the
reader makes one probe request for one older message. An empty probe proves the
walk ended exactly at 20,000. A nonempty probe means the channel exceeds the
20,000-message limit. The run logs the channel and count, fails that archive read, and
saves nothing for it.

### Later author opt-outs require a deliberate refresh

A read-once cache cannot notice a reaction added later. If an author adds the
🕸️ reaction or asks for removal, the maintainer bumps the reader version and
runs the Discord scrape once. The refreshed result then removes the mod from
`discord_cache.json` and later output. This manual process is accepted because
these channels are disused, but it is recorded as part of the decision rather
than left accidental.

### The dry run examines existing mods as well as new ones

Same-source dedup removes an old announcement only when another Discord copy
also exists. A forum-only current mod can receive the archive's Discord link,
source, or image during a cross-source merge. Merge debug and the existing diff
viewer are therefore required during the dry run.

The `mods.json` limit is not raised in advance. The copied-data run measures the
real result. The test limit is then set with a small stated margin, or the file
is split or trimmed if one file is no longer reasonable.

## Risks and Responses

- **The parser may no longer match current messages.** Run against copied data first, then turn real
  archive messages into tests before touching production data.
- **A channel may contain more than 20,000 messages.** The probe makes that a failed,
  unsaved read instead of a permanent partial result.
- **A config rename can disable Discord.** Back up and edit the real config,
  then require a startup log that names the expected channel count and contains
  no old-key warning.
- **The first live read is slow.** The run instructions state that hundreds of
  Discord requests are expected and that Discord has no two-minute source
  timeout.
- **The archive store can be lost or corrupt.** It is a rebuildable cache. A
  complete live run rebuilds it.

## Migration Plan

1. Implement and test the feature without adding the four production entries.
2. Compile the scraper executable from the repository.
3. Create a scratch working folder. Copy `qb_data`, `outputs`,
   `forum_cache.json`, `nexus_cache.json`, and `discord_cache.json` into it.
4. Put a scratch `config.properties` beside the executable. Point
   `qb_data_path` at the copied data. Use an absolute `publish_site_path`. Turn
   off QB, Forum, and Nexus for the live Discord scrape. Keep
   `modrepo_use_cached=false`.
5. Start the manager against the scratch folder. Confirm no other manager or
   viewer uses the real data folder.
6. Run a Discord-only scrape to populate the copied archive and Discord caches.
   Then run a merge-only job so the copied Forum and Nexus caches participate.
7. Inspect archive counts, parsed names, downloads, and new ids. Use merge debug
   and the diff viewer to inspect every changed existing mod.
8. Check the measured `mods.json` size. Set and test the new limit only after
   that measurement.
9. Add real direct-message fixtures for plain text, several links, attachments,
   no download, replies, system messages, author opt-out, and channel types 0
   and 5. Run analysis and the full test suite.
10. Back up the real `config.properties`, `qb_data/mod-ids.json`,
    `discord_cache.json`, `outputs`, and generated site files. Confirm no publish
    job is running.
11. Replace the old config key, add the four archive entries, and start the real
    run. Confirm startup reports the expected channel count and no old-key
    warning.
12. Confirm `discord_archive_cache.json` contains four complete entries. Run a
    second scrape and confirm no archive-channel calls were made.
13. Review the full output diff before publishing.

Before publication, rollback restores every backup from step 10, removes the
new archive cache, and restores the old config. After publication, removal is a
normal data correction because permanent ids may already have been shared.

## Open Questions

- How many mods do the four channels produce? The scratch run decides the site
  file limit.
- Two game-version labels cover channels that span several game releases. The
  cache design keeps those labels editable without another Discord read.
