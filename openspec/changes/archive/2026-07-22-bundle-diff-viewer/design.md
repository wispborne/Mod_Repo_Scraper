## Context

The merge half of this already exists and works: `MergeSnapshotStore` keeps one gzipped snapshot per merge run in `merges/`, `compareMerges` in `lib/viewer/merge_views.dart` turns two of them into added / gone / changed rows, and `web/views/merge_compare.js` draws it. This change does the same for the bundle, and the shape of the answer is already settled — the interesting decisions are all about cost.

The numbers, measured on the real bundle:

| | size |
|---|---|
| `forum-data-bundle.json` as published | 15.5 MB |
| gzipped whole | 4.3 MB |
| gzipped without post HTML | 1.17 MB |
| a merge snapshot, for comparison | 1.15 MB |

The bundle holds three maps keyed by topic id — `index` (999 entries), `details` (904) and `assumedDownloads` (785) — plus `updatedAt` and `meta`. Nearly all the weight is `contentHtml` inside `details`.

## Goals / Non-Goals

**Goals:**

- Answer "what did this run change?" in two clicks from the run.
- Compare any two saved bundles, searchable and paged, like the merge one.
- Cost about what the merge snapshots cost, so nobody has to think about the disk.
- Share the comparison code with the merge side rather than growing a second copy of it.

**Non-Goals:**

- Diffing the words of a post. That is a different feature with a different display, and it is what makes the snapshot expensive. A post that changed is reported as changed; that is where this stops.
- Republishing an old bundle. A snapshot is deliberately not a bundle — see below.
- Comparing across data folders, or against a bundle from someone else's machine.

## Decisions

### The snapshot drops the post HTML and keeps a fingerprint

Each entry in `details` loses `contentHtml` and gains `contentFingerprint`, a short hash of the text that was there. That single change takes a snapshot from 4.3 MB to 1.17 MB — the difference between "twenty of these is 86 MB" and "twenty of these is 24 MB, the same as the merges".

What it buys: a post whose text changed still shows up as changed, with the date and everything else around it, which is the fact people are usually after. What it costs: the diff cannot show the before-and-after words. That trade was made deliberately and is written on the page, so nobody goes looking for a detail that was never kept.

**A snapshot is therefore not a bundle.** It cannot be republished, and nothing must ever treat it as an output. This is the same rule `merges/` already lives by: `bundles/` is paperwork about a run, like its log file, and the trim there deletes only its own files.

*Alternative considered:* keep the HTML but only for topics that changed this run. Rejected — it makes a snapshot's contents depend on when it was taken, so two snapshots would not be comparable on equal terms, which is the whole job.

### Every bundle-writing run saves one, at the one place bundles get written

`ScraperService._rebuildBundle()` is the single spot that publishes, so the snapshot is saved there, from the same map that was just written. Every job kind except the prompt trial `llmTest` passes through it — including the per-topic ones, which republish so their new facts reach TriOS — so they all leave a snapshot without any of them knowing snapshots exist. That is the right set: a run that changed what TriOS receives is exactly a run worth comparing.

Saving a snapshot must never fail a run that has already published. The bundle is the job; this is paperwork about it, so a failure here is a line in the run's log and nothing more.

Nothing is offered on the job form. A tick box would mean the one run you most want to compare is the one you forgot to tick.

### `qb_bundles_to_keep`, default 20

A new config key beside `modrepo_merges_to_keep`, same meaning, same 0-keeps-everything rule. `BundleSnapshotStore` copies `MergeSnapshotStore`'s trim rules exactly: only `.json.gz` files sitting directly in `bundles/`, never the one just written, never a run that has not ended.

### One comparison helper, two callers

`compareMerges` already does the work: line rows up by a key, compare a named list of fields, sort added-then-gone-then-changed, count the unchanged rather than listing them. Only two things differ for bundles — the key is the topic id (exact, no fuzzy matching needed) and the fields are different ones.

So it becomes `compareRows({older, newer, keyOf, fields, labelOf, authorOf})`, with the merge side passing its `modKey` and its field list and the bundle side passing its own. The merge behaviour must not change; its existing tests are what say so.

### Which bundle fields are worth comparing

From `index`: `title`, `author`, `category`, `lastPostDate`, `isWip`, `inModIndex`, `sourceBoard`. From `details`: `contentFingerprint` (reported as "the post text changed"), the number of images, the links. From `assumedDownloads`: the download list. Plus the LLM facts, which is the part that costs money and therefore the part worth watching.

Fields not compared: `scrapedAt` and anything else that moves on every run whether or not the mod did. A diff full of "scraped at a different time" is a diff nobody reads.

### The shortcut from a run

`#/runs/<id>` gets a "what this run changed" link when that run has a snapshot and there is an older one to compare against. It opens the bundle what-changed page with both ids already picked. The older one is simply the next snapshot down the list — snapshots are named by run id, which starts with the time, so "the one before" is just the next name down.

## Risks / Trade-offs

- **The post-HTML decision is one-way** → snapshots taken now will never be able to show post text, even if we later decide we want it. Accepted: the cost was 3.5x for a display we are not building, and the fingerprint at least tells you *which* posts to go and look at by hand.
- **Two snapshot stores that must not drift** → they follow the same rules and the merge one already has tests pinning that it deletes nothing it shouldn't. The bundle one gets the same tests. If a third ever appears, the two should be made one before that happens.
- **Snapshots pile up faster than merges** — most QB runs publish a bundle, so twenty snapshots may only cover a few days of heavy use → that is what the config key is for, and the newest twenty is exactly the window in which "what changed lately" gets asked.
- **A snapshot could be mistaken for a bundle** by something reading the folder → the file is missing `contentHtml` entirely, so anything treating it as a bundle breaks loudly and immediately rather than publishing a bundle with no post text in it.

## Migration Plan

1. Pull the comparison helper out of `merge_views.dart` with the merge tests still passing unchanged.
2. Add the snapshot store and start writing `bundles/`, with nothing reading them yet.
3. Add the compare endpoints, then the frontend, then the run shortcut.

Nothing here changes an existing output, so any step can simply be left out.

## Open Questions

- Should the run detail page show a one-line summary ("12 topics changed") without being clicked? Cheap to add later; it means computing the comparison on the runs page, so leave it until the page is real.
