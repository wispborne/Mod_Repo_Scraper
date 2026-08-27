## Context

`DiscordReader.readAllMessages` walks each configured channel by listing its threads and reading each thread's messages. That is the only shape it knows. Every channel in the config today is a Discord forum channel, so it has never needed another.

The four channels this change adds are all disused, and three of them predate forum channels entirely — Discord only launched those in late 2022, and these were made in April 2017, March 2021 and May 2023. In a plain text channel there are no threads to walk, so pointing the reader at one today finds nothing and reports nothing: no crash, no warning, no mods.

The parser for the other shape is already in the file. `parseAsSingleMessage` takes one message and builds a `ScrapedMod` from it, including the right Discord permalink. It came across in the Dart port from the earlier scraper, which was written for exactly these channels and ran against them for years. In this repo it is unreachable — the only branch that calls it needs a message with no parent thread, and every message in the current path has one — and it has no tests, where `parseAsThread` has eighteen.

Two facts constrain the shape of the solution. The scraper runs twice a day from cron on a Linux host, so anything read on every run is read about seven hundred times a year. And a mod's web address comes from a permanent id handed out the first time it is seen and never reclaimed, so the first run that reads these channels is the one that decides several hundred addresses for good.

## Goals / Non-Goals

**Goals:**

- Read a Discord text channel as one mod per message, alongside the existing one-mod-per-thread reading.
- Read a channel nobody posts in any more only once, and keep the answer.
- Make a change to the message parser re-read every archive by itself, with nothing to do on the server.
- Keep every existing behaviour of the forum-channel path exactly as it is, including its cost.

**Non-Goals:**

- Working out whether an old mod is still worth having. Everything found is published; see `docs/adr/0001-no-liveness-filter-on-archived-discord-mods.md`.
- Changing the merge. An old announcement of a mod that still exists is grouped with it and dropped by same-source dedup, and that is the wanted behaviour.
- Marking archive-found mods in `ModRepo.json` or on the site. They are ordinary mods.
- Cutting the API cost of the live forum channels. That is what `openspec/changes/discord-incremental-cache` is for, and it comes after this.
- Rewriting `parseAsSingleMessage`. It is proven code from the scraper that read these channels; the plan is to confirm it survived the port, not to redo it.

## Decisions

### Discord tells us the channel's shape; the config tells us whether it is dead

Two separate facts, and only one of them is knowable from the API. The channel fetch the reader already makes on every channel returns a `type` field — 15 for a forum, 0 for plain text — and today that answer is parsed and thrown away. Adding one field to the `Channel` model is enough to branch on it, so no config entry can be filled in wrong.

Whether anyone still posts in a channel is not in the API at all. It cannot be derived from the channel type either: `1115946075262550016` is a **forum** channel and also long dead. It could in principle be derived from position in the config list — everything but the last is an archive — and that was rejected, because it makes the meaning of a line depend on its order, so shuffling the list silently changes what gets fetched, and it breaks the day two channels are live at once. So archive-ness is an explicit third part on the entry.

An unknown type falls back to the forum path. That is what every channel did before this change, so a Discord API change cannot turn a working channel into a silent one.

### A separate file for the archive answers, not the existing Discord cache

`discord_cache.json` is the Discord source's own derived cache, written whole after every successful scrape and read back by a merge. Putting the archive answers in it would not work: any run that skipped the archives would rewrite the file without them. So the archives get `discord_archive_cache.json`, keyed by channel id, in the same working folder and covered by the same `/*_cache.json` gitignore rule.

Committing the answers to the repo was considered — immutable data really is a fact rather than a cache, and checking it in would let someone rebuild the site with no Discord token. Rejected because no scraped data is checked into this repo at all, and breaking that rule as a side effect of this change is the wrong way to decide it.

The archive mods still have to end up **inside** `discord_cache.json` along with the live channels' mods when a scrape writes it. A `mergeModRepo` job touches no network and reads Discord mods only from that file, so leaving them out would make every archive mod vanish from any merge-only run. This is the easiest thing in the change to get wrong and it fails silently.

### A version number in the code, not a switch on the server

A saved answer that is never re-read is a trap: improve the parser and the stale answers stay for ever. "Delete the file to force a re-read" is a footgun when the thing running the scraper is cron on a box nobody logs into.

