# Starsector Mod Repo Scraper

A Dart application that scrapes Starsector mod metadata from the Fractal Softworks
forum and the USC Discord, then merges the results into a single
deduplicated list. It also runs a separate "QB" pipeline that produces a richer
forum-data bundle with per-topic details, images, and download links.

## Outputs

Online at: https://github.com/wispborne/StarsectorModRepo

| File | What it is |
|------|------------|
| `outputs/ModRepo.json` | Merged, deduplicated mod metadata from all enabled sources |
| `outputs/forum-data-bundle.json` | QB pipeline bundle (forum index + per-topic details) |
| `outputs/site/mods.json` | One record per mod, enough to search, filter and draw a card |
| `outputs/site/mods/<id>.json` | One file per mod, holding its whole page |
| `outputs/site/mods/<id>/index.html` | A small page per mod, so a shared link shows that mod |
| `outputs/site/updates.json` | The mods that put out a new version, newest first |
| `outputs/site/updates.xml` | The same releases as a feed anyone can subscribe to |

The last three are for the public website — see below. The first two are
unchanged by them, and TriOS keeps reading the bundle exactly as it did.

## The public website

`site/` holds a small read-only website built on the three files above: a home
page led by recent releases, a browse page with search and filters, a page per
mod at an address that never changes, a page per author, an index of everyone
with a mod here, and an About page. There is one search box in the bar at the
top of every page; "/" puts the cursor in it. It is plain HTML, CSS and
JavaScript with no build step, and it reads its data by fetching those files off
its own origin.

Browse opens on mods built for the current game release, most recently released
first. Older ones are one click away, and the page says how many there are.

Mods are filed under thirteen categories of the site's own, mapped from the 26
names the forum and Discord use between them. The names each source used are
still shown on the mod's own page.

A reader can tick mods into a list of their own, kept in their browser, and
share the whole thing as one link.

The pages are dark by default and light for anyone whose computer asks for
light pages. Both are checked for readable contrast.

Every mod has a real page of its own at `mods/<id>/`, and that is the mod's
address: the site links to it, the address bar shows it, and copying it out of
the address bar gives a link that Discord and a search engine can fetch and
read. Each of those pages is the site's own `index.html` with its title,
description and picture swapped for that mod's, so a shared link previews as
that mod rather than as the site.

Every other page is still a hash on the front document — `#/browse`, `#/about`.
Moving between the two shapes never reloads the site: a click on any link to one
of our own pages becomes a history entry, and Back and Forward draw whatever the
address then names.

The web server has to serve `index.html` for a folder — every static host does,
and the local one here is set up the same way.

A publish copies the data files and the contents of `site/` into the published
repo together, so that repo is a complete, servable copy of the site next to the
data it reads. It is served from Cloudflare Pages, but nothing in it depends on
Cloudflare: no Workers, no Pages Functions, no redirect rules.

**To serve it from an ordinary web server instead**, point that server's document
root at a clone of the published repo. Nothing else is needed — no build, no
runtime, no rewrite rules. Any static server will do:

```
git clone git@github.com:wispborne/StarsectorModRepo.git
cd StarsectorModRepo
python -m http.server 8080        # or nginx, caddy, Apache, anything
```

Then open `http://localhost:8080`. Every address the site uses is a `#/…` hash,
so a server that only serves files is enough — there is no need to send unknown
paths back to `index.html`.

**To look at the site on your own machine**, it has to be served over HTTP.
Opening `index.html` from the file system does not work — a browser refuses to
load ES modules and refuses to fetch files over `file://`, so the page comes up
blank with a CORS complaint in the console. Any static server will do.

Against the example data, which needs nothing built:

```
cd site
python -m http.server 8099
```

Then open `http://127.0.0.1:8099/?data=sample`. That reads the hand-written
files in `site/sample-data/`, which is how the site is worked on before a run
has built anything.

Against the real data, which a run writes to `outputs/site/`: the site's own
files and the data files have to sit in one folder, the way a publish puts them.
Copy both into one place and serve that:

```
mkdir -p /tmp/sitepreview && cp -r site/* outputs/site/* /tmp/sitepreview/
cd /tmp/sitepreview && python -m http.server 8099
```

Then open `http://127.0.0.1:8099` with no `?data=sample`.

**Working out which mods released** is a separate step, run at the end of every
scrape. It compares the saved bundles and only records a release when a mod's
version really moves forward — see `lib/site/release_detector.dart` for the
rules. To fill in the history from bundles already saved, run it over all of them
once:

```
dart run bin/backfill_releases.dart --data-dir qb_data
```

