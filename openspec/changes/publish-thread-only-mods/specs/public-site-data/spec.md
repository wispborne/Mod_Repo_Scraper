## ADDED Requirements

### Requirement: A thread's other mods are published as mods of their own
Some forum threads hold several mods at once. For each thread a published mod points at,
the builder SHALL publish one mod for every `main` mod the LLM named on that thread
which no mod already being published accounts for. Threads SHALL only be reached through
the mods being published; a thread in the bundle that no published mod points at
contributes nothing.

Whether a published mod accounts for a thread mod SHALL be decided by two comparisons in
order: the names match once each is cut at the first version it carries and stripped of
its bracketed prefix, and failing that, those same names match with everything but
letters and numbers removed. So a merged mod called "Useful.Tithes 1.0.a" and a thread
mod called "Useful.Tithes" are one mod; so are "Disco.Balls 1.1.c - More Lamp Colour
Options" and "Disco.Balls", where the version sits in the middle of the name; and so are
two spellings that differ only in punctuation. A thread whose LLM list holds exactly one
`main` mod SHALL be treated as accounted for by the merged mod pointing at it, whatever
either is called.

This comparison SHALL NOT be the one a mod's permanent id is filed under. That one leaves
a version of the form "1.0.a" in place, and it can never be made keener, because every
mod's web address is built from it. The two SHALL be kept as separate rules so that
matching can be as keen as it needs to be while no existing address moves.

A thread mod SHALL NOT be published unless its name appears in the thread's post text
and the LLM tied at least one download to it — a published mod's id is permanent, so an
invented one can never be quietly removed.

A mod the LLM marked as an add-on or a variant SHALL NOT be published this way. Those
stay add-ons on the page of the mod they belong to, exactly as they are today.

A thread-only mod SHALL take its name, downloads, image, version and other facts from
the LLM's reading of that thread, and its authors and forum URL from the thread itself.
Its game version SHALL be the thread's, falling back to the sibling merged mod's. Its
`sources` SHALL be `["forum"]`.

#### Scenario: A thread holding four mods
- **WHEN** a thread names four mods and two of them are already published as merged mods
- **THEN** the other two are published as mods of their own, each with the download the LLM tied to it, and the two already published are not published twice

#### Scenario: A name that differs only by its version
- **WHEN** a thread names a mod "Useful.Tithes" and a merged mod called "Useful.Tithes 1.0.a" is already being published for that same thread
- **THEN** only the merged mod is published, and no second mod appears for the same thing

#### Scenario: A version in the middle of the merged name
- **WHEN** a thread names a mod "Disco.Balls" and a merged mod called "Disco.Balls 1.1.c - More Lamp Colour Options" is already being published for that same thread
- **THEN** only the merged mod is published, and its permanent address is unchanged

#### Scenario: A single-mod thread whose names look nothing alike
- **WHEN** a merged mod called "Red" points at a thread titled "[0.98a] Red - the Oculian Armada (0.10.2-RC4) Mod" whose LLM list holds one `main` mod
- **THEN** that entry is treated as the merged mod and nothing extra is published

#### Scenario: An add-on stays an add-on
- **WHEN** a thread names a mod the LLM marked `addon` or `variant`
- **THEN** it is listed as an add-on on the main mod's page and is not published as a mod of its own

#### Scenario: A thread nobody published points at
- **WHEN** the bundle holds a thread that no published mod's forum link points at
- **THEN** nothing is published from it, however many mods the LLM named there

#### Scenario: A name the post never wrote
- **WHEN** the LLM names a mod on a thread whose post text never mentions that name
- **THEN** it is not published

### Requirement: A thread-only mod keeps a permanent id like any other
A mod published from a thread's LLM reading SHALL be given a permanent id from the same
id store as every other mod, and SHALL keep it forever. Its `mark` SHALL be the forum
topic id, so two different mods whose names clean to the same thing are told apart and
each keeps its own id.

#### Scenario: Two different mods with the same cleaned name
- **WHEN** SirHartley's "Lost.Sector" is published from topic 34161 and Kissa_Mies's "LOST_SECTOR" is already published from topic 27556
- **THEN** they are kept as two mods on two ids, and neither takes the other's web address

#### Scenario: The thread is scraped again
- **WHEN** a later run reads the same thread and the LLM names the same mods
- **THEN** each thread-only mod keeps the id it was given before, and its web address does not change

