## MODIFIED Requirements

### Requirement: A thread's other mods are published as mods of their own
Some forum threads hold several mods at once, and some hold mods the merge never
learned about. For every thread in the bundle, the builder SHALL publish one mod for
every `main` mod the LLM named on that thread which no mod already being published
accounts for. A thread SHALL be read whether or not a published mod points at it — the
merge learns about a mod from the board listings or from Discord, so a thread whose
title carries no game version, or which has fallen behind the newest board pages, is
never merged and would otherwise never reach the site however many mods the LLM read
off it.

Whether a published mod accounts for a thread mod SHALL be decided by two comparisons in
order: the names match once each is cut at the first version it carries and stripped of
its bracketed prefix, and failing that, those same names match with everything but
letters and numbers removed. So a merged mod called "Useful.Tithes 1.0.a" and a thread
mod called "Useful.Tithes" are one mod; so are "Disco.Balls 1.1.c - More Lamp Colour
Options" and "Disco.Balls", where the version sits in the middle of the name; and so are
two spellings that differ only in punctuation. This comparison SHALL be made only
against mods published from the same thread. A thread mod whose name matches a mod
published from some other thread SHALL still be published, and SHALL be told apart by
its permanent id — a fork that keeps the name of the mod it forked is a different mod
on a different thread, and the site already carries two mods of one name that way.

A thread whose LLM list holds exactly one `main` mod SHALL be treated as accounted for
by a merged mod pointing at it, whatever either is called. Where no merged mod points at
the thread there is nothing for that single entry to be accounted for by, and it SHALL
be published.

This comparison SHALL NOT be the one a mod's permanent id is filed under. That one leaves
a version of the form "1.0.a" in place, and it can never be made keener, because every
mod's web address is built from it. The two SHALL be kept as separate rules so that
matching can be as keen as it needs to be while no existing address moves.

A thread mod SHALL NOT be published unless its name appears in the thread's post text
and the LLM tied at least one download to it — a published mod's id is permanent, so an
invented one can never be quietly removed. These two rules together with the `main` role
SHALL be the whole gate on a thread nothing points at. No judgement of the thread's age,
of its game version, or of the model's separate mod-or-not answer SHALL be applied.

A mod the LLM marked as an add-on or a variant SHALL NOT be published this way. Those
stay add-ons on the page of the mod they belong to, exactly as they are today.

A thread-only mod SHALL take its name, downloads, image, version and other facts from
the LLM's reading of that thread, and its authors and forum URL from the thread itself.
Its game version SHALL be the thread's, falling back to a sibling merged mod's where
there is one. Its `sources` SHALL be `["forum"]`.

#### Scenario: A thread holding four mods
- **WHEN** a thread names four mods and two of them are already published as merged mods
- **THEN** the other two are published as mods of their own, each with the download the LLM tied to it, and the two already published are not published twice

#### Scenario: A thread nobody published points at
- **WHEN** the bundle holds a thread that no published mod's forum link points at, and the LLM named a `main` mod on it whose name the post writes and which has a download
- **THEN** that mod is published as a mod of its own, with a permanent id and the thread's title recorded as the thread it is part of

#### Scenario: A thread nobody points at, holding one mod
- **WHEN** the bundle holds a thread that no published mod points at and the LLM named exactly one `main` mod on it
- **THEN** that one mod is published — the rule that a single entry is the merged mod does not apply, because there is no merged mod

#### Scenario: A thread nobody points at that holds no mod
- **WHEN** the bundle holds a thread that no published mod points at and the LLM named no `main` mod on it, or named one the post never writes, or named one with no download
- **THEN** nothing is published from that thread

#### Scenario: A fork that keeps the original's name
- **WHEN** an unmerged thread names a `main` mod called "Junk Pirates" with its own download, and a merged mod called "Junk Pirates" is already published from a different thread
- **THEN** both are published, the merged mod keeps its existing web address, and the thread mod is given the same id with a number on the end

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

#### Scenario: A name the post never wrote
- **WHEN** the LLM names a mod on a thread whose post text never mentions that name
- **THEN** it is not published

#### Scenario: An old thread with a dead download
- **WHEN** an unmerged thread was last posted on years ago and the LLM named a `main` mod on it with a download whose link no longer works
- **THEN** it is published like any other, because the builder does not judge a thread's age and does not test a link