## For apps reading `forum-data-bundle.json`

The shipped fields are unchanged: `updatedAt`, `index` (a list of topic
summaries), `details` (the full record per topic), and `assumedDownloads` (the
rules-based downloads, keyed by topic ID). What is new is one optional field on
each `index` item: `llm`.

- **The rules result.** A plain set of rules reads each post and finds downloads.
  This is always present and never touched by the AI. The downloads live in
  `assumedDownloads`, keyed by topic ID:

  ```
  "assumedDownloads": { "12345": [ { "originalUrl": "...", "confidence": "high", ... } ] }
  ```

  Use this when the AI feature is off (the default). The mod details and the
  topic index (`details`, `index`) are always present too.

- **The AI result, on each topic.** When the AI (LLM) ran and found something for
  a topic, its output hangs off that topic's `index` item as an `llm` field. The
  `llm` field always holds a `mods` list — one entry for a normal single-mod
  thread, more when a thread carries several mods or a main mod plus add-ons:

  ```
  "index": [ {
    "topicId": 12345, "title": "...", ... ,
    "llm": { "mods": [ {
      "name": "...",
      "role": "main",            // main | addon | separate | variant
      "requires": null,          // for an add-on, the name of the mod it needs
      "downloads": [ {
        "url": "...",            // the raw link from the post
        "label": "...",          // the link text, word-for-word
        "kind": "direct",        // direct | mirror | trios
        "resolvedDirectUrl": "...", "sourceHost": "...", "fileName": "...",
        "confidence": "high", "requiresManualStep": false
      } ],
      "image": "ext:https://.../banner.png",  // a picture for this mod, or absent
      "version": "...", "changelog": {...}, "supportLinks": [...],
      "license": "...",
      "sourceCode": "https://github.com/someone/theirmod",  // where the code is kept, or absent
      "saveCompatibility": "Save compatible",  // the post's own words, or absent
      "summary": {...}
    } ] }
  } ]
  ```

  Each mod carries its own `downloads` and its own extras (mod version, changelog,
  support links like Patreon/Ko-fi, license, a link to where the code is kept,
  whether it can be added to an existing save, and a short written summary). Each
  download is filled out the same way the rules do it, so it has a
  direct URL, file name, and manual-step flag and can be used on its own.
  A single-mod thread is just a one-item `mods` list.

  When a thread holds more than one mod (or a main mod plus add-ons), a mod may
  also carry its own `image` — a picture taken from the post, given in the same
  `ext:<url>` form as the thread's `thumbnailPath`, so each mod can show its own
  banner. The field is absent when the post ties no clear picture to that mod.

### Which one to read

When a topic's `index` item **has** an `llm` field, that is the full answer for
that topic's mods and downloads — use it, and you do not need `assumedDownloads`
for that topic. When the `llm` field is **absent** (the AI feature was off, or it
found nothing for that topic), use the rules-based `assumedDownloads`.

`assumedDownloads` is always the rules-only list; the AI never writes into it.

`ModRepo.json` is rules-only and carries no AI data.

## Settings

Everything is driven by one file, `config.properties`, sitting next to the
program. Start from the example:

```
cp config.example.properties config.properties
```

`config.example.properties` lists every setting with its default and a note on
what it does, so it doubles as the reference. Your own `config.properties` is
ignored by git, because it holds real tokens — keep it that way.

Every setting is optional; leave one out and its default applies. A key that
isn't recognised is warned about at startup and then ignored, so a typo or an
old name shows up rather than quietly doing nothing.

The names are grouped by what they belong to: `modrepo_` for the merged-list
pipeline, `qb_` for the forum-bundle pipeline, `llm_` for the optional AI pass.
Only `log_level` stands on its own.

## Results viewer

A small local web page for checking the scraped data.

Start it:

```
dart run bin/viewer_server.dart
```

Or, on a machine with no Dart installed, unpack `mod_repo_scraper_server.tar.gz`
from a release and run `./mod_repo_scraper_server`. Unpack it **in the same
folder as `mod_repo_scraper`**: the archive holds the program and the `web/`
folder it serves, and both programs look for `qb_data/`, `outputs/` and
`config.properties` in the folder they are started from.

Then open http://127.0.0.1:8085/ . Flags (all optional, defaults shown):

| Flag | Default | What it points at |
|------|---------|-------------------|
| `--port` | `8085` | Port to listen on |
| `--data-dir` | `qb_data` | `mods-index.json`, `mods/`, the caches |
| `--outputs-dir` | `outputs` | `ModRepo.json`, `forum-data-bundle.json` |
| `--root-dir` | `.` | `merge-debug.json`, `ModRepo.log` |
| `--web-dir` | `web` | The viewer's own pages, served as-is |
| `--config` | `config.properties` | Read only to set up the manager (see below) |
| `--no-manager` | off | Run as the plain read-only viewer |