### Requirement: A thread-only mod says which thread it came from
A mod published from a thread's LLM reading SHALL carry the title of the thread it was
found on, in both the list record and its own file, so the site can say the mod is part
of that thread rather than presenting it as a thread of its own. A merged mod SHALL NOT
carry this field — as in TriOS, the field marks a made-up entry, and giving the same
field a wider meaning here would make the two unreadable to each other.

#### Scenario: Reading a thread-only mod's page
- **WHEN** the site draws the page for a thread-only mod
- **THEN** the page says which thread it is part of, and links to that thread

#### Scenario: A merged mod on a shared thread
- **WHEN** the site draws the page for a merged mod whose thread holds several mods
- **THEN** no "part of" line is shown — the page links its thread as every mod page does

### Requirement: A mod found on a thread has the forum as a source
A published mod whose thread was scraped and read SHALL have `forum` among its sources,
whether the merge learned about it from the forum, from Discord, or not at all. The
"Discord only" mark SHALL be shown only for a mod with no forum thread behind it.

#### Scenario: A mod posted on Discord that also has a thread
- **WHEN** a mod was merged from Discord alone but its forum thread was scraped and read
- **THEN** its sources hold both `discord` and `forum`, and it is not marked as Discord only

#### Scenario: A mod with no thread at all
- **WHEN** a mod was found on Discord and no forum thread is known for it
- **THEN** its sources hold `discord` alone and it is marked as Discord only

### Requirement: On a shared thread, facts and releases are never guessed
When a thread holds more than one `main` mod, each published mod on it SHALL take the
LLM entry whose name matches its own, and a mod matching no entry SHALL publish with no
LLM facts — never a sibling entry's downloads, changelog, version, image or text.

A thread's releases SHALL be credited to the merged mod only when the thread's LLM list
holds one `main` mod or none. A thread holding several `main` mods SHALL contribute
nothing to `updates.json` or the feed, whether one of its mods is merged or several —
the detector believes one version per thread and cannot say which mod it belongs to,
and a wrong entry in the feed is worse than a missing one.

An add-on on a shared thread whose `requires` names one of the thread's `main` mods
SHALL be listed only on that mod's page; one naming nothing that matches SHALL stay on
every `main` mod's page.

#### Scenario: A merged mod matching no LLM entry
- **WHEN** a merged mod sits on a thread with several `main` entries and none of their names matches it
- **THEN** its page carries no LLM facts, and the unmatched entries are still published as their own mods — no fact appears on two pages

#### Scenario: A release on a shared thread
- **WHEN** the release detector believes a new version for a thread holding several `main` mods
- **THEN** no mod is credited with it and the feed carries no entry for it

#### Scenario: A release on a mod's own thread
- **WHEN** the release detector believes a new version for a thread holding one `main` mod
- **THEN** the merged mod on that thread is credited, exactly as today

## MODIFIED Requirements

### Requirement: The description is the author's own post, kept formatted
Where a mod has a forum thread of its own — one holding no other `main` mod — its
description SHALL be taken from that thread's post and published as `descriptionHtml`: a
rebuilt piece of HTML holding only paragraphs, line breaks, lists, headings, quotes,
code, emphasis and links. Anything that can run, anything that can style the page and
anything that loads from another host SHALL be left out. Links SHALL carry
`rel="nofollow noopener"`. Bare web addresses SHALL be turned into links. Where the mod
has no forum post, the merged description SHALL be used, and failing that the AI
paragraph, labelled as AI. `description` SHALL keep holding the same words as plain
text.

Where the thread holds more than one `main` mod, the post SHALL NOT be any of those
mods' description — it is about all of them at once. Each SHALL fall back as if it had
no post: its own merged description first, failing that its own LLM entry's paragraph,
labelled as AI; a mod with neither SHALL be published with no description.

#### Scenario: A mod on both the forum and Discord
- **WHEN** a mod has a forum post and a Discord announcement
- **THEN** the description is the forum post, not the Discord announcement

#### Scenario: A post carries a script
- **WHEN** the post holds a `<script>`, a `<style>` or an `<img>`
- **THEN** none of them appear in `descriptionHtml`

#### Scenario: A very long post
- **WHEN** a post runs to tens of thousands of characters
- **THEN** the published description is cut off at a whole block and marked as cut short

#### Scenario: A mod on a thread that holds four
- **WHEN** a merged mod's thread holds four `main` mods and the mod has its own Discord announcement
- **THEN** its description is that announcement, not the shared post, and a sibling with neither announcement nor LLM paragraph is published with no description
