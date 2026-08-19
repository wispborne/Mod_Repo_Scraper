## Context

The scraper already produces two files: `ModRepo.json` (merged mods from the forum,
Discord and Nexus) and `forum-data-bundle.json` (one record per forum thread, with post
text, downloads, and facts the LLM pulled out — mod version, changelog, license, source
code, save compatibility). It also keeps hundreds of past bundles and can already work
out what changed between any two of them.

The public site today, Starmodder 3, reads only `ModRepo.json`. That file has no mod
version on any of its 904 entries, no changelog and no save compatibility. So the site
shows a fraction of what is known.

Some numbers from the current data, which shaped the decisions below:

- 891 threads carry LLM facts; 855 of them hold exactly one mod. Multi-mod threads are 4%.
- A mod version is present on 86% of them, a changelog on 65%, save compatibility on 40%,
  a source code link on 51%.
- 904 merged mods; 742 have a forum thread, 687 of those are in the bundle. 162 mods come
  from Discord or Nexus only.
- 318 bundle threads produce no merged mod. Most are old threads for mods that are still
  alive under a newer thread, or Starfarer-era abandonware.
- Across one month of saved bundles, the LLM's mod version contradicted itself 279 times.

## Goals / Non-Goals

**Goals:**

- Publish a small set of files the public site can read, without changing anything that
  already reads the existing outputs.
- Tell real mod releases apart from thread replies and extractor noise, reliably enough
  that the feed is worth reading.
- Give every mod a web address that never changes.
- Split the work so several parts can be built at the same time.

**Non-Goals:**

- No change to `ModRepo.json`, `forum-data-bundle.json`, the merge, the scrape, or the
  local viewer under `web/`. The launcher keeps reading the bundle.
- No change to the LLM prompt. Reading the version from the thread title instead of
  asking the LLM is a follow-up, not part of this.
- No matching of old threads to their current mod. The "older versions" list on a mod
  page is designed for but left empty until that matching exists.
- No mod dependency data, no Nexus download counts, no image hosting of our own.
- No server. The site is static files.

## Decisions

**The site source lives in this repo, under `site/`.**
It has to stay in step with the shape of the data, and the same rule already applies to
the local viewer. Keeping them in one repo means one change touches both. The built site
is copied out to wherever it is hosted. The alternative — keeping it in the Starmodder
repo — was rejected because a data shape change would then need two commits in two repos
to stay correct. The publish job copies `site/` into the published repo, which is what
Cloudflare Pages serves, so the source of truth stays here and the deployed copy is
always in step with the data it was built against.

**Three files, not one.**
`mods.json` has to be small enough for a browser to fetch and search whole, so it holds
only what a card and a filter need. Everything else moves to `mods/<id>.json`, fetched
one at a time. `updates.json` is separate because the home page wants it before anything
else. One combined file would be several megabytes and would make the front page slow.

**Permanent ids are stored, not computed.**
A mod's id is worked out from its name once, then written to `qb_data/mod-ids.json` and
read back on every later run. It cannot be recomputed each time, because thread titles
carry the version and change on every release. If the id file cannot be read, the run
fails rather than publishing a site where every address has changed.

**Release detection keeps a running state, and only backfills once.**
Walking all 214 saved bundles takes real time and memory. So the detector keeps a small
file of what it currently believes each mod's version is, plus how many scrapes in a row
that reading has held. Each run advances that state by one step. The full walk over every
saved bundle is a one-off command, run once to seed the state and fill the feed's history.

**The believed version never moves backwards.**
This is the single rule that makes the feed usable. The LLM re-reads the same post and
gives an older version 279 times a month. Without this rule, every one of those makes the
site "forget" a release and announce it again when the reading recovers. Tested over a
month of real data, this rule alone removed every duplicate.

**A version must hold for two scrapes before it is believed.**
A single odd reading never reaches the feed. With twice-daily scraping this delays a
release by up to about twelve hours, which is a fair price.

**The thread title can veto, but not propose.**
Where the title carries a version, a new version that disagrees with it is dropped. Where
it carries none, it has no say. Titles are the author's own words and are far steadier
than the extractor, but only 43% of threads have one, so the title cannot be the only
source yet.

**No corroboration requirement.**
An earlier design only believed a version change when a changelog entry or download file
name also changed. Measured over the same month, that dropped about a quarter of real
releases. The rules above do the job without it.

**The shapes are agreed first, and both sides build against sample files.**
This is what makes the work parallel. Stage 1 writes the model classes and a handful of
hand-made example files. After that the data side and the website side never block each
other — the website reads the samples until the real files exist.

