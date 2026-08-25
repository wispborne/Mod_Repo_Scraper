## ADDED Requirements

### Requirement: The scraper publishes three files for the public website
The scraper SHALL build and publish `mods.json`, one `mods/<id>.json` per mod, and
`updates.json`. These SHALL be built from the merged ModRepo mods and the forum data
bundle that already exist. `ModRepo.json` and `forum-data-bundle.json` SHALL keep their
current shape and SHALL keep being published, so anything already reading them keeps
working.

#### Scenario: A run builds the website files
- **WHEN** a run finishes that has both a merged mod list and a published bundle
- **THEN** it writes `mods.json`, a `mods/<id>.json` for every mod in it, and `updates.json`

#### Scenario: The existing outputs are untouched
- **WHEN** the website files are built
- **THEN** `ModRepo.json` and `forum-data-bundle.json` are byte-for-byte what they would have been without this step

### Requirement: Every mod has a permanent id that never changes
Each mod SHALL be given a short, readable id the first time it is seen, and SHALL keep
that id forever. The id SHALL be worked out from the mod's name with the game version,
the mod version and any bracketed prefix stripped out. Ids SHALL be stored in a file
that is read back on every run, so a run that fails part-way never hands out an id twice
or renames an existing mod.

#### Scenario: A mod is renamed by its release
- **WHEN** a thread's title changes from "[0.98a] Nexerelin v0.12.1e" to "[0.98a] Nexerelin v0.12.2"
- **THEN** the mod keeps the id it already had, and its web address does not change

#### Scenario: Two mods want the same id
- **WHEN** a new mod's name would produce an id that is already taken
- **THEN** it is given the id with a number on the end, and the mod that had it first keeps it

#### Scenario: The id file is missing
- **WHEN** the stored id file cannot be read
- **THEN** the run fails with a plain message and publishes nothing, rather than handing out fresh ids for mods that already had them

### Requirement: The mod list holds only what a list page needs
`mods.json` SHALL hold one record per mod with: its permanent id, name, authors,
categories, game version, mod version, one image, a one-line summary, whether it can be
added to an existing save, whether it has a direct download, whether its source code is
public, whether it is a work in progress, and when it last had a release. It SHALL NOT
hold post HTML, full changelogs, image galleries or link lists.

#### Scenario: The list stays small
- **WHEN** `mods.json` is built for the current mod set
- **THEN** it is under 2 MB, so a browser can fetch and search the whole thing at once

### Requirement: One file per mod holds the detail page
Each `mods/<id>.json` SHALL hold everything the mod's own page shows: the fields from
the list, plus the description, the image gallery, every download with its kind and file
name, the changelog by version, the license, the source code link, support links, links
out to the forum thread and any Discord or Nexus page, and the mod's release history.

#### Scenario: Opening a mod page
- **WHEN** the site opens a mod's page
- **THEN** it fetches only that mod's file, and needs nothing else to draw the page

### Requirement: Nothing internal reaches the published files
The published files SHALL NOT contain anything from `config.properties`, any token, any
local file path, any run id, any confidence score, or any flag that only means something
inside the scraper. Text the LLM wrote in its own words SHALL be marked as such, so the
site can tell it apart from words copied from the author's post.

#### Scenario: A generated summary is marked
- **WHEN** a mod record carries a summary the LLM wrote rather than copied
- **THEN** that field is marked as generated, and the site can label or hide it

### Requirement: Mods with no forum thread still get a page
A mod that came only from Discord or Nexus SHALL still get an id, a record in
`mods.json` and its own file. Fields that only the forum bundle can fill SHALL be left
out rather than guessed at.

#### Scenario: A Discord-only mod
- **WHEN** a mod has no forum thread
- **THEN** it appears in the list and has a page, with no changelog, no release history and no save-compatibility line

### Requirement: A mod's published name carries no thread-title noise
Every mod SHALL be published with a `displayName`: its name with the bracketed game
version at the front, the mod version, any date, any leading dash and any "WIP" or
"Updated" tail taken off. It SHALL be left out where it would be the same as the name.
The name as the thread wrote it SHALL still be published, so a search for an old
spelling still finds the mod. `mods.json` SHALL be in order of the shown name.

#### Scenario: A thread title becomes a name
- **WHEN** a thread is called "- [0.98a] Starter Pack v1.1.3"
- **THEN** the mod is published with the name as written and a `displayName` of "Starter Pack"

#### Scenario: A name that needs no tidying
- **WHEN** a mod is called "Industrial Evolution"
- **THEN** no `displayName` is published, because there is nothing to tidy

#### Scenario: Nothing would be left
- **WHEN** stripping would leave an empty name
- **THEN** the name is published exactly as it was written

### Requirement: The description is the author's own post, kept formatted
Where a mod has a forum thread, its description SHALL be taken from that thread's post
and published as `descriptionHtml`: a rebuilt piece of HTML holding only paragraphs,
line breaks, lists, headings, quotes, code, emphasis and links. Anything that can run,
anything that can style the page and anything that loads from another host SHALL be left
out. Links SHALL carry `rel="nofollow noopener"`. Bare web addresses SHALL be turned
into links. Where the mod has no forum post, the merged description SHALL be used, and
failing that the AI paragraph, labelled as AI. `description` SHALL keep holding the same
words as plain text.

