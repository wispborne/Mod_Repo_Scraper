# Every mod in an archived Discord channel is published, dead or not

The Unofficial Starsector Chat has four disused mod-announcement channels going
back to 2017. Whether a mod reaches Starmodder currently depends on where its
author posted it. A mod with a forum thread is visible. A mod announced only in
an old Discord channel may be missing.

We will read all four channels and publish every valid mod announcement. We will
not try to decide whether each mod is still alive.

We considered filtering by a working download, a newer mod with the same name,
or a cutoff date. Each rule gives wrong answers. People still play old game
versions. A dead link does not prove that a mod is unwanted. Browse already
hides old game versions behind its default switch, so these mods do not crowd
the normal current-version view.

## Consequences

A mod's site address comes from a permanent id in `mod-ids.json`. The first real
run could create several hundred permanent addresses. That run must therefore
happen against copied data first. Parsed names, new ids, downloads, and changes
to existing mods must be checked before production data is touched.

An old Discord announcement is not always discarded. If a current copy exists
only on the forum, a cross-source merge can add the old Discord link, source, or
image to that existing mod. The copied-data run must use merge debug and inspect
those changes as well as newly added mods.

`mods.json` will grow, but its size limit will not be guessed in advance. The
copied-data run will measure the real result. The test limit will then be raised
with a stated margin, or the file will be split or trimmed if one file is no
longer reasonable.

The archive origin is not added to `ModRepo.json` or the site. Accepted archive
mods are ordinary Discord mods and also reach TriOS.