The pages themselves only read. The one thing that writes is the manager, and
only when you ask it to run a job.

The page has these views:

| View | What it shows |
|------|---------------|
| Topics | Every forum topic, searchable and filterable (no download, low-confidence only, LLM found downloads the rules missed, more than one mod, placeholder, missing game version, WIP). Open one to see the rendered post beside the rule-based downloads and the LLM's per-mod results. When the manager is on, each row has a tick box for picking mods to act on. |
| Runs | What is running now, what is waiting, and every past run. Start a job, stop the running one, and open a run to read its record and its log. |
| LLM Test | The LLM test-mode report (`llm-test-output.json`), if you ran a test pass. |
| Merge | The merge run: summary, phase timings, match groups with reasons, and the pre-dedup / same-source / validation removals. Needs `merge-debug.json` (see below). |
| ModRepo | The merged `ModRepo.json`, with each mod's contributing sources. |
| Bundle | The `forum-data-bundle.json` that TriOS receives, plus a labeled card that approximates how TriOS shows a mod. |
| Files | The known output files, with a raw viewer (JSON pretty-printed; large files loaded in chunks). |
| Log | `ModRepo.log`, with a text filter and jump-to-end. |

### Merge debug data

When merge debug output is turned on, the scraper writes `merge-debug.json`
(in the repo root), which the Merge view reads. This replaces the old
`MergeDebug.html` page — the HTML report is no longer produced.

Turn it on with `modrepo_merge_debug=true` in `config.properties`.

## Jobs and run history

The QB pipeline runs as a **job**: a request that spells out what to do. The
command line turns your `config.properties` settings into one job and hands it
to the manager, so running the program works exactly as it always has. The job
kinds are:

| Kind | What it does |
|------|--------------|
| `fullRun` | Walk the boards and scrape, the way a normal run does |
| `rescrapeTopics` | Fetch the chosen mods fresh and redo everything for them |
| `resolveDownloads` | Work out the chosen mods' download links again |
| `extractLlm` | Ask the LLM about the chosen mods again |
| `llmCoveragePass` | Fill in LLM results for every saved mod, without scraping |
| `llmTest` | Try the prompt on a few saved posts and write a report |
| `rebuildBundle` | Build `forum-data-bundle.json` again from what is saved |

Each per-mod kind throws away one layer of saved answers and nothing else, so
redoing the downloads for one mod never disturbs its LLM results, and never
touches any other mod.

The config file now has three kinds of setting, and the split is enforced by the
code:

- **Environment** — where the files live and which services may be used:
  `qb_data_path`, `qb_manager_url`, `llm_base_url`, `llm_model`, the API keys,
  `log_level`.
- **Guardrails** — the limits that bind every job, whoever asked for it:
  `llm_max_topics`, `qb_delay_ms`, `llm_timeout_seconds`.
- **Job shape** — what a run should do: `qb_scope`, `qb_boards`, the page
  limits, `qb_use_cached`, `llm_enabled`, `llm_reprocess_only`, `llm_test_mode`.
  Only the command line reads these, to build its job.

Every run is recorded in `<qb_data_path>/runs/`: `runs-index.json` holds one
entry per run (what was asked for, when, how it went, counters, any error), and
each run also gets its own log file next to it. The record is written as the run
goes, so a run that is killed still leaves an honest account of how far it got —
and the next start marks it as interrupted. The viewer's **Runs** view is how you
read all this without opening the files.

### Running jobs from the browser

With the viewer open, the top bar always says what the manager is doing: the job
that is running and how far along it is, "manager ready" when nothing is, or
"viewing only" when this server can't run jobs. Clicking it opens the **Runs**
view.

From there you can:

- **Watch** the running job — progress, which phase it is in, which mod it is on
  — and stop it. Stopping happens between mods and keeps everything saved so far.
- **Look back**: every past run, newest first, with when it ran, how long it
  took, how it ended, its counters, and a badge when a spending cap cut it short.
  Open one to read its whole record and its log, and to press **Run this again**,
  which asks for exactly the same thing over again.
- **Start a job**: a full run (you pick the scope, the boards, and whether to ask
  the LLM), an LLM coverage pass, or a bundle rebuild. Every choice is on the
  form in front of you — nothing is taken from `config.properties` behind your
  back.

