# Archived Discord channels are read once after a complete live read

Four Discord channels are disused. The scraper runs twice a day. Walking several
thousand fixed messages on every run would make thousands of Discord calls each
week without finding new data.

A channel marked `archive` in `modrepo_discord_channels` is therefore read once.
Its mods are kept in `discord_archive_cache.json`, keyed by channel id and a
reader version held in the code.

## Only complete live answers are kept

Read once does not mean save whatever was collected. Channel metadata, thread
lists, thread details, allowed message pages, and author opt-out checks must all
finish. A failed request or a message channel larger than the 20,000-message limit
makes that channel incomplete. No entry is saved for it.

Raw HTTP replay can help development, but it can be old or partial. It is never
allowed to populate the archive store. A replay miss fails the Discord scrape so
the manager can use the last complete Discord source cache.

Each completed channel is saved immediately. The store writes a replacement
file beside the current cache and replaces the current file atomically. A later
channel failure or a stopped process does not throw away completed network work
or leave half a JSON document.

`ModRepoService` owns the working path and constructs the archive store. The
reader does not get a path from `BotConfig`.

## Refreshes are controlled by code

The reader version changes whenever parsing, message filtering, cleanup, URL or
image extraction, or author opt-out behavior can change stored mods. A version
change makes the next live run refresh every archive without a server-side file
edit.

Stored mods do not include the config's fallback game version. The current
channel setting is applied when saved mods are loaded. Correcting an approximate
game-version label therefore does not need a Discord read.

A missing, corrupt, or unknown-schema archive file is a cache miss. The run logs
the problem and rebuilds it from complete live reads.

## Later author opt-outs are manual

A read-once cache cannot notice a reaction added later. If an author adds the 🕸️
reaction or asks for removal, the maintainer bumps the reader version and runs
Discord once. The refreshed cache and outputs then remove the mod. This manual
step is accepted because the channels are disused, but it is part of the process
rather than an accidental gap.

## Considered options

Working out archive status from config order was rejected. Reordering the list
would silently change behavior. Treating every message channel as an archive was
also rejected because one dead channel is a forum channel and future live
message channels are possible. Discord supplies the channel type. Config supplies
archive status.
