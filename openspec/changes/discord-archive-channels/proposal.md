## Why

Whether a mod reaches Starmodder depends on where its author posted it. A mod
with a forum thread is visible today. An old mod announced only on Discord is
not. The Unofficial Starsector Chat has four disused mod-announcement channels
going back to April 2017. Mods that were never reposted are missing from the
catalog.

Three channels hold announcements as ordinary messages. The current reader only
walks forum-channel threads. It therefore finds nothing in those channels. The
ported `parseAsSingleMessage` parser can read that older format, but no current
code reaches it and no test covers it.

## What Changes

- The Discord reader handles message channels and thread channels separately.
  Discord types 0 and 5 hold messages. Types 15 and 16 hold threads. A missing
  type keeps the old forum behavior for old raw recordings. A present type that
  the reader does not support fails with a clear log line.
- Only ordinary Discord messages, type 0, become mod announcements. Replies and
  system messages are ignored. Threads attached to message channels are also
  ignored because they are side conversations.
- A channel can be marked `archive` in the config. A complete live read is saved
  once in `discord_archive_cache.json`. Later runs use that saved answer.
- An archive result is never saved from raw replay. It is also never saved after
  a failed request, a failed opt-out check, an unfinished page walk, or an
  unexpected empty result.
- Each completed channel is saved immediately with an atomic file replacement.
  A later failure therefore does not lose earlier network work.
- The saved answer carries a reader version. Any change that can alter a saved
  mod requires a version bump. The next live run then refreshes every archive.
- The cache stores mods before the config's fallback game version is applied.
  The current config label is applied whenever saved mods are loaded.
- **BREAKING (config):** `modrepo_discord_forum_channels` becomes
  `modrepo_discord_channels`. Each entry is
  `<channel id>:<game version>[:archive]`. Unknown third fields and duplicate
  channel ids produce warnings and are skipped.
- Forum threads keep their current limit of 100 messages. Message channels may
  read 200 full pages. A full final page gets one probe request. If older
  messages exist, the read is incomplete and cannot be saved as an archive.
- Four archive channels are added to the example config:
  `1115946075262550016:0.96a:archive`,
  `1104110077075542066:0.96a:archive`,
  `825068217361760306:0.95.1a:archive`, and
  `305506161615175680:0.9.1a:archive`.
- The first run happens against copied data. The measured `mods.json` size from
  that run decides its new tested size limit.

The merge rules are not changed. An old Discord announcement can still change
an existing forum mod by adding a Discord link, source, or image. The dry run
must inspect both new mods and changes to existing mods before publication.

There is no rule that tries to decide whether an old mod is still alive. The
reasons are recorded in
`docs/adr/0001-no-liveness-filter-on-archived-discord-mods.md`. The read-once and
later opt-out rules are recorded in
`docs/adr/0002-archived-discord-channels-are-read-once.md`.

## Capabilities

### New Capabilities

- `discord-archive-channels`: Read message-based Discord mod announcements and
  keep complete results for channels marked as archives.

### Modified Capabilities

<!-- None. The existing scraper-configuration requirements cover the renamed
     key and the startup warning for the removed key. -->

## Impact

- **Code:** `lib/bot/scraper/discord_reader.dart`, `lib/bot/common.dart`,
  `lib/manager/scraper_settings.dart`, `lib/manager/modrepo_service.dart`, a new
  archive store, and generated mapper files.
- **Config:** The Discord channel key is renamed. Each parsed entry becomes one
  named channel-settings value rather than another string map entry.
- **Files on disk:** `discord_archive_cache.json` sits beside the source caches.
  Archive mods are also written to `discord_cache.json` so merge-only jobs keep them.
- **Tests:** Config parsing, channel dispatch, message filtering, complete reads,
  cache recovery, read-once behavior, merge-only behavior, parser fixtures, and
  the measured site-data size.
- **Docs:** `CLAUDE.md`, the example config, and the two decision records.
- **Output:** `ModRepo.json` and the public site gain the accepted archive mods.
  Their file formats do not change.
- **Not affected:** The QB pipeline, publish behavior, and merge rules.
