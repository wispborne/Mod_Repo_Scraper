## Why

Whether a mod reaches Starmodder depends on where its author happened to post. A 2016 mod with a forum thread is on the site today; a 2016 mod announced only on Discord is nowhere at all. The Unofficial Starsector Chat has four disused mod-announcement channels going back to April 2017, and every mod in them that never got a forum thread and was never reposted is invisible to us.

Three of those four are plain text channels, from before Discord had forum channels. The reader only knows how to walk a forum channel's threads, so pointing it at a text channel today would find nothing and say nothing. The single-message parser it would need (`parseAsSingleMessage`) is still in the file — it came across in the Dart port from the earlier scraper, which was written for exactly these channels — but nothing can reach it and no test covers it.

## What Changes

- The Discord reader learns that a channel comes in two shapes. A **forum channel** keeps one mod per thread, which is what it already handles. A **text channel** keeps one mod per message, read through the existing `parseAsSingleMessage`. Discord's own `type` field on the channel says which it is, so nothing in the config declares it.
- Threads inside a text channel are ignored. These channels are announcement-only, so a thread there is a side conversation, and reading both would bring the same mod in twice from one channel.
- A channel can be marked as an **archive** in the config, meaning nobody posts there any more. An archive is read once; its mods are saved in a new `discord_archive_cache.json`, keyed by channel id, and later runs use that instead of calling Discord. Archive-ness is marked by hand because nothing in Discord's API says whether a channel is still in use — one of the four dead channels is a forum channel, so it cannot be worked out from the channel type either.
- The saved archive answers carry a version number that lives in the code and forms part of their key. Bumping it re-reads every archive on the next run, so a parser fix takes effect without anyone logging into the production server. Same mechanism as `ExtractionPrompt.promptVersion` in the QB pipeline.
- **BREAKING (config)**: `modrepo_discord_forum_channels` is renamed to `modrepo_discord_channels`, with no alias. The startup unknown-key warning is what catches an unedited config file — the same way commit `176b630` handled the last round of key renames. Each entry gains an optional third part: `<channel id>:<game version>[:archive]`.
- The message walk's page ceiling becomes the caller's choice — 25 pages (2,500 messages) for a forum thread as now, 200 pages (20,000 messages) for a text channel — and says so in the log when it stops early. It has never mattered for threads; an archive channel holding more than 2,500 announcements would have been silently truncated to the newest ones, which are exactly the ones most likely to be duplicates of mods we already have.
- Four channels are added to the config: `1115946075262550016` (0.96a, forum, archive), `1104110077075542066` (0.96a, text, archive), `825068217361760306` (0.95.1a, text, archive) and `305506161615175680` (0.9.1a, text, archive).
- `mods.json`'s pinned size limit goes from 2 MB to 3 MB. It is at 1.41 MB with about 450 mods of headroom, and this change is expected to add more than that.

Deliberately **not** changed: there is no rule that tries to work out whether an old mod is still alive, and the merge is not touched — an old announcement of a mod that still exists is grouped with it and discarded by same-source dedup, which is correct. Reasoning for both is in `docs/adr/0001-no-liveness-filter-on-archived-discord-mods.md` and `docs/adr/0002-archived-discord-channels-are-read-once.md`.

## Capabilities

### New Capabilities

- `discord-archive-channels`: Reading a Discord text channel as one mod per message alongside the existing one-mod-per-thread forum channels, and reading a channel marked as an archive once rather than on every run, with a code-held version number to force a re-read.

### Modified Capabilities

<!-- None. The config key rename is already governed by the existing requirements in
     `scraper-configuration` — "Config keys follow one naming scheme" covers the new
     name, and "Unknown config keys produce a startup warning" covers the old one.
     Neither requirement's text changes. The new `:archive` part of a channel entry is
     behaviour of the new capability, not of the config spec. -->

## Impact

