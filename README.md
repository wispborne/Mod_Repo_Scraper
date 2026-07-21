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
      "saveCompatibility": "Save compatible",  // the post's own words, or absent
      "summary": {...}
    } ] }
  } ]
  ```

  Each mod carries its own `downloads` and its own extras (mod version, changelog,
  support links like Patreon/Ko-fi, license, whether it can be added to an
  existing save, and a short written summary). Each
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

## Results viewer

A small local read-only web page for checking the scraped data.

Start it:

```
dart run bin/viewer_server.dart
```

Then open http://127.0.0.1:8085/ . Flags (all optional, defaults shown):

| Flag | Default | What it points at |
|------|---------|-------------------|
| `--port` | `8085` | Port to listen on |
| `--data-dir` | `new_data` | `mods-index.json`, `mods/`, the caches |
| `--outputs-dir` | `outputs` | `ModRepo.json`, `forum-data-bundle.json` |
| `--root-dir` | `.` | `merge-debug.json`, `ModRepo.log` |

The page has these views:

| View | What it shows |
|------|---------------|
| Topics | Every forum topic, searchable and filterable (no download, low-confidence only, LLM found downloads the rules missed, more than one mod, placeholder, missing game version, WIP). Open one to see the rendered post beside the rule-based downloads and the LLM's per-mod results. |
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
