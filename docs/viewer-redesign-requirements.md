# Results viewer redesign: requirements

Written 5 November 2026. These are the requirements for a full redesign of the results
viewer (`web/`, `lib/viewer/`, `bin/viewer_server.dart`). This is the local tool for running
the scraper and checking its data. It is not Starmodder, the public site in `site/`.

The layout and look were chosen from prototypes on 5 November 2026. See **Layout and look**.
Each part of the build gets its own openspec change that refers to this file.

## Who uses it and why

- **One user:** the person who runs the scraper. It is an expert's tool, but every label,
  message and explanation is written in plain English.
- **What it is for, in order of importance:**
  1. **Operate:** start jobs, watch them, publish, change settings.
  2. **Correct:** takedowns, author aliases, dependency names.
  3. **Investigate:** find out why a mod looks the way it does on Starmodder or in TriOS.
- **Devices:** desktop first. On a phone, the status bar, the Control page, the run pages
  and Takedowns must work. The diff and explorer pages can be desktop only.
- **Look:** dark only. Every page fits a lot of information while staying easy to scan and read.
  Different from Starmodder, so the internal tool is never mistaken for the public site.
  See **Layout and look**.

## Layout and look

The chosen layout is "Workbench" (variant C), from the prototypes in `design-samples/viewer-prototypes/`. The prototypes were in `web/prototype-control/` while the previous viewer existed.
in the "Homeworld" colours from `space-themes.html`, shown together as variant D.

### Layout

Every page uses the same code editor layout:

- **A nav rail** down the left edge: a narrow sidebar of icons only, in place of a labelled
  sidebar (see **Navigation**).
- **A toolbar** across the top of each page: the page's name, the page's main actions, the
  Pending changes count, and the search box.
- **The page's content** is below the toolbar. Pages with one main item show it in a
  large central panel. Other content goes in side panels stacked on the right. Each side panel
  has a heading bar. Each side panel can be collapsed.
- **A status bar** along the bottom edge: the running job and its progress, how many
  jobs are waiting, the build version, and the Update link.

### Colours

Use dark steel-blue greys, with sand colours for actions and borders. Each colour has one meaning:

| Name | Value | Used for |
|---|---|---|
| Background | `#11151a` | the page |
| Panel | `#171c22` | toolbars, nav rail, panel headings, status bar |
| Raised | `#212831` | buttons, chips, progress track |
| Line | `#222a33` | lines between rows and inside panels |
| Frame | `#4a4130` | the outer edges of the nav rail, toolbar, status bar and main panels |
| Text | `#dce2e8` | normal text |
| Dim text | `#8b96a2` | labels and secondary text |
| Faint text | `#7d8894` | hints, times, line numbers |
| Heading | `#f2e6cc` | page and run names |
| Action | `#e3b45a` | buttons, links, panel headings, corner brackets, the current page in the nav rail |
| Running | `#79c7c0` | what is running now |
| Done | `#8fd18a` | finished without errors |
| Failed | `#e8604f` | failed runs and errors |
| Warning | `#f2a65a` | warnings and counts that need attention |

The Action colour and the Warning colour must stay clearly different. Action means
"press this". Warning means "look at this".

### Type and shapes

- **Fonts:** words use the computer's own font (Segoe UI on Windows).
  Numbers, ids, times and logs use IBM Plex Mono. IBM Plex Sans was tried first.
  It was dropped on 5 November 2026 because it looked thinner and was harder to read on Windows.
  IBM Plex Mono is shipped with the viewer. Nothing may load from the internet.
- **Sizes:** words use 14px, smaller text uses 13px and labels use 12px.
  Their line heights are 20px, 18px and 16px. These are all whole pixels.
  The first version used 13px, 12px and 11px. Those sizes were too small to read comfortably.
- **Labels:** panel headings, toolbar titles and tab names use small IBM Plex Mono capitals
  with a little extra space between letters.
- **Shapes:** square corners everywhere. Buttons have two cut corners (top right and bottom
  left). The main panels have small corner brackets in the Action colour.
