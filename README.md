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