### Requirement: A thread-only mod keeps a permanent id like any other
A mod published from a thread's LLM reading SHALL be given a permanent id from the same
id store as every other mod, and SHALL keep it forever. Its `mark` SHALL be the forum
topic id, so two different mods whose names clean to the same thing are told apart and
each keeps its own id.

Merged mods SHALL be given their ids before any thread mod is, so that where a thread
mod's name collides with a merged mod's the merged mod keeps the plain id and the thread
mod takes the numbered one. Which mod holds which address SHALL therefore not depend on
the order threads are read.

#### Scenario: Two different mods with the same cleaned name
- **WHEN** SirHartley's "Lost.Sector" is published from topic 34161 and Kissa_Mies's "LOST_SECTOR" is already published from topic 27556
- **THEN** they are kept as two mods on two ids, and neither takes the other's web address

#### Scenario: A thread mod colliding with a merged mod
- **WHEN** a thread mod and a merged mod from a different thread clean to the same name
- **THEN** the merged mod keeps the plain id and the thread mod is given the numbered one, whichever thread was read first

#### Scenario: The thread is scraped again
- **WHEN** a later run reads the same thread and the LLM names the same mods
- **THEN** each thread-only mod keeps the id it was given before, and its web address does not change

## ADDED Requirements

### Requirement: A mod publishes when its forum thread was last posted on
Every published mod whose forum thread was scraped SHALL carry the date of the most
recent post on that thread, on both its list record and its own file. The value SHALL be
read from the thread's `lastPostDate` in the bundle, through the same date reading every
other forum date goes through, and SHALL be absent where the thread gives no readable
date or where the mod has no thread.

This is what separates a live thread from an archived one. Two mods sharing a name are
often the same mod's old and new threads, and every other published fact about them is
either identical or missing — the names match, the author is frequently the same person,
and the day a mod was first seen says when the thread started rather than whether anyone
still posts on it.

#### Scenario: A mod on a thread that still gets posts
- **WHEN** a mod's thread was last posted on in 2026
- **THEN** its record carries that date

#### Scenario: A mod on an archived thread
- **WHEN** a mod is published from a thread whose last post was in 2015
- **THEN** its record carries that date, and a reader comparing it with a same-name mod on a 2026 thread can see which is which

#### Scenario: A thread whose date cannot be read
- **WHEN** the forum gives a relative date such as "Today at 03:12:22 PM", which names no day
- **THEN** the field is absent rather than guessed

#### Scenario: A mod with no forum thread
- **WHEN** a mod was merged from Discord alone and no forum thread is known for it
- **THEN** the field is absent

### Requirement: A mod sharing its name with another published mod lists the others
Where two or more published mods share a name once each is cut at the first version it
carries and compared on letters and numbers alone, each of their pages SHALL carry a
list of the others. Each entry SHALL name the mod, its authors, its game version, its
mod version, when its thread was last posted on, and SHALL link to that mod's page on
the site.

Both a fork that kept the original's name and a mod's own older thread SHALL be listed
this way rather than either being dropped. An old thread often holds the last build that
ran on an old game version and a fork is often the only build that runs on the current
one, so the reader is given both with the facts to choose between them.

An entry SHALL be able to point at a page on the site rather than only out to the forum,
so the list works between two published mods and not only between a mod and a thread
that was never published.

#### Scenario: A mod's own older thread
- **WHEN** "Scy" is published from topic 29535 and a second "Scy" is published from topic 8010
- **THEN** each page lists the other, with its author, its versions and when its thread was last posted on, and links to it

#### Scenario: A fork that kept the original's name
- **WHEN** a fork called "Junk Pirates" is published from topic 35651 and the original "Junk Pirates" is published from topic 161
- **THEN** each page lists the other, and neither is left out

#### Scenario: Two unrelated mods that happen to share a name
- **WHEN** two mods called "Kadur Remnant" by different people are published from different threads
- **THEN** each page lists the other, because a reader who found one and meant the other needs to know the other exists

#### Scenario: A mod whose name nothing else shares
- **WHEN** a published mod's name matches no other published mod
- **THEN** its list is empty and nothing about other mods is shown on its page