- **Code**: `lib/bot/scraper/discord_reader.dart` (channel-shape dispatch, the text-channel read, the extracted no-scrape check, the page ceiling), `lib/bot/common.dart` (the renamed key, the third part of a channel entry, `BotConfig.discordForumChannelIdsAndGameVersions` renamed to `discordChannelsAndGameVersions`), a new small store for the archive results, and the Discord wiring in `lib/manager/modrepo_service.dart`.
- **Config**: `modrepo_discord_forum_channels` gone, `modrepo_discord_channels` in its place with four more channels; `config.example.properties` and `Common._recognizedKeys` updated together.
- **Files on disk**: a new `discord_archive_cache.json` beside the existing per-source caches, gitignored by the existing `/*_cache.json` rule. The archive mods must also end up inside `discord_cache.json` with the live ones, or a merge-only run — which never touches the network — would lose every one of them.
- **Tests**: `test/config_test.dart` (the renamed key, the `:archive` part), `test/discord_reader_test.dart` (the dispatch, and fixtures for `parseAsSingleMessage` built from real archived messages), `test/site/public_data_builder_test.dart` (the raised size limit).
- **Docs**: the Discord section of `CLAUDE.md` gains the vocabulary — forum channel, text channel, archive channel, announcement — and the read-once rule.
- **Output**: `ModRepo.json` and the site grow by however many mods the archives hold; the shape of neither file changes, and TriOS keeps reading `ModRepo.json` exactly as it does now.
- **Collides with**: `openspec/changes/discord-incremental-cache`, an unstarted proposal that reworks the same per-thread fetch path and is designed entirely around threads. This change lands first, so that one can be written against a reader that already knows there are two kinds of channel.
- **Not affected**: the QB pipeline, the results viewer, the publish step, and the merge itself.

---

## Review notes (not applied — nothing above this line has been changed)

A review of this change against the code, the git history, and the tests. Nothing
here has been acted on; the proposal, design, specs and tasks above are exactly
as they were written.

### Summary

The change is in good shape. Most of its claims are true, and the validator
passes. But there are two problems that should be fixed before anyone builds
this, and a few smaller ones.

### Claims verified as true

- `parseAsSingleMessage` really is dead code. Every message gets a parent thread
  attached at [discord_reader.dart:175](lib/bot/scraper/discord_reader.dart:175),
  so the branch that calls it can never run. It has no tests.
- The description of how the Discord caches fall back to each other matches the
  code.
- Commit `176b630` did rename all the config keys at once with no aliases, so the
  precedent is real.
- Both ADRs exist and say what the proposal says they say.
- The `.gitignore` rule and the 2 MB test are where the proposal says they are.
- The four channel ids contain their creation dates, and those dates match the
  design: April 2017, March 2021, May 2023, June 2023. The game-version labels
  fit those dates.

### Problem 1: a failed read gets saved forever

This is the worst one, and none of the documents mention it.

The plan is: read an archive channel once, save the answer, never ask Discord
again. But the code that reads messages does not fail loudly. If Discord returns
an error — bad token, or the bot can't see an old channel — the read returns an
empty list and only logs a warning
([discord_reader.dart:704](lib/bot/scraper/discord_reader.dart:704)). If the
network dies halfway, it returns a partial list.

So the first run could save "this channel has no mods" or "this channel has half
its mods" as the permanent answer. Nothing would ever retry, because not retrying
is the whole point of the archive cache.

There's a second way to hit the same trap. A dev run with
`modrepo_use_cached=true` replays old recorded Discord answers instead of calling
Discord. Those recordings don't include the archive channels. So the read comes
back empty, and that empty answer gets saved.

The fix: only save an archive answer when the read finished without errors. Never
save an empty answer. Never save while replaying. The spec needs a scenario for
this.

### Problem 2: the spec describes the current code wrongly, and following it would change behaviour

The proposal says a forum thread is currently read up to "25 pages (2,500
messages)". That's not what the code does. The thread walk passes `limit: 100`
([discord_reader.dart:171](lib/bot/scraper/discord_reader.dart:171)), so a thread
reads **one page of 100 messages** and stops. The 25-page guard exists but never
comes into play.

Why this matters: the spec says the new ceiling for a thread is "at most 25
pages". If someone implements that literally and removes the 100-message limit,
two things change. Long threads cost up to 25 times as many API calls. And the
thread parser starts seeing messages it never saw before, which can change which
download link a mod ends up with. The design explicitly promises the forum path
stays exactly as it is — so the spec contradicts its own goal.

The fix is just wording: keep the 100-message limit for threads, and describe the
page ceiling as a new, separate knob.

