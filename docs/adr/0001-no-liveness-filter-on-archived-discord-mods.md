# Every mod in an archived Discord channel is published, dead or not

The Unofficial Starsector Chat has four disused mod-announcement channels going
back to 2017. Whether a mod reaches Starmodder currently depends on where its
author happened to post: a 2016 mod with a forum thread is on the site, and a
2016 mod announced only on Discord is nowhere. We read all four channels and
publish everything in them, with no rule that tries to work out whether a mod is
still alive.

We considered filtering — by a working download link, by a newer mod of the same
name, by a cut-off date. Every such rule is wrong in both directions. People do
play old game versions, and a dead link does not mean a dead mod. The site
already has the right mechanism: Browse leaves out mods for older game versions
behind a switch that is on by default, so these mods are hidden from the default
view without anyone deciding they are worthless.

## Consequences

This is the part that cannot be undone. A mod's web address comes from a
permanent id in `mod-ids.json`, handed out the first time the mod is seen and
kept for ever. Publishing several hundred long-dead mods mints several hundred
permanent addresses, and there is no way to reclaim them if we change our minds.
That is why the first run is done against a copied data folder and read by hand
before anything real happens.

It also means `mods.json`, which the browse page fetches whole, grows — its
pinned size limit went from 2 MB to 3 MB to make room. And these mods go to
TriOS too, since they ride in `ModRepo.json`, with nothing marking them as
archive finds.
