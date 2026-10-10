# Starsector Mod Catalog

Collects what mod authors post about their Starsector mods on the forum, Discord and Nexus, and works out the one list of real mods behind those posts.

## Language

### What was scraped

**Source post**:
One thing a source published that might describe mods: a forum topic, a Discord announcement or thread, or a Nexus page. It can describe no mods, one mod, or several.
_Avoid_: Document, thread (when the source isn't the forum), topic (when the source isn't the forum)

**Opening run**:
The part of a source post that counts as the author's own words: the first post, plus each post straight after it by the same author, stopping at the first reply by anyone else.
_Avoid_: First post (when the later posts are meant too)

**Mod index**:
The forum topic where the forum staff list released mods by category, each line naming a mod and linking to its forum topic.
_Avoid_: Index (on its own, since the bundle also has an `index`)

### What was worked out

**Listing**:
One mod as one source post describes it. Found either by fixed rules or by the LLM. A source post gives zero or more listings.
_Avoid_: Candidate, entry, record, ScrapedMod

**Mod**:
One real mod, formed by merging every listing that describes it. It has a permanent id.
_Avoid_: Canonical mod, merged mod, catalog entry

**Collection**:
A source post that holds two or more mods. It is not itself a mod, but if its name already had a permanent id, it keeps that id and gets a page that lists the mods it holds.
_Avoid_: Collection mod, mod pack (a mod pack is a mod)

**Add-on**:
Something on a source post that needs another mod from the same source post to work. It is not a mod of its own. It is listed on that other mod's page.
_Avoid_: Submod, plugin

**Variant**:
Another build of a mod on the same source post, such as a lite version. It is not a mod of its own. It is listed on that mod's page.
_Avoid_: Fork (a fork is a separate mod by someone else)

**Permanent id**:
The name a mod's web address is built from. Once given, it never changes.
_Avoid_: Slug, mod id (the game's own `mod_info.json` id is a different thing)