- **Status marks:** a small diamond in the status colour. "Running" is an outlined tag.
- **Progress:** a thin bar split into parts.

## How it is built and shipped

- The pages stay plain JavaScript modules with no build step, served by the Dart server.
- The API may change wherever the new pages need it.
- The new viewer is built in a new folder, `web2/`, and served by the same server behind a
  switch (`--ui v2` or a second port), so the old and new viewers can be opened against the
  same data and compared.
- **Done.** The new viewer moved from `web2/` to `web/`. The previous viewer
  was deleted. The `--ui` option was removed.
- It ships all at once. At the switch-over, `web2/` replaces `web/` and the old folder is
  deleted. The same openspec change rewrites or removes the specs that describe today's
  viewer (`viewer-server`, `viewer-output-browsing`, `viewer-merge-explorer`,
  `viewer-llm-inspection`, `runs-page`, `topic-actions`, `topic-history`,
  `bundle-comparison`, `merge-comparison`), using this file as the source. Until then
  those specs stay as they are.

## Access and security

- The server only accepts connections from the same machine (`127.0.0.1`). The copy on the
  host is reached through an SSH tunnel.
- There is no sign-in because access is limited to the same machine. If the
  viewer is ever made reachable from another machine, a sign-in must be added first, and
  the Settings page, Publish, Update and Take down must be protected.
- No secret ever reaches the browser. Secrets can be set from the Settings page, but their
  values are never sent back. Other settings are shown as they are (see **Settings**).

## Navigation

- A nav rail runs down the left edge. It has three groups in the order below.
  A short line separates each group:
  - **Operate:** Control, Run history, Settings.
  - **Correct:** Takedowns, Author aliases, Dependency names.
  - **Investigate:** the mod and source post pages, the Source posts list, What changed,
    Catalog explorer, LLM test report, Files.
- Each icon shows only its page name on hover, not its group. Its accessible label is the
  page name.
  The current page is marked in the Action colour.
- The status, the number of waiting jobs, the build version and the Update link are in the
  status bar along the bottom of every page.
- The search box is in the toolbar at the top of every page (see **Search**).
- Detail pages have breadcrumbs, such as mod → source post → history.
  Top-level pages do not, because the nav rail already shows where you are.

## Operate

### Control (the first page)

One page replaces today's Home and Runs pages. It shows what is running now, what
happened last time, and what can be started.

The job buttons are in the toolbar. The large central panel shows the live
run, or the last run when nothing is running. It has tabs for its Log, what it changed and
its Record. The side panels on the right are Pending changes, Needs attention, Queue and
Recent runs, in that order. On a phone, the side panels go below the central panel.

- **The live run:** its kind, its progress, its live counters (errors, LLM calls) and the
  latest log lines, with Stop. When nothing is running, the same panel shows the last run
  with "Run again".
- **The queue**, with the jobs waiting.
- **Start a job:** Show the four common jobs as buttons in the toolbar: "Fetch and update",
  "Run LLM", "Rebuild from saved" and "Publish". "Fetch and update" is the most
  prominent. Each button has a drop-down for its options: forum scope, boards, Discord, Nexus and LLM on or off. Use today's
  defaults. "Run LLM" has two options: "Only changed" and "All". "Only changed" is the
  default. It does what today's LLM catch-up does. It reads posts with no answer or
  whose text or prompt has changed. "All" reads every post again. "All" needs a new
  option in the API. The LLM call limit applies to both options. Also offer the other
  "Without fetching" jobs: "Scan images" and "Match dependency names". Make these less
  prominent than the four common jobs.
- **The last run's result**, with a link to what it changed.
- **Needs attention:** items that need action, each with a count and a link to
  where the user can fix them. Only items with a count above zero are shown.
  The panel is hidden when there are none:
  - dependency names that are not matched
  - suggested author pairs with no decision yet
  - takedown entries that excluded nothing, and taken-down mods that returned under a new id
  - the LLM backlog: posts with no answer yet
  - the last run's errors
  - mods whose download is missing or broken
