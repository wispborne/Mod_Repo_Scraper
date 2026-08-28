## 0. Existing Discord reads fail instead of returning partial data

- [x] 0.1 Through `DiscordReader.readAllMessages`, test that a malformed or
  failed message response fails the Discord scrape
- [x] 0.2 Make message-read failures throw `DiscordReadException` instead of
  returning messages collected before the failure
- [x] 0.3 Test and enforce the same rule for failed forum-thread detail reads and
  an archived-thread walk that cannot finish
- [x] 0.4 Test and enforce the same rule for failed author opt-out lookups
- [x] 0.5 Read reaction users in pages of 100 and test an author found on the
  second page
- [x] 0.6 Add a characterization test that keeps forum threads at one page of at
  most 100 messages

## 1. Parse one named setting for each Discord channel

- [ ] 1.1 Add `DiscordChannelSettings` with `channelId`, `gameVersion`, and
  `isArchive`; use a list of these values through `BotConfig`,
  `ModRepoEnvironment`, and `DiscordReader`
- [ ] 1.2 Rename `modrepo_discord_forum_channels` to
  `modrepo_discord_channels` in `Common._recognizedKeys`, with no alias
- [ ] 1.3 Parse `<channel id>:<game version>[:archive]`; a missing third part is
  live and the only accepted third part is `archive`
- [ ] 1.4 Warn and skip an unknown third part or a duplicate channel id; keep
  parsing neighboring entries when one entry is bad
- [ ] 1.5 Test live entries, archive entries, malformed entries, unknown third
  parts, duplicate ids, and both example-config checks through
  `Common.readConfig`
- [ ] 1.6 Update `config.example.properties` with the new key, the four archive
  entries, and a plain-English migration note
- [ ] 1.7 Regenerate `common.mapper.dart` with build runner; do not edit it by
  hand

## 2. Dispatch supported channel and message types explicitly

- [ ] 2.1 Add nullable `type` to `Channel`, with named values for message
  channels 0 and 5 and thread channels 15 and 16
- [ ] 2.2 Through `DiscordReader.readAllMessages`, test types 0, 5, 15, and 16;
  test that a missing type uses the forum path and a present unsupported type
  fails with the channel id and type in the error
- [ ] 2.3 Fetch each channel once, then send it to the message reader or the
  existing thread reader; do not read threads attached to a message channel
- [ ] 2.4 Add required Discord `type` to `Message`; only type 0 direct messages
  can become mods, while replies and system messages are ignored
- [ ] 2.5 Test ordinary messages, replies, thread notices, pin notices, and other
  real system-message fixtures through the public reader
- [ ] 2.6 Pull the 🕸️ author check into one function used by message and thread channels
  without changing its two existing log messages
- [ ] 2.7 Run build runner for the changed `Channel` and `Message` models

## 3. Prove whether a direct-message walk finished

- [ ] 3.1 Keep the existing total limit of 100 messages for one forum thread
- [ ] 3.2 Let a message channel keep up to 200 pages of 100 messages
- [ ] 3.3 When page 200 is full, make one one-message probe request before the
  oldest kept message
- [ ] 3.4 Treat an empty probe as complete; treat a nonempty probe as an
  incomplete read that throws `DiscordReadException` and logs the channel and
  count
- [ ] 3.5 Test a short channel, exactly 20,000 messages, and more than 20,000
  messages through `DiscordReader.readAllMessages`

## 4. Save only complete live archive results

- [ ] 4.1 Add `DiscordArchiveStore`, constructed by `ModRepoService` from
  `ModRepoEnvironment.workingPath` and passed into `DiscordReader`
- [ ] 4.2 Give the file a schema version and each channel entry a reader version;
  keep the stored mods free of the config fallback game version
- [ ] 4.3 Treat a missing, corrupt, or unknown-schema file as an empty cache and
  log why a live rebuild is needed
