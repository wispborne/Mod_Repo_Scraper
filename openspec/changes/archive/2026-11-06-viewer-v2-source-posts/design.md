## Context

Old viewer pages: `web/views/topics.js` (the forum Topics list over `GET /api/topics`, with filters `noDownload`, `noLlmExtraction`, `placeholderDetail` and others, ticking kept in `sessionStorage['viewerSelectedTopics']`, and per-topic job buttons), `web/views/bundle.js` (`renderThreadPage`, shared by `#/topics/<id>` and `#/bundle/<id>`), `web/views/discord.js` (`#/discord/<id>` over `GET /api/discord/<threadId>`), `web/views/extraction_views.js` (shared pieces: the sandboxed post frame, picture lists, download tables, LLM mods, the per-topic job bar, the staleness check), `web/views/topic_history.js` (`GET /api/topics/<id>/history`). `mod-catalog.json` records each mod's source posts and the Collections; the catalog step also knows which forum topics it left out and which post mods point elsewhere (`CatalogListings.notMods`, `pointers`), and the takedown report (`takedown-matches.json`) lists posts with every mod taken down.

## Goals / Non-Goals

**Goals:** one list and one page for both kinds of source post, with everything the old pages show, plus what happened to each post.

**Non-Goals:** the mod page and the Collection page (next change); Nexus pages (Nexus is not read by the LLM, and no viewer page shows one today); What changed (a later change; history links to the old Details diff until then).

## Decisions

### `GET /api/posts`
Query: `q`, `kind` (`all`, `topic`, `discord`; default `all`), `filters` (comma-separated list: `noDownload`, `noLlmAnswer`, `placeholder`, `leftOut`, `takenDown`, `collection`), `sort` (`lastPost`, `title`, `mods`; default `lastPost`), `dir`, `page`, `pageSize` (same rules as the other lists, 0 for all). Answer:

```
{ items: [ { kind: "topic"|"discord", id, title, author, lastPostDate, board?,
             downloads, hasLlmAnswer, isPlaceholder, outcome, modCount } ],
  total, page, pageSize,
  counts: { noDownload, noLlmAnswer, placeholder } }
```

`outcome` is the short code from the outcome route. Forum rows reuse what `GET /api/topics` already joins. Discord rows come from `discord-posts.json`, the LLM store (`discord:<id>`) and the catalog. `counts` cover the whole store, not the filtered list, so the numbers at the top do not move as you filter.

### `GET /api/posts/outcome?kind=&id=`
```
{ kind, id,
  outcome: "mods" | "collection" | "leftOut" | "pointsTo" | "takenDown" | "notInBuild",
  line: "<one plain sentence>",
  mods: [ { id, name } ],
  collection?: { id, name },
  pointsTo?: { kind, id, modId?, modName? },
  reason?: "<why it was left out>" }
```

Read from the last built `mod-catalog.json` (and `takedown-matches.json`). `line` is written by the server so the list and the page say the same thing, for example "Became 4 mods: A, B, C and D.", "Became 1 mod: A.", "A Collection page listing 4 mods.", "Left out: the LLM says it is not a mod and nothing can be downloaded.", "Points to topic 18011, where Industrial.Evolution is published.", "Taken down.", "Not in the last build." If the catalog step does not save what it left out and why, the route says "Left out." without a reason rather than guessing; adding the reason to the saved catalog is in scope only if it is a small change.

### Pages
`#/posts` and `#/posts/<kind>/<id>` with `kind` `topic` or `discord`. The nav entry is Source posts. Detail pages have breadcrumbs (Source posts → the post → History). The old viewer's shared pieces are ported once into a new-viewer module (`web2/post_parts.js`) and used by the post page. Ticked posts are kept in `sessionStorage['viewer2SelectedPosts']` as `topic:<id>` / `discord:<id>`, apart from the old viewer's list, and survive paging and reloads in the tab.

### Jobs on ticked posts
Forum topics: `rescrapeTopics`, `extractLlm`, `resolveDownloads`, `describePictures` with `topicIds`. Discord threads: `extractLlm` with `discordThreadIds`. When the ticked posts mix kinds, buttons that only work on topics say how many of the ticked posts they will act on. Each goes through the new viewer's confirm dialog (`confirmAndStart` and `describeJob`, extended for these kinds).

### Take down from a post
The post page's Take down button reads `GET /api/takedowns/preview?post=<key>` like the old page's `takeDownThreadButton`, shows the preview, and adds `takeDownMod` pending changes for the mods it would take down.

### Search
`searchRoute` sends a topic id or forum address to `#/posts/topic/<id>` and a Discord address or long id to `#/posts/discord/<id>` in the new viewer. Other text still opens the old Topics list until the new search is built.

## Risks / Trade-offs

- [The outcome reflects the last build, not the data on disk] → The line says "in the last build" where it matters, and the page keeps the old staleness warning with its Rebuild button.
- [Porting about 1,700 lines of old pages] → Port the shared parts into one module. Check each page against the old viewer on the same data.