#### Scenario: A mod on both the forum and Discord
- **WHEN** a mod has a forum post and a Discord announcement
- **THEN** the description is the forum post, not the Discord announcement

#### Scenario: A post carries a script
- **WHEN** the post holds a `<script>`, a `<style>` or an `<img>`
- **THEN** none of them appear in `descriptionHtml`

#### Scenario: A very long post
- **WHEN** a post runs to tens of thousands of characters
- **THEN** the published description is cut off at a whole block and marked as cut short

### Requirement: The gallery holds screenshots, not badges
Pictures published in a mod's gallery SHALL leave out anything hosted by a donation or
badge service, anything whose address says it is a button, badge, avatar, icon or logo,
anything that is the forum's own furniture, and anything the post says is under 200
pixels wide. Where a picture's size is not given, nothing SHALL be assumed. A mod whose
pictures are all left out SHALL be published with no gallery rather than an empty one.
The one picture published for the card SHALL be chosen under the same rules.

#### Scenario: A post with a donation button
- **WHEN** a post holds a "Buy me a coffee" button and one screenshot
- **THEN** only the screenshot is published

### Requirement: A summary that is not a description is dropped
A copied summary that is only a web address, only a mod's name in emphasis marks, or
only a list of requirements SHALL NOT be published. The AI summary SHALL be used in its
place and labelled as AI. A summary that is kept SHALL have its emphasis marks taken off
and its spacing tidied.

#### Scenario: The summary is a download link
- **WHEN** a mod's copied summary is "Download: https://github.com/x/y"
- **THEN** the AI summary is published instead, marked as AI-written

### Requirement: The site has its own short set of categories
The site SHALL publish each mod under a fixed set of about a dozen categories of
its own, mapped from the names the forum's index and Discord's tags use. A raw
name that is not in the table SHALL leave the mod with no category rather than a
guessed one. The names each source used SHALL be kept on the mod's own page.

"Discord Only" SHALL NOT be a category. Where a mod was found SHALL be published
separately, as `forum`, `discord` or `nexus`.

#### Scenario: Names that mean the same thing
- **WHEN** a mod is filed under "Utility mods" by the forum and "Standalone Utilities" elsewhere
- **THEN** it is published under one category, "Utilities", and both raw names are on its page

#### Scenario: A tag nobody has seen before
- **WHEN** a source uses a name the table does not hold
- **THEN** the mod is published with no category for it, and the raw name is still on its page

#### Scenario: A mod only on Discord
- **WHEN** a mod was found on Discord and nowhere else
- **THEN** its sources are `["discord"]`, and "Discord Only" appears nowhere as a category

### Requirement: A mod says what it will not run without
Each mod SHALL publish the other mods it needs, by name, taken from what the
post says. A name SHALL be dropped unless the post itself names it. Where a
needed mod is one this site publishes, its id SHALL be published beside the name
so the site can link it; where it is not, the name SHALL still be published.

#### Scenario: A mod that needs a library
- **WHEN** the post says "Requires LazyLib and MagicLib"
- **THEN** both are published, each pointed at its own page

#### Scenario: A requirement the post never mentions
- **WHEN** the reading names a mod that does not appear in the post
- **THEN** it is dropped, because a wrong requirement sends a reader to install something they do not need

#### Scenario: A mod that names itself
- **WHEN** the reading names the mod itself as a requirement
- **THEN** it is left out

### Requirement: The releases are published as a feed
The releases SHALL also be written as an Atom file beside `updates.json`, and it
SHALL go out with every publish. Every link in it SHALL be relative, so the feed
works from whatever folder the site is served from. Each entry SHALL keep the
same name for ever, so a reader is never shown the same release twice. The file
SHALL carry only the newest releases, so it cannot grow without limit.

#### Scenario: Subscribing
- **WHEN** a reader gives their feed reader the site's address
- **THEN** the feed is offered from every page, and following an entry opens that mod's page

#### Scenario: The same release seen twice
- **WHEN** the feed is fetched again after another run
- **THEN** entries already shown carry the same names as before, and are not shown again

### Requirement: Every mod has a small page of its own for sharing
The scraper SHALL write `mods/<id>/index.html` for every mod: that mod's title,
description and picture as page and Open Graph tags, one line of visible words,
and a script that sends a reader on to the mod's real page. It SHALL go out with
every publish, and a page for a mod this run no longer produces SHALL be
removed.

It SHALL need nothing of the host but the ordinary rule that a folder is served
its `index.html`. No redirect rule, no Worker, and no server that reads the
address.

#### Scenario: A link shared in Discord
- **WHEN** somebody pastes a link to `mods/<id>/`
- **THEN** the preview shows that mod's name, its description and its picture

#### Scenario: Somebody with no scripts
- **WHEN** a reader opens that page with scripts turned off
- **THEN** they see the mod's name, a line about it, and a link to the real page

#### Scenario: A mod disappears
- **WHEN** a mod that had a page is no longer produced
- **THEN** its page is removed from the outputs and from the published repo
