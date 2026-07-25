## Context

Every run that publishes a Forum Data Bundle saves a snapshot of it to `qb_data/bundles/<run id>.json.gz` (about 1 MB each, 20 kept by default). The bundle diff page already compares two whole snapshots. This change reads the same files the other way round: one topic, across every kept snapshot.

Measured on real data: reading and parsing all 14 snapshots on disk takes about half a second and 997 topics each. Only 5 of those topics changed at all across two days of runs — so most histories will be short, and the page has to be honest and pleasant about "nothing changed".

The comparing machinery already exists and is spec-pinned: `topicsOf` flattens a snapshot into per-topic records, `bundleFields` says which fields matter and what to call them, `changedFields` diffs two records ([lib/viewer/bundle_views.dart](../../../lib/viewer/bundle_views.dart), [lib/viewer/compare_rows.dart](../../../lib/viewer/compare_rows.dart)).

## Goals / Non-Goals

**Goals:**

- One page that tells one topic's story: which runs changed it, and what each run changed.
- Diffs a person can read: plain-words summary lines, and list fields (downloads, LLM facts) diffed item by item.
- An "on disk now, not published" entry at the top when the working data is ahead of the published bundle.
- Honest edges: say where history ends (the oldest kept snapshot), and say plainly when nothing changed.

**Non-Goals:**

- No history beyond the kept snapshots. No ledger, no new files, no scraper changes. If deeper history is ever wanted, it is a separate change.
- No blame table ("when did each field last move") — decided against; the log answers the real question.
- No sidebar entry. The page means nothing without a topic, so it is only reached from a thread page.
- No ModRepo/merge history. The merge snapshots could feed the same page one day; not now.

## Decisions

### Read the snapshots; keep nothing new

The history is computed from the snapshots that `bundle-run-history` already saves. The alternative — an append-only ledger written by the scraper so history outlives the 20-snapshot trim — was considered and rejected for now: it puts writes on the scraper side, adds a second thing that can drift from the snapshots, and since snapshots only started existing recently, nothing has deep history to lose yet. The trade (about ten days of history on the production schedule) is accepted and stated on the page.

### The server builds the history; the browser gets a small answer

Walk the kept snapshots oldest to newest, pull the topic's record out of each with `topicsOf`'s flattening, and diff each record against the previous one with `changedFields` over `bundleFields`. Runs where nothing changed produce no entry. The browser receives only the entries — never a snapshot — matching the rule the compare route already follows.

A topic can also appear or disappear between snapshots. Those become entries too: "first seen in a saved bundle" and "dropped from the bundle", the per-topic versions of the compare page's added/gone.

### One new route: `GET /api/topics/<id>/history`

It sits with the other topic routes and returns the entries newest first, each carrying the run id, when it was saved, the kind of job (read from the run id's tail, as the compare page's pickers already do), and the changed fields. It also returns where history ends — the oldest kept snapshot's date — and how many snapshots were looked at, so the page can say "the same in all 14 saved bundles, going back to 22 July" instead of a bare empty state. No paging: an entry per changed run, at most a few dozen, and most topics will have a handful.

### Its own small cache, not the snapshot holding pen

`data_access.dart`'s `_held` pen keeps two whole snapshots — sized for the compare page's pair. A history request touches every snapshot and would evict the pen's pair each time. So the history route gets its own cache: computed answers keyed by topic id, all dropped whenever the snapshot list changes (a new snapshot saved or an old one trimmed — cheap to detect, the list is already read per request). Answers are small (a few KB), so holding hundreds is fine. The cold cost — about half a second to walk 14 snapshots — is paid once per snapshot-list change per topic, which is acceptable for a debug page; if it ever isn't, the flattened per-topic records could be cached per snapshot instead, but that is not done now.

### Lists diff item by item

The compare page shows a changed list as two JSON blobs — tolerable across 997 topics, useless on a page devoted to one. Here:

- **Downloads** are lined up by `originalUrl` — the thing that makes two entries "the same download". An added link is one `+` row, a dropped link one `−` row, and a link whose details moved (resolved URL, file name, confidence) shows only the parts that moved.
- **LLM facts** are lined up by mod name within the topic, then diffed per part: a download added or dropped, an extra (version, summary, changelog…) that changed shows old → new for that part alone. A whole mod appearing or disappearing is one row.
- **Links and images** in the detail are plain lists; added/removed rows by value, with counts.

This item-by-item diffing lives on the server beside the history builder, so the browser gets rows, not two lists to reconcile.

### Labels come from `bundleFields`

Summary lines and diff rows use the labels `bundleFields` already carries ("post text", "LLM facts", "last post"), so this page and the bundle diff page never disagree about what a field is called. The post text has no before-and-after (snapshots keep a fingerprint, not the words) — the existing `describe` wording is reused as-is.

### The working copy sits at the top of the log

The thread page already works out whether the on-disk data is ahead of the published bundle (`bundleStaleness`). The history page does the same check and, when the data is ahead (or the topic is not in any bundle yet), draws a first entry styled as unpublished — hollow dot, "on disk now, not published" — with the existing Rebuild bundle button (manager on only). This is the git viewer's "uncommitted changes" row, and it puts the fix next to the finding.

### Routes and entry

`#/topics/<id>/history` and `#/bundle/<id>/history` both render one new view module, mirroring how the thread page itself is reached two ways; the breadcrumb runs back through whichever list the reader came from, then the thread. The thread page gains a History button in its controls row, next to "Open on the forum". No sidebar entry.

### The look: a straight rail

One column, a vertical line down the left with a dot per entry — a topic has no branches, so the "graph" is a line. Filled dots for saved runs, a hollow dot for the unpublished entry, and the bottom of the rail capped with "Older runs are not kept. History starts <date>." Each entry is a collapsed card (summary line of changed-field labels) that expands to the diff, reusing the `change-card` / `diff-table` styling the compare page already has.

## Risks / Trade-offs

- [Most topics have an empty history and the page could read as broken] → The empty state names what was checked: how many snapshots, back to what date. That is a true and complete answer, not a shrug.
- [In production a full run touches every topic, so noisy fields would flood the log] → Only `bundleFields` are compared — `scrapedAt`, `replies`, `views` stay out, exactly as on the compare page. The two pages cannot drift because they share the list.
- [Half a second cold per topic if the server just restarted] → Accepted for a debug page; the per-topic cache makes repeats instant until the snapshot list changes.
- [A snapshot that fails to read would punch a hole in the timeline] → An unreadable snapshot is skipped and the neighbours are diffed across the gap; the page notes how many snapshots it could read. Same stance as `readRaw` already takes: broken paperwork degrades, never breaks the page.
- [Raising `qb_bundles_to_keep` makes the cold walk slower] → Linear at about 35 ms per snapshot, so the default 500 is a cold walk of roughly twenty seconds for the first topic looked at after a run saves a new snapshot; every topic after that is instant until the next run. That is the price of a long history with this design. If it starts to hurt, the fix is an index built once per new snapshot rather than a walk per topic — not a smaller limit.