On the **Topics** view, tick the mods you want and use the bar at the top:
re-scrape, re-resolve downloads, or re-run the LLM on just those. The ticks stay
put while you page and search, and are cleared once you send the job. A single
mod's page has the same three buttons for itself alone.

Every button says what it is about to do, and what it costs — network requests,
LLM budget — before it does it. Jobs started from the browser always fetch fresh
pages; replaying saved pages stays a command-line option (`qb_use_cached`).

When the server has no config file, none of this appears: no tick boxes, no
buttons, and the Runs view explains in one sentence how to turn the manager on.
Viewing-only is a normal way to run the server, not a broken one.

### Running jobs from the server

When the viewer server can read a config file, it also offers a management API
under `/api/manager/`. Jobs asked for here go through the same queue and land in
the same run history as jobs started from the command line.

| Route | What it does |
|-------|--------------|
| `GET /api/manager/status` | Whether the manager is on, which folder it works on, what is running (with its phase and current item), and what is queued |
| `POST /api/manager/jobs` | Start a job. The body is a job request, e.g. `{"kind":"extractLlm","topicIds":[123],"runLlm":true}`. Answers straight away with the queued run |
| `POST /api/manager/jobs/cancel` | Stop the running job. It stops between mods and keeps what it has saved |
| `GET /api/manager/runs` | Past runs, newest first, paged with `page` and `pageSize` |
| `GET /api/manager/runs/<id>` | One run's record |
| `GET /api/manager/runs/<id>/log?tail=N` | The end of that run's own log (200 lines by default) |

A request that can't be read, names a kind that doesn't exist, or asks for a
per-mod kind with no mods listed is refused with a plain reason and never
reaches the queue.

If there is no config file to read (or you pass `--no-manager`), the viewer runs
exactly as before and every manager route answers "the manager is off". The
server only ever binds to `127.0.0.1`, and **no setting from the config file is
ever sent over HTTP** — not tokens, endpoints, models or limits. The one
exception is the data folder, which the command line needs to check both sides
mean the same folder.

The server reads the config file for the folder to work on (`qb_data_path`). If
you started it with a `--data-dir` that points somewhere else, it says so at
startup, because the pages would then be showing a different folder from the one
jobs write to.

### Running the command line through the server

Set `qb_manager_url` in `config.properties` (for example
`http://127.0.0.1:8085`) and the command line hands its QB job to that server
instead of doing the work itself. The console looks the same — same phases, same
progress bar, fed by asking the server about once a second — and Ctrl-C asks the
server to stop the job, then waits for it to settle. A second Ctrl-C stops
watching and leaves the server to finish.

Leave the key blank (the default) and the command line does the work itself,
exactly as it always has. If the address can't be reached, the server has no
manager, or it works on a different folder, the command line says so in plain
words and runs the job itself. A problem handing over the job never means the
job is quietly skipped.

### One writer at a time

While a job runs, whoever is running it holds a lock file,
`<qb_data_path>/scraper.lock`, holding their process id, whether they are the
`server` or the `cli`, and when they started. A second job on the same folder —
from the other program — waits its turn and says who it is waiting for, rather
than writing the same files at the same time. A lock left behind by a program
that has since died is cleared away, with a line in the log saying so. The file
exists only while a job is running.

## Scrapers

There are two scrapers that can be run independently based on the configuration.properties file.

`bot/scraper` contains the one written by Wisp, originally in Kotlin. It scrapes the USC Discord and the Forum's Mod Index and Modding subforum.

`bot/scraper/qb` contains a modified version of the one written by @theRoastSuckling aka kyuubi_, originally in C#. [Link to original scraper](https://github.com/theRoastSuckling/QBMBAMM/tree/main/src/QBModsBrowser.Scraper). It scrapes the Forum's Mod Index, Modding & Libraries subforums, and fetches the post stats and html from each individual mod page.

## How merging works (according to AI)

`mod_merger.dart` runs in stages:

1. **Bucket by forum topic id** — mods that share a `topic=<id>` URL are
   guaranteed matches and grouped first.
2. **Trigram candidate index** — for the remaining mods, a trigram index
   narrows comparisons to plausible candidates so matching stays roughly
   linear instead of O(n²).
3. **Fuzzy + alias match** — names go through `_prepForMatching` (lowercased,
   non-alpha stripped) and a subsequence-based fuzzy match (sublime-fuzzy
   port). Authors are normalized through ~50 hardcoded alias groups in
   `mod_repo_utils.dart`.
4. **Same-source dedup, merge, validate** — duplicates within a source are
   removed, fields are merged across sources, and the final list is validated.