So the saved answers are keyed on the channel id **and** a version number that lives in the code. Bumping it in the same commit as a parser change means the next scheduled run re-reads every archive without anyone doing anything. This is exactly what `ExtractionPrompt.promptVersion` already does for the LLM extraction cache in the QB pipeline — same problem, same shape, and a reader who knows one will recognise the other.

### The page ceiling becomes the caller's, and says when it fires

`_getMessages` stops after 25 pages of 100. For a forum thread that is far more than one ever holds, so it has never fired. An archive channel could hold more than 2,500 announcements, and the walk goes newest-first — so the messages it would drop are the oldest ones, which are exactly the mods this change exists to find. Worse, it drops them silently.

The ceiling becomes a parameter: 25 for a thread, 200 for a text channel. And hitting it is logged either way, because a guard that discards data without saying so is worse than no guard.

## Risks / Trade-offs

- **The ported parser may have drifted.** `parseAsSingleMessage` has never run in this repo and nothing tests it. A subtle drift — taking the wrong line as the name — mints permanent web addresses for mangled mods. → The first run is done against a **copy** of the data folder, with the output read by hand before anything real happens. Note that `idStore.save()` fires inside the site build, before publishing is involved, so "run it but do not push" does not protect `mod-ids.json`; only a separate folder does. A command-line run cannot publish at all (`PublishService` is only built by the viewer server), so the copy is safe as long as the server is not pointed at the same folder.

- **Real messages from those channels then become fixtures.** The dry run hands over a dozen genuine archived announcements at no extra cost, and pasting the interesting ones into `discord_reader_test.dart` is how every other parser in that file earned its trust.

- **The volume is a guess.** Two channels produce 464 mods today. Four more could be anywhere from 300 to 1,200, and nothing tells us until the dry run. `mods.json` is at 1.41 MB against a 2 MB pinned limit, which is roughly 450 mods of headroom; the limit goes to 3 MB. → If the dry run lands past about 900 new mods, 3 MB is not enough either and the choice between trimming a field and splitting the file has to be made then. The dry run is what tells us, before anything is published.

- **The config key rename can silently disable Discord.** An unedited `config.properties` on the production host would leave `modrepo_discord_channels` unset, and the reader would find no channels. → The startup unknown-key warning names `modrepo_discord_forum_channels` as unrecognised, and the reader already logs that it found no channels in the config. This is the same trade this project took in commit `176b630`, which renamed every key at once with no aliases.

- **It collides with `discord-incremental-cache`.** That proposal reworks the same per-thread fetch path and its design is keyed entirely on threads. → This change lands first. That one is unstarted — a proposal with no code — so it can be written against a reader that already knows there are two shapes of channel, rather than retrofitted.

- **Archive channels might not be as fixed as we think.** If a channel is merely disused rather than locked, someone could post in it and we would never see it. → Bumping the version number re-reads everything, so the recovery is one line and a deploy.

## Migration Plan

1. Write the openspec proposal, specs and tasks. *(this document)*
2. Build it, with tests for the new code — the shape dispatch, the config entry with three parts, the archive read-once path, the page ceiling's log line.
3. Copy `qb_data` and `outputs` into a scratch folder and run the scraper there with `qb_data_path` pointing at the copy. Read the new mods and their ids by hand.
4. Take a dozen real messages from that run and turn them into `parseAsSingleMessage` fixtures.
5. Throw the copy away. Run for real, and check the archive cache was written and the second run makes no Discord calls for those channels.

Rolling back means restoring `mod-ids.json` and `discord_archive_cache.json` from before the run and reverting the config line — which works cleanly only while nothing has been published. That is the whole reason for step 3.

## Open Questions

- How many mods do the four channels actually hold? Unknown until step 3, and it decides whether 3 MB is enough for `mods.json`.
- `825068217361760306` ran from March 2021 to May 2023, spanning both 0.95a and 0.95.1a; it is labelled `0.95.1a`, where more of its life was spent. `305506161615175680` spans 0.8a through 0.9.1a and is labelled `0.9.1a`. Under the one-label-per-channel rule these are accepted as approximations, and the early posts in each are labelled newer than they really are.
