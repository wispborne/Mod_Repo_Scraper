# Starmodder revamp: recommendations and plan

Written 19 August 2026 from a read of everything in `site/`, the public data models in
`lib/site/models/`, the real published files in `outputs/site` (906 mods at the time), and
the site opened in a browser against that data at desktop and phone widths.

## What the site does well today

- It is fast and honest: static files, no server, every page is a shareable address, and
  the filters and search ride in the address so a link brings the same list back.
- The release feed is a real idea nobody else has: mods whose version actually moved,
  not threads somebody replied to.
- The AI-written summaries are labelled and can be switched off. That is the right
  call for a modding audience, who are suspicious of machine text.
- It already copes with the messy parts of the data: broken image links step out of the
  way, empty sections are left out rather than drawn empty, and phones are handled.

## What the real data says

These numbers decide which ideas are worth doing first.

| Field | How many of 906 mods have it |
|---|---|
| Picture | 727 |
| Summary (390 of them AI-written) | 853 |
| Direct download | 612 (so 294 mod pages have no download button) |
| Mod version | 606 |
| Save-compatibility known | 166 |
| Source code link | 382 |
| A release in the feed | 32 (37 releases in about a month, 26 with notes) |
| Changelog | 472 |
| Any category at all | 780 (126 have none) |

Two more things the data shows:

- The category list is messy as published: "Utility mods", "Standalone Utilities" and
  "Quality of Life" sit side by side; so do "Other/Misc.", "Miscellaneous Mods" and
  "Misc. Campaign Mods"; and "Portrait/Flag Pack", "Portrait Packs" and "Flag Packs".
  "Discord Only" is listed as a category but is really a source.
- The game-version list is messy too: "0.98a", "0.98" and "0.98a-RC8" are three separate
  filter choices for the same game release. 509 mods are for 0.98a; about 400 are for
  older versions and are mixed in with them alphabetically.

## What the browser showed

Opened against the real data at 1254px and 400px wide. The layout holds up; the content
it shows is the problem.

- **Mod names carry thread-title noise.** The first cards a reader sees, on Home and on
  Browse, are "- Starter Pack v1.1.3", "- Stat-Derived Ship Costs ... v1.1.4",
  "[0.98] Show Encounter Stats v1.1.2", "[WIP] Europa Federation", "Diable ArmAonics
  1.3.7". Leading dashes, bracketed game versions, "WIP" tags and version numbers are
  all in the name. Because Browse sorts by name, every dash and bracket sorts to the
  front, so page one of Browse is the worst-named mods on the site.
- **The description is the wrong post.** Nexerelin, the most important mod in the
  game, says "4X in Starsector. Download: <https://github.com/...> Changelog: <...>
  Ko-Fi: <...>". That is the Discord announcement, not the forum post. The builder takes
  `ScrapedMod.description` from the merge, which picks one source's text, and never
  looks at the forum post HTML the bundle already holds. Many cards show the same
  thing: "**StopBloatingMe**", "Download link: <https://github...", "REQUIRES LAZYLIB,
  LUNALIB, MAGICLIB" as the whole summary.
- **The gallery is not screenshots.** Nexerelin's "Screenshots" are a blurred "en"
  icon, a title banner and a yellow "Buy me a coffee" button. Every image in the post
  is taken as a screenshot, including badges, avatars and donation buttons.
- **Bare URLs in descriptions are not links** and are not broken on phones: at 400px
  wide the Nexerelin description is clipped on the right at "…/download/v0".
- **Release rows do not look clickable.** A row with notes opens on click, but there is
  no chevron, no "read notes" wording, and the pointer is the only hint. Rows without
  notes say "no notes" in grey, which reads as a fault.
- **Moving between pages keeps the scroll position.** Going from the foot of Home to
  Browse lands halfway down Browse, above the fold of nothing in particular.
- **Cards are uneven.** A grid row stretches to the tallest card, so a one-line summary
  leaves a card that is two-thirds empty space; long raw summaries run to ten lines.

Those findings add a new first item below and reorder the rest: fix what is shown
before restyling how it is shown.

## The recommendations

Ordered by how much they help a reader against how much work they take. Each says what
to change, why, and whether it needs the Dart builder to publish anything new.

### 0. Fix what the pages show (builder, medium, do first)