- When the manager is off, the page says "Viewing only" in one sentence, explains how to
  turn the manager on, and shows no job buttons.

### Run history and the run page

- **Run history:** every saved run, newest first, with its kind, state, times and counters.
- **The run page:** the run's record, its live log, "Run again", and "What this run
  changed" (or "What this run has changed so far" while it is still going).
- The live log keeps the reader's scroll position and anything they have selected, and
  follows new lines only while the reader is at the bottom.

### Run notifications

- The browser tab's title shows the state while a run is going, then the result, for
  example "▶ Fetch and update 40%", then "✓ Done" or "✗ Failed".
- An optional browser notification when a run ends or fails, turned on in the viewer's
  own settings. No sound.

### Settings

A page for changing `config.properties` from the browser.

- **Every setting can be changed.** They are shown in four groups:
  - **Secrets:** the Discord token, the Nexus token, LLM keys.
  - **Environment:** folders, the LLM address and model, the fallback, how much history
    to keep.
  - **Limits:** the LLM call cap, delays, timeouts.
  - **Command-line and cron runs only:** the job-shape settings (scope, boards, cached
    replay, LLM on or off). The viewer's own jobs never read these, but the twice-daily cron
    run does.
- Each setting shows the plain-English note from `config.example.properties`.
- **Secrets:** shown only as "Set" or "Not set", with a box to type a new value and a
  Clear button. A secret's value is never sent to the browser.
- **Settings that differ from the default are marked**, and each has "Reset to default".
- **Saving:**
  - Every value is checked first: the key is known, numbers are numbers, addresses are
    addresses.
  - Before saving, the page shows the old and new values for each change (a secret only
    as "changed") and asks for confirmation.
  - The updated file is saved as a temporary file, then replaces the original. Comments and line order
    are kept. If keeping them proves too hard, the previous file is saved as
    `config.properties.bak` instead.
- **When a change takes effect:** the server reads the file again before each job, so
  nothing restarts. A setting that cannot change while the server runs (the data folder,
  the port, whether the manager is on) says "Takes effect after a restart".
- **Saving during a job is allowed.** The running job keeps the settings it started with,
  and the change applies from the next job. The save message says so.

### Updating the viewer

The Update button follows the current rules. It appears only when Gitea has a newer release and the
host can run the update. Updates are refused while a job is running or waiting. The page reloads
once the new build responds. If the update was rolled back, the page shows the log.

## Correct

### Saving corrections

- Takedowns, author aliases and dependency names all work the same way. Changes go into
  one shared **Pending changes** list. One button saves them all,
  rebuilds once, and then publishes if the "Publish afterwards" box is ticked.
- The Pending changes list is always visible while it is not empty. Each item can be
  removed before saving.
- Saving runs one job that applies every kind of change. The API needs a new job for this.
- Pending changes are kept in the browser for the session, as ticked topics are today.
  The page warns the user before they leave with unsaved changes. Changes are never stored on the
  server.
- A refused change (an unknown id, a person already on the list) is shown with the server's
  own message, and nothing is written.

### Starting corrections from other pages

Buttons on other pages add an item to the Pending changes list instead of acting at once:

- "Take down" on every mod page and source post page.
- "These are the same person" next to an author's name.
- "Match this to a mod" next to a requirement on a mod's page.

### The correction pages

Each page shows its full list:

- **Takedowns:** every entry, what it excluded from the last build, warnings (excluded
  nothing, a mod returned under a new id), the author form, and Restore.
- **Author aliases:** each person and how many mods use each of their names, suggested
  pairs, and pairs marked "different people".
- **Dependency names:** every spelling seen, how often, what it matched and how (hand entry,
  rules, LLM, not matched), saved answers that no build used, and a mod picker.

## Investigate

Investigation pages are organized by **mod**, not by output file.

### The mod page

The mod page is found by its permanent id. Its sections, in order:

