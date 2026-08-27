# Archived Discord channels are read once, not on every run

Four of the Discord channels we read are disused: the server has moved on, and
nothing in them can change again. The scraper runs twice a day from cron, so
re-walking roughly five thousand fixed messages every time would be a few
thousand API calls a week to learn nothing. A channel marked `archive` in
`modrepo_discord_channels` is read once, and its mods are kept in
`discord_archive_cache.json`, keyed by channel id.

A saved result that is never re-read is a trap: improve the message parser and
the old answers stay stale for ever, on a server nobody logs into. So the saved
answers carry a version number that lives in the code and forms part of their
key. Changing the parser means bumping it, and the next run re-reads every
archive by itself. This is the same trick `ExtractionPrompt.promptVersion`
already uses to re-read every forum topic when the LLM prompt changes.

## Considered options

Working out which channels are archives from their position in the config was
rejected: it makes the meaning of a line depend on its order, so shuffling the
list would silently change what gets fetched. Treating "text channel" as
"archive" was also rejected, because one of the dead channels is a forum
channel — Discord's API says what kind a channel is, but nothing in it says
whether anyone still posts there.