- **Clean display names.** The id store already strips the bracketed game version, the
  version number and dates to build a mod's id; publish a `displayName` built the same
  way (also dropping leading dashes and "[WIP]" / "Updated: …" tails, with "WIP" kept as
  the badge it already is). Keep the raw thread title in the per-mod file.
- **Prefer the forum post for the description, and publish it formatted.** Where a mod
  has a forum thread, take the description from the thread's post in the bundle, as a
  cleaned, safe subset of its HTML (paragraphs, lists, bold, links, headings; scripts,
  styles and images stripped; links `rel="nofollow"`). Fall back to the Discord text,
  then the AI paragraph. Turn bare URLs into links everywhere and let them break on
  phones (`overflow-wrap: anywhere`).
- **Clean the summary the same way.** Drop a summary that is only a URL, only
  Markdown emphasis, or only "Requires X"; fall back to the AI sentence, labelled as now.
- **Filter the gallery.** Drop images from donation and badge hosts (ko-fi,
  buymeacoffee, patreon, shields.io, forum smileys), images the post uses as an avatar
  or title banner where a width is known, and anything under about 200px on a side
  where the size is known. Where nothing survives, show no Screenshots section.
- **Scroll to the top on every route change** (site only, one line in `app.js`).
- **Make release rows say what they do**: a chevron on rows with notes and "Read the
  notes" on hover; leave the "no notes" label off entirely.
- **Even out the cards**: clamp the summary to three lines with an ellipsis and let the
  badges sit at the foot.

### 1. Put search in the header, on every page (site only, small)

Today the search box is only on Home and Browse. Someone on a mod page who wants another
mod has to go back. Put one search box in the header bar, send it to Browse, and let the
`/` key focus it. Show a small result dropdown (top five names) as they type, because
`mods.json` is already loaded.

### 2. Change what Browse shows by default (site only, small)

Alphabetical order over 906 mods, 48 to a page, is nineteen pages of A to Z. Nobody reads
that. Default to "for the current game version first", then by most recently released,
then by name. Add a "Current game version only" switch that is on by default (with the
count of hidden older mods shown, and one click to include them). Fold "0.98", "0.98a"
and "0.98a-RC8" into one filter choice.

### 3. Tidy the public categories (builder, medium)

Publish a small, fixed set of public categories (about twelve: Factions, Ships and
weapons, Utilities and libraries, Quality of life, Campaign and exploration, Portraits
and flags, Audio and visual, Total conversions, and so on) mapped from the raw names,
and keep the raw names in the per-mod file for the Details box. Drop "Discord Only" as a
category and show it as a source instead. Then show the categories as a row of clickable
chips on Home and at the top of Browse, each with its count. Right now the only way to
browse by kind is a dropdown with 25 overlapping names.

### 4. Replace the author dropdown with a typeahead (site only, small)

A dropdown of 589 names is unusable. Search already covers authors, so the dropdown can
go; in its place, a small "People" result group in the search dropdown from item 1, and
an authors index page (`#/authors`) listing everyone with their mod counts.

### 5. Make the mod page answer the reader's questions in order (site only, medium)

The order a reader wants is: what is it, is it for my game version, can I add it to my
save, what does it need, how do I get it, what changed lately, where do I talk to the
author. Today the links out (forum thread, Discord, source code, license) are in a
Details box at the very bottom, under the release history. Changes:

- A top strip with the picture on one side and the name, authors, version, game version,
  save-compatibility and download button on the other.
- The forum thread link moved up next to the download, as the second action on the page.
  For the 294 mods with no direct download, make "Get it from the forum thread" (or
  Discord) the primary button so no page is a dead end.
- A "Needs" line for dependencies (see item 7), right under the header.
- Screenshots open in a simple in-page lightbox instead of a raw image in a new tab.
- "More by this author" and "Similar mods" (same category) at the foot, so the page leads
  somewhere instead of ending.

### 6. (Folded into item 0: the formatted forum-post description.)

### 7. Publish dependencies (builder and LLM prompt, medium, the most valuable data item)