1. **Header:** name, permanent id, authors, links to its Starmodder page and to its raw
   published files. Under the name: any old ids that now lead here, and its takedown
   status.
2. **What Starmodder shows:** the key fields of its published record, read from
   `outputs/site/mods/<id>.json`.
3. **Where each fact came from:** for each field, which source post and which LLM answer
   supplied it. The server does not report this yet. It must be changed to do so.
4. **Source posts:** each forum thread, Discord thread and Nexus page, with how it joined
   (forum link, name, shared download), its LLM name, and whether the rules or the LLM
   found it.
5. **History:** changes to this mod across the saved merges and bundles, matched by
   permanent id.
6. **Raw JSON**, collapsed.

The page also has per-post job buttons, which act on all of the mod's posts.

### The source post page

One page for each forum thread and each Discord thread, replacing today's thread page and
Discord thread page. It keeps what they show today: the LLM's mods with their downloads and
extras, the rules' downloads, the pictures grouped by post with their AI descriptions, the
posts in sandboxed frames, the warning when the published bundle is behind with its Rebuild
button, the per-post job buttons, the topic history, and raw JSON.

It always says what happened to the post, in one line, for example:

- "Became 4 mods: …"
- "Left out: the LLM says it is not a mod and nothing can be downloaded."
- "Points to topic 18011."
- "Taken down."

A **Collection** also gets a small page of its own that lists its mods.

### The Source posts list

Forum threads and Discord threads in one list, with search, filters and sorting. Posts can
be ticked across pages, and the per-post jobs (Re-scrape, Re-run LLM, Resolve downloads,
Scan images) act on the ticked posts. The data-quality numbers (topics with no download,
no LLM answer, placeholders) appear at the top of Investigate. Each opens this list
with the matching filter.

### What changed

One page replaces Catalog diff and Details diff. Two tabs, **Mods** and **Facts**,
share one picker for the two things being compared: two runs, or a run against the data on
disk right now. A comparison with the data on disk updates only when Refresh is pressed.

### Other investigation tools

- **Catalog explorer:** why each group of posts became one mod, before and after for a
  group, and what was removed. It stays separate from What changed, because it explains
  why a merge happened rather than what changed.
- **LLM test report**, which is still the only place that starts an LLM test job.
- **Files:** a list of the output files with their size and date. Each can be opened as raw text.

### Removed pages and features

- **Log:** it shows `ModRepo.log`, the old pipeline's log, which goes away after the switch
  to the new files. Each run's own log replaces it.
- **The Mod Details list:** the mod page replaces it.
- **Home:** Control replaces it.
- **The "mod card preview"** in the `viewer-output-browsing` spec: the code no longer has
  it, and the spec is corrected at the switch-over.

## Search

One search box at the top of every page. It finds:

- mods by name, nickname, author or permanent id
- forum topics by id or title
- Discord threads by id or name
- runs by id

Results are grouped by kind. Pasting a forum or Discord address goes straight to that
post's page.

## Rules for every page

- The state of every list (search, filters, sort, page) is kept in the address, so a
  reload, a bookmark or Back brings the same list back.
- One setting controls rows per page throughout the viewer: 25 to 500, or all.
- Detail pages end with a collapsed raw JSON section.
- Lists of collapsible sections have "Expand all".
- In a diff, a closed row names which fields changed, not how many.
- Dialogs appear within the page, never as browser popups. A confirmation dialog says in one
  sentence what the job will do.
- When the server refuses something, its message is shown exactly as written.
- Pages that compare against live data update only when Refresh is pressed, never on a
  timer.
- Icons are bundled with the app. Nothing loads from the internet.
- "Manager off" is a normal viewing-only mode, not an error: no job buttons, no tick boxes,
  and one sentence saying how to turn it on.
- Every field the scraper publishes can be seen somewhere in the viewer, even if only in
  raw JSON. When the data changes, the viewer changes with it.
- Everything can be reached by keyboard. "/" opens search, Escape closes dialogs, and Enter
  confirms the focused button. No other shortcuts until they are asked for.
- All text is plain English.