- [ ] 4.4 Define the reader-version comment to cover parsing, message filtering,
  cleanup, URL and image extraction, and author opt-out behavior
- [ ] 4.5 Never write the archive store while `CachingClient.isReplaying`; a
  replay miss fails the Discord scrape so the manager can use `discord_cache`
- [ ] 4.6 Save an archive entry only after channel metadata, thread lists, thread
  details, allowed message pages, and reaction checks all finish
- [ ] 4.7 Accept an empty archive only when metadata reports no last message or
  thread and the first history response is empty; treat other empty results as
  incomplete
- [ ] 4.8 Save each completed channel immediately by writing beside the cache and
  atomically replacing it
- [ ] 4.9 Apply the current configured fallback game version when live or cached
  mods are added to the run, not before archive storage

## 5. Test cache and merge behavior at public boundaries

- [ ] 5.1 Test that a first complete live read writes one archive entry and a
  second run with the same reader version makes no calls for that channel
- [ ] 5.2 Test that a reader-version change refreshes every archive and that a
  game-version config change does not require a Discord call
- [ ] 5.3 Test that message, thread, reaction, ceiling, and unexpected-empty
  failures write no entry while preserving entries completed earlier in the run
- [ ] 5.4 Test corrupt and unknown-schema cache recovery and atomic replacement
- [ ] 5.5 Test that raw replay never populates the archive store
- [ ] 5.6 Test that archive mods are written into `discord_cache.json` with live
  Discord mods and remain available to a merge-only job
- [ ] 5.7 Add real `parseAsSingleMessage` fixtures covering names, downloads,
  attachments, missing downloads, replies, and system messages

## 6. Document the finished behavior

- [ ] 6.1 Update the Discord section of `CLAUDE.md` with message channels, thread
  channels, archive channels, mod announcements, supported Discord type values,
  and the unchanged 100-message forum limit
- [ ] 6.2 Document complete-read requirements, live-only atomic saves, reader
  version coverage, game-version timing, and the path from archive entries into
  `discord_cache.json`
- [ ] 6.3 Document the manual later-opt-out process: bump the reader version,
  rerun Discord once, rebuild, and publish the removal
- [ ] 6.4 Note that `discord_archive_cache.json` is a derived cache rebuilt after
  corruption or an unknown schema

## 7. Run against copied data before production

- [ ] 7.1 Compile the scraper executable and create a scratch working folder
- [ ] 7.2 Copy `qb_data`, `outputs`, `forum_cache.json`, `nexus_cache.json`, and
  `discord_cache.json` into the scratch folder
- [ ] 7.3 Create a scratch config with an absolute `publish_site_path`, copied
  `qb_data_path`, live Discord reads, and QB, Forum, and Nexus scraping off
- [ ] 7.4 Start the manager against the scratch folder and confirm no process is
  using the real data folder
- [ ] 7.5 Run a Discord-only scrape, then a merge-only job so the copied Forum and
  Nexus caches participate
- [ ] 7.6 Inspect archive counts, parsed names, downloads, and new ids; use merge
  debug and the diff viewer to inspect every changed existing mod
- [ ] 7.7 Measure `mods.json`, then set its tested limit with a stated margin or
  change the file design if one file is no longer reasonable
- [ ] 7.8 Turn real messages from message and thread channels into parser and filtering
  fixtures; run analysis and the full test suite

## 8. Migrate and verify production safely

- [ ] 8.1 Back up real `config.properties`, `qb_data/mod-ids.json`,
  `discord_cache.json`, `outputs`, and generated site files
- [ ] 8.2 Replace the old Discord channel key and add the four archive entries;
  confirm startup reports the expected count with no old-key warning
- [ ] 8.3 Run once and confirm four complete archive entries were saved; run
  again and confirm no archive-channel calls were made
- [ ] 8.4 Review the complete output diff before publishing
- [ ] 8.5 Before publication, rollback restores every backup, removes
  `discord_archive_cache.json`, and restores the old config
