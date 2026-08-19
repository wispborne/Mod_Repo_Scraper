## Why

The scraper knows far more about each mod than any public site shows. It has mod
versions, changelogs copied word for word from the post, whether a mod can be added to
an existing save, where the source code lives, licenses and support links. Starmodder
today reads only `ModRepo.json`, which carries none of that, and its mod version field
is empty on every single entry.

The scraper also keeps hundreds of saved bundles and can already work out what changed
between any two of them. Nothing public uses that either. Starsector players have no
way to see which mods actually got a new release this week, only which threads someone
replied in.

Starmodder 4 is a public, read-only website built on what the scraper already collects.

## What Changes

- The scraper publishes three new files for the website, alongside the outputs it
  already writes:
  - `mods.json` — one record per mod, enough to search, filter and draw a card.
  - `mods/<id>.json` — one file per mod, holding the fuller detail page data.
  - `updates.json` — a feed of real mod releases, newest first.
- A new "release detection" step works out which mods actually put out a new version,
  by comparing saved bundles. It ignores thread replies, view counts and the many cases
  where the extractor reads the same post twice and disagrees with itself.
- Every mod gets a permanent web address, based on a slug frozen the first time the mod
  is seen. Thread titles change on every release, so the address can never be built from
  the mod's current name.
- The public site is rebuilt around four page types: a home page that leads with recent
  releases, a browse page with search and filters, a page per mod, and a page per author.
- A checkbox lets the reader hide every summary the AI wrote, and the choice is
  remembered between visits.
- The site is hosted on Cloudflare Pages, served from the same repo the data is published
  to. Nothing in the site depends on Cloudflare, so it can move to your own server by
  pointing a web server at the same folder.
- `ModRepo.json` and `forum-data-bundle.json` are unchanged. TriOS keeps reading the
  bundle exactly as it does today. Nothing existing breaks.

## Capabilities

### New Capabilities
- `public-site-data`: the three files the scraper publishes for the website — what goes
  in them, what is deliberately left out, and how a mod's permanent id is decided.
- `mod-release-detection`: how a real release is told apart from noise, using saved
  bundles, the thread title and the mod's last known version.
- `public-site-pages`: the website itself — home, browse, mod page, author page, what
  each shows and how search and filters behave.

### Modified Capabilities
- `output-publishing`: the publishing step gains three more files to write and push.

## Impact

- **New code**: a public-data builder and a release detector in `lib/`, plus a new
  website in its own folder.
- **Touched code**: the publishing step, to write and push the new files.
- **Untouched on purpose**: the merge, the QB scrape, the bundle, the launcher, and the
  existing local viewer under `web/`.
- **Data quality**: the release feed rests on the LLM's version extraction, which is
  known to be unreliable. The detector is built to cope with that, and reading the
  version from the thread title is expected to replace it later.