### Problem 3: announcement channels would still be silent

The new code recognizes three channel types: forum (15), media (16), and text
(0). Anything else is read as a forum channel.

Discord has another type: announcement channels, type 5. They hold messages
directly, like text channels. If any of the four old channels is type 5, it gets
read as a forum channel, finds no threads, and produces nothing — which is
exactly the bug this change is supposed to fix.

The design says the forum fallback is safe because "a Discord API change cannot
turn a working channel into a silent one". For text-shaped channels it's the
opposite: the forum fallback **is** the silent path.

Fix: treat type 5 like text, or at least log every channel's type number so the
dry run shows what these channels actually are.

### Problem 4: Discord's system messages could become fake mods

A text channel's history isn't just posts. It also has system messages:
"so-and-so pinned a message", "so-and-so started a thread", server boosts. The
`Message` model has no field to tell these apart.

The tasks say to drop messages with no text, and most system messages have empty
text — but not guaranteed all of them. Any that slip through become mods, and
mods get permanent web addresses.

Fix: add the message `type` field to the model and only keep ordinary messages
(types 0 and 19). Or at minimum, add "look for system-message junk" to the
dry-run checklist.

### Problem 5: nobody decided when the game-version label gets applied

Mods from a channel get that channel's game version stamped on them
([discord_reader.dart:113](lib/bot/scraper/discord_reader.dart:113)). Question:
does the archive cache save the mods before or after the stamp?

If after: correcting a label in the config later does nothing, because the cache
already has the old label baked in, and only a version bump re-reads it. If
before: config edits just work.

The design already admits two of the four labels are approximations, so someone
correcting one later is likely. One sentence deciding this would prevent a
confusing afternoon.

### Problem 6: the effect on existing mods hasn't been looked at

The proposal says an old announcement of a mod that still exists gets "discarded
by same-source dedup". That's only true when the mod is also in a *live Discord
channel*. Plenty of these mods will instead be alive on the forum only.

For those, the old announcement merges into the live forum mod. The merger's
priority rules protect the text fields, but links, images, and sources get
combined. So a living mod's page could gain a Discord link pointing at a 2017
message, and a 2017 screenshot as its announcement picture — which the site
actually shows, behind the picture setting.

Maybe that's fine. But the dry-run checklist only looks at the *new* mods. Add a
step: turn on merge debug and use the ModRepo diff viewer to see what changed on
the mods that already existed.

### Problem 7: a typo in `:archive` fails silently

Write `:archvie` and nothing complains. The channel just quietly gets treated as
live and re-read on every run. The project already warns about unknown config
keys for exactly this reason — an unknown third part deserves the same warning.

### Problem 8: an author can no longer opt out of an archived channel

The 🕸️ reaction lets an author remove their mod from scraping. But an archive
channel is read once. If an author reacts *after* that one read, nobody ever sees
it — until a version bump happens for some unrelated reason.

Since this is a consent mechanism and the mods go on a public site, that deserves
a sentence in the ADR. Either "accepted — bump the version if anyone asks", or a
plan to re-read occasionally. Right now it's an accident, not a decision.

### Small things

- `parseAsThread` has 16 tests, not "eighteen".
- The proposal says `mods.json` is 1.41 MB; CLAUDE.md says about 1.35 MB. Both
  files get edited by this change, so pick one number.
- The spec covers "Discord sent no type" but not "Discord sent a type we don't
  recognize". The design covers both; the spec should too.
- If `discord_archive_cache.json` is corrupt, treat it as missing and re-read.
  It's a cache. Don't let anyone apply the `mod-ids.json` rule ("unreadable means
  fail the run") by analogy.
- The Discord scrape has no timeout, unlike forum and Nexus. For this change
  that's good — the first archive read is 800+ requests and a 2-minute timeout
  would kill it. But it means the first real run will be slow. Say so in the
  migration plan so nobody thinks it's hung.

### Bottom line

The design is sound, the decisions are well argued, and doing a dry run first is
the right call given the permanent ids. Fix problems 1 and 2 before writing any
code. Problem 1 can corrupt data with no recovery except a version bump. Problem
2 is a wrong sentence in the spec that would lead a careful implementer to break
a stated goal.