**Text the LLM wrote is marked, and the reader can turn it off.**
Everything else in the published data is copied from the author's post. The one-line and
one-paragraph summaries are not. They are flagged in the data, labelled on the page, and
controlled by a checkbox. The checkbox is on by default, because a summary is often the
only plain description a mod has. The choice is kept in a cookie so it holds between
visits.

`localStorage` would do the same job without a cookie banner and is what the site already
uses for the view and sort settings, so this is worth revisiting. It is one line either
way and nothing else depends on the choice.

**Hosting is Cloudflare Pages, deployed from the published repo.**
The site is static files, so Pages serves it for nothing. Pages watches the published
repo, which the publish job already pushes to twice a day — so the publish job copies the
site's own files in alongside the data, and one push updates both.

That puts the data on the same origin as the pages, served from Cloudflare's edge. The
alternative — leaving the site on Pages and fetching data from `raw.githubusercontent`,
which is what Starmodder 3 does today — was rejected: it is rate limited, poorly cached,
and a cross-origin fetch on every page load.

Nothing in the site may depend on Cloudflare. No Workers, no Pages Functions, no
redirect rules that only Cloudflare understands. Anything Pages can serve, a plain web
server can serve, so moving to your own box stays a matter of pointing a different server
at the same folder.

## Staging

Stage 1 comes first and is small. Stages 2 to 5 can then run at the same time, by
different people or in different branches. Stage 6 joins them up.

```
  Stage 1  shapes and sample files
              |
     +--------+--------+--------+--------+
     |        |        |        |        |
  Stage 2  Stage 3  Stage 4  Stage 5     |
  build    detect   site     publish     |
  the data releases shell +  the files   |
  files             browse               |
     +--------+--------+--------+--------+
              |
  Stage 6  home page, mod page, author page on real data
```

- **Stage 1 — shapes and samples.** The model classes for the three files, plus a few
  hand-written example files checked into `site/sample-data/`. Nothing else can start
  until these exist, and everything can start once they do.
- **Stage 2 — the data builder.** Turns merged mods plus the bundle into `mods.json` and
  the per-mod files. Owns the permanent id store.
- **Stage 3 — release detection.** The version cleaning, the comparison, the believed-
  version state, the backfill command, and `updates.json`.
- **Stage 4 — site shell and browse.** Page routing, permanent addresses, search,
  filters, sorting, the grid and list views, phone layout. Built against the samples.
- **Stage 5 — publishing and hosting.** Copying the data files and the site's own files
  into the published repo, removing per-mod files for mods that no longer exist, and
  wiring Cloudflare Pages up to that repo.
- **Stage 6 — the remaining pages.** Home, mod page and author page, against real data.

Stages 2 and 3 both touch the data side but share no files. Stages 4 and 5 touch nothing
either of them touches.

## Risks / Trade-offs

- **The feed rests on a noisy source.** → The rules above were tested over a month of
  real saved bundles and gave 31 releases with 29 correct. Reading the version from the
  thread title is the planned follow-up and will cut the noise at source.
- **The feed will be quiet at first.** Only about a month of saved bundles carry LLM
  facts, and the first version seen for a mod is never a release. → The home page also
  shows recently added mods, so it is not empty while the history builds.
- **Losing the id file breaks every link to the site.** → The run fails loudly rather
  than publishing new ids, and the file is small enough to keep in the published repo as
  a second copy.
- **Images are hotlinked from the forum and Discord.** A public site with traffic puts
  that load on someone else, and Discord's links expire. → Out of scope here, but it will
  need solving before the site is promoted anywhere.
- **Per-mod files mean a thousand small files in the published repo.** → Cheap on disk,
  but it makes the repo's commit history noisy, and the repo grows twice a day forever.
  Cloudflare Pages allows 20,000 files per deployment, so the count is fine, but repo
  size will need watching after a year or two. Accepted; the alternative is a slow front
  page.
- **A mod on Discord or Nexus only gets a thin page.** → The page leaves fields out
  rather than showing them empty, so it reads as deliberate.
- **Multi-mod threads are handled by showing the main mod and listing its add-ons.**
  Three threads have a second unrelated mod that this hides. → Accepted for now; 3 out of
  891.

## Open Questions

- Does the site get its own domain, or a subdomain of one you already have?
- Should the AI summary setting live in a cookie or in `localStorage`? Cookie for now.
- Is the 12-hour delay from the two-scrape settle rule acceptable, or should the feed
  show unsettled releases as provisional?
