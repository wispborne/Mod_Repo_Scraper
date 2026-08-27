## 1. The config entry gains a third part, and the key is renamed

- [ ] 1.1 In `lib/bot/common.dart`, rename `modrepo_discord_forum_channels` to `modrepo_discord_channels` in `_recognizedKeys` — the old name is gone with no alias, so an unedited config file is caught by the existing unknown-key warning
- [ ] 1.2 Rename `BotConfig.discordForumChannelIdsAndGameVersions` to `discordChannelsAndGameVersions`, and follow the renames through `lib/bot/scraper/discord_reader.dart`, `lib/manager/scraper_settings.dart` and `lib/manager/modrepo_service.dart`
- [ ] 1.3 Change what `_parseForumChannelIds` returns so an entry can say it is an archive: `<channel id>:<game version>[:archive]`. Keep the existing rule that an entry with fewer than two parts is ignored, and keep the whole list readable when one entry is malformed
- [ ] 1.4 Rename that parser to match what it now parses, and give it a comment saying why archive-ness is in the config when the channel's shape is not
- [ ] 1.5 Run `dart run build_runner build --delete-conflicting-outputs` — `BotConfig` is a `@MappableClass`, so `common.mapper.dart` has to be regenerated, never hand-edited
- [ ] 1.6 Update `config.example.properties`: the new key name, the four new channels, and a plain-English note saying what the third part means and that Discord tells us the rest
- [ ] 1.7 Tests in `test/config_test.dart` — the new key reads, an entry with `:archive` is marked, an entry without it is not, a malformed entry is skipped and its neighbours still read, and both existing example-config tests still pass

## 2. The reader learns there are two shapes of channel

- [ ] 2.1 Add `type` to the `Channel` model in `lib/bot/scraper/discord_reader.dart`, with named constants for Discord's numbering (15 forum, 16 media, 0 text) and a helper saying whether each post in this channel is its own thread
- [ ] 2.2 Make an unknown or missing type fall back to the forum path, so a Discord API change cannot turn a working channel silent
- [ ] 2.3 Run `build_runner` again — `Channel` is a `@MappableClass` too
- [ ] 2.4 Split the per-channel work: fetch the channel once, then send it to either the thread reader or the new message reader. `_readAllThreadsFromForumChannelId` takes the already-fetched `Channel` instead of fetching its own
- [ ] 2.5 Pull the 🕸️ opt-out check out of the thread loop into one function both readers call, keeping its two log lines word for word — the check is per message, and a reaction only counts when it came from the person who wrote the post
- [ ] 2.6 Write the text-channel reader: walk the channel's own messages, drop the ones with no text, apply the opt-out check, run each survivor through the existing `parseAsSingleMessage`, then `_cleanUpMod` and drop empty names — the same tail the thread reader already has
- [ ] 2.7 Do not read threads hanging off a text channel, and say why in a comment: these channels are announcement-only, so a thread is a side conversation and reading both would bring one mod in twice

## 3. The message walk stops loudly

- [ ] 3.1 Give `_getMessages` a page ceiling the caller picks, with named constants — 25 pages for a forum thread as now, 200 for a text channel
- [ ] 3.2 Log when the walk stops because it hit the ceiling rather than because a short page came back, naming the channel and how many messages were read
- [ ] 3.3 Test both: a channel smaller than the ceiling is read whole with nothing logged about it, and one larger stops and says so

## 4. An archive channel is read once

- [ ] 4.1 Write the archive store — one file, `discord_archive_cache.json`, in the working folder beside the other per-source caches, holding each archive channel's mods keyed by channel id, plus the reader version they were written under
- [ ] 4.2 Add the reader version constant with a comment saying to bump it whenever the message parser changes, and pointing at `ExtractionPrompt.promptVersion` as the same idea in the QB pipeline
- [ ] 4.3 In `readAllMessages`, take an archive channel's mods from the store when they are there and the version matches; otherwise read it from Discord and write them
- [ ] 4.4 Make sure the archive mods go into the Discord source's own `discord_cache.json` alongside the live channels' mods when a scrape writes it — a merge that touches no network reads only that file, so leaving them out loses every archive mod silently
- [ ] 4.5 Test: a first run reads an archive from Discord and writes the store; a second run with the same version makes no Discord calls for it; raising the version makes the next run read it again
- [ ] 4.6 Test: a merge with no scrape still sees the archive channels' mods
- [ ] 4.7 Check the file is covered by the existing `/*_cache.json` line in `.gitignore` rather than adding a new one

## 5. The four channels, and the size limit

- [ ] 5.1 Add the four channels to `config.example.properties`: `1115946075262550016:0.96a:archive`, `1104110077075542066:0.96a:archive`, `825068217361760306:0.95.1a:archive`, `305506161615175680:0.9.1a:archive`
- [ ] 5.2 Check every game version is spelled the way `ModRepo.json` already spells it — `0.9.1a` not `0.91`, `0.95.1a` not `0.95` — since the string goes through `Version.parse` and drives the site's version filter
- [ ] 5.3 Raise the pinned limit in `test/site/public_data_builder_test.dart` from 2 MB to 3 MB, with a comment saying why it moved

## 6. Docs

- [ ] 6.1 Add the vocabulary to the Discord part of `CLAUDE.md`: forum channel (one mod per thread), text channel (one mod per message), archive channel (nobody posts there, read once), announcement (one post, one mod)
- [ ] 6.2 Write down the read-once rule, the version number that forces a re-read, and the trap that archive mods have to reach `discord_cache.json` or a merge-only run loses them
- [ ] 6.3 Note in `CLAUDE.md`'s caching section that `discord_archive_cache.json` is a third kind of thing on disk — a derived cache that is never invalidated by age, only by the version number

## 7. The careful first run

- [ ] 7.1 Copy `qb_data` and `outputs` into a scratch folder, and make a config pointing `qb_data_path` at the copy with the four channels turned on
- [ ] 7.2 Run the scraper with that folder as its working directory, and check the viewer server is not running against the real folder
- [ ] 7.3 Read the run: how many mods each archive channel produced, what names they got, and what ids `mod-ids.json` in the copy handed out. Look for mangled names, which is what a drifted parser looks like
- [ ] 7.4 Check `mods.json` in the copy against the 3 MB limit, and say plainly if it does not fit — that is a decision to take before publishing, not after
- [ ] 7.5 Take a dozen real messages from the run — a plain one, one with several links, one with an attachment, one with no download — and turn them into `parseAsSingleMessage` tests in `test/discord_reader_test.dart`, checking the name and the right download for each
- [ ] 7.6 Throw the copy away, run for real, and check that the archive cache was written and a second run makes no Discord calls for those channels