A Starsector mod nearly always needs LazyLib, MagicLib, GraphicsLib or Nexerelin. That is
the single most useful fact a modding site can show and Starmodder does not show it. Add
`requires` (a list of mod names, ideally resolved to mod ids so each is a link) to the
LLM extraction and publish it in both `mods.json` (so it can be a filter: "show mods that
need Nexerelin") and the per-mod file. The existing `addons[].requires` field shows the
pattern already works.

### 8. A release feed people can subscribe to (builder, small)

The builder already writes `updates.json`. Write `updates.xml` (RSS or Atom) next to it
and link it from the header and the Home page. Modders and server admins live in RSS and
Discord; a static feed file costs nothing and is the thing most likely to bring people
back. A per-author feed (`authors/<name>.xml`) is a cheap second step.

### 9. Per-mod static pages for sharing and search engines (builder, medium)

Everything is behind `#/mods/<id>`, so every shared link shows the same title and no
preview in Discord, and search engines see one page. Have the builder write a tiny
`mods/<id>/index.html` for each mod: the right `<title>`, description and Open Graph
image tags, one line of visible text, and a script that sends the browser on to
`#/mods/<id>`. A plain static server serves it, nothing Cloudflare-specific is needed, and
the site's own fetching is unchanged. Do the same for authors later.

### 10. An About page, and a way to report a problem (site only, small)

A reader, and more importantly a mod author, needs one place that says: where this data
comes from, how often it is collected, what "AI" means here and how to turn it off, how
releases are worked out, and how to get a wrong entry fixed or a mod taken down. Link it
from the footer. Put a "Something wrong with this page?" link at the foot of every mod
page that opens a prefilled GitHub issue (or a forum post) naming the mod id.

### 11. "My mod list" the reader can share (site only, medium)

Starsector players build and trade mod lists constantly. Let a reader tick mods into a
list kept in the browser, see it as one page (with every download link and the
dependencies from item 7 pulled in), and share it as a single address (the ids packed
into the hash). TriOS already understands a list of mods, so a later step is an "Open
this list in TriOS" button. No server is needed for any of it.

### 12. A visual pass, once the structure is settled (site only, medium)

The look is the internal viewer's look: cyan on navy, every block a bordered panel, every
title the link colour. It reads as a tool, not a place. Keep the palette if it is wanted,
but: give the pages a type scale (the `h1` is 1.6rem, which feels small over a stack of
cards), make mod names white and leave cyan for actions, use fewer borders and more
space, and give Home a proper front: a one-line promise, the search box, the category
chips, then the releases. Offer a light theme via `prefers-color-scheme`. Run an
accessibility pass: the filter switches need `aria-pressed`, inputs need a visible focus
ring (they currently remove the outline), and a skip link is missing.

### 13. Small things that add up (site only, all small)

- Show "Updated 3 days ago" on cards where a release date is known, and colour the game
  version badge green, amber or grey for current, one behind, or old.
- Make the back button from a mod page land on the same scroll position in Browse.
- The "No picture" card should show the first letter of the name, or a category icon,
  instead of the words "No picture".
- Release rows on Home should show the mod's picture as a small thumbnail; a text list is
  easy to skim past.
- Put the footer's "Data collected 14 August" line on the mod page too, next to the
  download, as "Last checked".

## What I would not do

- No accounts, comments, ratings or endorsements. They need a server, moderation, and
  trust the site does not yet have; the forum and Nexus already do them.
- No changing the URL scheme away from the hash for the app itself. The static-shell
  pages in item 9 give sharing and search engines what they need without redirect rules.
- No rebuilding on a framework. The plain-module approach is holding up fine at this
  size and keeps the site servable from any folder.

## Suggested order

1. **Week one:** item 0 first (clean names, the forum-post description, gallery
   filtering; plus the site-only fixes in it), then items 1, 2, 4, 10 and the small
   things in 13. The site gets noticeably better for a reader.
2. **Week two, builder changes:** items 3, 7 and 8. Each needs a model change, a
   regenerated mapper, a sample-data update (the test pins the two together) and a line in
   the spec under `openspec/`.
3. **Week three:** item 5 (the mod page rework, which now has the formatted description
   and dependencies to show), item 9 (static shells), item 11 (mod lists).
4. **Week four:** item 12, the visual and accessibility pass, once the pages have their
   final shape so it is done once.

## Things worth checking before building

- Count how many mods have both a forum post and a Discord post, to size how many
  descriptions item 0 changes (Nexerelin's case is common among the bigger mods).
- Decide the public category set (item 3) with someone who knows the mod scene; it is a
  product decision, not a code one.
